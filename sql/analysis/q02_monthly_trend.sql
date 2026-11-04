-- =====================================================================
-- Q02 · Monthly revenue trend                                 [easy]
-- Question : Is the business growing? Revenue and orders per month.
-- Concepts : GROUP BY, ORDER BY, aggregates per group
-- =====================================================================
SELECT
    order_month,                                   -- first day of the month, e.g. 2017-11-01
    COUNT(*)                            AS orders,
    COUNT(DISTINCT customer_unique_id)  AS customers,
    ROUND(SUM(revenue), 2)              AS revenue_brl,
    ROUND(AVG(revenue), 2)              AS avg_order_value_brl
FROM delivered_orders
GROUP BY order_month                               -- one result row per month
ORDER BY order_month;                              -- oldest first
