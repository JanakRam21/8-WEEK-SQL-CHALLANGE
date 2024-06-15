
SELECT 
customer_id,
plan_name,
price,
start_date
FROM subscriptions as S
INNER JOIN plans as P ON S.plan_id = P.plan_id
WHERE customer_id <= 8;


-- B. Data Analysis Questions
-- 1. How many customers has Foodie-Fi ever had?
SELECT 
COUNT(DISTINCT customer_id) as customer_count
FROM subscriptions;


-- 2. What is the monthly distribution of trial plan start_date values for our dataset - use the start of the month as the group by value
SELECT
    extract(month from start_date) AS month_start,
    COUNT(customer_id) AS trial_start_count
FROM
    plans p inner join subscriptions s
    on p.plan_id-s.plan_id
WHERE
    plan_name = 'trial'
GROUP BY
 extract(month from start_date) 
ORDER BY
    month_start;


-- 3. What plan start_date values occur after the year 2020 for our dataset? Show the breakdown by count of events for each plan_name
SELECT
    plan_name,
    COUNT(Start_date) AS event_count
FROM
    subscriptions s join plans p
    on p.plan_id=s.plan_id
WHERE
    extract(year from start_date) > '2020'
GROUP BY
    plan_name
ORDER BY
    event_count DESC;

-- 4. What is the customer count and percentage of customers who have churned rounded to 1 decimal place?
SELECT 
(SELECT COUNT(DISTINCT customer_id) FROM subscriptions) as customer_count,
ROUND((COUNT(DISTINCT customer_id)/(SELECT COUNT(DISTINCT customer_id) FROM subscriptions))*100,1) as churned_customers_percent
FROM subscriptions 
WHERE plan_id = 4;


-- 5. How many customers have churned straight after their initial free trial - what percentage is this rounded to the nearest whole number?
WITH CTE AS (
SELECT 
customer_id,
plan_name,
ROW_NUMBER() OVER(PARTITION BY customer_id ORDER BY start_date ASC) as rn
FROM subscriptions as S
INNER JOIN plans as P on S.plan_id = P.plan_id
)
SELECT 
COUNT(DISTINCT customer_id) as churned_afer_trial_customers,
ROUND((COUNT(DISTINCT customer_id) / (SELECT COUNT(DISTINCT customer_id) FROM subscriptions))*100,0) as percent_churn_after_trial
FROM CTE
WHERE rn = 2
AND plan_name = 'churn';


-- 6. What is the number and percentage of customer plans after their initial free trial?
WITH CTE AS (
SELECT
customer_id,
plan_name,
ROW_NUMBER() OVER(PARTITION BY customer_id ORDER BY start_date ASC) as rn
FROM subscriptions as S
INNER JOIN plans as P on P.plan_id = S.plan_id
)
SELECT 
plan_name,
COUNT(customer_id) as customer_count,
ROUND((COUNT(customer_id) / (SELECT COUNT(DISTINCT customer_id) FROM CTE))*100,1) as customer_percent
FROM CTE
WHERE rn = 2
GROUP BY plan_name;


-- 7. What is the customer count and percentage breakdown of all 5 plan_name values at 2020-12-31?
WITH CTE AS (
SELECT *
,ROW_NUMBER() OVER(PARTITION BY customer_id ORDER BY start_date DESC) as rn
FROM subscriptions
WHERE start_date <= '2020-12-31'
)
SELECT 
plan_name,
COUNT(customer_id) as customer_count,
ROUND((COUNT(customer_id)/(SELECT COUNT(DISTINCT customer_id) FROM CTE))*100,1) as percent_of_customers
FROM CTE
INNER JOIN plans as P on CTE.plan_id = P.plan_id
WHERE rn = 1
GROUP BY plan_name;


-- 8. How many customers have upgraded to an annual plan in 2020?
-- Any customer going to annual plan
SELECT COUNT(customer_id) as annual_upgrade_customers
FROM subscriptions as S
INNER JOIN plans as P on P.plan_id = S.plan_id
WHERE extract(year from start_date) = 2020
AND plan_name = 'pro annual';

-- 9. How many days on average does it take for a customer to an annual plan from the day they join Foodie-Fi?

WITH trial_plan_customer_cte AS
  (SELECT *
   FROM subscriptions
   JOIN plans USING (plan_id)
   WHERE plan_id=0),
     annual_plan_customer_cte AS
  (SELECT *
   FROM subscriptions
   JOIN plans USING (plan_id)
   WHERE plan_id=3)
SELECT round(avg(datediff(annual_plan_customer_cte.start_date, trial_plan_customer_cte.start_date)), 2)AS avg_conversion_days
FROM trial_plan_customer_cte
INNER JOIN annual_plan_customer_cte USING (customer_id);

-- 10. Can you further breakdown this average value into 30 day periods (i.e. 0-30 days, 31-60 days etc)
WITH next_plan_cte AS
  (SELECT *,
          lead(start_date, 1) over(PARTITION BY customer_id
                                   ORDER BY start_date) AS next_plan_start_date,
          lead(plan_id, 1) over(PARTITION BY customer_id
                                ORDER BY start_date) AS next_plan
   FROM subscriptions),
     window_details_cte AS
  (SELECT *,
          datediff(next_plan_start_date, start_date) AS days,
          round(datediff(next_plan_start_date, start_date)/30) AS window_30_days
   FROM next_plan_cte
   WHERE next_plan=3)
SELECT window_30_days,
       count(*) AS customer_count
FROM window_details_cte
GROUP BY window_30_days
ORDER BY window_30_days;

-- 11. How many customers downgraded from a pro monthly to a basic monthly plan in 2020?
WITH next_plan_cte AS
  (SELECT *,
          lead(plan_id, 1) over(PARTITION BY customer_id
                                ORDER BY start_date) AS next_plan
   FROM subscriptions)
SELECT count(*) AS downgrade_count
FROM next_plan_cte
WHERE plan_id=2
  AND next_plan=1
  AND year(start_date);