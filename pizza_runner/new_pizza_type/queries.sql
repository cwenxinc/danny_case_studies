/* --------------------
   Pizza Runner Case Study: 
   Danny started a pizza business called "Pizza Runner" and recruited
   "runners" to deliver fresh pizza from Pizza Runner Headquarters to 
   his customers. He wants to better direct his runners and optimize 
   Pizza Runner's operations.
   -------------------- */
   
/* --------------------
   E. New Pizza Type
   -------------------- */
   
   -- If Danny wants to expand his range of pizzas - how would this impact the existing data design? Write an INSERT statement to demonstrate what would happen if a new Supreme pizza with all the toppings was added to the Pizza Runner menu?
   
   -- Adding a new pizza would not affect customer_orders or runner_orders because they are based on orders, but it would update pizza_names and pizza_recipes. pizza_toppings stay the same.
   
   INSERT INTO pizza_runner.pizza_names
   VALUES (3, 'Supreme');
   
   SELECT *
   FROM pizza_runner.pizza_names;
   
   INSERT INTO pizza_runner.pizza_recipes
   VALUES (3, '1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12');
   
   SELECT *
   FROM pizza_runner.pizza_recipes;