select * from fact_orders;

-- order status breadown
select 
order_status,
count(*) as order_count,
round(count(*) *100/(select count(*) from fact_orders),2)as percentage,
round(count(*) * 100 /sum(count(*)) over (),2) as running_pct
from fact_orders
group by order_status 
order by order_count desc;