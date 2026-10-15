import sqlite3, sys
import pandas as pd

query_file = sys.argv[1]
with open(query_file) as f:
    query = f.read()

conn = sqlite3.connect("olist.db")
df = pd.read_sql_query(query, conn)
conn.close()

pd.set_option("display.width", 200)
pd.set_option("display.max_columns", None)
print(df.to_string(index=False))