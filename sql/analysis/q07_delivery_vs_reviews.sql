-- =====================================================================
-- Q07 · Does late delivery hurt review scores?                [medium]
-- Question : How does delivering early / on time / late (vs the date we
--            promised) change the customer's review?
-- Concepts : CASE WHEN to build buckets, GROUP BY a calculated column,
--            CORR() for correlation
-- =====================================================================

-- Part A: review score by how early or late the order arrived
SELECT
    CASE
        WHEN delay_days <= -10 THEN '1. 10+ days early'
        WHEN delay_days <= -1  THEN '2. 1-9 days early'
        WHEN delay_days =  0   THEN '3. on the promised day'
        WHEN delay_days <=  3  THEN '4. 1-3 days late'
        WHEN delay_days <=  7  THEN '5. 4-7 days late'
        ELSE                        '6. 8+ days late'
    END                                                          AS delivery_vs_promise,
    COUNT(*)                                                     AS orders,
    ROUND(AVG(review_score), 2)                                  AS avg_review,
    ROUND(100.0 * AVG(CASE WHEN review_score = 1 THEN 1 ELSE 0 END), 1) AS one_star_pct,
    ROUND(100.0 * AVG(CASE WHEN review_score = 5 THEN 1 ELSE 0 END), 1) AS five_star_pct
FROM delivered_orders
WHERE delay_days IS NOT NULL AND review_score IS NOT NULL
GROUP BY 1                        -- "1" = the first column in the SELECT (the bucket)
ORDER BY 1;

-- Part B: on time vs late, side by side
SELECT
    CASE WHEN on_time THEN 'on time or early' ELSE 'late' END    AS delivery,
    COUNT(*)                                                     AS orders,
    -- SUM(COUNT(*)) OVER () = total across both groups (a window function, see Q08)
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)           AS pct_of_orders,
    ROUND(AVG(review_score), 2)                                  AS avg_review,
    ROUND(100.0 * AVG(CASE WHEN review_score <= 2 THEN 1 ELSE 0 END), 1) AS low_review_pct
FROM delivered_orders
WHERE on_time IS NOT NULL AND review_score IS NOT NULL
GROUP BY on_time
ORDER BY on_time DESC;

-- Part C: correlation, from -1 to +1 (negative = later delivery, lower score)
SELECT ROUND(CORR(delay_days, review_score)::numeric, 3) AS corr_delay_vs_score
FROM delivered_orders
WHERE delay_days IS NOT NULL AND review_score IS NOT NULL;
