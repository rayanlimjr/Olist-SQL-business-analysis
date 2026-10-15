import sqlite3
import pandas as pd
import glob
import os

conn = sqlite3.connect('olist.db')
for f in glob.glob("data/archive/*.csv"):
    name = os.path.basename(f).replace("olist_", "").replace("_dataset.csv", "").replace(".csv", "")
    pd.read_csv(f).to_sql(name, conn, if_exists='replace', index=False)
    print("loaded", name)
conn.close()