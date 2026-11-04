-- =====================================================================
-- Q08 · Month-over-month and year-over-year growth            [advanced]
-- Question : How fast is revenue growing month to month, and how does
--            2018 compare with the same month in 2017?
-- Concepts : window functions - LAG() and running SUM() OVER, named WINDOW
--   A window function looks at OTHER rows (e.g. the previous month)
--   without collapsing rows the way GROUP BY does.
-- =====================================================================
WITH monthly AS (
    SELECT order_month, SUM(revenue) AS revenue, COUNT(*) AS orders
    FROM delivered_orders
    GROUP BY order_month
)
SELECT
    order_month,
    orders,
    ROUND(revenue, 2)                                                  AS revenue_brl,
    ROUND(LAG(revenue) OVER w, 2)                                      AS prev_month_brl,
    -- growth % = (this month - last month) / last month
    ROUND(100.0 * (revenue - LAG(revenue) OVER w) / LAG(revenue) OVER w, 1)         AS mom_growth_pct,
    -- LAG(revenue, 12) = the same month one year earlier
    ROUND(100.0 * (revenue - LAG(revenue, 12) OVER w) / LAG(revenue, 12) OVER w, 1) AS yoy_growth_pct,
    ROUND(SUM(revenue) OVER w, 2)                                      AS running_total_brl
FROM monthly
WINDOW w AS (ORDER BY order_month)     -- define the window once, reuse it as "OVER w"
ORDER BY order_month;
