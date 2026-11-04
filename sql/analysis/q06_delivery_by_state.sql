-- =====================================================================
-- Q06 · Delivery performance by state                         [medium]
-- Question : How fast do orders arrive, and how often on time, in
--            each state? Do slow states also give lower ratings?
-- Concepts : WHERE vs HAVING, AVG of a true/false condition
-- =====================================================================
SELECT
    customer_region                                     AS region,
    customer_state                                      AS state,
    COUNT(*)                                            AS delivered_orders,
    ROUND(AVG(delivery_days), 1)                        AS avg_delivery_days,
    ROUND(100.0 * AVG(CASE WHEN on_time THEN 1 ELSE 0 END), 1) AS on_time_pct,
    ROUND(AVG(review_score), 2)                         AS avg_review
FROM delivered_orders
WHERE order_delivered_customer_date IS NOT NULL   -- WHERE filters rows BEFORE grouping
GROUP BY customer_region, customer_state
HAVING COUNT(*) >= 100                            -- HAVING filters groups AFTER grouping
ORDER BY avg_delivery_days DESC;                  -- slowest states first
