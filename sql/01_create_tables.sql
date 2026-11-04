-- =====================================================================
-- 01_create_tables.sql
-- Clean tables for the Olist e-commerce data (PostgreSQL).
-- Run automatically by scripts/load_data.py; safe to re-run.
--
-- Data types:  VARCHAR = short text (ids, codes), TEXT = free text,
--              NUMERIC(10,2) = exact money, TIMESTAMP = date + time.
-- Constraints: PRIMARY KEY = unique row id, REFERENCES = must match a row
--              in the parent table, CHECK = value must pass a rule.
-- =====================================================================

-- Drop child tables before parents (CASCADE removes dependent links)
DROP TABLE IF EXISTS order_reviews, order_payments, order_items, orders,
                     products, sellers, customers, geolocation CASCADE;

-- One row per zip-code prefix (aggregated from ~1M raw GPS points)
CREATE TABLE geolocation (
    geolocation_zip_code_prefix VARCHAR(5) PRIMARY KEY,   -- text: keeps leading zeros
    geolocation_lat             DOUBLE PRECISION NOT NULL,
    geolocation_lng             DOUBLE PRECISION NOT NULL,
    geolocation_city            TEXT NOT NULL,
    geolocation_state           VARCHAR(2) NOT NULL
);

-- One row per order's buyer record (customer_unique_id = the real person)
CREATE TABLE customers (
    customer_id              VARCHAR(32) PRIMARY KEY,
    customer_unique_id       VARCHAR(32) NOT NULL,
    customer_zip_code_prefix VARCHAR(5) NOT NULL,          -- no FK: a few zips have no GPS data
    customer_city            TEXT NOT NULL,
    customer_state           VARCHAR(2) NOT NULL
);

CREATE TABLE sellers (
    seller_id              VARCHAR(32) PRIMARY KEY,
    seller_zip_code_prefix VARCHAR(5) NOT NULL,
    seller_city            TEXT NOT NULL,
    seller_state           VARCHAR(2) NOT NULL
);

-- Category translation is merged in, so every query gets English names
CREATE TABLE products (
    product_id                 VARCHAR(32) PRIMARY KEY,
    product_category_name      TEXT,                       -- original Portuguese (NULL if unknown)
    product_category           TEXT NOT NULL,              -- English; 'uncategorized' if unknown
    product_name_length        INT,
    product_description_length INT,
    product_photos_qty         INT,
    product_weight_g           INT CHECK (product_weight_g > 0),
    product_length_cm          INT,
    product_height_cm          INT,
    product_width_cm           INT
);

-- NULL dates mean "hasn't happened yet" (e.g. not delivered)
CREATE TABLE orders (
    order_id                      VARCHAR(32) PRIMARY KEY,
    customer_id                   VARCHAR(32) NOT NULL UNIQUE REFERENCES customers (customer_id),
    order_status                  VARCHAR(20) NOT NULL,
    order_purchase_timestamp      TIMESTAMP NOT NULL,
    order_approved_at             TIMESTAMP,
    order_delivered_carrier_date  TIMESTAMP,
    order_delivered_customer_date TIMESTAMP,
    order_estimated_delivery_date TIMESTAMP NOT NULL
);

-- One row per item line in an order (composite key)
CREATE TABLE order_items (
    order_id            VARCHAR(32) NOT NULL REFERENCES orders (order_id),
    order_item_id       SMALLINT NOT NULL,
    product_id          VARCHAR(32) NOT NULL REFERENCES products (product_id),
    seller_id           VARCHAR(32) NOT NULL REFERENCES sellers (seller_id),
    shipping_limit_date TIMESTAMP NOT NULL,
    price               NUMERIC(10,2) NOT NULL CHECK (price > 0),
    freight_value       NUMERIC(10,2) NOT NULL CHECK (freight_value >= 0),
    PRIMARY KEY (order_id, order_item_id)
);

-- One row per payment method used on an order
CREATE TABLE order_payments (
    order_id             VARCHAR(32) NOT NULL REFERENCES orders (order_id),
    payment_sequential   SMALLINT NOT NULL,
    payment_type         VARCHAR(20) NOT NULL,
    payment_installments SMALLINT NOT NULL CHECK (payment_installments >= 0),
    payment_value        NUMERIC(10,2) NOT NULL CHECK (payment_value >= 0),
    PRIMARY KEY (order_id, payment_sequential)
);

-- One review per order (the latest one, see docs/data_cleaning.md)
CREATE TABLE order_reviews (
    order_id                VARCHAR(32) PRIMARY KEY REFERENCES orders (order_id),
    review_id               VARCHAR(32) NOT NULL,
    review_score            SMALLINT NOT NULL CHECK (review_score BETWEEN 1 AND 5),
    review_comment_title    TEXT,
    review_comment_message  TEXT,
    review_creation_date    TIMESTAMP NOT NULL,
    review_answer_timestamp TIMESTAMP NOT NULL
);

-- Indexes speed up the joins and lookups used most in the analysis
CREATE INDEX idx_customers_unique_id ON customers (customer_unique_id);
CREATE INDEX idx_order_items_product ON order_items (product_id);
CREATE INDEX idx_order_items_seller  ON order_items (seller_id);
CREATE INDEX idx_orders_purchase_ts  ON orders (order_purchase_timestamp);
