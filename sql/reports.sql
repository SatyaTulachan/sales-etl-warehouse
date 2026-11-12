-- Q0: Sanity check. Total sales must equal the sum in the CSV.
SELECT ROUND(SUM(sales), 2) AS total_sales, COUNT(*) AS lines, COUNT(DISTINCT order_id) AS orders
FROM fact_sales;

-- Q1: Monthly revenue and month-over-month change (CTE + LAG window function)
WITH monthly AS (
    SELECT d.year, d.month, d.month_name,
           ROUND(SUM(f.sales), 2) AS revenue
    FROM fact_sales f
    JOIN dim_date d ON d.date_key = f.order_date_key
    GROUP BY d.year, d.month, d.month_name
)
SELECT year, month, month_name, revenue,
       LAG(revenue) OVER (ORDER BY year, month) AS prev_month,
       ROUND(100.0 * (revenue - LAG(revenue) OVER (ORDER BY year, month))
             / LAG(revenue) OVER (ORDER BY year, month), 1) AS mom_change_pct
FROM monthly
ORDER BY year, month;

-- Q2: Top 10 products by sales
SELECT p.product_name, p.category, ROUND(SUM(f.sales), 2) AS revenue
FROM fact_sales f
JOIN dim_product p ON p.product_key = f.product_key
GROUP BY p.product_name, p.category
ORDER BY revenue DESC
LIMIT 10;

-- Q3: Best sub-category in each category (RANK with PARTITION BY)
SELECT category, sub_category, revenue, rank_in_category
FROM (
    SELECT p.category, p.sub_category,
           ROUND(SUM(f.sales), 2) AS revenue,
           RANK() OVER (PARTITION BY p.category ORDER BY SUM(f.sales) DESC) AS rank_in_category
    FROM fact_sales f
    JOIN dim_product p ON p.product_key = f.product_key
    GROUP BY p.category, p.sub_category
) ranked
WHERE rank_in_category <= 3
ORDER BY category, rank_in_category;

-- Q4: Sales by region and year, with each region's share of that year's total
SELECT d.year, l.region,
       ROUND(SUM(f.sales), 2) AS revenue,
       ROUND(100.0 * SUM(f.sales) / SUM(SUM(f.sales)) OVER (PARTITION BY d.year), 1) AS pct_of_year
FROM fact_sales f
JOIN dim_date d     ON d.date_key = f.order_date_key
JOIN dim_location l ON l.location_key = f.location_key
GROUP BY d.year, l.region
ORDER BY d.year, revenue DESC;

-- Q5: Top 3 customers in each segment (ROW_NUMBER)
SELECT segment, customer_name, revenue
FROM (
    SELECT c.segment, c.customer_name,
           ROUND(SUM(f.sales), 2) AS revenue,
           ROW_NUMBER() OVER (PARTITION BY c.segment ORDER BY SUM(f.sales) DESC) AS rn
    FROM fact_sales f
    JOIN dim_customer c ON c.customer_key = f.customer_key
    GROUP BY c.segment, c.customer_name
) t
WHERE rn <= 3
ORDER BY segment, rn;

-- Q6: Average days to ship by ship mode (joins the date dimension twice)
SELECT f.ship_mode,
       ROUND(AVG(sd.full_date - od.full_date), 1) AS avg_days_to_ship,
       COUNT(*) AS lines
FROM fact_sales f
JOIN dim_date od ON od.date_key = f.order_date_key
JOIN dim_date sd ON sd.date_key = f.ship_date_key
GROUP BY f.ship_mode
ORDER BY avg_days_to_ship;

