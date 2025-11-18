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

-- order level percentage
select 
dd.year,
dd.quarter,
dd.month,
dd.month_name,
count(fo.order_id) as order_count,
round(avg(count(fo.order_id)) over(partition by dd.year,dd.quarter),0) as quarter_avg,
round(count(fo.order_id)*100 /sum(count(fo.order_id)) over(partition by dd.year),2 ) as pct_of_year
from fact_orders fo 
join dim_date dd on fo.datekey = dd.date_key
group by dd.year,dd.quarter,dd.month,dd.month_name
order by dd.year,dd.quarter,dd.month;


-- how does our growth compare yer over year in quarter
-- YoY comparison by quarter
WITH quarterly_orders AS (
    SELECT 
        dd.year,
        dd.quarter,
        COUNT(fo.order_id) AS order_count
    FROM fact_orders fo
    JOIN dim_date dd ON fo.datekey = dd.date_key
    GROUP BY dd.year, dd.quarter
)
SELECT 
    quarter,
    SUM(CASE WHEN year = 2016 THEN order_count ELSE 0 END) AS `2016 order`,
    SUM(CASE WHEN year = 2017 THEN order_count ELSE 0 END) AS `2017 order`,
    SUM(CASE WHEN year = 2018 THEN order_count ELSE 0 END) AS `2018 order`
FROM quarterly_orders
GROUP BY quarter
ORDER BY quarter;



-- quarter wise yearly growth
WITH quarterly_orders AS (
    SELECT 
        dd.year,
        dd.quarter,
        COUNT(fo.order_id) AS order_count
    FROM fact_orders fo
    JOIN dim_date dd ON fo.datekey = dd.date_key
    GROUP BY dd.year, dd.quarter
),
yearly_totals AS (
    SELECT 
        year,
        SUM(CASE WHEN quarter = 1 THEN order_count ELSE 0 END) AS `Q1 order`,
        SUM(CASE WHEN quarter = 2 THEN order_count ELSE 0 END) AS `Q2 order`,
        SUM(CASE WHEN quarter = 3 THEN order_count ELSE 0 END) AS `Q3 order`,
        SUM(CASE WHEN quarter = 4 THEN order_count ELSE 0 END) AS `Q4 order`,
        SUM(order_count) AS total_orders
    FROM quarterly_orders
    GROUP BY year
),
with_growth AS (
    SELECT *,
        LAG(total_orders) OVER (ORDER BY year) AS previous_year_orders
    FROM yearly_totals
)
SELECT 
    year,
    `Q1 order`,
    `Q2 order`,
    `Q3 order`,
    `Q4 order`,
    total_orders AS `Total`,
    ROUND(
        CASE 
            WHEN previous_year_orders IS NULL THEN NULL
            WHEN previous_year_orders = 0 THEN NULL
            ELSE ((total_orders - previous_year_orders) / previous_year_orders) * 100
        END, 2
    ) AS `YoY Growth %`
FROM with_growth
ORDER BY year;


-- Monthly growth in yearly
with monthly_orders as(
select dd.year,dd.month,count(fo.order_id)as order_count
from fact_orders fo 
join dim_date dd on fo.datekey = dd.date_key
group by dd.year,dd.month
),
yearly_totals as(
select 
year,
sum(case when month = 1 then order_count else 0 end) as January,
sum(case when month = 2 then order_count else 0 end) as February,
sum(case when month = 3 then order_count else 0 end) as March,
sum(case when month = 4 then order_count else 0 end) as April,
sum(case when month = 5 then order_count else 0 end) as May,
sum(case when month = 6 then order_count else 0 end) as June,
sum(case when month = 7 then order_count else 0 end) as July,
sum(case when month = 8 then order_count else 0 end) as August,
sum(case when month = 9 then order_count else 0 end) as September,
sum(case when month = 10 then order_count else 0 end) as October,
sum(case when month = 11 then order_count else 0 end) as November,
sum(case when month = 12 then order_count else 0 end) as Decemebr,
sum(order_count)as total_orders 
from monthly_orders group by year
),
with_growth as(
select *,
lag(total_orders) over(order by year) as previous_year_orders from yearly_totals
)
select 
year,
January,
February,
March,
April,
May,
June,
July,
August,
September,
October,
November,
Decemebr,
total_orders as total,
round(
case 
when previous_year_orders is null then null
when previous_year_orders = 0 then null
else ((total_orders - previous_year_orders)/previous_year_orders) *100 
end,2
)as 'YOY Growth %'
 from with_growth
 order by year;

select month_name from dim_date;

-- 
with day_orders as(
select dd.month,dd.day,dd.month_name,
count(fo.order_id) as order_count 
from fact_orders fo 
join dim_date dd on fo.datekey = dd.date_key
group by dd.month,dd.day
),
month_totals as(
select 
month,month_name,
sum(case when day = 1 then order_count else 0 end) as `Monday`,
sum(case when day = 2 then order_count else 0 end) as `Tuesday`,
sum(case when day = 3 then order_count else 0 end) as `Wednesday`,
sum(case when day = 4 then order_count else 0 end) as `Thursday`,
sum(case when day = 5 then order_count else 0 end) as `Friday`,
sum(case when day = 6 then order_count else 0 end) as `Saturday`,
sum(order_count)as total_orders
from day_orders group by month
),
with_growth as(
select * ,lag(total_orders) over (order by month) as previous_month_orders
from month_totals
)
select month_name,`Monday`,`Tuesday`,`Wednesday`,`Thursday`,`Friday`,`Saturday`, total_orders AS `Total`
from with_growth;


-- return customer ananlysi
WITH customer_order_history AS (
    SELECT 
        dc.customer_unique_id,
        fo.order_id,
        fo.order_purchase_timestamp,
        ROW_NUMBER() OVER (
            PARTITION BY dc.customer_unique_id 
            ORDER BY fo.order_purchase_timestamp
        ) AS order_number,
        COUNT(*) OVER (PARTITION BY dc.customer_unique_id) AS total_customer_orders
    FROM fact_orders fo 
    JOIN dim_customer dc ON fo.customer_id = dc.customer_id
),
return_customer AS (
    SELECT 
        CASE 
            WHEN order_number = 1 THEN 'First_Order'
            WHEN order_number = 2 THEN 'Second_Order'
            WHEN order_number = 3 THEN 'Third_Order'
            WHEN order_number <= 5 THEN '4-5_th_Order'
            ELSE '6+_Orders'
        END AS order_sequance,
        COUNT(*) AS order_count,
        COUNT(DISTINCT customer_unique_id) AS customer_count
    FROM customer_order_history 
    GROUP BY order_sequance
),
with_percentage AS (
    SELECT *,
        ROUND(
            (customer_count * 100.0) / 
            (SELECT COUNT(DISTINCT customer_unique_id) FROM customer_order_history),
            2
        ) AS customer_percentage
    FROM return_customer
)
SELECT 
    order_sequance,
    order_count,
    customer_count,
    customer_percentage
FROM with_percentage
ORDER BY 
    CASE 
        WHEN order_sequance = 'First_Order' THEN 1
        WHEN order_sequance = 'Second_Order' THEN 2
        WHEN order_sequance = 'Third_Order' THEN 3
        WHEN order_sequance = '4-5_th_Order' THEN 4
        ELSE 5
    END;

-- time between first and second order
CREATE VIEW vw_customer_days_analysis AS
with repeat_customers as(
select 
dc.customer_unique_id,
min(fo.order_purchase_timestamp) as first_order_date,
max(fo.order_purchase_timestamp) as last_order_date,
count(fo.order_id)as order_count,
datediff(max(fo.order_purchase_timestamp),min(fo.order_purchase_timestamp))
as days_between_orders 
from fact_orders fo
join dim_customer dc on fo.customer_id = dc.customer_id
group by dc.customer_unique_id
having count(fo.order_id) >= 2
)
select case
when days_between_orders <= 30 then '0-30 days'
when days_between_orders <= 90 then '31-90 days'
when days_between_orders <= 180 then '91-180 days'
else '+180 days'
end as repurchase_window,
count(*) as customer_count,
round(avg(days_between_orders),1)as avg_days,
round(count(*) * 100/sum(count(*)) over (),2)as pct_of_repaet_customers
from repeat_customers 
group by repurchase_window
ORDER BY MIN(days_between_orders);




-- Top 30 busiest days
SELECT 
    DATE(fo.order_purchase_timestamp) AS order_date,
    dd.day_name,
    dd.month_name,
    dd.year,
    COUNT(fo.order_id) AS order_count,
    RANK() OVER (ORDER BY COUNT(fo.order_id) DESC) AS day_rank,
    ROUND(
        COUNT(fo.order_id) * 100.0 / 
        AVG(COUNT(fo.order_id)) OVER (),
        2
    ) AS vs_daily_avg_pct,
    CASE 
        WHEN dd.day_name IN ('Saturday', 'Sunday') THEN 'Weekend'
        ELSE 'Weekday'
    END AS day_type,
    CASE 
        WHEN dd.month IN (11, 12) THEN 'Holiday Season'
        WHEN dd.month IN (6, 7) THEN 'Mid-Year'
        ELSE 'Regular'
    END AS season
FROM fact_orders fo
JOIN dim_date dd ON fo.datekey = dd.date_key
GROUP BY order_date, dd.day_name, dd.month_name, dd.year
ORDER BY order_count DESC
LIMIT 30;



CREATE VIEW vw_customer_retention_analysis AS
WITH customer_order_history AS (
    SELECT 
        dc.customer_unique_id,
        fo.order_id,
        fo.order_purchase_timestamp,
        ROW_NUMBER() OVER (
            PARTITION BY dc.customer_unique_id 
            ORDER BY fo.order_purchase_timestamp
        ) AS order_number,
        COUNT(*) OVER (PARTITION BY dc.customer_unique_id) AS total_customer_orders
    FROM fact_orders fo 
    JOIN dim_customer dc ON fo.customer_id = dc.customer_id
),
return_customer AS (
    SELECT 
        CASE 
            WHEN order_number = 1 THEN 'First_Order'
            WHEN order_number = 2 THEN 'Second_Order'
            WHEN order_number = 3 THEN 'Third_Order'
            WHEN order_number <= 5 THEN '4-5_th_Order'
            ELSE '6+_Orders'
        END AS order_sequance,
        COUNT(*) AS order_count,
        COUNT(DISTINCT customer_unique_id) AS customer_count
    FROM customer_order_history 
    GROUP BY 
        CASE 
            WHEN order_number = 1 THEN 'First_Order'
            WHEN order_number = 2 THEN 'Second_Order'
            WHEN order_number = 3 THEN 'Third_Order'
            WHEN order_number <= 5 THEN '4-5_th_Order'
            ELSE '6+_Orders'
        END
),
with_percentage AS (
    SELECT 
        order_sequance,
        order_count,
        customer_count,
        ROUND(
            (customer_count * 100.0) / 
            (SELECT COUNT(DISTINCT customer_unique_id) FROM customer_order_history),
            2
        ) AS customer_percentage,
        CASE 
            WHEN order_sequance = 'First_Order' THEN 1
            WHEN order_sequance = 'Second_Order' THEN 2
            WHEN order_sequance = 'Third_Order' THEN 3
            WHEN order_sequance = '4-5_th_Order' THEN 4
            ELSE 5
        END AS sort_order
    FROM return_customer
)
SELECT 
    order_sequance,
    order_count,
    customer_count,
    customer_percentage,
    sort_order
FROM with_percentage;

