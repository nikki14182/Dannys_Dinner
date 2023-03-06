CREATE TABLE sales (
  "customer_id" VARCHAR(1),
  "order_date" DATE,
  "product_id" INTEGER
);

INSERT INTO sales
  ("customer_id", "order_date", "product_id")
VALUES
  ('A', '2021-01-01', '1'),
  ('A', '2021-01-01', '2'),
  ('A', '2021-01-07', '2'),
  ('A', '2021-01-10', '3'),
  ('A', '2021-01-11', '3'),
  ('A', '2021-01-11', '3'),
  ('B', '2021-01-01', '2'),
  ('B', '2021-01-02', '2'),
  ('B', '2021-01-04', '1'),
  ('B', '2021-01-11', '1'),
  ('B', '2021-01-16', '3'),
  ('B', '2021-02-01', '3'),
  ('C', '2021-01-01', '3'),
  ('C', '2021-01-01', '3'),
  ('C', '2021-01-07', '3');

select *
from sales;

CREATE TABLE menu (
  "product_id" INTEGER,
  "product_name" VARCHAR(5),
  "price" INTEGER
);

INSERT INTO menu
  ("product_id", "product_name", "price")
VALUES
  ('1', 'sushi', '10'),
  ('2', 'curry', '15'),
  ('3', 'ramen', '12');

select *
from menu;

CREATE TABLE members (
  "customer_id" VARCHAR(1),
  "join_date" DATE
);

INSERT INTO members
  ("customer_id", "join_date")
VALUES
  ('A', '2021-01-07'),
  ('B', '2021-01-09');

select *
from members;
  
-- 1. What is the total amount each customer spent at the restaurant?
select s.customer_id, sum(m.price) as total_sales
from sales as s
left join menu as m
	on s.product_id = m.product_id
group by s.customer_id;

-- 2. How many days has each customer visited the restaurant?
select customer_id, count(distinct(order_date)) as visit_count
from sales
group by customer_id;

-- 3. What was the first item from the menu purchased by each customer?
with first_sale as 
(
select customer_id, order_date,m.product_name,
	dense_rank() over(partition by s.customer_id 
	order by s.order_date) as rank
from sales as s
join menu as m
	on s.product_id = m.product_id
)

select customer_id, product_name
from first_sale
where rank = 1
group by customer_id,product_name;

-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?
select top 1(count(s.product_id)) as most_purchased, product_name
from sales as s
join menu as m
	on s.product_id = m.product_id
group by s.product_id, product_name
order by most_purchased desc;

-- 5. Which item was the most popular for each customer?
with popular_item as
(
select s.customer_id, count(m.product_id) as order_count, m.product_name,
	dense_rank() over(partition by customer_id
	order by count(customer_id)desc) as rank
from menu as m
join sales as s
	on m.product_id = s.product_id
group by s.customer_id, m.product_name
)

select customer_id,product_name,order_count
from popular_item
where rank = 1;

-- 6. Which item was purchased first by the customer after they became a member?
with first_purchase as
(
select s.customer_id, m.join_date,s.order_date,s.product_id,
	dense_rank() over(partition by s.customer_id 
	order by s.order_date) as rank
from sales as s
join members as m
	on s.customer_id = m.customer_id
where s.order_date >= m.join_date
)

select fp.customer_id, fp.order_date, menu.product_name
from first_purchase as fp
join menu
	on fp.product_id = menu.product_id
where rank = 1;

-- 7. Which item was purchased just before customer became a member?
with purchase_before_membership as
(
select s.customer_id, s.order_date, m.join_date, s.product_id,
	dense_rank() over(partition by s.customer_id
	order by s.order_date desc) as rank
from sales as s
join members as m
	on s.customer_id = m.customer_id
where s.order_date < m.join_date
)

select pbm.customer_id, pbm.order_date, menu.product_name
from purchase_before_membership as pbm
join menu
	on pbm.product_id = menu.product_id
where rank = 1;

-- 8. What is the total items and amount spent for each member before they became a member?
select s.customer_id, count(distinct s.product_id) as menu_item,
	sum(menu.price) as total_sales
from sales as s
join members as m
	on s.customer_id = m.customer_id
join menu
on s.product_id = menu.product_id
where s.order_date < m.join_date
group by s.customer_id;

-- 9. If each $1 spent equates to 10 points and sushi has a 2x points multiplier- how many points would each customer have?
with points as
(
	select *,
		case
			when product_id = 1 then price * 20
			else price * 10
		end as point
	from menu
)

select s.customer_id, sum(p.point) as total_points
from points as p
join sales as s
	on p.product_id = s.product_id
group by s.customer_id;

-- 10. In the first week after a customer joins the program they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?
with date_cte as
(
	select *,
		dateadd(day, 6, join_date) as valid_date,
		eomonth('2021-01-31') as last_date
	from members as m
)

select d.customer_id, s.order_date, d.join_date, d.valid_date, d.last_date, m.product_name, m.price,
	sum(case
		when m.product_name = 'sushi' then 2 * 10 * m.price
		when s.order_date between d.join_date and d.valid_date then 2 * 10 * m.price
		else 10 * m.price
		end) as points
from date_cte as d
join sales as s
	on d.customer_id = s.customer_id
join menu as m
	on s.product_id = m.product_id
where s.order_date < d.last_date
group by d.customer_id, s.order_date, d.join_date, d.valid_date, d.last_date, m.product_name, m.price;


