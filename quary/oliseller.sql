-- Total Sellers
SELECT 
    COUNT(DISTINCT seller_id) AS total_sellers
FROM dim_seller;
-- top 10 seller by revnue
SELECT 
    ds.seller_id,
    ds.seller_city,
    ds.seller_state,
    COUNT(DISTINCT foi.order_id) AS total_orders,
    COUNT(DISTINCT fo.customer_id) AS unique_customers,
    ROUND(SUM(foi.price), 2) AS total_revenue,
    ROUND(AVG(foi.price), 2) AS avg_order_value,
    ROUND(SUM(foi.freight_value), 2) AS total_freight,
    ROUND(SUM(foi.freight_value) / SUM(foi.price) * 100, 2) AS freight_pct,
    ROUND(AVG(DATEDIFF(fo.order_deliver_customer_date, fo.order_purchase_timestamp)), 1) AS avg_delivery_days,
    ROUND(AVG(dor.review_score), 2) AS avg_review_score,
    RANK() OVER (ORDER BY SUM(foi.price) DESC) AS revenue_rank
FROM dim_seller ds
INNER JOIN fact_order_items foi 
    ON ds.seller_id = foi.seller_id
INNER JOIN fact_orders fo 
    ON foi.order_id = fo.order_id
LEFT JOIN dim_order_review dor 
    ON fo.order_id = dor.order_id
WHERE fo.order_status = 'delivered'
    AND fo.order_deliver_customer_date IS NOT NULL
GROUP BY ds.seller_id, ds.seller_city, ds.seller_state
ORDER BY total_revenue DESC
LIMIT 10;


-- top 10 seller by order

SELECT 
    ds.seller_id,
    ds.seller_city,
    ds.seller_state,
    COUNT(DISTINCT foi.order_id) AS total_orders,
    COUNT(DISTINCT fo.customer_id) AS unique_customers,
    ROUND(SUM(foi.price), 2) AS total_revenue,
    ROUND(AVG(foi.price), 2) AS avg_order_value,
    ROUND(SUM(foi.freight_value), 2) AS total_freight,
    ROUND(SUM(foi.freight_value) / SUM(foi.price) * 100, 2) AS freight_pct,
    ROUND(AVG(DATEDIFF(fo.order_deliver_customer_date, fo.order_purchase_timestamp)), 1) AS avg_delivery_days,
    ROUND(AVG(dor.review_score), 2) AS avg_review_score,
    RANK() OVER (ORDER BY COUNT(DISTINCT foi.order_id) DESC) AS order_rank
FROM dim_seller ds
INNER JOIN fact_order_items foi 
    ON ds.seller_id = foi.seller_id
INNER JOIN fact_orders fo 
    ON foi.order_id = fo.order_id
LEFT JOIN dim_order_review dor 
    ON fo.order_id = dor.order_id
WHERE fo.order_status = 'delivered'
    AND fo.order_deliver_customer_date IS NOT NULL
GROUP BY ds.seller_id, ds.seller_city, ds.seller_state
ORDER BY total_orders DESC
LIMIT 10;


-- both
WITH revenue_ranked AS (
    SELECT 
        ds.seller_id,
        ds.seller_city,
        ds.seller_state,
        COUNT(DISTINCT foi.order_id) AS total_orders,
        ROUND(SUM(foi.price), 2) AS total_revenue,
        ROUND(AVG(foi.price), 2) AS avg_order_value,
        RANK() OVER (ORDER BY SUM(foi.price) DESC) AS revenue_rank
    FROM dim_seller ds
    INNER JOIN fact_order_items foi ON ds.seller_id = foi.seller_id
    INNER JOIN fact_orders fo ON foi.order_id = fo.order_id
    WHERE fo.order_status = 'delivered'
    GROUP BY ds.seller_id, ds.seller_city, ds.seller_state
),
order_ranked AS (
    SELECT 
        ds.seller_id,
        COUNT(DISTINCT foi.order_id) AS total_orders,
        RANK() OVER (ORDER BY COUNT(DISTINCT foi.order_id) DESC) AS order_rank
    FROM dim_seller ds
    INNER JOIN fact_order_items foi ON ds.seller_id = foi.seller_id
    INNER JOIN fact_orders fo ON foi.order_id = fo.order_id
    WHERE fo.order_status = 'delivered'
    GROUP BY ds.seller_id
)
SELECT 
    rr.seller_id,
    rr.seller_city,
    rr.seller_state,
    rr.total_orders,
    rr.total_revenue,
    rr.avg_order_value,
    rr.revenue_rank,
    COALESCE(orr.order_rank, 999) AS order_rank,
    CASE 
        WHEN rr.revenue_rank <= 10 AND COALESCE(orr.order_rank, 999) <= 10 THEN 'Both Top 10'
        WHEN rr.revenue_rank <= 10 THEN 'Top 10 Revenue Only'
        WHEN COALESCE(orr.order_rank, 999) <= 10 THEN 'Top 10 Orders Only'
        ELSE 'Other'
    END AS top_10_category
FROM revenue_ranked rr
LEFT JOIN order_ranked orr ON rr.seller_id = orr.seller_id
WHERE rr.revenue_rank <= 10 OR COALESCE(orr.order_rank, 999) <= 10
ORDER BY rr.revenue_rank;


-- 

WITH top_revenue_sellers AS (
    SELECT 
        ds.seller_id,
        ds.seller_state,
        COUNT(DISTINCT foi.order_id) AS total_orders,
        ROUND(SUM(foi.price), 2) AS total_revenue,
        ROUND(AVG(foi.price), 2) AS avg_order_value,
        ROUND(AVG(dor.review_score), 2) AS avg_review_score,
        'Top Revenue' AS category,
        RANK() OVER (ORDER BY SUM(foi.price) DESC) AS rank_position
    FROM dim_seller ds
    INNER JOIN fact_order_items foi ON ds.seller_id = foi.seller_id
    INNER JOIN fact_orders fo ON foi.order_id = fo.order_id
    LEFT JOIN dim_order_review dor ON fo.order_id = dor.order_id
    WHERE fo.order_status = 'delivered'
    GROUP BY ds.seller_id, ds.seller_state
    ORDER BY total_revenue DESC
    LIMIT 10
),
top_order_sellers AS (
    SELECT 
        ds.seller_id,
        ds.seller_state,
        COUNT(DISTINCT foi.order_id) AS total_orders,
        ROUND(SUM(foi.price), 2) AS total_revenue,
        ROUND(AVG(foi.price), 2) AS avg_order_value,
        ROUND(AVG(dor.review_score), 2) AS avg_review_score,
        'Top Orders' AS category,
        RANK() OVER (ORDER BY COUNT(DISTINCT foi.order_id) DESC) AS rank_position
    FROM dim_seller ds
    INNER JOIN fact_order_items foi ON ds.seller_id = foi.seller_id
    INNER JOIN fact_orders fo ON foi.order_id = fo.order_id
    LEFT JOIN dim_order_review dor ON fo.order_id = dor.order_id
    WHERE fo.order_status = 'delivered'
    GROUP BY ds.seller_id, ds.seller_state
    ORDER BY total_orders DESC
    LIMIT 10
),
combined_top_sellers AS (
    SELECT * FROM top_revenue_sellers
    UNION ALL
    SELECT * FROM top_order_sellers
)
SELECT 
    category,
    rank_position,
    seller_id,
    seller_state,
    total_orders,
    total_revenue,
    avg_order_value,
    avg_review_score,
    -- Performance indicators
    CASE 
        WHEN avg_order_value >= 200 THEN 'High Value'
        WHEN avg_order_value >= 100 THEN 'Medium Value'
        ELSE 'Low Value'
    END AS value_segment,
    CASE 
        WHEN avg_review_score >= 4.5 THEN '⭐ Excellent'
        WHEN avg_review_score >= 4.0 THEN '✓ Good'
        WHEN avg_review_score >= 3.5 THEN '○ Average'
        ELSE '⚠ Needs Improvement'
    END AS quality_rating
FROM combined_top_sellers
ORDER BY category DESC, rank_position;
