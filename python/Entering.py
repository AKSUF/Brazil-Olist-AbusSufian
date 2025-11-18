from sqlalchemy import create_engine
import pandas as pd

# Connect to the MySQL database
engine = create_engine('mysql+pymysql://root:Ni#hal55@localhost:3306/olist')

# Load CSV
df = pd.read_csv("G:/DATAPROJECT/Olist/archive (1)/product_category_name_translation.csv")

# Clean column names
df.columns = (
    df.columns
    .str.strip()
    .str.lower()
    .str.replace(' ', '_')
    .str.replace('-', '_')
    .str.replace(r'[^0-9a-zA-Z_]', '', regex=True)
)

# Drop unnamed columns
df = df.loc[:, ~df.columns.str.contains('^unnamed')]

# Fix data types (adjust as needed)
if 'date' in df.columns:
    df['date'] = pd.to_datetime(df['date'], errors='coerce').dt.date
if 'qty' in df.columns:
    df['qty'] = pd.to_numeric(df['qty'], errors='coerce').fillna(0).astype(int)
if 'amount' in df.columns:
    df['amount'] = pd.to_numeric(df['amount'], errors='coerce').fillna(0).astype(float)
if 'ship_postal_code' in df.columns:
    df['ship_postal_code'] = df['ship_postal_code'].astype(str)
if 'b2b' in df.columns:
    df['b2b'] = df['b2b'].astype(str).str.lower().isin(['true', '1', 'yes'])

# Upload to MySQL
df.to_sql('product_category_name_translation', con=engine, if_exists='replace', index=False)

print("✅ Data uploaded successfully!")
