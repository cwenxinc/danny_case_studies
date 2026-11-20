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
   Part A: Pizza Metrics
   -------------------- */
    
   -- 1. How many pizzas were ordered?
   SELECT 
   		COUNT(pizza_id) AS total_pizza_orders
   FROM customer_orders_clean;
   
   -- 2. How many **unique customer orders** were made?
   SELECT 
   		COUNT(DISTINCT order_id) AS total_unique_orders
   FROM customer_orders_clean;
   
   -- 3. How many **successful** orders were delivered by each runner?
   SELECT 
   		runner_id,
   		SUM(
          CASE WHEN cancellation_clean IS NULL THEN 1 ELSE 0 END
        ) AS n_successful_orders
   FROM runner_orders_clean
   GROUP BY runner_id
   ORDER BY n_successful_orders DESC;
   
   -- 4. How many of each type of pizza was **delivered**?
   SELECT
   		p.pizza_name, 
        COUNT(c.order_id) AS n_delivered
   FROM customer_orders_clean c
   JOIN runner_orders_clean r ON c.order_id = r.order_id
   JOIN pizza_runner.pizza_names p ON c.pizza_id = p.pizza_id
   WHERE r.cancellation_clean IS NULL -- delivered orders only
   GROUP BY p.pizza_name
   ORDER BY n_delivered DESC;
   
   -- 5. How many Vegetarian and Meatlovers were ordered by each customer?
   SELECT
   		c.customer_id, 
        SUM(
          CASE WHEN p.pizza_name = 'Vegetarian' THEN 1 ELSE 0 END
        ) AS n_vegetarian, 
        SUM(
          CASE WHEN p.pizza_name = 'Meatlovers' THEN 1 ELSE 0 END
        ) AS n_meatlovers
   FROM customer_orders_clean c
   JOIN pizza_runner.pizza_names p ON c.pizza_id = p.pizza_id
   GROUP BY c.customer_id
   ORDER BY c.customer_id;
   
   -- 6. What was the maximum number of pizzas **delivered** in a **single** order?
   SELECT
   		c.order_id, 
        COUNT(c.pizza_id) AS max_pizzas_delivered
   FROM customer_orders_clean c
   JOIN runner_orders_clean r ON c.order_id = r.order_id
   WHERE r.cancellation_clean IS NULL -- delivered orders only
   GROUP BY c.order_id
   ORDER BY COUNT(c.pizza_id) DESC
   LIMIT 1;
   
   -- 7. For each customer, how many **delivered pizzas** had at least 1 change and how many had no changes? (Change = exclusion or extra)
   SELECT
   		c.customer_id, 
        SUM(CASE WHEN c.exclusions_clean IS NULL AND c.extras_clean IS NULL THEN 1 ELSE 0 END) AS n_pizzas_no_change, 
        COUNT(c.pizza_id) - SUM(CASE WHEN c.exclusions_clean IS NULL AND c.extras_clean IS NULL THEN 1 ELSE 0 END) AS n_pizzas_change
   FROM customer_orders_clean c
   JOIN runner_orders_clean r ON c.order_id = r.order_id
   WHERE r.cancellation_clean IS NULL -- delivered orders only
   GROUP BY c.customer_id
   ORDER BY c.customer_id;
   
   -- 8. How many pizzas were delivered that had both exclusions and extras?
   SELECT
   		COUNT(c.order_id) AS n_pizzas_both_exclusions_and_extras
   FROM customer_orders_clean c
   JOIN runner_orders_clean r ON c.order_id = r.order_id
   WHERE r.cancellation_clean IS NULL AND -- delivered orders only
   		exclusions_clean IS NOT NULL AND
        extras_clean IS NOT NULL;
   
   -- 9. What was the total volume of pizzas ordered for **each hour of the day**?
   WITH hours_with_orders AS (
   		SELECT
   			DATE_PART('hour', order_time) AS order_hour, 
        	COUNT(pizza_id) AS n_pizzas_ordered
   		FROM customer_orders_clean
   		GROUP BY order_hour
   ), 
   hours AS (
   		SELECT GENERATE_SERIES(0, 23) AS hour
   )
   SELECT
   		h.hour AS hour_of_day, 
        COALESCE(ho.n_pizzas_ordered, 0) AS n_pizzas_ordered
   FROM hours h
   LEFT JOIN hours_with_orders ho ON h.hour = ho.order_hour
   ORDER BY h.hour;
   
   -- 10. What was the volume of orders for each day of the week?
   WITH weekdays_with_orders AS (
   		SELECT
   			EXTRACT(DOW FROM order_time) AS order_weekday,
        	COUNT(DISTINCT order_id) AS n_orders
   		FROM customer_orders_clean
   		GROUP BY order_weekday
   ), 
   weekdays AS (
     	SELECT *
   		FROM (
     		VALUES
     			(0, 'Sunday'), 
     			(1, 'Monday'),
     			(2, 'Tuesday'), 
     			(3, 'Wednesday'), 
     			(4, 'Thursday'), 
     			(5, 'Friday'), 
     			(6, 'Saturday')
     		) AS weekdays(weekday, weekday_name)
    )
    SELECT
    	w.weekday_name AS day_of_week, 
        COALESCE(wo.n_orders, 0) AS n_orders
    FROM weekdays w
    LEFT JOIN weekdays_with_orders wo ON w.weekday = wo.order_weekday
    ORDER BY w.weekday;