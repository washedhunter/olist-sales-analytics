-- =====================================================================
-- Q03 · Top 10 product categories by revenue                  [easy]
-- Question : Which product categories bring in the most money?
-- Concepts : JOIN across 3 tables, GROUP BY, ORDER BY ... DESC, LIMIT
-- =====================================================================
SELECT
    p.product_category                AS category,
    COUNT(DISTINCT oi.order_id)       AS orders,     -- DISTINCT: an order can hold 2+ items of a category
    COUNT(*)                          AS items_sold,
    ROUND(SUM(oi.price), 2)           AS revenue_brl,
    ROUND(AVG(oi.price), 2)           AS avg_item_price_brl,
    ROUND(AVG(d.review_score), 2)     AS avg_review   -- each item carries its order's review
FROM order_items oi
JOIN delivered_orders d ON d.order_id = oi.order_id    -- keeps only delivered orders in scope
JOIN products p         ON p.product_id = oi.product_id
GROUP BY p.product_category
ORDER BY revenue_brl DESC
LIMIT 10;
