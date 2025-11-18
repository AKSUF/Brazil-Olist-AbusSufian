SELECT 
    review_score,
    COUNT(*) AS review_count,
    ROUND(COUNT(*) / (SELECT COUNT(*) FROM dim_order_review) * 100, 2) AS percentage,
    ROUND(SUM(COUNT(*)) OVER (ORDER BY review_score DESC) / 
          (SELECT COUNT(*) FROM dim_order_review) * 100, 2) AS cumulative_pct,
    -- Visual representation
    CONCAT(REPEAT('⭐', review_score), ' (', review_score, ')') AS star_rating,
    REPEAT('█', CAST(COUNT(*) / 2000 AS UNSIGNED)) AS distribution_bar
FROM dim_order_review
GROUP BY review_score
ORDER BY review_score DESC;


-- review for time intelligence
SELECT 
    dd.year,
    dd.quarter,
    dd.month_name,
    COUNT(dor.review_id) AS total_reviews,
    ROUND(AVG(dor.review_score), 2) AS avg_review_score,
    COUNT(CASE WHEN dor.review_score = 5 THEN 1 END) AS five_star_count,
    COUNT(CASE WHEN dor.review_score >= 4 THEN 1 END) AS positive_reviews,
    COUNT(CASE WHEN dor.review_score <= 2 THEN 1 END) AS negative_reviews,
    ROUND(COUNT(CASE WHEN dor.review_score >= 4 THEN 1 END) / COUNT(*) * 100, 2) AS positive_rate_pct,
    ROUND(COUNT(CASE WHEN dor.review_score <= 2 THEN 1 END) / COUNT(*) * 100, 2) AS negative_rate_pct,
    -- Month-over-Month change
    LAG(AVG(dor.review_score), 1) OVER (ORDER BY dd.year, dd.month) AS prev_month_avg_score,
    ROUND(AVG(dor.review_score) - LAG(AVG(dor.review_score), 1) OVER (ORDER BY dd.year, dd.month), 2) AS mom_score_change
FROM dim_order_review dor
INNER JOIN fact_orders fo ON dor.order_id = fo.order_id
INNER JOIN dim_date dd ON fo.datekey = dd.date_key
GROUP BY dd.year, dd.quarter, dd.month, dd.month_name
ORDER BY dd.year, dd.month;

-- seller review

WITH seller_review_metrics AS (
    SELECT 
        ds.seller_id,
        ds.seller_state,
        ds.seller_city,
        COUNT(DISTINCT dor.review_id) AS total_reviews,
        ROUND(AVG(dor.review_score), 2) AS avg_review_score,
        COUNT(CASE WHEN dor.review_score = 5 THEN 1 END) AS five_star_reviews,
        COUNT(CASE WHEN dor.review_score >= 4 THEN 1 END) AS positive_reviews,
        COUNT(CASE WHEN dor.review_score = 3 THEN 1 END) AS neutral_reviews,
        COUNT(CASE WHEN dor.review_score <= 2 THEN 1 END) AS negative_reviews,
        ROUND(SUM(foi.price), 2) AS total_revenue,
        COUNT(DISTINCT foi.order_id) AS total_orders,
        ROUND(AVG(DATEDIFF(fo.order_deliver_customer_date, fo.order_purchase_timestamp)), 1) AS avg_delivery_days
    FROM dim_seller ds
    INNER JOIN fact_order_items foi ON ds.seller_id = foi.seller_id
    INNER JOIN fact_orders fo ON foi.order_id = fo.order_id
    LEFT JOIN dim_order_review dor ON fo.order_id = dor.order_id
    WHERE fo.order_status = 'delivered'
        AND fo.order_deliver_customer_date IS NOT NULL
    GROUP BY ds.seller_id, ds.seller_state, ds.seller_city
    HAVING total_reviews >= 10  -- Minimum threshold for meaningful analysis
)
SELECT 
    seller_id,
    seller_state,
    seller_city,
    total_reviews,
    avg_review_score,
    five_star_reviews,
    positive_reviews,
    neutral_reviews,
    negative_reviews,
    total_revenue,
    total_orders,
    avg_delivery_days,
    -- Calculated metrics
    ROUND(positive_reviews / total_reviews * 100, 2) AS positive_rate_pct,
    ROUND(negative_reviews / total_reviews * 100, 2) AS negative_rate_pct,
    ROUND(five_star_reviews / total_reviews * 100, 2) AS five_star_rate_pct,
    -- NPS-style score (Promoters - Detractors)
    ROUND((five_star_reviews - negative_reviews) / total_reviews * 100, 2) AS nps_style_score,
    -- Quality Rating
    CASE 
        WHEN avg_review_score >= 4.5 THEN '⭐⭐⭐⭐⭐ Excellent'
        WHEN avg_review_score >= 4.0 THEN '⭐⭐⭐⭐ Very Good'
        WHEN avg_review_score >= 3.5 THEN '⭐⭐⭐ Good'
        WHEN avg_review_score >= 3.0 THEN '⭐⭐ Fair'
        ELSE '⭐ Poor'
    END AS quality_category,
    -- Performance Classification
    CASE 
        WHEN avg_review_score >= 4.5 AND negative_reviews / total_reviews <= 0.05 THEN 'Elite Performer'
        WHEN avg_review_score >= 4.0 AND negative_reviews / total_reviews <= 0.10 THEN 'Top Performer'
        WHEN avg_review_score >= 3.5 THEN 'Good Performer'
        WHEN avg_review_score >= 3.0 THEN 'Average Performer'
        ELSE 'Needs Improvement'
    END AS seller_classification
FROM seller_review_metrics
ORDER BY avg_review_score DESC, total_reviews DESC;



-- review for product category

SELECT 
    COALESCE(dp.product_category_name, 'Unknown') AS category,
    COUNT(DISTINCT dor.review_id) AS total_reviews,
    ROUND(AVG(dor.review_score), 2) AS avg_review_score,
    COUNT(CASE WHEN dor.review_score = 5 THEN 1 END) AS five_star,
    COUNT(CASE WHEN dor.review_score = 4 THEN 1 END) AS four_star,
    COUNT(CASE WHEN dor.review_score = 3 THEN 1 END) AS three_star,
    COUNT(CASE WHEN dor.review_score = 2 THEN 1 END) AS two_star,
    COUNT(CASE WHEN dor.review_score = 1 THEN 1 END) AS one_star,
    ROUND(COUNT(CASE WHEN dor.review_score >= 4 THEN 1 END) / COUNT(*) * 100, 2) AS positive_rate,
    ROUND(COUNT(CASE WHEN dor.review_score <= 2 THEN 1 END) / COUNT(*) * 100, 2) AS negative_rate,
    COUNT(DISTINCT foi.product_id) AS unique_products,
    ROUND(SUM(foi.price), 2) AS total_revenue,
    -- Category rank by review score
    RANK() OVER (ORDER BY AVG(dor.review_score) DESC) AS satisfaction_rank
FROM dim_order_review dor
INNER JOIN fact_orders fo ON dor.order_id = fo.order_id
INNER JOIN fact_order_items foi ON fo.order_id = foi.order_id
LEFT JOIN dim_product dp ON foi.product_id = dp.product_id
WHERE fo.order_status = 'delivered'
GROUP BY category
HAVING total_reviews >= 50  -- Minimum threshold
ORDER BY avg_review_score DESC, total_reviews DESC;


-- deliver time impacts on review
WITH delivery_review_data AS (
    SELECT 
        dor.review_score,
        DATEDIFF(fo.order_deliver_customer_date, fo.order_estimated_delivery_date) AS delivery_delay_days,
        DATEDIFF(fo.order_deliver_customer_date, fo.order_purchase_timestamp) AS total_delivery_days,
        CASE 
            WHEN DATEDIFF(fo.order_deliver_customer_date, fo.order_estimated_delivery_date) <= 0 THEN 'On-Time or Early'
            WHEN DATEDIFF(fo.order_deliver_customer_date, fo.order_estimated_delivery_date) BETWEEN 1 AND 3 THEN '1-3 Days Late'
            WHEN DATEDIFF(fo.order_deliver_customer_date, fo.order_estimated_delivery_date) BETWEEN 4 AND 7 THEN '4-7 Days Late'
            ELSE '8+ Days Late'
        END AS delivery_status,
        foi.price AS order_value
    FROM dim_order_review dor
    INNER JOIN fact_orders fo ON dor.order_id = fo.order_id
    INNER JOIN fact_order_items foi ON fo.order_id = foi.order_id
    WHERE fo.order_deliver_customer_date IS NOT NULL
        AND fo.order_estimated_delivery_date IS NOT NULL
        AND fo.order_status = 'delivered'
)
SELECT 
    delivery_status,
    COUNT(*) AS order_count,
    ROUND(AVG(review_score), 2) AS avg_review_score,
    ROUND(AVG(delivery_delay_days), 1) AS avg_delay_days,
    ROUND(AVG(total_delivery_days), 1) AS avg_total_delivery_days,
    COUNT(CASE WHEN review_score >= 4 THEN 1 END) AS positive_reviews,
    COUNT(CASE WHEN review_score <= 2 THEN 1 END) AS negative_reviews,
    ROUND(COUNT(CASE WHEN review_score >= 4 THEN 1 END) / COUNT(*) * 100, 2) AS positive_rate_pct,
    ROUND(COUNT(CASE WHEN review_score <= 2 THEN 1 END) / COUNT(*) * 100, 2) AS negative_rate_pct,
    ROUND(AVG(order_value), 2) AS avg_order_value
FROM delivery_review_data
GROUP BY delivery_status
ORDER BY 
    CASE delivery_status
        WHEN 'On-Time or Early' THEN 1
        WHEN '1-3 Days Late' THEN 2
        WHEN '4-7 Days Late' THEN 3
        WHEN '8+ Days Late' THEN 4
    END;


-- cooments 

SELECT 
    CASE 
        WHEN review_score = 5 THEN '5 Stars'
        WHEN review_score = 4 THEN '4 Stars'
        WHEN review_score = 3 THEN '3 Stars'
        WHEN review_score = 2 THEN '2 Stars'
        WHEN review_score = 1 THEN '1 Star'
    END AS rating_category,
    COUNT(*) AS total_reviews,
    COUNT(CASE WHEN review_comment_title IS NOT NULL AND review_comment_title != '' THEN 1 END) AS reviews_with_title,
    COUNT(CASE WHEN review_comment_message IS NOT NULL AND review_comment_message != '' THEN 1 END) AS reviews_with_comment,
    ROUND(COUNT(CASE WHEN review_comment_title IS NOT NULL AND review_comment_title != '' THEN 1 END) / COUNT(*) * 100, 2) AS title_rate_pct,
    ROUND(COUNT(CASE WHEN review_comment_message IS NOT NULL AND review_comment_message != '' THEN 1 END) / COUNT(*) * 100, 2) AS comment_rate_pct,
    -- Average time between delivery and review
    ROUND(AVG(DATEDIFF(dor.review_creation_date, fo.order_deliver_customer_date)), 1) AS avg_days_to_review
FROM dim_order_review dor
INNER JOIN fact_orders fo ON dor.order_id = fo.order_id
WHERE fo.order_status = 'delivered'
GROUP BY review_score
ORDER BY review_score DESC;


-- customer timing
WITH review_timing AS (
    SELECT 
        dor.review_score,
        DATEDIFF(dor.review_creation_date, fo.order_deliver_customer_date) AS days_after_delivery,
        CASE 
            WHEN DATEDIFF(dor.review_creation_date, fo.order_deliver_customer_date) = 0 THEN 'Same Day'
            WHEN DATEDIFF(dor.review_creation_date, fo.order_deliver_customer_date) BETWEEN 1 AND 3 THEN '1-3 Days'
            WHEN DATEDIFF(dor.review_creation_date, fo.order_deliver_customer_date) BETWEEN 4 AND 7 THEN '4-7 Days'
            WHEN DATEDIFF(dor.review_creation_date, fo.order_deliver_customer_date) BETWEEN 8 AND 14 THEN '8-14 Days'
            WHEN DATEDIFF(dor.review_creation_date, fo.order_deliver_customer_date) BETWEEN 15 AND 30 THEN '15-30 Days'
            ELSE '30+ Days'
        END AS review_timing_bucket,
        CASE WHEN dor.review_comment_message IS NOT NULL AND dor.review_comment_message != '' THEN 1 ELSE 0 END AS has_comment
    FROM dim_order_review dor
    INNER JOIN fact_orders fo ON dor.order_id = fo.order_id
    WHERE fo.order_deliver_customer_date IS NOT NULL
        AND dor.review_creation_date IS NOT NULL
        AND fo.order_status = 'delivered'
)
SELECT 
    review_timing_bucket,
    COUNT(*) AS review_count,
    ROUND(AVG(review_score), 2) AS avg_review_score,
    ROUND(AVG(days_after_delivery), 1) AS avg_days_after_delivery,
    COUNT(CASE WHEN review_score >= 4 THEN 1 END) AS positive_reviews,
    COUNT(CASE WHEN review_score <= 2 THEN 1 END) AS negative_reviews,
    ROUND(SUM(has_comment) / COUNT(*) * 100, 2) AS comment_rate_pct,
    ROUND(COUNT(*) / (SELECT COUNT(*) FROM review_timing) * 100, 2) AS pct_of_total_reviews
FROM review_timing
GROUP BY review_timing_bucket
ORDER BY 
    CASE review_timing_bucket
        WHEN 'Same Day' THEN 1
        WHEN '1-3 Days' THEN 2
        WHEN '4-7 Days' THEN 3
        WHEN '8-14 Days' THEN 4
        WHEN '15-30 Days' THEN 5
        WHEN '30+ Days' THEN 6
    END;