-- customer base metrics
create view customerbasics as
select
count(distinct customer_id) as total_customers,
count(distinct customer_unique_id)as unique_individuals,
count(*) - count(distinct customer_unique_id)as duplicate_customer_ids,
round((count(*) - count(distinct customer_unique_id)) * 100 /count(*),2) as duplicate_rate_pct,
count(distinct customer_state) as states_covered,
count(distinct customer_city)as cities_covered,
count(distinct customer_zip_code_prefix)as zip_codes_overed from dim_customer;

-- investigate duplicate custoer patterns
create view customer_investigate as
with customer_frequancy as(
select 
customer_unique_id,
count(distinct customer_id)as id_count,
group_concat(distinct customer_city order by customer_city)as cities,
group_concat(distinct customer_state order by customer_state)as states,
count(distinct customer_zip_code_prefix) as zip_count
from dim_customer
group by customer_unique_id
having count(distinct customer_id) >1
)
select 
id_count as ids_per_customer,
count(*) as customer_count,
round(avg(zip_count),2) as avg_zip_code,
round(count(*) *100/sum(count(*)) over(),2)as pct_of_duplicates from 
customer_frequancy 
group by id_count order by id_count;

-- customer disribution by state with concentration metrics
create view customer_pareto as
select 
customer_state,
count(distinct customer_unique_id)as customer_count,
round(count(distinct customer_unique_id) * 100/
sum(count(distinct customer_unique_id)) over(),2) as pct_of_customers,

sum(count(distinct customer_unique_id))
 over (order by count(distinct customer_unique_id) desc) as cumulative_customers,
 round(
 sum(count(distinct customer_unique_id))
 over (order by count(distinct customer_unique_id) desc)* 100 /
 sum(count(distinct customer_unique_id)) over (),2
 )as cumulative_pct,
 case
 when 
round(
sum(count(distinct customer_unique_id)) 
over (order by count(distinct customer_unique_id) desc) *100 /
sum(count(distinct customer_unique_id)) over(),2) <= 80 then 'Pareto A(top 80%)'
when 
round(
sum(count(distinct customer_unique_id)) 
over (order by count(distinct customer_unique_id)desc) * 100 /
 sum(count(distinct customer_unique_id)) over(),2) <= 95 then 'Pareto B(Next 15%)'
 else  'Pareto C(last 5%)'
 end as abc_category
 from dim_customer
 group by customer_state 
 order by customer_count desc;


-- herfindahal hirschman index
select 
round(sum(power(pct_of_customers /100,2)) * 10000,0) as hhi_score,
case 
when sum(power(pct_of_customers/100,2)) * 10000 <1500 then 'Unconecntrated(low riskk)'
when sum(power(pct_of_customers/100,2)) * 10000 < 2500 then 'Moderate  Concetration'
else 'High Concentration'
end as concentration_risk
from 
(
select 
customer_state,
count(distinct customer_unique_id) * 100.0/
sum(count(distinct customer_unique_id)) over() as pct_of_customers
from dim_customer
group by customer_state 
)state_distribution;


-- calculae gini coffeinct
with ranked_states as(
select 
customer_state,
count(distinct customer_unique_id)as customer_count,
row_number() over(order by count(distinct customer_unique_id))as rank_order from dim_customer
group by customer_state
)
select round(
1-(2* sum((customer_count * (rank_order - 0.5))) / (count(*) * sum(customer_count))),3
)as gini_coefficint from ranked_states;



-- city distributtion with long tail analysis
with city_customers as(
select 
customer_city,
customer_state,
count(distinct customer_unique_id)as customer_count
from dim_customer 
group by customer_city,customer_state
),
city_ranked as(
select customer_city,customer_state,customer_count,
row_number() over (order by customer_count desc) as city_rank,
sum(customer_count) over (order by customer_count desc)as cumulative_customers,
round(
sum(customer_count) over(order by customer_count desc) * 100 /
sum(customer_count)over(),2
)as cumulative_pct
from city_customers
)
select 
case 
when city_rank <= 10 then 'top 10 citites'
when city_rank <= 50 then 'Top  11-50ciites'
when city_rank <= 200 then 'Top 51-200 cities'
else 'Long Tail(201+)'
end as city_tier,
count(*) as city_count,
sum(customer_count)as total_customers ,
round(avg(customer_count),1)as avg_customers_per_city,
round(sum(customer_count) *100/(select sum(customer_count) from city_customers),2)as pct_of_customers
from city_ranked
group by city_tier
order by min(city_rank);


-- Test for power law (Zipf's Law) in city distribution
-- If cities follow power law: rank * customer_count ≈ constant
create view top_city as
select 
city_rank,customer_city,customer_count,
city_rank * customer_count aszipf_product,
ROUND(AVG(city_rank * customer_count) 
OVER (ORDER BY city_rank ROWS BETWEEN 4 PRECEDING AND 4 FOLLOWING), 0) AS moving_avg_zipf
from (
select customer_city,
count(distinct customer_unique_id)as customer_count,
row_number() over (order by count(distinct customer_unique_id) desc) as city_rank
from dim_customer
group by customer_city
)ranked order by city_rank limit 10;


-- 80/20 rule
-- Customer revenue concentration (80/20 analysis)
create view customer_revenue_concentration as
WITH customer_revenue AS (
    SELECT 
        dc.customer_unique_id,
        SUM(foi.price + foi.freight_value) AS total_revenue
    FROM dim_customer dc
    JOIN fact_orders fo ON dc.customer_id = fo.customer_id
    JOIN fact_order_items foi ON fo.order_id = foi.order_id
    GROUP BY dc.customer_unique_id
),
ranked_customers AS (
    SELECT 
        customer_unique_id,
        total_revenue,
        ROW_NUMBER() OVER (ORDER BY total_revenue DESC) AS revenue_rank,
        SUM(total_revenue) OVER (ORDER BY total_revenue DESC) AS cumulative_revenue,
        ROUND(
            SUM(total_revenue) OVER (ORDER BY total_revenue DESC) * 100.0 /
            SUM(total_revenue) OVER (),
            2
        ) AS cumulative_revenue_pct
    FROM customer_revenue
)
SELECT 
    'Top 1%' AS customer_tier,
    COUNT(*) AS customer_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM customer_revenue), 2) AS pct_of_customers,
    MAX(cumulative_revenue_pct) AS cumulative_revenue_pct
FROM ranked_customers
WHERE revenue_rank <= (SELECT COUNT(*) * 0.01 FROM customer_revenue)
UNION ALL
SELECT 'Top 5%', COUNT(*), ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM customer_revenue), 2), MAX(cumulative_revenue_pct)
FROM ranked_customers
WHERE revenue_rank <= (SELECT COUNT(*) * 0.05 FROM customer_revenue)
UNION ALL
SELECT 'Top 10%', COUNT(*), ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM customer_revenue), 2), MAX(cumulative_revenue_pct)
FROM ranked_customers
WHERE revenue_rank <= (SELECT COUNT(*) * 0.10 FROM customer_revenue)
UNION ALL
SELECT 'Top 20%', COUNT(*), ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM customer_revenue), 2), MAX(cumulative_revenue_pct)
FROM ranked_customers
WHERE revenue_rank <= (SELECT COUNT(*) * 0.20 FROM customer_revenue);



-- state performance scorecard

-- State performance scorecard
WITH state_metrics AS (
    SELECT 
        dc.customer_state,
        COUNT(DISTINCT dc.customer_unique_id) AS total_customers,
        COUNT(DISTINCT fo.order_id) AS total_orders,
        SUM(foi.price + foi.freight_value) AS total_revenue,
        AVG(foi.price + foi.freight_value) AS avg_order_value,
        COUNT(DISTINCT fo.order_id) * 1.0 / COUNT(DISTINCT dc.customer_unique_id) AS orders_per_customer,
        SUM(CASE WHEN fo.is_delayed = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(DISTINCT fo.order_id) AS delay_rate_pct,
        AVG(CASE WHEN dor.review_score IS NOT NULL THEN dor.review_score END) AS avg_review_score,
        SUM(CASE WHEN dor.review_score <= 2 THEN 1 ELSE 0 END) * 100.0 / 
            NULLIF(COUNT(DISTINCT dor.review_id), 0) AS negative_review_pct
    FROM dim_customer dc
    JOIN fact_orders fo ON dc.customer_id = fo.customer_id
    JOIN fact_order_items foi ON fo.order_id = foi.order_id
    LEFT JOIN dim_order_review dor ON fo.order_id = dor.order_id
    GROUP BY dc.customer_state
)
SELECT 
    customer_state,
    total_customers,
    total_orders,
    ROUND(total_revenue, 2) AS total_revenue,
    ROUND(avg_order_value, 2) AS avg_order_value,
    ROUND(orders_per_customer, 3) AS orders_per_customer,
    ROUND(delay_rate_pct, 2) AS delay_rate_pct,
    ROUND(avg_review_score, 2) AS avg_review_score,
    ROUND(negative_review_pct, 2) AS negative_review_pct,
    -- Composite Quality Score
    ROUND(
        (orders_per_customer * 30) +  -- Weight repeat purchase
        (avg_review_score * 15) +      -- Weight satisfaction
        ((100 - delay_rate_pct) * 0.3) +  -- Penalize delays
        ((100 - negative_review_pct) * 0.2),  -- Penalize negative reviews
        2
    ) AS quality_score
FROM state_metrics
ORDER BY quality_score DESC;
select * from dim_customer;


