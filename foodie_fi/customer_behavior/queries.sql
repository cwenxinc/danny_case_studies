/* --------------------
   Foodie-Fi Case Study:
   Foodie-Fi is a subscription-based streaming service offering food-
   related content. It provides several subscription tiers and attracts 
   new customers with a 7-day free trial of its pro monthly plan. 
   
   The Foodie-Fi team aims to better understand customer engagement
   with its subscription offerings to inform business decisions and 
   optimize operations.
   --------------------*/ 
   
/* --------------------
   Data Understanding - Customer Journey
   --------------------*/ 
   
   -- Begin by exploring each customer's onboarding journey
   
   -- Customers' onboarding journeys generally fall into one of the following four patterns:
   -- 1) the customer is satisfied with Foodie-Fi's service and continues with the monthly plan after the trial or upgrades to the annual plan (e.g., customers 2, 18, and 19);
   -- 2) the customer is satisfied with Foodie-Fi's service but prefers a lower level of commitment, downgrading to the basic plan after the trial (e.g., customer 1);
   -- 3) the customer initially opts for a lower level of commitment but eventually decides to upgrade (e.g., customers 13 and 16);
   -- 4) the customer eventually churns after using Foodie-Fi's service for some time (e.g., customers 11 and 15).
	SELECT
		s.customer_id, 
    	p.plan_name AS plan, 
    	s.start_date
	FROM foodie_fi.subscriptions s
	JOIN foodie_fi.plans p ON s.plan_id = p.plan_id
	WHERE s.customer_id IN (1, 2, 11, 13, 15, 16, 18, 19)
	ORDER BY 
		s.customer_id,
		s.start_date;
        
/* --------------------
   Data Analysis - Customer Behavior
   --------------------*/ 
   
   -- 1. How many customers has Foodie-Fi ever had?
   -- Note that a customer may upgrade/downgrade and have multiple records in the database
   SELECT
   		COUNT(DISTINCT customer_id) AS total_customers
   FROM foodie_fi.subscriptions;
   
   -- 2. What is the monthly distribution of **trial plan** start dates? Use the **start of the month** for grouping.
   SELECT
		DATE_TRUNC('month', start_date)::DATE AS start_month,
    	COUNT(start_date) AS n_trial_plans
   FROM foodie_fi.subscriptions
   WHERE plan_id = 0 -- trial plan
   GROUP BY start_month
   ORDER BY start_month;

   -- 3. Which plan start dates occur after 2020? Show the breakdown by count of events for each plan.
   SELECT
		p.plan_name AS plan, 
    	COUNT(s.start_date) AS n_events
   FROM foodie_fi.subscriptions s 
   JOIN foodie_fi.plans p ON s.plan_id = p.plan_id
   WHERE EXTRACT(YEAR FROM s.start_date) > 2020
   GROUP BY p.plan_name
   ORDER BY n_events DESC;

   -- 4. What are the count and percentage of customers who have churned (rounded to 1 decimal place)?
   -- If we assume linear customer journeys, then churns are final and don't occur twice (i.e. churned customers don't re-subscribe to Foodie-Fi)
	WITH total_customers AS (
      SELECT 
      	COUNT(DISTINCT customer_id) AS n_customers 
      FROM foodie_fi.subscriptions
    )
    SELECT
    	COUNT(DISTINCT customer_id) AS n_churned, 
        CONCAT(
          ROUND(
          	100 * COUNT(DISTINCT customer_id) / 
          	(SELECT n_customers FROM total_customers)::NUMERIC, 1
          ), '%'
        ) AS pct_churned
    FROM foodie_fi.subscriptions
    WHERE plan_id = 4;
    
    -- If a customer re-subscribes after churning, the churn event will not necessarily be their last recorded activity
    -- Check each customer's most recent subscription plan to determine whether they have churned or are currently active
    WITH total_customers AS (
      SELECT 
      	COUNT(DISTINCT customer_id) AS n_customers 
      FROM foodie_fi.subscriptions
    ), 
    recent_plans AS (
      SELECT
    	*, 
        RANK() OVER(
          PARTITION BY customer_id 
          ORDER BY start_date DESC
        ) AS plan_rank
      FROM foodie_fi.subscriptions
    )
    SELECT
    	COUNT(customer_id) AS n_churned, -- turns out none of the customers returns after churning - customer journeys are indeed linear
        CONCAT(
          ROUND(
          	100 * COUNT(customer_id) / 
          	(SELECT n_customers FROM total_customers)::NUMERIC, 1
          ), '%'
        ) AS pct_churned
    FROM recent_plans
    WHERE 
    	plan_rank = 1 AND -- customers who have churned and have not returned
        plan_id = 4;

    -- 5. How many customers have churned **straight after their initial free trial**, and what percentage is this (rounded to the nearest whole number)?
    -- Our previous analysis shows that no customers re-subscribe after churning, so we can safely assume that customers who churn immediately after their trial have the 'trial' plan as their second-to-last subscription record
    WITH total_customers AS (
      SELECT 
      	COUNT(DISTINCT customer_id) AS n_customers 
      FROM foodie_fi.subscriptions
    ),
	recent_plans AS (
  	  SELECT
		*, 
    	RANK() OVER(
          PARTITION BY customer_id 
      	  ORDER BY start_date DESC
    	) AS plan_rank
  	  FROM foodie_fi.subscriptions
	),
    churns AS (
      SELECT
    	COUNT(customer_id) AS n_churned
      FROM recent_plans
      WHERE
    	plan_rank = 1 AND
		plan_id = 4
    )
    SELECT -- the question doesn't specify which percentage to report, so report both overall percentage and percentage among all customers who have churned
    	COUNT(customer_id) AS n_churned_after_trial, 
        CONCAT(
          ROUND(
          	100 * COUNT(customer_id) / 
          	(SELECT n_customers FROM total_customers)::NUMERIC
          ), '%'
        ) AS pct_churned_after_trial_overall,
        CONCAT(
          ROUND(
          	100 * COUNT(customer_id) /
          	(SELECT n_churned FROM churns)::NUMERIC
          ), '%'
        ) AS pct_churned_after_trial_among_churns
    FROM recent_plans
    WHERE 
    	customer_id IN ( -- among customers who have churned...
          SELECT customer_id 
          FROM recent_plans 
          WHERE plan_rank = 1 AND plan_id = 4
        ) AND
        plan_rank = 2 AND -- ...those whose second-to-last record is the trial plan
		plan_id = 0;

	-- 6. What is the breakdown of customer plans after the initial free trial?
	-- The requirements for this question are a little ambiguous. Since the question asks about customer plans, we will consider all plan changes customers make after their initial trial, including upgrades, downgrades, and churns. We will treat each of these changes as an individual event rather than only considering the current subscription plan for each customer
    SELECT
    	p.plan_name AS post_trial_plan, 
        COUNT(s.plan_id) AS n_plans, 
        CONCAT(
          ROUND(
            100 * COUNT(s.plan_id) / SUM(COUNT(s.plan_id)) OVER()
          ), '%'
        ) AS pct_plans
    FROM foodie_fi.subscriptions s
    JOIN foodie_fi.plans p ON s.plan_id = p.plan_id
    WHERE NOT s.plan_id = 0 -- post-trial post
    GROUP BY p.plan_name
    ORDER BY n_plans DESC;

	-- 7. What is the customer count and percentage breakdown of all five plans on 2020-12-31?
	-- Each customer's latest subscription record before/on 2020-12-31 is their subscription status on 2020-12-31
    WITH recent_plans AS (
      SELECT
    	*, 
        ROW_NUMBER() OVER( -- start dates may overlap - assign one rank to each plan record
          PARTITION BY customer_id
          ORDER BY start_date DESC
        ) AS plan_rank
      FROM foodie_fi.subscriptions
      WHERE start_date <= '2020-12-31' -- focus on plan changes before/on 2020-12-31
    )
    SELECT 
    	p.plan_name AS plan, 
        COUNT(r.plan_id) AS n_plans_on_2020_12_31, 
        CONCAT(
          ROUND(
            100 * COUNT(r.plan_id) / SUM(COUNT(r.plan_id)) OVER()
          ), '%'
        ) AS pct_plans_on_2020_12_31
    FROM recent_plans r
    JOIN foodie_fi.plans p ON r.plan_id = p.plan_id
    WHERE r.plan_rank = 1
    GROUP BY p.plan_name
    ORDER BY n_plans_on_2020_12_31 DESC;

	-- 8. How many customers have **upgraded** to an annual plan in 2020?
	-- Customers may upgrade to the pro annual plan from the trial (0 -> 3), basic monthly (1 -> 3), or pro monthly (2 -> 3). Since pro annual is the highest subscription tier and cannot be a downgrade from another plan, simply identify customers who have subscribed to the annual plan at any point in their customer journey
	SELECT
		COUNT(DISTINCT customer_id) AS n_customers_upgraded_to_annual
	FROM foodie_fi.subscriptions
	WHERE 
		DATE_PART('year', start_date) = 2020 AND 
    	plan_id = 3;

	-- 9. How many days on average does it take for a customer to join an annual plan **from the day they join Foodie-Fi**?
    -- Assume each customer experiences at most one trial and one annual subscription
	WITH annual_customers AS (
  	  SELECT
		customer_id
  	  FROM foodie_fi.subscriptions
  	  GROUP BY customer_id
  	  HAVING SUM(CASE WHEN plan_id = 3 THEN 1 ELSE 0 END) = 1
	), 
	time_to_annual AS (
  	  SELECT
		customer_id, 
    	MAX(start_date) - MIN(start_date) AS days_to_annual
  	  FROM foodie_fi.subscriptions
  	  WHERE 
		customer_id IN (SELECT customer_id FROM annual_customers) AND
    	plan_id IN (0, 3)
  	  GROUP BY customer_id
	)
	SELECT
		CEIL(AVG(days_to_annual)) AS avg_days_to_annual
	FROM time_to_annual;
    
    -- Assume none of the conditions above; take the earliest trial start date as the join date and measure how many days it takes to reach the first annual subscription
    WITH customer_journeys AS (
      SELECT
    	customer_id, 
        MIN(start_date) FILTER (WHERE plan_id = 0) AS join_date, 
        MIN(start_date) FILTER (WHERE plan_id = 3) AS first_annual_date
      FROM foodie_fi.subscriptions
      GROUP BY customer_id
    )
    SELECT
    	CEIL(AVG(first_annual_date - join_date)) AS avg_days_to_annual
    FROM customer_journeys
    WHERE first_annual_date IS NOT NULL; -- restrict to customers who have upgraded to the annual plan at some point

	-- 10. Can you further break down this average value into 30-day periods (i.e. 0-30 days, 31-60 days, etc.)?
	-- The requirements of the question are a bit ambiguous. We will calculate how many customers fall into each 30-day interval, without assuming that each customer has at most one trial or annual subscription record
    WITH customer_journeys AS (
      SELECT
    	customer_id, 
        MIN(start_date) FILTER (WHERE plan_id = 0) AS join_date, 
        MIN(start_date) FILTER (WHERE plan_id = 3) AS first_annual_date
      FROM foodie_fi.subscriptions
      GROUP BY customer_id
    ), 
    day_intervals AS (
      SELECT
    	customer_id, 
        first_annual_date - join_date AS days_to_annual, 
        ((first_annual_date - join_date) - 1) / 30 AS day_interval -- the minus 1 ensures that days landing on interval bounds are grouped correctly
      FROM customer_journeys
      WHERE first_annual_date IS NOT NULL -- restrict to customers who have upgraded to the annual plan at some point
    )
    SELECT
    	CASE 
        	WHEN day_interval = 0 THEN '0-30 days'
            ELSE CONCAT(day_interval * 30 + 1, '-', (day_interval + 1) * 30, ' days')
        END AS days_to_annual, 
        COUNT(customer_id) AS n_customers
    FROM day_intervals
    GROUP BY day_interval
    ORDER BY day_interval;

	-- 11. How many customers downgraded **from a pro monthly to a basic monthly plan** in 2020?
    -- The caveat of this question is that a customer could start a pro monthly plan **before 2020** and downgrade to basic monthly during 2020!
    WITH plan_changes AS (
      SELECT
    	customer_id, 
      	plan_id AS current_plan, 
      	start_date, 
        LAG(plan_id) OVER(
          PARTITION BY customer_id
          ORDER BY start_date
        ) AS prev_plan
      FROM foodie_fi.subscriptions
    )
    SELECT
    	COUNT(DISTINCT customer_id) AS n_customers_downgraded -- not disregarding instances where a customer downgrades multiple times in 2020
    FROM plan_changes
    WHERE 
    	current_plan = 1 AND prev_plan = 2 AND -- downgrade from pro monthly to basic monthly
    	DATE_PART('year', start_date) = 2020; -- the downgrade took place in 2020