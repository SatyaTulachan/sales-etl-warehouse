import pandas as pd

df = pd.read_csv("data/raw/train.csv", encoding="latin-1")

print(df.shape)
print(df.head())
print(df.columns)
print(df.isnull().sum())
print(df.duplicated().sum())
