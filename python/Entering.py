from sqlalchemy import create_engine
import pandas as pd

# -----------------------------
# 1. LOAD CSV
# -----------------------------
df = pd.read_csv("G:/DATAPROJECT/panti/Data/brand.csv")

# -----------------------------
# 2. DEBUG: PRINT ORIGINAL COLUMNS
# -----------------------------
print("ORIGINAL COLUMNS:", list(df.columns))

# -----------------------------
# 3. FIX: REMOVE EMPTY / BAD COLUMNS
# -----------------------------

# Remove None or NaN column names
df = df.loc[:, df.columns.notnull()]

# Remove columns where column name is "" after strip
df = df.loc[:, df.columns.astype(str).str.strip() != ""]

# Remove "Unnamed: xx" columns
df = df.loc[:, ~df.columns.str.contains('^unnamed', case=False, na=False)]

# Remove columns with ALL NaN values
df = df.dropna(axis=1, how='all')

# -----------------------------
# 4. CLEAN COLUMN NAMES
# -----------------------------
df.columns = (
    df.columns
    .astype(str)
    .str.strip()
    .str.lower()
    .str.replace(' ', '_')
    .str.replace('-', '_')
    .str.replace(r'[^0-9a-zA-Z_]', '', regex=True)
)

# -----------------------------
# 5. REMOVE ANY COLUMNS THAT BECOME EMPTY AFTER CLEANING
# -----------------------------
df = df.loc[:, df.columns.astype(str).str.strip() != ""]

# -----------------------------
# 6. DEBUG: PRINT FINAL COLUMNS
# -----------------------------
print("FINAL COLUMNS:", list(df.columns))

# STOP if blank columns still exist
if any(col.strip() == "" for col in df.columns):
    raise ValueError("❌ ERROR: Still contains blank column names. Check CSV header.")

# -----------------------------
# 7. CONNECT TO MYSQL
# -----------------------------
engine = create_engine('mysql+pymysql://root:Ni#hal55@localhost:3306/panti')

# -----------------------------
# 8. UPLOAD TO MYSQL
# -----------------------------
df.to_sql('brand', con=engine, if_exists='replace', index=False)

print("✅ Data uploaded successfully!")
