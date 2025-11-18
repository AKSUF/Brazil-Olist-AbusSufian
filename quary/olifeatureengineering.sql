-- order lifecycle 
alter table fact_orders 
add column approval_time_hours decimal(10,2);

-- set approval time after ordering
update fact_orders set approval_time_hours =
timestampdiff(HOUR,order_purchase_timestamp,order_approved_at)
where order_approved_at is not null;

-- delivery time 
alter table fact_orders 
add column delivery_days int;

-- diffrece between 
update fact_orders 
set delivery_days = 
datediff(order_deliver_customer_date,order_purchase_timestamp)
where order_deliver_customer_date is not null;


-- is delayed
alter table fact_orders
add column is_delayed tinyint default 0;

update fact_orders 
set is_delayed =
case 
when order_deliver_customer_date > order_estimated_delivery_date then 1
when order_deliver_customer_date is null
and curdate()>order_estimated_delivery_date then 1
else 0 
end;

-- carrier handoff time
alter table fact_orders
add column carrier_handoff_days int;

update fact_orders 
set carrier_handoff_days = 
datediff(order_deliver_carrier_date,order_approved_at)
where order_deliver_carrier_date is not null
and order_approved_at is not null;


-- Total Order Value
select * from vw_order_totals;

-- total item values
alter table fact_order_items 
add column total_item_value decimal(10,2);

update fact_order_items 
set total_item_value = price + freight_value;

-- how much does add to product cost : find out percenatge
ALTER TABLE fact_order_items
MODIFY COLUMN freight_percentage DECIMAL(7,2);
SET FOREIGN_KEY_CHECKS = 0;

update fact_order_items 
set freight_percentage= 
case 
when price >0 then ROUND((freight_value / price) * 100, 2)
else null
end;

-- how tight are shipping deadlines
alter table fact_order_items
add column days_to_ship_limit int;

-- shiiping urgency 
update fact_order_items foi
join fact_orders fo on foi.order_id = fo.order_id
set foi.days_to_ship_limit = 
datediff(foi.shipping_limit_date,fo.order_purchase_timestamp);

-- divided the dataset in different parts
SET @q1 = (SELECT price FROM fact_order_items ORDER BY price LIMIT 1 OFFSET 28162);
SET @q2 = (SELECT price FROM fact_order_items ORDER BY price LIMIT 1 OFFSET 56325);
SET @q3 = (SELECT price FROM fact_order_items ORDER BY price LIMIT 1 OFFSET 84487);

-- update dim_product

update dim_product dp
join (select product_id,price from 
fact_order_items group by product_id) ap on dp.product_id = ap.product_id
set dp.price_class = 
case 
when ap.price <= 39.90 then 'Budget'
when ap.price <= 74.99 then 'Standard'
when ap.price <= 134.90 then 'Premium'
else 'Luxury'
end;

ALTER TABLE dim_product
add COLUMN price_class VARCHAR(20);



alter table dim_product
add column price_class int;
select * from dim_product;
select * from fact_order_items;


select * from dim_order_payments;

alter table dim_order_payments
add column installment_category varchar(20);

update dim_order_payments
set installment_category = 
case 
when payment_installments = 1 then 'Full Payment'
when payment_installments between 2 and 3 then 'Short-term'
when payment_installments between  4 and 6 then 'Medium-term'
when  payment_installments >6 then 'Long-term'
else 'Unknown'
end;

-- customer returning
select * from vw_customer_behavior;

select * from dim_customer;

alter table dim_customer
add column geographic_segment varchar(40);


-- update the categroze stae
update dim_customer
set geographic_segment =
case
when geographic_segment in('SP','RJ','MG') then 'Southest (core)'
when geographic_segment in ('PR','SC','RS') then 'South'
when geographic_segment in ('BA','PE','CE') then 'Northeast'
when geographic_segment in ('DF','GO','MT','MS') then 'Central -West'
when geographic_segment in ('AM','PA','RO','AC') then 'North'
else 'Other'
end;

-- Seller Performance Score
CREATE VIEW vw_seller_performance AS
SELECT 
    s.seller_id,
    COUNT(DISTINCT foi.order_id) AS total_orders,
    SUM(foi.price) AS total_revenue,
    AVG(foi.price) AS avg_item_price,
    AVG(or_rev.review_score) AS avg_review_score,
    AVG(fo.delivery_days) AS avg_delivery_days,
    SUM(fo.is_delayed) * 100.0 / COUNT(fo.order_id) AS delay_rate_pct,
    CASE 
        WHEN AVG(or_rev.review_score) >= 4.5 
             AND SUM(fo.is_delayed) * 100.0 / COUNT(fo.order_id) < 5 THEN 'Top Performer'
        WHEN AVG(or_rev.review_score) >= 4.0 
             AND SUM(fo.is_delayed) * 100.0 / COUNT(fo.order_id) < 10 THEN 'Good'
        WHEN AVG(or_rev.review_score) >= 3.0 THEN 'Average'
        ELSE 'Needs Improvement'
    END AS performance_tier
FROM dim_seller s
JOIN fact_order_items foi ON s.seller_id = foi.seller_id
JOIN fact_orders fo ON foi.order_id = fo.order_id
LEFT JOIN dim_order_review or_rev ON fo.order_id = or_rev.order_id
GROUP BY s.seller_id;

-- customer satisfaction
alter table dim_order_review
add column sentiment_category varchar(20);

update dim_order_review
set sentiment_category=
case 
when review_score >= 5 then 'Very Satified'
when review_score = 4 then 'Satisfied'
when review_score = 3 then 'Neutral'
when review_score = 2 then 'Dissatisfied'
else 'Very Dissatiifed'
end;


-- seller perfomance
select * from vw_seller_performance;


ALTER TABLE dim_order_review 
ADD COLUMN response_time_days INT;

UPDATE dim_order_review
SET response_time_days = 
    DATEDIFF(review_answer_timestamp, review_creation_date);

-- customer 
select * from vw_order_distance;


