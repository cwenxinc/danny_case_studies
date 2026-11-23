/* --------------------
   Payment Schedule
   --------------------*/
   
   -- Create a new table showing the payments made by each customer throughout 2020, subject to the following business rules:
   -- 1) payments are always due on the same day of the month as the original start date of the customer's monthly paid plan;
   -- 2) upgrades from basic monthly to any pro plans take effect immediately, with the current month's payment adjusted by the amount already paid;
   -- 3) upgrades from pro monthly to pro annual take effect at the end of the current billing period, with payment collected at that time;
   -- 4) once a customer churns they will no longer make payments.