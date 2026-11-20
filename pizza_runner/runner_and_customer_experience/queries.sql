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
   B. Runner and Customer Experience
   -------------------- */
   
   -- 1. How many runners signed up for each 1 week period? (i.e. **week starts 2021-01-01**)
   -- group registration dates into consecutive 7-day intervals and mark each interval by the start date of the week
   SELECT
   	   DATE '2021-01-01' 
        	+ ((registration_date - DATE '2021-01-01') / 7) * 7
        AS signup_week, -- use integer division to extract whole week number
        COUNT(runner_id) AS n_runners
   FROM pizza_runner.runners
   GROUP BY signup_week
   ORDER BY signup_week;
   
   -- 2. What was the average time in minutes it took for each runner **to arrive at the Pizza Runner HQ** to pickup the order?
   WITH orders_with_pickup AS (
     	SELECT
   			DISTINCT c.order_id, -- do not count the same order multiple times
        	c.order_time, 
        	r.pickup_time_clean,
     		CEIL(
              EXTRACT(EPOCH FROM r.pickup_time_clean - c.order_time) / 60.0
            ) AS minutes_to_pickup,
        	r.runner_id
   		FROM customer_orders_clean c
   		JOIN runner_orders_clean r ON c.order_id = r.order_id
  		WHERE r.pickup_time_clean IS NOT NULL
   )
   SELECT
   	   runner_id, 
        CEIL(AVG(minutes_to_pickup)) AS avg_min_to_pickup
   FROM orders_with_pickup
   GROUP BY runner_id
   ORDER BY runner_id;
   
   -- 3. Is there any relationship between the number of pizzas and how long the order takes to prepare?
   -- it seems that preparation time increases with pizza volume
   SELECT
   	   COUNT(c.pizza_id) OVER(
          PARTITION BY c.order_id
        ) AS n_pizzas_ordered,
        CEIL(
          EXTRACT(EPOCH FROM r.pickup_time_clean - c.order_time) / 60.0
        ) AS prep_time -- estimate preparation time by the time from order to pickup
   FROM customer_orders_clean c
   JOIN runner_orders_clean r ON c.order_id = r.order_id
   WHERE r.pickup_time_clean IS NOT NULL
   ORDER BY n_pizzas_ordered;
   
   -- typically the more pizzas ordered, the longer the preparation takes
   WITH order_summary AS (
     SELECT
   		COUNT(c.pizza_id) OVER(
          PARTITION BY c.order_id
        ) AS n_pizzas_ordered,
        CEIL(
          EXTRACT(EPOCH FROM r.pickup_time_clean - c.order_time) / 60.0
        ) AS prep_time
     FROM customer_orders_clean c
     JOIN runner_orders_clean r ON c.order_id = r.order_id
     WHERE r.pickup_time_clean IS NOT NULL
   )
   SELECT
   	   n_pizzas_ordered, 
        AVG(prep_time) AS avg_prep_time
   FROM order_summary
   GROUP BY n_pizzas_ordered
   ORDER BY n_pizzas_ordered;
   
   -- 4. What was the average distance travelled for each customer?
   WITH orders_delivered AS (
     	SELECT
   			DISTINCT c.order_id, -- do not count the same order multiple times
        	c.customer_id, 
        	r.distance_clean
     	FROM customer_orders_clean c
     	JOIN runner_orders_clean r ON c.order_id = r.order_id
     	WHERE r.distance_clean IS NOT NULL
   )
   SELECT
   	   customer_id, 
        ROUND(AVG(distance_clean), 1) AS avg_km_travelled
   FROM orders_delivered
   GROUP BY customer_id
   ORDER BY customer_id;
   
   -- 5. What was the difference between the longest and shortest delivery times for all orders?
   SELECT
   	   MAX(duration_clean) AS longest_delivery_time,
        MIN(duration_clean) AS shortest_delivery_time, 
        MAX(duration_clean) - MIN(duration_clean) AS time_diff
   FROM customer_orders_clean c
   JOIN runner_orders_clean r ON c.order_id = r.order_id
   WHERE duration_clean IS NOT NULL;
   
   -- 6. What was the average **speed** for each runner for each delivery and do you notice any trend for these values?
   -- runners generally pick up their speed with each new order
   SELECT
   	   DISTINCT c.order_id,
        r.runner_id, 
        ROUND(r.distance_clean / (r.duration_clean / 60.0), 1) AS km_h
   FROM customer_orders_clean c
   JOIN runner_orders_clean r ON c.order_id = r.order_id
   WHERE duration_clean IS NOT NULL AND
   		distance_clean IS NOT NULL
   ORDER BY 
   		r.runner_id, 
        c.order_id;
       
   -- overall, speed increases with each new order as well
   SELECT
   	   DISTINCT c.order_id,
        r.runner_id, 
        ROUND(r.distance_clean / (r.duration_clean / 60.0), 1) AS km_h
   FROM customer_orders_clean c
   JOIN runner_orders_clean r ON c.order_id = r.order_id
   WHERE duration_clean IS NOT NULL AND
   		distance_clean IS NOT NULL
   ORDER BY c.order_id;
   
   -- runner 2 has the highest average speed
   WITH delivery_speeds AS (
     	SELECT
   			DISTINCT c.order_id, -- remove duplicate records
        	r.runner_id, 
        	r.distance_clean / (r.duration_clean / 60.0) AS km_h
     	FROM customer_orders_clean c
     	JOIN runner_orders_clean r ON c.order_id = r.order_id
     	WHERE duration_clean IS NOT NULL AND
   			distance_clean IS NOT NULL
     	ORDER BY c.order_id
   )
   SELECT
   	   runner_id, 
        ROUND(AVG(km_h), 1) AS avg_km_h
   FROM delivery_speeds
   GROUP BY runner_id
   ORDER BY avg_km_h DESC;
   
   -- 7. What is the successful delivery percentage for each runner?
   SELECT
   	   runner_id,
        COUNT(order_id) AS n_orders,
        SUM(CASE WHEN cancellation_clean IS NULL THEN 1 ELSE 0 END) AS n_deliveries, 
        ROUND(100 * 
              SUM(CASE WHEN cancellation_clean IS NULL THEN 1 ELSE 0 END)
              / COUNT(order_id)::NUMERIC
        ) AS success_pct -- decimals prevent integer division
   FROM runner_orders_clean
   GROUP BY runner_id
   ORDER BY runner_id;