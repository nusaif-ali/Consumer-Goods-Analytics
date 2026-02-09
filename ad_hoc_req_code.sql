# 1. Provide the list of markets in which customer "Atliq Exclusive" operates its
#    business in the APAC region.

SELECT
DISTINCT market FROM  dim_customer
WHERE region = 'APAC' AND customer = "Atliq Exclusive";

# 2. What is the percentage of unique product increase in 2021 vs. 2020? The final output contains these fields,
#    unique_products_2020, unique_products_2021 ,percentage_chg

WITH product_counts AS (
    SELECT
        fiscal_year,
        COUNT(DISTINCT product_code) AS unique_products
    FROM fact_sales_monthly
    WHERE fiscal_year IN (2020, 2021)
    GROUP BY fiscal_year
)

SELECT
    MAX(CASE WHEN fiscal_year = 2020 THEN unique_products END) AS unique_products_2020,
    MAX(CASE WHEN fiscal_year = 2021 THEN unique_products END) AS unique_products_2021,
    ROUND(
        (
            (MAX(CASE WHEN fiscal_year = 2021 THEN unique_products END)
           - MAX(CASE WHEN fiscal_year = 2020 THEN unique_products END))
            * 100.0
            / MAX(CASE WHEN fiscal_year = 2020 THEN unique_products END)
        ), 2
    ) AS percentage_chg
FROM product_counts;


# 3. Provide a report with all the unique product counts for each segment and
#     sort them in descending order of product counts. The final output contains
#     2 fields they are segment,product_count

SELECT
segment,
count(distinct product_code) as product_count
FROM dim_product
group by segment
order by product_count desc

#   4. Follow-up: Which segment had the most increase in unique products in
#      2021 vs 2020? The final output contains these fields,
#      segment,product_count_2020,product_count_2021,difference

SELECT
    p.segment,
    COUNT(DISTINCT CASE WHEN s.fiscal_year = 2020 THEN s.product_code END) AS product_count_2020,
    COUNT(DISTINCT CASE WHEN s.fiscal_year = 2021 THEN s.product_code END) AS product_count_2021,
    COUNT(DISTINCT CASE WHEN s.fiscal_year = 2021 THEN s.product_code END)
  - COUNT(DISTINCT CASE WHEN s.fiscal_year = 2020 THEN s.product_code END) AS difference
FROM dim_product p
JOIN fact_sales_monthly s
    USING (product_code)
WHERE s.fiscal_year IN (2020, 2021)
GROUP BY p.segment
ORDER BY difference DESC


# 5. Get the products that have the highest and lowest manufacturing costs.
#    The final output should contain these fields,
#    product_code,product,manufacturing_cost

select 
p.product_code,
p.product,
manufacturing_cost
from dim_product p
join fact_manufacturing_cost c
using (product_code)
where manufacturing_cost = (select min(manufacturing_cost) from fact_manufacturing_cost)
 or
 manufacturing_cost = (select max(manufacturing_cost) from fact_manufacturing_cost)


#   6. Generate a report which contains the top 5 customers who received an
#      average high pre_invoice_discount_pct for the fiscal year 2021 and in the
#      Indian market. The final output contains these fields,
#      customer_code,customer,average_discount_percentage

select
c.customer_code,
c.customer as customer_name,
round(avg(pre_invoice_discount_pct),4) as average_discount_percentage
from dim_customer c
join fact_pre_invoice_deductions d
using (customer_code)
where d.fiscal_year = 2021 and c.market = 'India'
group by c.customer_code, c.customer
order by average_discount_percentage desc
limit 5


#    7. Get the complete report of the Gross sales amount for the customer “Atliq
#       Exclusive” for each month. This analysis helps to get an idea of low and
#       high-performing months and take strategic decisions.The final report contains these columns:
#       Month,Year,Gross sales Amount

WITH temp_table AS(
	select customer,
    monthname(date) as months,
    month(date) as month_number,
    year(date) as year,
    (sold_quantity * gross_price) as gross_sales
FROM fact_sales_monthly s join
fact_gross_price g using (product_code)
join dim_customer c using(customer_code)
where customer = "Atliq Exclusive"
)
select
months,
year,
concat(round(sum(gross_sales)/1000000,2),"M") as gross_sales from temp_table
group by year,months
order by year,month_number

#     8. In which quarter of 2020, got the maximum total_sold_quantity? The final
#        output contains these fields sorted by the total_sold_quantity,
#        Quarter,total_sold_quantity

WITH cte AS
(
    SELECT
        sold_quantity,
        fiscal_year,
        MONTH(date) AS month_num,
        CASE
            WHEN MONTH(date) IN (9,10,11) THEN 'Q1'
            WHEN MONTH(date) IN (12,1,2)  THEN 'Q2'
            WHEN MONTH(date) IN (3,4,5)   THEN 'Q3'
            WHEN MONTH(date) IN (6,7,8)   THEN 'Q4'
        END AS Quarter
    FROM fact_sales_monthly
    WHERE fiscal_year = 2020
)

SELECT
    Quarter,
    concat(round(SUM(sold_quantity)/1000000,2)," M") AS total_sold_quantity
FROM cte
GROUP BY Quarter
ORDER BY total_sold_quantity DESC;

#   9. Which channel helped to bring more gross sales in the fiscal year 2021
#      and the percentage of contribution? The final output contains these fields,
#      channel,gross_sales_mln,percentage

with cte as(
SELECT
    c.channel,
    sum(g.gross_price * s.sold_quantity) AS gross_sales
FROM fact_sales_monthly s
JOIN fact_gross_price g
    ON s.product_code = g.product_code
JOIN dim_customer c
    ON s.customer_code = c.customer_code
WHERE s.fiscal_year = 2021
group by c.channel
order by gross_sales desc
)

select 
channel,
round(gross_sales/1000000,2) as Gross_sales_in_mln,
round(gross_sales/(sum(gross_sales) OVER())*100,2) as percentage
from cte

#    10. Get the Top 3 products in each division that have a high 
#        total_sold_quantity in the fiscal_year 2021? The final output contains these
#        division,product_code,product, total_sold_quantity, rank_order

with cte as 
(select
p.division,
p.product_code,
concat(p.product,"(",p.variant,")") as product,
sum(sold_quantity) as total_sold_quantity,
row_number() OVER (partition by division order by sum(sold_quantity) desc) AS rank_order
from dim_product p 
join fact_sales_monthly s
using (product_code)
where fiscal_year=2021
group by product_code
)

select 
*
from cte
where rank_order in (1,2,3)



