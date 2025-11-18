-- order lifecycle 
alter table fact_orders 
add column approval_time_hours decimal(10,2);

update fact_orders set approval_time_hours =
timestampdiff(HOUR,order_purchase_timestamp,order_approved_at)
where order_approved_at is not null;

-- delivery time 
alter table fact_orders 
add column delivery_days int;

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
when ap.price <= 134.90 then 'Budget'
when ap.price <= 74.99 then 'Standard'
when ap.price <= 134.90 then 'Premium'
else 'Luxury'
end;



alter table dim_product
add column price_class int;
select * from dim_product;
select * from fact_order_items;
