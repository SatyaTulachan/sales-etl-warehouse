import pandas as pd

df = pd.read_csv("data/raw/train.csv", encoding="latin-1")

print("--- Data types ---")
print(df.dtypes)

print("\n--- Date samples ---")
print(df[["Order Date", "Ship Date"]].head())

print("\n--- Missing postal codes ---")
print(df[df["Postal Code"].isnull()][["City", "State"]].drop_duplicates())

print("\n--- Unique counts ---")
print("customers:", df["Customer ID"].nunique())
print("products :", df["Product ID"].nunique())
print("orders   :", df["Order ID"].nunique())

print("\n--- Product IDs with more than one name ---")
names_per_id = df.groupby("Product ID")["Product Name"].nunique()
print((names_per_id > 1).sum())

print("\n--- Category values ---")
print(df["Category"].unique())
print(df["Segment"].unique())
print(df["Region"].unique())
