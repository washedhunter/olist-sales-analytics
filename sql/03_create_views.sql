-- =====================================================================
-- 03_create_views.sql
-- delivered_orders: ONE ROW PER DELIVERED ORDER, Jan 2017 - Aug 2018,
-- with revenue, delivery and review facts already attached.
--
-- Why a view? Every analysis uses the same scope and the same revenue
-- definition, written once. Items are summed per order BEFORE joining,
-- so revenue can never be double counted (the fan-out trap).
-- Created automatically by scripts/load_data.py.
-- =====================================================================

CREATE OR REPLACE VIEW delivered_orders AS
WITH order_totals AS (                       -- step 1: one row per order
    SELECT order_id,
           COUNT(*)           AS items,
           SUM(price)         AS revenue,    -- revenue = item prices (excl. freight)
           SUM(freight_value) AS freight
    FROM order_items
    GROUP BY order_id
)
SELECT
    o.order_id,
    c.customer_unique_id,                    -- the real person (not customer_id)
    c.customer_state,
    CASE                                     -- Brazil's 5 official regions
        WHEN c.customer_state IN ('SP', 'RJ', 'MG', 'ES')       THEN 'Southeast'
        WHEN c.customer_state IN ('PR', 'SC', 'RS')             THEN 'South'
        WHEN c.customer_state IN ('DF', 'GO', 'MT', 'MS')       THEN 'Center-West'
        WHEN c.customer_state IN ('AC', 'AM', 'AP', 'PA', 'RO', 'RR', 'TO') THEN 'North'
        ELSE 'Northeast'
    END AS customer_region,
    o.order_purchase_timestamp,
    DATE_TRUNC('month', o.order_purchase_timestamp)::date AS order_month,
    t.items,
    t.revenue,
    t.freight,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,
    -- days from purchase to delivery, e.g. 8.4 (NULL if no delivery date)
    ROUND(EXTRACT(EPOCH FROM o.order_delivered_customer_date - o.order_purchase_timestamp) / 86400, 1)
        AS delivery_days,
    -- delivered vs promised date: +3 = 3 days late, -5 = 5 days early
    o.order_delivered_customer_date::date - o.order_estimated_delivery_date::date AS delay_days,
    o.order_delivered_customer_date::date <= o.order_estimated_delivery_date::date AS on_time,
    r.review_score
FROM orders o
JOIN customers c       ON c.customer_id = o.customer_id
JOIN order_totals t    ON t.order_id = o.order_id
LEFT JOIN order_reviews r ON r.order_id = o.order_id      -- LEFT: keep orders even without a review
WHERE o.order_status = 'delivered'
  AND o.order_purchase_timestamp >= '2017-01-01'
  AND o.order_purchase_timestamp <  '2018-09-01';         -- the 20 complete months
