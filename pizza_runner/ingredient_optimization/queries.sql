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
   C. Ingredient Optimization
   -------------------- */
   
   -- 1. What are the standard ingredients for each pizza?
   WITH toppings_breakdown AS (
   		SELECT
   			pizza_id, 
        	CAST(
              UNNEST(STRING_TO_ARRAY(toppings, ', ')) AS NUMERIC
            ) AS topping_id -- split comma-separated toppings into rows
   		FROM pizza_runner.pizza_recipes
   )
   SELECT
   		n.pizza_name AS pizza,
        STRING_AGG(t.topping_name, ', ') AS standard_ingredients
   FROM toppings_breakdown b
   JOIN pizza_runner.pizza_toppings t ON b.topping_id = t.topping_id
   JOIN pizza_runner.pizza_names n ON b.pizza_id = n.pizza_id
   GROUP BY n.pizza_name;
   
   -- 2. What was the most commonly added extra?
   WITH extras_breakdown AS (
     	SELECT
   			order_id, 
        	CAST(
              UNNEST(STRING_TO_ARRAY(extras_clean, ', ')) AS NUMERIC
            ) AS extra
   		FROM customer_orders_clean
   		WHERE extras_clean IS NOT NULL
   )
   SELECT
   		t.topping_name AS most_common_extra
   FROM extras_breakdown e
   JOIN pizza_runner.pizza_toppings t ON e.extra = t.topping_id
   GROUP BY t.topping_name
   ORDER BY COUNT(e.order_id) DESC -- assume most common means most pizzas
   LIMIT 1;
   
   -- 3. What was the most common exclusion?
   WITH exclusions_breakdown AS (
     	SELECT
   			order_id, 
        	CAST(
              UNNEST(STRING_TO_ARRAY(exclusions_clean, ', ')) AS NUMERIC
            ) AS exclusion
   		FROM customer_orders_clean
   		WHERE exclusions_clean IS NOT NULL
   )
   SELECT
   		t.topping_name AS most_common_exclusion
   FROM exclusions_breakdown e
   JOIN pizza_runner.pizza_toppings t ON e.exclusion = t.topping_id
   GROUP BY t.topping_name
   ORDER BY COUNT(e.order_id) DESC -- assume most common means most pizzas
   LIMIT 1;
   
   -- 4. Generate an order item for each record in the customer_orders table in the format of one of the following: Meat Lovers; Meat Lovers - Exclude Beef; Meat Lovers - Extra Bacon; Meat Lovers - Exclude Cheese, Bacon - Extra Mushroom, Peppers.
   WITH changes AS (
     	SELECT
   			DISTINCT order_id, 
        	pizza_id, 
        	CAST(
          		UNNEST(STRING_TO_ARRAY(exclusions_clean, ', ')) AS NUMERIC
        	) AS exclusion, 
        	CAST(
          		UNNEST(STRING_TO_ARRAY(extras_clean, ', ')) AS NUMERIC
        	) AS extra
   		FROM customer_orders_clean
     	ORDER BY order_id
   ), 
   changes_to_list AS (
   		SELECT
   			c.order_id, 
        	c.pizza_id, 
        	STRING_AGG(t1.topping_name, ', ') AS toppings_to_exclude,
        	STRING_AGG(t2.topping_name, ', ') AS toppings_to_add
   		FROM changes c
   		LEFT JOIN pizza_runner.pizza_toppings t1 ON c.exclusion = t1.topping_id
   		LEFT JOIN pizza_runner.pizza_toppings t2 ON c.extra = t2.topping_id
   		GROUP BY 
   			c.order_id, 
        	c.pizza_id
   		ORDER BY
   			c.order_id, 
        	c.pizza_id
   ), 
   customer_orders_updated AS (
   		SELECT
   			o.order_id, 
        	o.customer_id, 
        	n.pizza_name, 
        	CASE 
        		WHEN exclusions_clean IS NOT NULL THEN 
     				CONCAT('Exclude ', toppings_to_exclude)
            	ELSE exclusions_clean
        	END AS exclusions, 
        	CASE
        		WHEN extras_clean IS NOT NULL THEN 
     				CONCAT('Extra ', toppings_to_add)
            	ELSE extras_clean
        	END AS extras, 
        	o.order_time
   		FROM customer_orders_clean o
   		LEFT JOIN changes_to_list c ON o.order_id = c.order_id AND o.pizza_id = c.pizza_id
     	JOIN pizza_runner.pizza_names n ON o.pizza_id = n.pizza_id
     	ORDER BY 
     		o.order_id, 
     		o.pizza_id
   )
   SELECT
   		order_id, 
        customer_id, 
        CONCAT_WS(' - ', pizza_name, exclusions, extras) AS order_item -- note that pizza name, exclusions and extras are separated by a common separator
   FROM customer_orders_updated;
  
   -- 5. Generate an **alphabetically ordered** comma separated ingredient list for each pizza order from the customer_orders table and **add a 2x** in front of any relevant ingredients. For example: "Meat Lovers: 2xBacon, Beef, ... , Salami".
   -- Step 1) Map each pizza's standard ingredients to their names and sort them alphabetically
   -- Step 2) Map each order's exclusions and extras to their respective ingredient names
   -- Step 3) Remove excluded ingredients from the standard ingredient list
   -- Step 4) Identify extras in the standard ingredient list and prefix them with '2x'
   -- Step 5) Combine the pizza name with the updated ingredient list
   WITH standard_toppings AS (
   		SELECT
   			pizza_id, 
        	CAST(
              UNNEST(STRING_TO_ARRAY(toppings, ', ')) AS NUMERIC
            ) AS topping
   		FROM pizza_runner.pizza_recipes
   ), 
   standard_toppings_to_list AS (
   		SELECT
   			s.pizza_id,
     		n.pizza_name,
        	ARRAY_AGG(t.topping_name ORDER BY t.topping_name) AS toppings -- put the toppings into alphabetical order
   		FROM standard_toppings s
   		JOIN pizza_runner.pizza_toppings t ON s.topping = t.topping_id
   		JOIN pizza_runner.pizza_names n ON s.pizza_id = n.pizza_id
   		GROUP BY 
     		s.pizza_id,
     		n.pizza_name
   ), 
   changes AS (
   		SELECT
   			DISTINCT order_id, 
        	pizza_id, 
        	CAST(UNNEST(STRING_TO_ARRAY(exclusions_clean, ', ')) AS NUMERIC) AS exclusion_id, 
        	CAST(UNNEST(STRING_TO_ARRAY(extras_clean, ', ')) AS NUMERIC) AS extra_id
   		FROM customer_orders_clean
   ), 
   changes_to_list AS (
   		SELECT
   			c.order_id, 
        	c.pizza_id, 
        	ARRAY_AGG(t1.topping_name) FILTER (WHERE t1.topping_name IS NOT NULL) AS excluded_toppings, -- handle instances where exclusions < extras
        	ARRAY_AGG(t2.topping_name) FILTER (WHERE t2.topping_name IS NOT NULL) AS extra_toppings -- -- handle instances where extras < exclusions
   		FROM changes c
   		LEFT JOIN pizza_runner.pizza_toppings t1 ON c.exclusion_id = t1.topping_id
   		LEFT JOIN pizza_runner.pizza_toppings t2 ON c.extra_id = t2.topping_id
   		GROUP BY 
   			c.order_id, 
        	c.pizza_id
   ), 
   customer_orders_updated AS (
   		SELECT
   			o.order_id, 
        	o.customer_id, 
        	s.pizza_name, 
        	s.toppings, 
        	CASE
        		WHEN o.exclusions_clean IS NOT NULL THEN c.excluded_toppings
            	ELSE o.exclusions_clean::TEXT[] -- cast null strings into null arrays for type compatibility
        	END AS exclusions, 
        	CASE
        		WHEN o.extras_clean IS NOT NULL THEN c.extra_toppings
            	ELSE o.extras_clean::TEXT[] -- cast null strings into null arrays for type compatibility
        	END AS extras
   		FROM customer_orders_clean o
   		JOIN standard_toppings_to_list s ON o.pizza_id = s.pizza_id
   		LEFT JOIN changes_to_list c ON o.order_id = c.order_id AND o.pizza_id = c.pizza_id
   )
   SELECT 
   		order_id, 
        customer_id, 
        CONCAT_WS(
          ': ', 
          pizza_name,
          ARRAY_TO_STRING(
          	ARRAY(
          		SELECT 
          			CASE
          				WHEN topping = ANY(COALESCE(extras, ARRAY[]::TEXT[])) THEN '2x' || topping -- safely handle situations where the customer asks all toppings to be excluded and topping turns out null (unlikely but doesn't hurt to account for)
          				ELSE topping
          			END
          		FROM UNNEST(toppings) AS topping
          		WHERE topping <> ALL(COALESCE(exclusions, ARRAY[]::TEXT[])) -- turn null arrays into empty arrays for operator comparison
          	), ', '
          )
        ) AS ingredient_list
   FROM customer_orders_updated
   ORDER BY order_id;
   
   -- 6. What is the total quantity of each ingredient used in all **delivered** pizzas sorted by most frequent first?
   -- Step 1) count all the ingredients from standard use
   -- Step 2) then modify the quantity for each ingredient based on extras/exclusions
   WITH n_per_pizza AS (
     	SELECT
   			pizza_id, 
        	COUNT(order_id) AS n_pizzas
   		FROM customer_orders_clean
   		WHERE order_id IN ( -- delivered orders only
     		SELECT order_id
     		FROM runner_orders_clean
     		WHERE cancellation_clean IS NULL 
   		)
   		GROUP BY pizza_id
   ), 
   standard_quantities AS (
     	SELECT
   			CAST(
          		UNNEST(STRING_TO_ARRAY(r.toppings, ', ')) AS NUMERIC
        	) AS topping, 
        	SUM(n.n_pizzas) AS quantity
   		FROM pizza_runner.pizza_recipes r
   		JOIN n_per_pizza n ON r.pizza_id = n.pizza_id
   		GROUP BY topping
     	ORDER BY topping
   ), 
   excluded_quantities AS (
   		SELECT
   			CAST(
          		UNNEST(STRING_TO_ARRAY(exclusions_clean, ', ')) AS NUMERIC
        	) AS excluded_topping, 
        	COUNT(pizza_id) AS excluded_quantity
   		FROM customer_orders_clean
   		WHERE order_id IN ( -- delivered orders only
     		SELECT order_id
     		FROM runner_orders_clean
     		WHERE cancellation_clean IS NULL -- delivered orders only
   		) AND exclusions_clean IS NOT NULL
   		GROUP BY excluded_topping
   ), 
   extra_quantities AS (
   		SELECT
   			CAST(
          		UNNEST(STRING_TO_ARRAY(extras_clean, ', ')) AS NUMERIC
        	) AS extra_topping, 
        	COUNT(pizza_id) AS extra_quantity
   		FROM customer_orders_clean
  		WHERE order_id IN (
    		SELECT order_id
          	FROM runner_orders_clean
          	WHERE cancellation_clean IS NULL -- delivered orders only
     	) AND extras_clean IS NOT NULL
   		GROUP BY extra_topping
   )
   SELECT
   		t.topping_name AS ingredient, 
        s.quantity
        	+ COALESCE(e1.excluded_quantity, 0) 
            + COALESCE(e2.extra_quantity, 0) AS total_quantity_used
   FROM standard_quantities s
   LEFT JOIN excluded_quantities e1 ON s.topping = e1.excluded_topping
   LEFT JOIN extra_quantities e2 ON s.topping = e2.extra_topping
   JOIN pizza_toppings t ON s.topping = t.topping_id
   ORDER BY total_quantity_used DESC;