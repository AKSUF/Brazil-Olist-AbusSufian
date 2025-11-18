-- product catalog utilization
-- Product catalog utilization
SELECT 
    'Total Catalog' AS product_status,
    COUNT(*) AS product_count,
    0 AS orders,
    0 AS revenue
FROM products
UNION ALL
SELECT 
    'Active (Sold)' AS product_status,
    COUNT(DISTINCT product_id) AS product_count,
    COUNT(*) AS orders,
    ROUND(SUM(price), 2) AS revenue
FROM fact_order_items
UNION ALL
SELECT 
    'Inactive (Never Sold)' AS product_status,
    COUNT(*) AS product_count,
    0 AS orders,
    0 AS revenue
FROM products p
WHERE p.product_id NOT IN (SELECT DISTINCT product_id FROM fact_order_items);


-- Statistical significance: Do our 2,045 products represent the catalog adequately?
SELECT 
    COUNT(DISTINCT foi.product_id) AS active_products,
    (SELECT COUNT(*) FROM products) AS total_catalog,
    ROUND(
        COUNT(DISTINCT foi.product_id) * 100.0 / (SELECT COUNT(*) FROM products),
        2
    ) AS sample_coverage_pct,
    COUNT(*) AS total_observations,
    CASE 
        WHEN COUNT(*) > 30 THEN 'Statistically Significant (n>30)'
        ELSE 'Small Sample'
    END AS statistical_validity
FROM fact_order_items foi;


-- Category performance overview
SELECT 
    COALESCE(dp.product_category_name, 'Unknown') AS category,
    COUNT(DISTINCT dp.product_id) AS unique_products,
    COUNT(foi.order_id) AS total_orders,
    SUM(foi.price) AS gross_revenue,
    SUM(foi.freight_value) AS total_freight,
    SUM(foi.price + foi.freight_value) AS total_revenue,
    ROUND(AVG(foi.price), 2) AS avg_product_price,
    ROUND(AVG(foi.freight_value), 2) AS avg_freight,
    ROUND(AVG(foi.price + foi.freight_value), 2) AS avg_total_price,
    ROUND(AVG(foi.freight_value) * 100.0 /
    NULLIF(AVG(foi.price), 0), 2) AS freight_pct_of_price,
    ROUND(COUNT(foi.order_id) * 100.0 /
    SUM(COUNT(foi.order_id)) OVER (), 2) AS pct_of_orders,
    ROUND(SUM(foi.price + foi.freight_value) * 100.0 / 
    SUM(SUM(foi.price + foi.freight_value)) OVER (), 2) AS pct_of_revenue
FROM fact_order_items foi
LEFT JOIN dim_product dp ON foi.product_id = dp.product_id
GROUP BY category
ORDER BY total_revenue DESC;


-- ABC classification (Pareto analysis)
WITH product_revenue AS (
    SELECT 
        foi.product_id,
        dp.product_category_name,
        COUNT(DISTINCT foi.order_id) AS order_count,
        SUM(foi.price + foi.freight_value) AS total_revenue,
        ROUND(AVG(foi.price), 2) AS avg_price
    FROM fact_order_items foi
    LEFT JOIN dim_product dp ON foi.product_id = dp.product_id
    GROUP BY foi.product_id, dp.product_category_name
),
ranked_products AS (
    SELECT 
        *,
        ROW_NUMBER() OVER (ORDER BY total_revenue DESC) AS revenue_rank,
        SUM(total_revenue) OVER (ORDER BY total_revenue DESC) AS cumulative_revenue,
        ROUND(
            SUM(total_revenue) OVER (ORDER BY total_revenue DESC) * 100.0 /
            SUM(total_revenue) OVER (),
            2
        ) AS cumulative_revenue_pct
    FROM product_revenue
)
SELECT 
    product_id,
    product_category_name,
    order_count,
    ROUND(total_revenue, 2) AS total_revenue,
    avg_price,
    revenue_rank,
    cumulative_revenue_pct,
    CASE 
        WHEN cumulative_revenue_pct <= 80 THEN 'A (Top 80% Revenue)'
        WHEN cumulative_revenue_pct <= 95 THEN 'B (Next 15% Revenue)'
        ELSE 'C (Last 5% Revenue)'
    END AS abc_class
FROM ranked_products
ORDER BY revenue_rank limit 10;

--  abc clas summery 
-- ABC classification (Pareto analysis)
WITH product_revenue AS (
    SELECT 
        foi.product_id,
        dp.product_category_name,
        COUNT(DISTINCT foi.order_id) AS order_count,
        SUM(foi.price + foi.freight_value) AS total_revenue,
        ROUND(AVG(foi.price), 2) AS avg_price
    FROM fact_order_items foi
    LEFT JOIN dim_product dp ON foi.product_id = dp.product_id
    GROUP BY foi.product_id, dp.product_category_name
),
ranked_products AS (
    SELECT 
        *,
        ROW_NUMBER() OVER (ORDER BY total_revenue DESC) AS revenue_rank,
        SUM(total_revenue) OVER (ORDER BY total_revenue DESC) AS cumulative_revenue,
        ROUND(
            SUM(total_revenue) OVER (ORDER BY total_revenue DESC) * 100.0 /
            SUM(total_revenue) OVER (),
            2
        ) AS cumulative_revenue_pct
    FROM product_revenue
)
SELECT 
    product_id,
    product_category_name,
    order_count,
    ROUND(total_revenue, 2) AS total_revenue,
    avg_price,
    revenue_rank,
    cumulative_revenue_pct,
    CASE 
        WHEN cumulative_revenue_pct <= 80 THEN 'A (Top 80% Revenue)'
        WHEN cumulative_revenue_pct <= 95 THEN 'B (Next 15% Revenue)'
        ELSE 'C (Last 5% Revenue)'
    END AS abc_class
FROM ranked_products
ORDER BY revenue_rank limit 10;







-- XYZ classification (demand predictability)
WITH monthly_sales AS (
    SELECT 
        foi.product_id,
        DATE_FORMAT(fo.order_purchase_timestamp, '%Y-%m') AS sale_month,
        COUNT(*) AS monthly_units,
        SUM(foi.price) AS monthly_revenue
    FROM fact_order_items foi
    JOIN fact_orders fo ON foi.order_id = fo.order_id
    GROUP BY foi.product_id, sale_month
),
product_variability AS (
    SELECT 
        product_id,
        COUNT(DISTINCT sale_month) AS months_active,
        ROUND(AVG(monthly_units), 2) AS avg_monthly_units,
        ROUND(STDDEV(monthly_units), 2) AS stddev_monthly_units,
        ROUND(
            STDDEV(monthly_units) / NULLIF(AVG(monthly_units), 0),
            2
        ) AS coefficient_of_variation
    FROM monthly_sales
    GROUP BY product_id
    HAVING COUNT(DISTINCT sale_month) >= 3  -- At least 3 months of data
)
SELECT 
    pv.product_id,
    dp.product_category_name,
    pv.months_active,
    pv.avg_monthly_units,
    pv.stddev_monthly_units,
    pv.coefficient_of_variation,
    CASE 
        WHEN pv.coefficient_of_variation <= 0.5 THEN 'X (Stable Demand)'
        WHEN pv.coefficient_of_variation <= 1.0 THEN 'Y (Variable Demand)'
        ELSE 'Z (Erratic Demand)'
    END AS xyz_class,
    CASE 
        WHEN pv.coefficient_of_variation <= 0.5 THEN 'Easy to forecast, stock consistently'
        WHEN pv.coefficient_of_variation <= 1.0 THEN 'Moderate forecasting, safety stock needed'
        ELSE 'Hard to forecast, JIT or discontinue'
    END AS inventory_strategy
FROM product_variability pv
LEFT JOIN dim_product dp ON pv.product_id = dp.product_id
ORDER BY pv.coefficient_of_variation;