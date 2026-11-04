-- =====================================================================
-- Q05 · How customers pay                                     [medium]
-- Question : Which payment methods do customers use, and how often do
--            they split the cost into instalments?
-- Concepts : CASE WHEN inside an aggregate (a "conditional count")
-- =====================================================================
WITH payments AS (
    SELECT
        p.payment_type,
        COUNT(*)                         AS payments,
        COUNT(DISTINCT p.order_id)       AS orders,
        SUM(p.payment_value)             AS amount,
        AVG(p.payment_installments)      AS avg_installments,
        -- CASE returns 1 or 0 per row, so AVG = share of rows where it's true
        AVG(CASE WHEN p.payment_installments > 1 THEN 1 ELSE 0 END) AS share_in_installments
    FROM order_payments p
    JOIN delivered_orders d ON d.order_id = p.order_id
    GROUP BY p.payment_type
)
SELECT
    payment_type,
    payments,
    orders,
    ROUND(amount, 2)                                                AS amount_brl,
    ROUND(100.0 * amount / (SELECT SUM(amount) FROM payments), 1)   AS share_of_amount_pct,
    ROUND(avg_installments, 1)                                      AS avg_installments,
    ROUND(100.0 * share_in_installments, 1)                         AS pct_paid_in_installments
FROM payments
ORDER BY amount DESC;
