import pandas as pd
from sqlalchemy import create_engine, text

engine = create_engine("postgresql+psycopg2:///sales_dw")

# ---------- EXTRACT (from the cleaned file) ----------
# postal_code must be read as text, or leading zeros (e.g. 05401) get lost
df = pd.read_csv(
    "data/clean/clean_sales.csv",
    dtype={"postal_code": str},
    parse_dates=["order_date", "ship_date"],
)
print("Rows read:", len(df))

# ---------- TRANSFORM: build the dimension tables ----------
dim_customer = (
    df[["customer_id", "customer_name", "segment"]].drop_duplicates()
)

dim_product = (
    df[["product_id", "product_name", "category", "sub_category"]].drop_duplicates()
)

loc_cols = ["country", "region", "state", "city", "postal_code"]
dim_location = df[loc_cols].drop_duplicates()

# Calendar table: every day from Jan 1 of the first year to Dec 31 of the last year
# (ship dates can run past the last order date, so we cover both columns)
start = pd.Timestamp(year=min(df["order_date"].min(), df["ship_date"].min()).year, month=1, day=1)
end = pd.Timestamp(year=max(df["order_date"].max(), df["ship_date"].max()).year, month=12, day=31)
days = pd.date_range(start, end, freq="D")
dim_date = pd.DataFrame({
    "date_key": days.strftime("%Y%m%d").astype(int),
    "full_date": days.date,
    "year": days.year,
    "quarter": days.quarter,
    "month": days.month,
    "month_name": days.month_name(),
    "day": days.day,
    "day_name": days.day_name(),
})

# ---------- LOAD ----------
with engine.begin() as conn:   # one transaction: all of it succeeds or none of it does
    # Empty the tables so the script can be re-run safely
    conn.execute(text(
        "TRUNCATE fact_sales, dim_date, dim_location, dim_product, dim_customer "
        "RESTART IDENTITY CASCADE"
    ))

    # 1) Dimensions first (the fact table needs their keys)
    dim_customer.to_sql("dim_customer", conn, if_exists="append", index=False)
    dim_product.to_sql("dim_product", conn, if_exists="append", index=False)
    dim_location.to_sql("dim_location", conn, if_exists="append", index=False)
    dim_date.to_sql("dim_date", conn, if_exists="append", index=False)

    # 2) Read the surrogate keys back from the database
    cust_keys = pd.read_sql("SELECT customer_key, customer_id FROM dim_customer", conn)
    prod_keys = pd.read_sql("SELECT product_key, product_id FROM dim_product", conn)
    loc_keys = pd.read_sql(
        "SELECT location_key, country, region, state, city, postal_code FROM dim_location",
        conn,
    )

    # 3) Build the fact table: swap each natural ID for its surrogate key
    fact = (
        df.merge(cust_keys, on="customer_id", how="left")
          .merge(prod_keys, on="product_id", how="left")
          .merge(loc_keys, on=loc_cols, how="left")
    )
    fact["order_date_key"] = fact["order_date"].dt.strftime("%Y%m%d").astype(int)
    fact["ship_date_key"] = fact["ship_date"].dt.strftime("%Y%m%d").astype(int)

    # Safety check: no row should have lost a key in the lookups
    keys = ["customer_key", "product_key", "location_key"]
    assert fact[keys].isnull().sum().sum() == 0, "Some rows did not match a dimension!"
    assert len(fact) == len(df), "Row count changed during the merges!"

    fact = fact[[
        "row_id", "order_id", "order_date_key", "ship_date_key",
        "customer_key", "product_key", "location_key", "ship_mode", "sales",
    ]]
    fact.to_sql("fact_sales", conn, if_exists="append", index=False,
                method="multi", chunksize=1000)

# ---------- VERIFY ----------
with engine.connect() as conn:
    for table in ["dim_customer", "dim_product", "dim_location", "dim_date", "fact_sales"]:
        n = conn.execute(text(f"SELECT COUNT(*) FROM {table}")).scalar()
        print(f"{table:15s} {n}")
