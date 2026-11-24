/* --------------------
   Payment Schedule
   --------------------*/
   
   -- Create a new table showing the payments made by each customer throughout 2020, subject to the following business rules:
   -- 1) payments are always due on the same day of the month as the original start date of the customer's monthly paid plan;
   -- 2) upgrades from basic monthly to any pro plans take effect immediately, with the current month's payment adjusted by the amount already paid;
   -- 3) upgrades from pro monthly to pro annual take effect at the end of the current billing period, with payment collected at that time;
   -- 4) once a customer churns they will no longer make payments.

WITH plan_orders AS (
  SELECT
	*, 
    ROW_NUMBER() OVER(
      PARTITION BY customer_id
      ORDER BY start_date
    ) AS plan_order
  FROM foodie_fi.subscriptions
  WHERE NOT plan_id = 0
), 
monthly_billing_dates AS (
  SELECT
	customer_id, 
    start_date AS monthly_billing_date
  FROM plan_orders
  WHERE 
  	plan_order = 1 AND 
  	plan_id IN (1, 2) -- find customers who started with a monthly plan - the start date of the initial monthly plan defines the billing dates of all later monthly payments
), 
annual_billing_dates AS (
  SELECT
	customer_id, 
    start_date AS annual_billing_date
  FROM foodie_fi.subscriptions
  WHERE plan_id = 3 -- find ALL annual plan start dates
),  
payment_dates AS (
  
  SELECT
      m.customer_id, 
      sm.billing_date::DATE
  FROM monthly_billing_dates m
  CROSS JOIN LATERAL GENERATE_SERIES(
    m.monthly_billing_date, 
    '2020-12-31', 
    '1 month'
  ) AS sm(billing_date)
  WHERE NOT EXISTS ( -- only retain monthly dates **before** an annual plan takes effect; the returned values don't matter because we only need to check whether a matching record exists
    SELECT 1
    FROM foodie_fi.subscriptions s
    WHERE 
    	s.customer_id = m.customer_id AND
    	s.plan_id = 3 AND
		sm.billing_date >= s.start_date
  )
  
  UNION ALL
  
  SELECT
      a.customer_id, 
      sa.billing_date::DATE
  FROM annual_billing_dates a
  CROSS JOIN LATERAL GENERATE_SERIES(
    a.annual_billing_date, 
    '2020-12-31', 
    '1 year'
  ) AS sa(billing_date)
  
),
customers_churned_after_trial AS (
  SELECT 
  	customer_id
  FROM plan_orders
  WHERE 
  	plan_order = 1 AND 
  	plan_id = 4
), 
customers_churned_later AS (
  SELECT
	customer_id, 
    start_date AS churn_date
  FROM plan_orders
  WHERE 
  	plan_id = 4 AND 
  	customer_id NOT IN ( -- for those customers who churned at a later time, all payments before their churn dates should be included
      SELECT customer_id 
      FROM customers_churned_after_trial
    )
),
payment_dates_before_churns AS (
  SELECT
	d.customer_id, 
    d.billing_date
  FROM payment_dates d
  LEFT JOIN customers_churned_later c ON 
	d.customer_id = c.customer_id AND
	d.billing_date >= c.churn_date
  WHERE c.churn_date IS NULL -- a NULL churn date means either the customer hasn't churned yet or the billing date is before their churn date; only retain payments before the effective churn date
), 
plan_details AS (
  SELECT
	customer_id, 
    plan_id, 
    start_date, 
    LEAD(start_date) OVER(
      PARTITION BY customer_id
      ORDER BY start_date
    ) AS end_date, -- the start date of the next plan is when the current plan ends
  	LAG(plan_id) OVER(
      PARTITION BY customer_id
      ORDER BY start_date
    ) AS prev_plan
  FROM foodie_fi.subscriptions
  WHERE plan_id NOT IN (0, 4) -- trials are not relevant, and churns have already been accounted for
), 
regular_payments AS (
  SELECT
      c.customer_id, 
      d.plan_id, 
      c.billing_date
  FROM payment_dates_before_churns c
  LEFT JOIN plan_details d ON
      c.customer_id = d.customer_id AND
      c.billing_date >= d.start_date AND 
      (c.billing_date < d.end_date OR d.end_date IS NULL) -- currently active plans don't have end dates
),
upgrade_dates AS (
  SELECT
	customer_id, 
    plan_id, 
    start_date
  FROM plan_details
  WHERE
	plan_id IN (2, 3) AND
    prev_plan = 1 AND
  	DATE_PART('year', start_date) = 2020 -- identify basic-to-pro upgrades that occurred in 2020
), 
irregular_upgrade_dates AS ( -- given irregular number of days across months (e.g. Februrary vs March), the current date checks are actually not rigorous enough
  SELECT
  	u.customer_id, 
  	u.plan_id, 
  	u.start_date
  FROM upgrade_dates u
  LEFT JOIN monthly_billing_dates m ON 
  	u.customer_id = m.customer_id AND
  	DATE_PART('day', u.start_date) != DATE_PART('day', m.monthly_billing_date) -- upgrades on regular payment dates have already been captured and should not be included
  WHERE m.customer_id IS NOT NULL
), 
irregular_payments AS (
  SELECT
	iu.customer_id, 
    iu.plan_id, 
    p.plan_name, 
    iu.start_date AS payment_date, 
    p.price - (
      SELECT price 
      FROM foodie_fi.plans 
      WHERE plan_id = 1
    ) AS amount
  FROM irregular_upgrade_dates iu
  JOIN foodie_fi.plans p ON iu.plan_id = p.plan_id
), 
price_adjustments AS (
  
  SELECT
      r.customer_id, 
      r.plan_id, 
      p.plan_name, 
      r.billing_date AS payment_date, 
      p.price AS amount
  FROM regular_payments r
  JOIN foodie_fi.plans p ON r.plan_id = p.plan_id

  UNION ALL

  SELECT *
  FROM irregular_payments
  WHERE plan_id = 2 -- insert basic-to-pro-monthly upgrades; handle basic-to-pro-annual upgrades separately, because the payment schedule already has these records but shows incorrect amounts
  
)
SELECT
	a.customer_id, 
    a.plan_id, 
    a.plan_name, 
    a.payment_date, 
	CASE
    	WHEN b.payment_date IS NOT NULL THEN b.amount
        ELSE a.amount
    END AS amount, 
    ROW_NUMBER() OVER(
      PARTITION BY a.customer_id
      ORDER BY a.payment_date
    ) AS payment_order
FROM price_adjustments a
LEFT JOIN (SELECT * FROM irregular_payments WHERE plan_id = 3) b ON -- modify existing basic-to-pro-annual upgrades
	a.customer_id = b.customer_id AND
    a.plan_id = b.plan_id AND
    a.payment_date = b.payment_date
WHERE a.payment_date BETWEEN '2020-01-01' AND '2020-12-31' -- safety check to ensure only payments in 2020 are included
ORDER BY
	a.customer_id, 
    a.payment_date;