/* --------------------
   Pizza Runner Case Study: 
   Danny started a pizza business called "Pizza Runner" and recruited
   "runners" to deliver fresh pizza from Pizza Runner Headquarters to 
   his customers. He wants to better direct his runners and optimize 
   Pizza Runner's operations.
   -------------------- */
   
   -- reconcile data inconsistencies in customer_orders and runner_orders before analysis
   
   -- standardize null value representation in exclusions and extras
   CREATE TABLE customer_orders_clean AS
   SELECT
   		order_id, 
        customer_id, 
        pizza_id,
        NULLIF(NULLIF(exclusions, 'null'), '') AS exclusions_clean, 
        NULLIF(NULLIF(extras, 'null'), '') AS extras_clean, 
        order_time
   FROM pizza_runner.customer_orders;
   
   -- standardize null value representation in pickup_time, distance, duration, and cancellation
   -- strip distance and duration of all non-numeric characters
   -- convert the data types of pickup_time, distance, and duration
   CREATE TABLE runner_orders_clean AS
   SELECT
   		order_id,  
        runner_id,
        CAST(
          	NULLIF(pickup_time, 'null') 
          	AS TIMESTAMP
        ) AS pickup_time_clean,
        CAST(
          	NULLIF(REGEXP_REPLACE(distance, '[^\d.]', '', 'g'), '')
          	AS NUMERIC
        ) AS distance_clean, 
        CAST(
          	NULLIF(REGEXP_REPLACE(duration, '[^\d]', '', 'g'), '')
          	AS INTEGER
        ) AS duration_clean, 
        NULLIF(NULLIF(cancellation, 'null'), '') AS cancellation_clean
   FROM pizza_runner.runner_orders;
   
/* -------------------- 
   C. Pricing and Ratings
   -------------------- */
   
   -- 1. If a Meat Lovers pizza costs $12 and Vegetarian costs $10 and there were **no charges for changes** - how much money has Pizza Runner made so far if there are **no delivery fees**?
   
   -- create a table for pizza prices
   CREATE TABLE pizza_prices (
    	"pizza_id" INTEGER, 
     	"price" INTEGER
   );

   INSERT INTO pizza_prices
   VALUES
   		(1, 12), 
        (2, 10);
        
   SELECT
   		CONCAT('$', SUM(p.price)) AS total_revenue
   FROM customer_orders_clean c
   JOIN pizza_prices p ON c.pizza_id = p.pizza_id
   WHERE c.order_id IN (
     	SELECT order_id
     	FROM runner_orders_clean
     	WHERE cancellation_clean IS NULL -- only successful orders make money
   );
   
   -- 2. What if there was an additional $1 charge for any pizza **extras**?
   
   WITH order_summary AS (
     SELECT
   		c.order_id, 
        c.customer_id, 
        p.price, 
        COALESCE(
          ARRAY_LENGTH(STRING_TO_ARRAY(c.extras_clean, ', '), 1), 0
        ) * 1 AS extra_price
     FROM customer_orders_clean c
     JOIN pizza_prices p ON c.pizza_id = p.pizza_id
     WHERE c.order_id IN (
     	SELECT order_id
     	FROM runner_orders_clean
     	WHERE cancellation_clean IS NULL -- only successful orders make money
     )
   )
   SELECT 
  		CONCAT('$', SUM(price + extra_price)) AS total_revenue_extras_included
   FROM order_summary;
   
   -- 3. The Pizza Runner team now wants to add an additional ratings system that allows customers to rate their runner, how would you design an additional table for this new dataset - generate a schema for this new table and insert your own data for ratings for each successful customer order between 1 to 5.
   
   -- ratings are associated with order_id, customer_id, and runner_id
   -- since customer_id and runner_id can be derived from customer_orders and runner_orders, and each rating is uniquely associated with each order, create a table of successful (i.e. not cancelled) orders and their ratings
   CREATE TABLE customer_ratings (
     	"order_id" INTEGER, 
     	"rating" INTEGER
   );
   
   INSERT INTO customer_ratings
   VALUES
   		(1, 4),
        (2, 5), 
        (3, 4), 
        (4, 3), 
        (5, 4), 
        (7, 5), 
        (8, 5), 
        (10, 5);
   
   -- 4. Using your newly generated table - can you join all of the information together to form a table which has the following information for successful deliveries: customer_id, order_id, runner_id, rating, order_time, pickup_time, time between order and pickup, delivery duration, average speed, and total number of pizzas?
   WITH order_details AS (
     SELECT
   		order_id, 
        customer_id, 
        order_time,
        COUNT(pizza_id) AS n_pizzas
     FROM customer_orders_clean
     GROUP BY 
   		order_id, 
        customer_id, 
        order_time
   )
   SELECT
   		d.customer_id, 
        d.order_id, 
        r.runner_id, 
        c.rating, 
        d.order_time, 
        r.pickup_time_clean AS pickup_time,
        CEIL(
          EXTRACT(EPOCH FROM r.pickup_time_clean - d.order_time) / 60.0
        ) AS time_between_min,
        r.duration_clean AS delivery_duration_min, 
        ROUND(
          r.distance_clean / (r.duration_clean / 60.0), 1
        ) AS delivery_speed_km_h, 
        d.n_pizzas
   FROM runner_orders_clean r
   JOIN order_details d ON r.order_id = d.order_id
   JOIN customer_ratings c ON r.order_id = c.order_id
   WHERE r.cancellation_clean IS NULL;
   
   -- 5. If a Meat Lovers pizza was $12 and Vegetarian $10 fixed prices with no cost for extras and each runner is paid $0.30 per kilometre traveled - how much money does Pizza Runner have left over after these deliveries?
   WITH revenue_cost_per_order AS (
   	SELECT 
   		c.order_id, 
        SUM(p.price) AS revenue, 
        (SUM(r.distance_clean) / COUNT(c.pizza_id)::NUMERIC) * 0.3 AS cost -- some orders have multiple pizzas, but we only count delivery fee once!
   	FROM customer_orders_clean c
   	JOIN runner_orders_clean r ON c.order_id = r.order_id
   	JOIN pizza_prices p ON c.pizza_id = p.pizza_id
   	WHERE r.cancellation_clean IS NULL -- only delivered orders make money
   	GROUP BY c.order_id
   )
   SELECT
   		CONCAT('$', ROUND(SUM(revenue - cost), 2)) AS total_profit
   FROM revenue_cost_per_order;