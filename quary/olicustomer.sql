-- customer base metrics
select
count(distinct customer_id) as total_customers,
count(distinct customer_unique_id)as unique_individuals,
count(*) - count(distinct customer_unique_id)as duplicate_customer_ids,
round((count(*) - count(distinct customer_unique_id)) * 100 /count(*),2) as duplicate_rate_pct,
count(distinct customer_state) as states_covered,
count(distinct customer_city)as cities_covered,
count(distinct customer_zip_code_prefix)as zip_codes_overed from dim_customer;

-- investigate duplicate custoer patterns
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


select * from dim_customer;