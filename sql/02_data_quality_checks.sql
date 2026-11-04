-- =====================================================================
-- 02_data_quality_checks.sql
-- Run after scripts/load_data.py. Each row is one check: how many rows
-- break the rule, and what we expect. Anything unexpected = investigate.
-- =====================================================================

-- 1. Keys and duplicates (the table constraints already enforce these;
--    the queries prove it and show how you would check without them)
SELECT 1 AS check_no,
       'Duplicate order_id in orders' AS check_name,
       COUNT(*) - COUNT(DISTINCT order_id) AS rows_found,
       '0' AS expected
FROM orders

UNION ALL
SELECT 2, 'Orders with more than one review',
       COUNT(*) - COUNT(DISTINCT order_id), '0'
FROM order_reviews

-- 2. Missing links between tables (LEFT JOIN ... IS NULL finds orphans)
UNION ALL
SELECT 3, 'Orders with no items (canceled / unavailable)',
       COUNT(*), '775, kept: real orders that never shipped'
FROM orders o
LEFT JOIN order_items oi ON oi.order_id = o.order_id
WHERE oi.order_id IS NULL

UNION ALL
SELECT 4, 'Orders with no payment record',
       COUNT(*), '1, kept'
FROM orders o
WHERE NOT EXISTS (SELECT 1 FROM order_payments p WHERE p.order_id = o.order_id)

UNION ALL
SELECT 5, 'Customers whose zip has no GPS location',
       COUNT(*), '279, kept (no map point)'
FROM customers c
LEFT JOIN geolocation g ON g.geolocation_zip_code_prefix = c.customer_zip_code_prefix
WHERE g.geolocation_zip_code_prefix IS NULL

-- 3. Business-logic rules
UNION ALL
SELECT 6, 'Delivered orders missing a delivery date',
       COUNT(*), '8, kept (excluded from delivery-time metrics)'
FROM orders
WHERE order_status = 'delivered' AND order_delivered_customer_date IS NULL

UNION ALL
SELECT 7, 'Delivered to customer before purchase',
       COUNT(*), '0'
FROM orders
WHERE order_delivered_customer_date < order_purchase_timestamp

UNION ALL
SELECT 8, 'Delivered to customer before handed to carrier',
       COUNT(*), '23, kept (timestamp entry errors)'
FROM orders
WHERE order_delivered_customer_date < order_delivered_carrier_date

UNION ALL
SELECT 9, 'Products without a category',
       COUNT(*), '610, labelled uncategorized'
FROM products
WHERE product_category = 'uncategorized'

UNION ALL
SELECT 10, 'Item price zero or negative',
       COUNT(*), '0'
FROM order_items
WHERE price <= 0

-- Without ORDER BY, SQL does not guarantee the order of rows
ORDER BY check_no;
