-- =====================================================================
-- Q10 · Top 3 categories in each of the 5 biggest states      [advanced]
-- Question : Do different regions buy different things? Which
--            categories should we push in each key state?
-- Concepts : RANK() OVER (PARTITION BY ...), multiple CTEs, IN (subquery)
-- =====================================================================
WITH category_state AS (
    SELECT d.customer_state      AS state,
           p.product_category    AS category,
           SUM(oi.price)         AS revenue
    FROM order_items oi
    JOIN delivered_orders d ON d.order_id = oi.order_id
    JOIN products p         ON p.product_id = oi.product_id
    GROUP BY d.customer_state, p.product_category
),
ranked AS (
    SELECT state, category, revenue,
           -- rank categories WITHIN each state (1 = biggest), restarting per state
           RANK() OVER (PARTITION BY state ORDER BY revenue DESC)  AS rank_in_state,
           100.0 * revenue / SUM(revenue) OVER (PARTITION BY state) AS share_of_state
    FROM category_state
)
SELECT state, rank_in_state, category,
       ROUND(revenue, 2)        AS revenue_brl,
       ROUND(share_of_state, 1) AS pct_of_state_revenue
FROM ranked
WHERE rank_in_state <= 3
  AND state IN (                              -- the 5 states with the most revenue
      SELECT customer_state FROM delivered_orders
      GROUP BY customer_state ORDER BY SUM(revenue) DESC LIMIT 5)
ORDER BY state, rank_in_state;
