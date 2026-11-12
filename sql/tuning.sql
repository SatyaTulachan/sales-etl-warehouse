-- Synthetic table: the fact table repeated 200 times (1.96M rows)
CREATE TABLE fact_sales_big AS
SELECT f.row_id + (g.n - 1) * 10000 AS row_id,
       f.order_id, f.order_date_key, f.ship_date_key,
       f.customer_key, f.product_key, f.location_key,
       f.ship_mode, f.sales
FROM fact_sales f
CROSS JOIN generate_series(1, 200) AS g(n);
ANALYZE fact_sales_big;

-- BEFORE (no indexes): Parallel Seq Scan
EXPLAIN (ANALYZE, BUFFERS)
SELECT SUM(sales) FROM fact_sales_big WHERE customer_key = 100;      -- ~40 ms
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM fact_sales_big WHERE order_id = 'CA-2017-152156';      -- ~44 ms

-- Add indexes
CREATE INDEX idx_big_customer ON fact_sales_big(customer_key);
CREATE INDEX idx_big_order    ON fact_sales_big(order_id);
ANALYZE fact_sales_big;

-- AFTER: Bitmap Index Scan + Bitmap Heap Scan
-- Re-run the same two queries:                                       -- ~1.7 ms and ~0.23 ms
