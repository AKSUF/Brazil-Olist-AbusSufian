create database olist;
use olist;
-- customer table 
CREATE TABLE customers (
    customer_id VARCHAR(50),
    customer_unique_id VARCHAR(50),
    customer_zip_code_prefix VARCHAR(10),
    customer_city VARCHAR(50),
    customer_state CHAR(2)
);

-- geolocation time
CREATE TABLE geolocation (
    geolocation_zip_code_prefix VARCHAR(10),
    geolocation_lat DECIMAL(15,12),
    geolocation_lng DECIMAL(15,12),
    geolocation_city VARCHAR(50),
    geolocation_state CHAR(2)
);

-- order_items table
CREATE TABLE order_items (
    order_id VARCHAR(50),
    order_item_id INT,
    product_id VARCHAR(50),
    seller_id VARCHAR(50),
    shipping_limit_date DATETIME,
    price DECIMAL(10,2),
    freight_value DECIMAL(10,2)
);

-- order payments table
CREATE TABLE order_payments (
    order_id VARCHAR(50),
    payment_sequential INT,
    payment_type VARCHAR(20),
    payment_installments INT,
    payment_value DECIMAL(10,2)
);

-- order review table
CREATE TABLE order_reviews (
    review_id VARCHAR(50),
    order_id VARCHAR(50),
    review_score INT,
    review_comment_title VARCHAR(255),
    review_comment_message TEXT,
    review_creation_date DATETIME,
    review_answer_timestamp DATETIME
);

-- orders table
CREATE TABLE orders (
    order_id VARCHAR(50),
    customer_id VARCHAR(50),
    order_status VARCHAR(20),
    order_purchase_timestamp DATETIME,
    order_approved_at DATETIME,
    order_delivered_carrier_date DATETIME,
    order_delivered_customer_date DATETIME,
    order_estimated_delivery_date DATETIME
);

-- sellers table
CREATE TABLE sellers (
    seller_id VARCHAR(50),
    seller_zip_code_prefix VARCHAR(10),
    seller_city VARCHAR(50),
    seller_state CHAR(2)
);

-- product table
CREATE TABLE products (
 product_id VARCHAR(50),
 product_category_name VARCHAR(50),
 product_name_length INT, 
 product_description_length INT, 
 product_photos_qty INT,
 product_weight_g INT, 
 product_length_cm INT,
 product_height_cm INT,
 product_width_cm INT 
 );
 
 -- prduct category table
 CREATE TABLE product_category_name_translation (
    product_category_name VARCHAR(50),
    product_category_name_english VARCHAR(100)
);

-- Modifcation for making starand fact table 

-- fact orders table (rename fact_orders)
create table if not exists orders(
order_id varchar(50) primary key,
cutomer_id varchar(50) not null,
order_status varchar(20),
order_purchase_timestamp datetime,
order_approved_at datetime,
order_delivered_carrier_date datetime,
order_delivered_customer_date datetime,
order_estimated_delivery_date datetime,
customer_id_ref varchar(50),
purchase_date date,
foreign key(customer_id_ref) references customers(customer_id)
);

-- dimension table customer
CREATE TABLE IF NOT EXISTS dim_customer(
customer_id varchar(50) primary key,
customer_unique_id varchar(50),
customer_zip_code_prefix varchar(10),
customer_city varchar(100),
customer_state varchar(2)
);

-- inserting into dim customer table
insert IGNORE into dim_customer
(customer_id,customer_unique_id,customer_zip_code_prefix,customer_city,customer_state)
select customer_id,customer_unique_id,customer_zip_code_prefix,customer_city,customer_state
from customers c join dim_geolocation dg on  c.customer_zip_code_prefix = dg.geolocation_zip_code_prefix;

-- table for dimension geolocation
CREATE TABLE dim_geolocation (
geo_code int auto_increment primary key,
    geolocation_zip_code_prefix VARCHAR(10),
    geolocation_lat DECIMAL(15,12),
    geolocation_lng DECIMAL(15,12),
    geolocation_city VARCHAR(50),
    geolocation_state CHAR(2)
);

 -- inserting data into geolocation
insert into dim_geolocation
(geolocation_zip_code_prefix,geolocation_lat,geolocation_lng,geolocation_city,geolocation_state)
 select  geolocation_zip_code_prefix,geolocation_lat,geolocation_lng, geolocation_city, geolocation_state 
 from geolocation;

-- create table dimension seller
create table if not exists dim_seller(
seller_id varchar(50) primary key,
seller_zip_code_prefix varchar (10),
seller_city varchar(100),
seller_state varchar(2)
);

-- inserting data into dimension seller
insert IGNORE into dim_seller
(seller_id,seller_zip_code_prefix,seller_city,seller_state)
select seller_id,seller_zip_code_prefix,seller_city,seller_state
from sellers c join dim_geolocation dg on  c.seller_zip_code_prefix = dg.geolocation_zip_code_prefix;

-- creating table fordimension product
create table if not exists dim_product(
product_id varchar(50) primary key,
product_category_name varchar(100),
product_name_length int,
product_description_length int,
product_photos_qty int,
product_weight_g decimal(10,2),
product_length_cm decimal(10,2),
product_height_cm decimal(10,2),
product_width_cm decimal(10,2)
);


-- inserting into dim_product table
insert ignore into dim_product 
(product_id,product_category_name,product_name_length,product_description_length,product_photos_qty,
product_weight_g,product_length_cm,product_height_cm,product_width_cm
)
select  t.product_id, t.product_category_name,t.product_name_lenght, t.product_description_lenght ,
 t.product_photos_qty, t.product_weight_g, t.product_length_cm, t.product_height_cm, t.product_width_cm
 from products  t join product_category_name_translation pc 
 on t. product_category_name = pc.product_category_name_english ;
 
-- date table for dataset
CREATE TABLE dim_date (
    date_key INT PRIMARY KEY,  -- YYYYMMDD format, e.g., 20231105
    full_date DATE NOT NULL,
    year INT NOT NULL,
    quarter INT NOT NULL,
    month INT NOT NULL,
    month_name VARCHAR(20) NOT NULL,
    day INT NOT NULL,
    day_name VARCHAR(20) NOT NULL,
    week_of_year INT NOT NULL,
    is_weekend BOOLEAN DEFAULT FALSE
);

-- inserting data according to order_purchase_timestamp column of fact_order table
INSERT INTO dim_date (
    date_key,
    full_date,
    year,
    quarter,
    month,
    month_name,
    day,
    day_name,
    week_of_year,
    is_weekend
)
SELECT DISTINCT
    DATE_FORMAT(DATE(order_purchase_timestamp), '%Y%m%d') AS date_key,
    DATE(order_purchase_timestamp) AS full_date,
    YEAR(order_purchase_timestamp) AS year,
    QUARTER(order_purchase_timestamp) AS quarter,
    MONTH(order_purchase_timestamp) AS month,
    MONTHNAME(order_purchase_timestamp) AS month_name,
    DAY(order_purchase_timestamp) AS day,
    DAYNAME(order_purchase_timestamp) AS day_name,
    WEEK(order_purchase_timestamp, 1) AS week_of_year,  -- mode 1: ISO week
    CASE 
        WHEN DAYOFWEEK(order_purchase_timestamp) IN (1, 7) THEN 1
        ELSE 0
    END AS is_weekend
FROM fact_orders
WHERE order_purchase_timestamp IS NOT NULL;

-- creatin dimesntion table for product catgeoy
create table if not exists dim_product_category_name_translation(
product_category_name varchar(50),
product_category_name_english varchar(100)
);

-- inseting data into dimesnsion poduct category
insert into dim_product_category_name_translation
(product_category_name,product_category_name_english)
select product_category_name ,product_category_name_english 
from product_category_name_translation;

-- receceate the orders table with fact/-orders
create table if not exists fact_orders(
order_id varchar(50) primary key,
customer_id varchar(50) not null,
order_status varchar(20),
order_purchase_timestamp datetime,
order_approved_at datetime,
order_deliver_carrier_date datetime,
order_deliver_customer_date datetime,
order_estimated_delivery_date datetime,
purchase_date date ,
foreign key(customer_id) references dim_customer(customer_id)
);

-- inserting into fact_orders table
insert ignore into fact_orders
(order_id,customer_id,order_status,order_purchase_timestamp,order_approved_at,order_deliver_carrier_date,
order_deliver_customer_date,order_estimated_delivery_date
)
select order_id,customer_id,order_status,order_purchase_timestamp,order_approved_at,order_delivered_carrier_date,
order_delivered_customer_date,order_estimated_delivery_date from orders; 

-- creating table for fact_order_items
create table if not exists fact_order_items(
order_id varchar(50) not null,
item_id int not null,
primary key(order_id,item_id),
product_id varchar(50),
seller_id varchar(50),
shipping_limit_date datetime,
price decimal(10,2),
freight_value decimal(10,2),
foreign key(order_id) references fact_orders(order_id),
foreign key(product_id) references dim_product(product_id),
foreign key(seller_id) references dim_seller(seller_id)
);

-- inserting data into fact_orders_items
insert ignore into fact_order_items 
(order_id,item_id,product_id,seller_id,shipping_limit_date,price,freight_value)
select order_id,order_item_id,product_id,seller_id,shipping_limit_date,price,freight_value
from order_items;

-- create order revie dim table

create table if not exists dim_order_review(
    review_id VARCHAR(50),
    order_id VARCHAR(50),
    review_score INT,
    review_comment_title VARCHAR(255),
    review_comment_message TEXT,
    review_creation_date DATETIME,
    review_answer_timestamp DATETIME,
    foreign key(order_id) references fact_orders(order_id)
);

-- create table dim_order_payent
create table if not exists dim_order_payments(
payment_id int primary key auto_increment,
order_id varchar (50),
payment_sequantial int,
payment_type varchar(20),
payment_installments int,
payment_value decimal (10,2),
foreign key(order_id) references fact_orders(order_id)
);

-- add foreign key from category tab;e
alter table dim_product 
add constraint fk_product_category 
foreign key(product_category_name)
references dim_product_category_name_translation(product_category_name_english);

-- add foreign key fom date table
alter table fact_orders
add constraint fk_order_date
foreign key(datekey)
references dim_date(date_key);

-- adding datekey in fact_odes table
UPDATE fact_orders AS fo
SET datekey = DATE_FORMAT(DATE(order_purchase_timestamp), '%Y%m%d')
WHERE order_purchase_timestamp IS NOT NULL;

-- new  geo table fo custome dimension
CREATE TABLE customer_geo (
    zip_code_prefix VARCHAR(10) PRIMARY KEY,  -- Natural PK
    geolocation_lat DECIMAL(10, 8),
    geolocation_lng DECIMAL(10, 8),
    geolocation_city VARCHAR(100),
    geolocation_state VARCHAR(2)
);
-- inseting data into customer_geo fom dim_geolocation
insert ignore into customer_geo  
select geolocation_zip_code_prefix  as zip_code_prefix,
geolocation_lat,geolocation_lng,geolocation_city,geolocation_state from dim_geolocation;

-- create seller geo for seller dimansion
CREATE TABLE seller_geo (
    zip_code_prefix VARCHAR(10) PRIMARY KEY,  -- Natural PK
    geolocation_lat DECIMAL(10, 8),
    geolocation_lng DECIMAL(10, 8),
    geolocation_city VARCHAR(100),
    geolocation_state VARCHAR(2)
);

-- inserting data into seller geo dimesnion from seller_geo
insert ignore into seller_geo  
select geolocation_zip_code_prefix  as zip_code_prefix,
geolocation_lat,geolocation_lng,geolocation_city,geolocation_state from dim_geolocation;

alter table dim_customer
add constraint fk_czip_cg
foreign key(customer_zip_code_prefix) REFERENCES customer_geo(zip_code_prefix);

alter table dim_seller
add constraint fk_czip_cs
foreign key(seller_zip_code_prefix) REFERENCES seller_geo(zip_code_prefix);

insert  into fact_order_items (order_id,item_id,product_id,seller_id,shipping_limit_date,price,freight_value)
select order_id,order_item_id,product_id,seller_id,shipping_limit_date,price,freight_value from order_items;


ALTER TABLE customer_geo
ADD INDEX idx_zip_code_prefix (zip_code_prefix);

ALTER TABLE seller_geo
ADD INDEX idx_zip_code_prefix (zip_code_prefix);

ALTER TABLE dim_seller
ADD CONSTRAINT fk_czip_cs
FOREIGN KEY (seller_zip_code_prefix)
REFERENCES customer_geo(zip_code_prefix);

insert into dim_order_review(
review_id,order_id,review_score,review_comment_title,review_comment_message,review_creation_date,review_answer_timestamp
)
select review_id,order_id,review_score,review_comment_title,review_comment_message,review_creation_date,review_answer_timestamp
from order_reviews;

insert into dim_order_payments
(order_id,payment_sequantial,payment_type,payment_installments,payment_value)
select order_id,payment_sequential,payment_type,payment_installments,payment_value
from order_payments;




