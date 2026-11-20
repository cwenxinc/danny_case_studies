/* --------------------
   Danny's Diner Case Study: 
   Danny just opened a small Japanese restaurant and wants to learn more
   about his customers, especially their visiting patterns, how much
   they've spent and also which menu items are their favorite, in order
   to deliver a more personalized experience for his loyal customers.
   -------------------- */

-- 1. What is the total amount each customer spent at the restaurant?
SELECT
	s.customer_id, 
    SUM(m.price) AS total_spent
FROM dannys_diner.sales s
JOIN dannys_diner.menu m ON s.product_id = s.product_id
GROUP BY s.customer_id
ORDER BY 
	total_spent DESC, 
	customer_id;

-- 2. How many **days** has each customer visited the restaurant?
SELECT
	customer_id, 
    COUNT(DISTINCT order_date) AS n_days
FROM dannys_diner.sales
GROUP BY customer_id
ORDER BY n_days DESC;

-- 3. What was **the first item** from the menu purchased by each customer?
WITH orders AS (
  SELECT
		*,
		RANK() OVER(
      		PARTITION BY customer_id 
      		ORDER BY order_date
    	) AS order_rank
	FROM dannys_diner.sales
)
SELECT
	DISTINCT o.customer_id, 
    o.order_date AS first_order_date, 
    m.product_name AS first_order
FROM orders o
JOIN dannys_diner.menu m ON o.product_id = m.product_id
WHERE o.order_rank = 1
ORDER BY o.customer_id;

-- 4. What is **the most purchased** item on the menu and how many times was it purchased **by all customers**?
WITH most_popular_item AS (
	SELECT
  		product_id, 
    	COUNT(order_date) AS n_purchases
	FROM dannys_diner.sales
	GROUP BY product_id
	ORDER BY n_purchases DESC
	LIMIT 1
)
SELECT
	m.product_name AS most_purchased_item, 
    p.n_purchases
FROM most_popular_item p
JOIN dannys_diner.menu m ON p.product_id = m.product_id;

-- 5. Which item was the most popular for each customer?
-- Define popularity by the number of purchases
WITH item_counts AS (
	SELECT
		customer_id, 
    	product_id, 
    	COUNT(order_date) AS n_purchases
	FROM dannys_diner.sales
	GROUP BY 
		customer_id, 
    	product_id
), 
item_ranks AS (
	SELECT
		*, 
    	RANK() OVER(
      	PARTITION BY customer_id 
      	ORDER BY n_purchases DESC
    	) AS item_rank
	FROM item_counts
)
SELECT
	r.customer_id, 
    m.product_name AS most_popular_item, 
    r.n_purchases
FROM item_ranks r
JOIN dannys_diner.menu m ON r.product_id = m.product_id
WHERE r.item_rank = 1
ORDER BY customer_id;

-- 6. Which item was purchased first by the customer **after they became a member**?
WITH member_orders AS (
  	SELECT
		s.customer_id, 
    	m.join_date, 
    	s.order_date, 
    	s.product_id,
    	RANK() OVER(
      		PARTITION BY s.customer_id 
      		ORDER BY s.order_date
    	) AS order_rank
	FROM dannys_diner.sales s
	JOIN dannys_diner.members m ON s.customer_id = m.customer_id
	WHERE s.order_date >= m.join_date
)
SELECT
	mo.customer_id, 
    mo.join_date AS member_start_date, 
    mo.order_date AS first_member_order_date, 
    m.product_name AS first_member_order
FROM member_orders mo
JOIN dannys_diner.menu m ON mo.product_id = m.product_id
WHERE mo.order_rank = 1
ORDER BY mo.customer_id;

-- 7. Which item was purchased **just before** the customer became a member?
WITH non_member_orders AS (
  	SELECT
		s.customer_id, 
    	m.join_date, 
    	s.order_date, 
    	s.product_id, 
    	RANK() OVER(
      		PARTITION BY s.customer_id 
      		ORDER BY s.order_date DESC
    	) AS order_rank
	FROM dannys_diner.sales s
	JOIN dannys_diner.members m ON s.customer_id = m.customer_id
	WHERE s.order_date < m.join_date
)
SELECT
	nmo.customer_id, 
    nmo.join_date AS member_start_date,
    nmo.order_date AS last_nonmember_order_date, 
    m.product_name AS last_nonmember_order
FROM non_member_orders nmo
JOIN dannys_diner.menu m ON nmo.product_id = m.product_id
WHERE nmo.order_rank = 1
ORDER BY nmo.customer_id;

-- 8. What is the total items and amount spent for each member before they became a member?
SELECT
	s.customer_id, 
    COUNT(s.product_id) AS total_items, 
    SUM(p.price) AS total_spent
FROM dannys_diner.sales s
JOIN dannys_diner.members m ON s.customer_id = m.customer_id
JOIN dannys_diner.menu p ON s.product_id = p.product_id
WHERE s.order_date < m.join_date
GROUP BY s.customer_id
ORDER BY s.customer_id;

-- 9.  If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?
WITH points_system AS (
	SELECT
  		product_id, 
  		product_name, 
    	price, 
    	CASE
    		WHEN product_name = 'sushi' THEN price * 10 * 2
       		ELSE price * 10
    	END AS points
	FROM dannys_diner.menu
)
SELECT
	s.customer_id, 
    SUM(p.points) AS total_points
FROM dannys_diner.sales s
JOIN points_system p ON s.product_id = p.product_id
GROUP BY s.customer_id
ORDER BY total_points DESC;

-- 10. **In the first week** after a customer joins the program (**including their join date**) they earn 2x points **on all items**, not just sushi - how many points do customer A and B have **at the end of January**?
WITH orders_before_feb AS (
  	SELECT
		s.customer_id,
    	m.join_date AS first_week_start_date, 
    	m.join_date + INTERVAL '6 days' AS first_week_end_date, 
    	s.order_date, 
    	s.product_id
	FROM dannys_diner.sales s
	JOIN dannys_diner.members m ON s.customer_id = m.customer_id
	WHERE s.order_date < '2021-02-01'
), 
points_system_first_week AS (
	SELECT
		product_id, 
    	product_name, 
    	price * 10 * 2 AS points
	FROM dannys_diner.menu
), 
points_system_regular AS (
 	SELECT
		product_id, 
    	product_name, 
    	CASE
  			WHEN product_name = 'sushi' THEN price * 10 * 2
 			ELSE price * 10
  		END AS points
	FROM dannys_diner.menu 
), 
points_earned_first_week AS (
	SELECT
		o.customer_id, 
    	SUM(fw.points) AS first_week_points
	FROM orders_before_feb o
	JOIN points_system_first_week fw ON o.product_id = fw.product_id
	WHERE o.order_date BETWEEN o.first_week_start_date AND o.first_week_end_date -- orders within the first week window
	GROUP BY o.customer_id
), 
points_earned_regular AS (
SELECT
	o.customer_id, 
    SUM(r.points) AS regular_points
FROM orders_before_feb o
JOIN points_system_regular r ON o.product_id = r.product_id
WHERE o.order_date < o.first_week_start_date OR o.order_date > o.first_week_end_date -- orders outside of the first week window
GROUP BY o.customer_id
)
SELECT
	pr.customer_id, 
    pr.regular_points + pfw.first_week_points AS total_points
FROM points_earned_regular pr
FULL JOIN points_earned_first_week pfw ON pr.customer_id = pfw.customer_id -- use full join to account for possible instances of zero points in either purchase window
ORDER BY customer_id;

/* --------------------
   Bonus:
   In addition to learning about his loyal customers, Danny wants to
   generate some basic datasets to help his team inspect the data 
   without needing to use SQL.
   -------------------- */
   
-- 1. Create a table showing all the orders made by a customer, including customer_id, order_date, product_name, price, and whether they are a loyalty program member by the time of the order (Y/N).
SELECT
	s.customer_id, 
    s.order_date, 
    p.product_name, 
    p.price, 
    CASE 
    	WHEN s.order_date >= m.join_date THEN 'Y'
        ELSE 'N'
    END AS member
FROM dannys_diner.sales s
JOIN dannys_diner.menu p ON s.product_id = p.product_id
LEFT JOIN dannys_diner.members m ON s.customer_id = m.customer_id
ORDER BY 
	s.customer_id, 
    s.order_date,
    p.product_name;
     
-- 2. On top of the table, gauge each loyal customer's favorite menu item by ranking their purchases by order date, excluding purchases when they have not joined the loyalty program.
WITH customer_history AS (
  SELECT
	s.customer_id, 
    s.order_date, 
    p.product_name, 
    p.price, 
    CASE 
    	WHEN s.order_date >= m.join_date THEN 'Y'
        ELSE 'N'
    END AS member
FROM dannys_diner.sales s
JOIN dannys_diner.menu p ON s.product_id = p.product_id
LEFT JOIN dannys_diner.members m ON s.customer_id = m.customer_id
ORDER BY 
	s.customer_id, 
    s.order_date,
    p.product_name
), 
purchase_rankings AS (
	SELECT
		*, 
    	DENSE_RANK() OVER(
      		PARTITION BY customer_id 
      		ORDER BY order_date
    	) AS rank
	FROM customer_history
	WHERE NOT member = 'N'
	UNION ALL
	SELECT
		*, 
    	NULL AS rank
	FROM customer_history
	WHERE member = 'N'
)
SELECT *
FROM purchase_rankings
ORDER BY
	customer_id, 
    order_date, 
    product_name;