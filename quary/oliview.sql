-- created as delievr view for fact_orders
create view vw_order_totals as
select 
foi.order_id,
sum(foi.price) as subtotal,
sum(foi.freight_value) as total_freight,
sum(foi.price + foi.freight_value) as total_order_value,
count(foi.item_id)as item_count
from fact_order_items foi 
group by foi.order_id;

create view vw_customer_behavior as
select 
customer_unique_id,
count(distinct order_id)as order_count,
case 
when count(distinct order_id) =1 then 'One time'
when count(distinct order_id)  between 2 and 3 then  'Occasional'
when count(distinct order_id) >3 then 'Frequent'
end as customer_segment,
min(order_purchase_timestamp) as first_order_date,
max(order_purchase_timestamp) as last_order_date,
datediff(max(order_purchase_timestamp),min(order_purchase_timestamp)) as customer_lifetime_days
from fact_orders fo 
join dim_customer dc on fo.customer_id = dc.customer_id
group by customer_unique_id;


-- customer distand 
-- Using Haversine formula for great-circle distance
CREATE VIEW vw_order_distance AS
SELECT 
    foi.order_id,
    foi.seller_id,
    fo.customer_id,
    (6371 * ACOS(
        COS(RADIANS(cg.geolocation_lat)) * 
        COS(RADIANS(sg.geolocation_lat)) * 
        COS(RADIANS(sg.geolocation_lng) - RADIANS(cg.geolocation_lng)) + 
        SIN(RADIANS(cg.geolocation_lat)) * 
        SIN(RADIANS(sg.geolocation_lat))
    )) AS distance_km,
    CASE 
        WHEN (6371 * ACOS( COS(RADIANS(cg.geolocation_lat)) * 
        COS(RADIANS(sg.geolocation_lat)) * 
        COS(RADIANS(sg.geolocation_lng) - RADIANS(cg.geolocation_lng)) + 
        SIN(RADIANS(cg.geolocation_lat)) * 
        SIN(RADIANS(sg.geolocation_lat)))) <= 100 THEN 'Local (<100km)'
        WHEN (6371 * ACOS( COS(RADIANS(cg.geolocation_lat)) * 
        COS(RADIANS(sg.geolocation_lat)) * 
        COS(RADIANS(sg.geolocation_lng) - RADIANS(cg.geolocation_lng)) + 
        SIN(RADIANS(cg.geolocation_lat)) * 
        SIN(RADIANS(sg.geolocation_lat)))) <= 500 THEN 'Regional (100-500km)'
        WHEN (6371 * ACOS( COS(RADIANS(cg.geolocation_lat)) * 
        COS(RADIANS(sg.geolocation_lat)) * 
        COS(RADIANS(sg.geolocation_lng) - RADIANS(cg.geolocation_lng)) + 
        SIN(RADIANS(cg.geolocation_lat)) * 
        SIN(RADIANS(sg.geolocation_lat)))) <= 1500 THEN 'Long-distance (500-1500km)'
        ELSE 'Very Long-distance (>1500km)'
    END AS distance_category
FROM fact_order_items foi
JOIN fact_orders fo ON foi.order_id = fo.order_id
JOIN dim_customer dc ON fo.customer_id = dc.customer_id
JOIN dim_customer_geo cg ON dc.customer_zip_code_prefix = cg.zip_code_prefix
JOIN dim_seller ds ON foi.seller_id = ds.seller_id
JOIN dim_seller_geo sg ON ds.seller_zip_code_prefix = sg.zip_code_prefix;

show tables;