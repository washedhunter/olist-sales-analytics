-- =====================================================================
-- Q04 · Revenue and freight by customer state                 [medium]
-- Question : Where do our customers and our revenue come from, and
--            where is shipping a big part of what customers pay?
-- Concepts : CTE (WITH), scalar subquery for a share of total
-- =====================================================================
WITH state_totals AS (            -- a CTE is a named temporary result we can query below
    SELECT
        customer_region                     AS region,
        customer_state                      AS state,
        COUNT(*)                            AS orders,
        COUNT(DISTINCT customer_unique_id)  AS customers,
        SUM(revenue)                        AS revenue,
        SUM(freight)                        AS freight
    FROM delivered_orders
    GROUP BY customer_region, customer_state
)
SELECT
    region,
    state,
    orders,
    customers,
    ROUND(revenue, 2)                                                       AS revenue_brl,
    -- the subquery returns one number (total revenue), used on every row
    ROUND(100.0 * revenue / (SELECT SUM(revenue) FROM state_totals), 1)     AS revenue_share_pct,
    ROUND(revenue / orders, 2)                                              AS avg_order_value_brl,
    ROUND(freight / orders, 2)                                              AS avg_freight_brl,
    ROUND(100.0 * freight / revenue, 1)                                     AS freight_pct_of_revenue
FROM state_totals
ORDER BY revenue DESC;
