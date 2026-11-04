-- =====================================================================
-- Q11 · Seller performance                                    [advanced]
-- Question : How dependent are we on a few big sellers, and which big
--            sellers give customers a poor experience?
-- Concepts : NTILE(), cumulative SUM() OVER, avoiding fan-out with a
--            seller-per-order step, HAVING
-- =====================================================================

-- Part A: revenue concentration - split sellers into 10 equal groups (deciles)
WITH seller_revenue AS (
    SELECT oi.seller_id, SUM(oi.price) AS revenue
    FROM order_items oi
    JOIN delivered_orders d ON d.order_id = oi.order_id
    GROUP BY oi.seller_id
),
deciles AS (
    SELECT seller_id, revenue,
           NTILE(10) OVER (ORDER BY revenue DESC) AS decile   -- 1 = top 10% of sellers
    FROM seller_revenue
)
SELECT
    decile,
    COUNT(*)                                                               AS sellers,
    ROUND(SUM(revenue), 2)                                                 AS revenue_brl,
    ROUND(100.0 * SUM(revenue) / SUM(SUM(revenue)) OVER (), 1)             AS pct_of_revenue,
    ROUND(100.0 * SUM(SUM(revenue)) OVER (ORDER BY decile)
                / SUM(SUM(revenue)) OVER (), 1)                            AS cumulative_pct
FROM deciles
GROUP BY decile
ORDER BY decile;

-- Part B: scorecard for the 15 biggest sellers (with at least 50 orders)
WITH seller_orders AS (
    -- one row per seller per order. Without this step, an order with 3 items
    -- from one seller would count its review and delivery 3 times (fan-out)
    SELECT oi.seller_id,
           oi.order_id,
           SUM(oi.price)                                         AS revenue,
           MAX(d.review_score)                                   AS review_score,
           MAX(CASE WHEN d.on_time THEN 1 WHEN NOT d.on_time THEN 0 END) AS on_time
    FROM order_items oi
    JOIN delivered_orders d ON d.order_id = oi.order_id
    GROUP BY oi.seller_id, oi.order_id
)
SELECT
    so.seller_id,
    s.seller_state,
    COUNT(*)                              AS orders,
    ROUND(SUM(so.revenue), 2)             AS revenue_brl,
    ROUND(AVG(so.review_score), 2)        AS avg_review,
    ROUND(100.0 * (1 - AVG(so.on_time)), 1) AS late_pct,
    CASE WHEN AVG(so.review_score) < 3.9 OR 1 - AVG(so.on_time) > 0.10
         THEN 'needs attention' ELSE 'healthy' END AS status
FROM seller_orders so
JOIN sellers s ON s.seller_id = so.seller_id
GROUP BY so.seller_id, s.seller_state
HAVING COUNT(*) >= 50
ORDER BY revenue_brl DESC
LIMIT 15;
