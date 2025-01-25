use gdb023;
select * from dim_customer;#customer_code,#customer,platform,channel,market,sub_zone,region
select * from dim_product;#product_code,division,segment,category,product,variant
select * from fact_gross_price;#product_code,fiscal_year,gross_price
select * from fact_manufacturing_cost;#product_code,fiscal_year,manufacturing_cost
select * from fact_pre_invoice_deductions;#customer_code,fiscal_year,pre_invoice_discount_pct
select * from fact_sales_monthly; # date,product_code,customer_code,sold_quantity,fiscal_year 
select distinct year(date) from fact_sales_monthly;
-- 1. Provide the list of markets in which customer "Atliq Exclusive" operates its 
-- business in the APAC region.
select 
      market from dim_customer 
where customer = "Atliq Exclusive" and region = "APAC";

-- 2. What is the percentage of unique product increase in 2021 vs. 2020? The
-- final output contains these fields,
--      unique_products_2020
--      unique_products_2021
--      percentage_chg
WITH CTE as(
   Select 
        count(distinct dp.product) as unique_products,
        get_fiscal_year(fsm.date) as fiscal_year 
   from dim_product dp
		JOIN fact_sales_monthly fsm 
             ON dp.product_code = fsm.product_code 
   where get_fiscal_year(fsm.date) IN(2020,2021)  
   group by get_fiscal_year(fsm.date)),
CTE1 as(
select 
      MAX(CASE WHEN fiscaL_year = 2020 THEN unique_products END) AS unique_products_2020,
      MAX(CASE WHEN fiscal_year = 2021 THEN unique_products END) AS unique_products_2021,
      (MAX(CASE WHEN fiscal_year = 2021 THEN unique_products END) -
      MAX(CASE WHEN fiscal_year = 2020 THEN unique_products END))*100.0/
      MAX(CASE WHEN fiscal_year = 2020 THEN unique_products END) AS Percentage_chng from cte)
select * from CTE1;


-- 3. Provide a report with all the unique product counts for each segment and
-- sort them in descending order of product counts. The final output contains 2 fields,
--      segment
--      product_count
select 
      segment, count(distinct product) as product_count 
 from dim_product 
 group by segment 
 order by product_count desc;
 
-- 4. Follow-up: Which segment had the most increase in unique products in
-- 2021 vs 2020? The final output contains these fields,
--            segment
--            product_count_2020
--            product_count_2021
--            difference
with CTE AS(
    select 
          segment, 
          count(distinct product) as product_count, 
          get_fiscal_year(fsm.date) as fiscal_year 
    from dim_product dp
         join fact_sales_monthly fsm 
              ON dp.product_code = fsm.product_code
    where get_fiscal_year(fsm.date) IN (2020,2021) 
    group by segment,get_fiscal_year(fsm.date)),
CTE1 AS(
     select segment,
          MAX(CASE WHEN fiscaL_year = 2020 THEN product_count END) AS product_count_2020,
          MAX(CASE WHEN fiscal_year = 2021 THEN product_count END) AS product_count_2021,
          (MAX(CASE WHEN fiscal_year = 2021 THEN product_count END) -
          MAX(CASE WHEN fiscal_year = 2020 THEN product_count END)) AS difference 
	 from CTE group by segment)
select * from CTE1;


-- 5. Get the products that have the highest and lowest manufacturing costs.
-- The final output should contain these fields,
--           product_code
--           product
--           manufacturing_cost
select 
      dp.product_code, 
      dp.product, 
      fmc.manufacturing_cost 
from dim_product dp 
     JOIN fact_manufacturing_cost fmc
         ON dp.product_code = fmc.product_code 
where fmc.manufacturing_cost in(240.5364, 0.8920) 
order by fmc.manufacturing_cost desc;

-- 6. Generate a report which contains the top 5 customers who received an
-- average high pre_invoice_discount_pct for the fiscal year 2021 and in the
-- Indian market. The final output contains these fields,
--            customer_code
--            customer
--            average_discount_percentage
select 
      dc.customer_code, 
      dc.customer, 
      AVG(fpc.pre_invoice_discount_pct) as average_discount_percentage 
from dim_customer dc 
    JOIN fact_pre_invoice_deductions fpc
         ON dc.customer_code = fpc.customer_code 
    JOIN fact_sales_monthly fsm 
         ON fpc.customer_code = fsm.customer_code 
where get_fiscal_year(fsm.date) = 2021 and dc.market ='India' 
group by dc.customer_code, dc.customer 
order by average_discount_percentage 
desc limit 5;

-- 7. Get the complete report of the Gross sales amount for the customer “Atliq
-- Exclusive” for each month. This analysis helps to get an idea of low and
-- high-performing months and take strategic decisions.
-- The final report contains these columns:
--        Month
--        Year
--        Gross sales Amount
select  
      date(fsm.date) as month,
      get_fiscal_year(fsm.date) as year, 
      sum(sold_quantity * gross_price) as Gross_Sales_Amount
from fact_gross_price fgp 
     JOIN fact_sales_monthly fsm 
          ON fgp.product_code = fsm.product_code 
     JOIN dim_customer dc 
          ON fsm.customer_code = dc.customer_code
where customer = "Atliq Exclusive" 
group by year, fsm.date
order by Gross_Sales_Amount desc;

-- 8. In which quarter of 2020, got the maximum total_sold_quantity? The final
-- output contains these fields sorted by the total_sold_quantity,
--                Quarter
--                total_sold_quantity

with CTE AS(
             select 
                    get_fiscal_quarter(date) as Quarter, 
                    sum(sold_quantity) as total_sold_quantity
             from fact_sales_monthly 
             where get_fiscal_year(date) = 2020 
             group by get_fiscal_quarter(date)
)
select 
      Quarter, 
	  total_sold_quantity 
from CTE
order by total_sold_quantity desc;
      
-- 9. Which channel helped to bring more gross sales in the fiscal year 2021
-- and the percentage of contribution? The final output contains these fields,
--             channel
--             gross_sales_mln
--             percentage

WITH CTE AS(
             select 
                    dc.channel, 
                    ROUND(sum(fsm.sold_quantity*fgp.gross_price/1000000),3) as gross_sales_mln 
			   from dim_customer dc
                    JOIN fact_sales_monthly fsm 
                         ON dc.customer_code = fsm.customer_code
			        JOIN fact_gross_price fgp 
				         ON fsm.product_code = fgp.product_code 
			   where get_fiscal_year(fsm.date) = 2021
			   group by dc.channel),
CTE1 AS(
         select *, 
                 ROUND(sum(gross_sales_mln),3) as total_gross_sales 
		 from CTE)
select 
	   CTE.channel,
       CTE.gross_sales_mln,
       ROUND((CTE.gross_sales_mln/CTE1.total_gross_Sales)*100,3) as percentage
from CTE, CTE1 
order by CTE.gross_sales_mln desc;

-- 10. Get the Top 3 products in each division that have a high
-- total_sold_quantity in the fiscal_year 2021? The final output contains these fields,
--         division
--         product_code
--         product
--         total_sold_quantity
--         rank_order

with cte as(
            select
                   dp.division, 
                   dp.product_code, 
                   dp.product,
                   sum(sold_quantity) as total_sold_quantity 
			from dim_product dp 
                   JOIN fact_sales_monthly fsm 
                        ON dp.product_code = fsm.product_code 
			where get_fiscal_year(fsm.date) = 2021
			group by dp.product 
			order by total_sold_quantity desc),
cte1 as(
        select *, 
        dense_rank()  OVER(PARTITION BY division order by total_sold_quantity desc)as rank_order 
        from cte)
select * from cte1 where rank_order <= 3;
