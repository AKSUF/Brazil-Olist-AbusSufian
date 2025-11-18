-- Prenormalization data schema
call AutoDetectColumnCategory('customers');
call AutoDetectColumnCategory('geolocation');
call AutoDetectColumnCategory('order_items');
call AutoDetectColumnCategory('order_payments');
call AutoDetectColumnCategory('order_reviews');
call AutoDetectColumnCategory('orders');
call AutoDetectColumnCategory('sellers');
call AutoDetectColumnCategory('products');
call AutoDetectColumnCategory('product_category_name_translation');

-- to check the table size
SELECT 
    table_name AS `Table`,
    ROUND(((data_length + index_length) / 1024 / 1024), 2) AS `Size (MB)`
FROM information_schema.TABLES 
WHERE table_schema = "olist"  -- Your database name here
ORDER BY `Size (MB)` DESC;

-- normalization and denormalization schema
call AutoDetectColumnCategory('dim_customer');
call AutoDetectColumnCategory('dim_customer_geo');
call AutoDetectColumnCategory('dim_date');
call AutoDetectColumnCategory('dim_order_payments');
call AutoDetectColumnCategory('dim_order_review');
call AutoDetectColumnCategory('dim_product');
call AutoDetectColumnCategory('dim_product_category_name_translation');
call AutoDetectColumnCategory('dim_seller');
call AutoDetectColumnCategory('dim_seller_geo');
call AutoDetectColumnCategory('fact_order_items');
call AutoDetectColumnCategory('fact_orders');

select * from dim_seller_geo;
show tables;


ALTER TABLE dim_customer
DROP COLUMN geolocation_lat,
DROP COLUMN geolocation_lng,
DROP COLUMN geolocation_city,
DROP COLUMN geolocation_state;

ALTER TABLE dim_seller
DROP COLUMN geolocation_lat,
DROP COLUMN geolocation_lng,
DROP COLUMN geolocation_city,
DROP COLUMN geolocation_state;
