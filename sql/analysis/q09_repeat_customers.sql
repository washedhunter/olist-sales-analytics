-- =====================================================================
-- Q09 · Repeat vs one-time customers                          [advanced]
-- Question : How many customers come back, how much are they worth,
--            and how soon do they return?
-- Concepts : CTE per customer, window over grouped rows, ROW_NUMBER(),
--            LEAD(), PARTITION BY
-- =====================================================================

-- Part A: one-time vs repeat customers
WITH customer_orders AS (                       -- one row per real person
    SELECT customer_unique_id,
           COUNT(*)     AS orders,
           SUM(revenue) AS revenue
    FROM delivered_orders
    GROUP BY customer_unique_id
)
SELECT
    CASE WHEN orders = 1 THEN 'one-time' ELSE 'repeat (2+ orders)' END   AS customer_type,
    COUNT(*)                                                            AS customers,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)                  AS pct_of_customers,
    ROUND(SUM(revenue), 2)                                              AS revenue_brl,
    ROUND(100.0 * SUM(revenue) / SUM(SUM(revenue)) OVER (), 1)          AS pct_of_revenue,
    ROUND(AVG(revenue), 2)                                              AS revenue_per_customer_brl
FROM customer_orders
GROUP BY 1
ORDER BY customers DESC;

-- Part B: for customers who came back, how long until their 2nd order?
WITH ordered AS (
    SELECT
        customer_unique_id,
        -- PARTITION BY = restart the numbering for each customer
        ROW_NUMBER() OVER w AS order_number,
        -- LEAD() = the NEXT order's date for the same customer
        LEAD(order_purchase_timestamp::date) OVER w - order_purchase_timestamp::date AS days_to_next_order
    FROM delivered_orders
    WINDOW w AS (PARTITION BY customer_unique_id ORDER BY order_purchase_timestamp)
)
SELECT
    CASE
        WHEN days_to_next_order = 0    THEN '1. same day'
        WHEN days_to_next_order <= 30  THEN '2. within 30 days'
        WHEN days_to_next_order <= 90  THEN '3. 31-90 days'
        WHEN days_to_next_order <= 180 THEN '4. 91-180 days'
        ELSE                                '5. after 180 days'
    END                                                AS time_to_second_order,
    COUNT(*)                                           AS customers,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct
FROM ordered
WHERE order_number = 1 AND days_to_next_order IS NOT NULL   -- first order that has a next one
GROUP BY 1
ORDER BY 1;
