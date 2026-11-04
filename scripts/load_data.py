"""Phase 2: clean the raw Olist CSVs and load them into PostgreSQL.

Run from the project folder:   python scripts/load_data.py
Safe to re-run: the tables are dropped and recreated every time.
Each cleaning decision is explained in docs/data_cleaning.md.
"""
import os
from pathlib import Path

import pandas as pd
from dotenv import load_dotenv
from sqlalchemy import URL, create_engine, text

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data" / "raw"
load_dotenv(ROOT / ".env")

# Two categories are missing from Olist's translation file, so we add them ourselves
MISSING_TRANSLATIONS = {
    "pc_gamer": "pc_gamer",
    "portateis_cozinha_e_preparadores_de_alimentos": "portable_kitchen_and_food_preparers",
}


def get_engine(database):
    """Connection to one PostgreSQL database, using the details in .env."""
    url = URL.create(
        "postgresql+psycopg",
        username=os.getenv("PG_USER"),
        password=os.getenv("PG_PASSWORD"),
        host=os.getenv("PG_HOST"),
        port=int(os.getenv("PG_PORT", "5432")),
        database=database,
    )
    return create_engine(url)


def create_database(name):
    """Create the database if it doesn't exist (CREATE DATABASE needs autocommit mode)."""
    with get_engine("postgres").execution_options(isolation_level="AUTOCOMMIT").connect() as conn:
        exists = conn.execute(text("SELECT 1 FROM pg_database WHERE datname = :n"), {"n": name}).scalar()
        if not exists:
            conn.execute(text(f'CREATE DATABASE "{name}"'))
            print(f"Created database '{name}'")


def read(name, dates=()):
    """Read a raw CSV with every column as text (so zip codes like 01310 keep their zero), then parse dates."""
    df = pd.read_csv(RAW / f"{name}.csv", dtype=str)
    for col in dates:
        df[col] = pd.to_datetime(df[col])
    return df


# ---------- Cleaning: one function per table ----------

def clean_geolocation():
    geo = read("olist_geolocation_dataset").drop_duplicates()
    geo[["geolocation_lat", "geolocation_lng"]] = geo[["geolocation_lat", "geolocation_lng"]].astype(float)
    # A few points have coordinates outside Brazil: drop them before averaging
    in_brazil = geo["geolocation_lat"].between(-33.75, 5.3) & geo["geolocation_lng"].between(-74.0, -34.7)
    geo = geo[in_brazil]
    geo["geolocation_city"] = geo["geolocation_city"].str.strip()
    # Collapse ~1M points into one row per zip prefix: average position, most common city/state
    most_common = lambda s: s.mode().iloc[0]
    return geo.groupby("geolocation_zip_code_prefix", as_index=False).agg(
        geolocation_lat=("geolocation_lat", "mean"),
        geolocation_lng=("geolocation_lng", "mean"),
        geolocation_city=("geolocation_city", most_common),
        geolocation_state=("geolocation_state", most_common),
    )


def clean_products():
    products = read("olist_products_dataset").rename(columns={
        "product_name_lenght": "product_name_length",            # fix typos from the source
        "product_description_lenght": "product_description_length",
    })
    translation = read("product_category_name_translation")
    to_english = dict(zip(translation["product_category_name"], translation["product_category_name_english"]))
    to_english |= MISSING_TRANSLATIONS
    products["product_category"] = products["product_category_name"].map(to_english).fillna("uncategorized")

    measures = ["product_name_length", "product_description_length", "product_photos_qty",
                "product_weight_g", "product_length_cm", "product_height_cm", "product_width_cm"]
    products[measures] = products[measures].astype(float).astype("Int64")   # "40.0" -> 40, blanks stay empty
    # A weight of 0 g is impossible: mark it unknown instead of guessing a value
    products.loc[products["product_weight_g"] == 0, "product_weight_g"] = pd.NA
    return products


def clean_orders():
    return read("olist_orders_dataset", dates=[
        "order_purchase_timestamp", "order_approved_at", "order_delivered_carrier_date",
        "order_delivered_customer_date", "order_estimated_delivery_date",
    ])


def clean_order_items():
    items = read("olist_order_items_dataset", dates=["shipping_limit_date"])
    items["order_item_id"] = items["order_item_id"].astype(int)
    items[["price", "freight_value"]] = items[["price", "freight_value"]].astype(float)
    return items


def clean_order_payments():
    payments = read("olist_order_payments_dataset")
    payments[["payment_sequential", "payment_installments"]] = (
        payments[["payment_sequential", "payment_installments"]].astype(int))
    payments["payment_value"] = payments["payment_value"].astype(float)
    return payments


def clean_order_reviews():
    reviews = read("olist_order_reviews_dataset", dates=["review_creation_date", "review_answer_timestamp"])
    reviews["review_score"] = reviews["review_score"].astype(int)
    for col in ["review_comment_title", "review_comment_message"]:
        reviews[col] = reviews[col].str.strip().replace("", pd.NA)    # trim spaces; blank -> empty
    # Some orders have 2-3 reviews: keep only the most recent one per order
    reviews = reviews.sort_values(["review_answer_timestamp", "review_creation_date"])
    return reviews.drop_duplicates("order_id", keep="last")


# ---------- Load ----------

def main():
    db_name = os.getenv("PG_DATABASE", "olist")
    create_database(db_name)

    # Order matters: parent tables load before the child tables that point to them
    tables = {
        "geolocation": clean_geolocation(),
        "customers": read("olist_customers_dataset"),
        "sellers": read("olist_sellers_dataset"),
        "products": clean_products(),
        "orders": clean_orders(),
        "order_items": clean_order_items(),
        "order_payments": clean_order_payments(),
        "order_reviews": clean_order_reviews(),
    }

    engine = get_engine(db_name)
    with engine.begin() as conn:    # one transaction: every table loads, or none do
        conn.exec_driver_sql((ROOT / "sql" / "01_create_tables.sql").read_text())
        for name, df in tables.items():
            df.to_sql(name, conn, if_exists="append", index=False, method="multi", chunksize=2000)
            print(f"{name:15} {len(df):>9,} rows loaded")
        # Recreate the analysis view (dropping the tables also drops views built on them)
        conn.exec_driver_sql((ROOT / "sql" / "03_create_views.sql").read_text())
        print("delivered_orders view created")
        # Gather table statistics so PostgreSQL plans fast queries straight after a fresh load
        conn.exec_driver_sql("ANALYZE")
        print("Statistics updated (ANALYZE)")
    print("Done.")


if __name__ == "__main__":
    main()
