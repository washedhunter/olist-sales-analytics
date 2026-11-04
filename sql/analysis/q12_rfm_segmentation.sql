-- =====================================================================
-- Q12 · RFM customer segmentation                             [advanced]
-- Question : Which customers are valuable, which are new, and which are
--            slipping away? (who should marketing target, and how)
-- Concepts : chained CTEs, NTILE() scoring, CASE rules for segments
--
-- RFM = Recency (how long since the last order), Frequency (how many
-- orders), Monetary (how much spent). Scores: 5 = best, 1 = worst.
-- Frequency uses fixed rules, not NTILE: 97% of customers have exactly
-- 1 order, and NTILE would split those identical values arbitrarily.
-- =====================================================================
WITH rfm AS (
    SELECT
        customer_unique_id,
        DATE '2018-09-01' - MAX(order_purchase_timestamp)::date AS recency_days,  -- day after the data ends
        COUNT(*)                                                AS frequency,
        SUM(revenue)                                            AS monetary
    FROM delivered_orders
    GROUP BY customer_unique_id
),
scored AS (
    SELECT *,
           NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score,   -- most recent 20% get 5
           NTILE(5) OVER (ORDER BY monetary)          AS m_score    -- top 20% spenders get 5
    FROM rfm
),
segmented AS (
    SELECT *,
           CASE
               WHEN frequency >= 2 AND r_score >= 4 THEN '1. Loyal & active'
               WHEN frequency >= 2                  THEN '2. Loyal, at risk'
               WHEN r_score >= 4 AND m_score >= 4   THEN '3. New, high spend'
               WHEN r_score >= 4                    THEN '4. New'
               WHEN r_score >= 2 AND m_score >= 4   THEN '5. High spend, slipping away'
               WHEN r_score >= 2                    THEN '6. Slipping away'
               ELSE                                      '7. Lost'
           END AS segment
    FROM scored
)
SELECT
    segment,
    COUNT(*)                                                    AS customers,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)          AS pct_of_customers,
    ROUND(AVG(recency_days))                                    AS avg_days_since_last_order,
    ROUND(AVG(frequency), 2)                                    AS avg_orders,
    ROUND(AVG(monetary), 2)                                     AS avg_spend_brl,
    ROUND(100.0 * SUM(monetary) / SUM(SUM(monetary)) OVER (), 1) AS pct_of_revenue
FROM segmented
GROUP BY segment
ORDER BY segment;
