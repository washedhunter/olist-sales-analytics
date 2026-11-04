-- =====================================================================
-- Q01 · Business overview                                     [easy]
-- Question : How big is the business? Headline numbers for management.
-- Concepts : COUNT, SUM, AVG, COUNT(DISTINCT), ROUND, type cast (::)
-- Scope    : delivered orders, Jan 2017 - Aug 2018 (view delivered_orders)
-- =====================================================================
SELECT
    COUNT(*)                            AS delivered_orders,
    COUNT(DISTINCT customer_unique_id)  AS unique_customers,     -- real people, not customer_id
    ROUND(SUM(revenue), 2)              AS total_revenue_brl,
    ROUND(AVG(revenue), 2)              AS avg_order_value_brl,  -- AOV = revenue / orders
    ROUND(SUM(freight), 2)              AS total_freight_brl,
    ROUND(AVG(items), 2)                AS avg_items_per_order,
    -- ::numeric turns the whole numbers into decimals so the division keeps its decimals
    ROUND(COUNT(*)::numeric / COUNT(DISTINCT customer_unique_id), 3) AS orders_per_customer
FROM delivered_orders;
