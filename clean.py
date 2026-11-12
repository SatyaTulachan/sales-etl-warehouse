import os
import pandas as pd

# ---------- EXTRACT ----------
df = pd.read_csv("data/raw/train.csv", encoding="latin-1")
print("Raw rows:", len(df))

# ---------- TRANSFORM ----------
# 1. Tidy column names: "Order Date" -> "order_date", "Sub-Category" -> "sub_category"
df.columns = (
    df.columns.str.strip().str.lower()
    .str.replace(" ", "_").str.replace("-", "_")
)

# 2. Trim extra spaces in text columns
for col in df.columns:
    if pd.api.types.is_string_dtype(df[col]):
        df[col] = df[col].str.strip()

# 3. Convert dates (they are day/month/year)
df["order_date"] = pd.to_datetime(df["order_date"], format="%d/%m/%Y")
df["ship_date"] = pd.to_datetime(df["ship_date"], format="%d/%m/%Y")

# 4. Fill missing postal codes (all 11 are Burlington, Vermont = 05401)
df["postal_code"] = df["postal_code"].fillna(5401)
df["postal_code"] = df["postal_code"].astype(int).astype(str).str.zfill(5)

# 5. One name per product_id (keep the most common name)
name_map = df.groupby("product_id")["product_name"].agg(lambda s: s.mode().iloc[0])
df["product_name"] = df["product_id"].map(name_map)

# ---------- CHECKS ----------
print("Missing values left:", df.isnull().sum().sum())
print("Duplicate rows:", df.duplicated().sum())
print("Customer IDs with >1 name:",
      (df.groupby("customer_id")["customer_name"].nunique() > 1).sum())
print("Product IDs with >1 name:",
      (df.groupby("product_id")["product_name"].nunique() > 1).sum())
print("Ship date before order date:", (df["ship_date"] < df["order_date"]).sum())
print("Date range:", df["order_date"].min().date(), "to", df["order_date"].max().date())

# ---------- SAVE ----------
os.makedirs("data/clean", exist_ok=True)
df.to_csv("data/clean/clean_sales.csv", index=False)
print("Saved", len(df), "rows to data/clean/clean_sales.csv")
