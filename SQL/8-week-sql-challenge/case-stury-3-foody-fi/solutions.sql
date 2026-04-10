/*
========================
CASE STUDY #3 - Foody-Fi
========================
*/

SET search_path = foodie_fi;

/*
========================================
A. CUSTOMER JOURNEY
========================================
Based on the 8 sample customers shown in the prompt.
*/

SELECT
    s.customer_id,
    p.plan_name,
    s.start_date
FROM subscriptions AS s
JOIN plans AS p
    ON s.plan_id = p.plan_id
WHERE s.customer_id IN (1, 2, 11, 13, 15, 16, 18, 19)
ORDER BY s.customer_id, s.start_date;

-- Brief journey notes
-- Customer 1: trial -> basic monthly
-- Customer 2: trial -> pro annual
-- Customer 11: trial -> churn
-- Customer 13: trial -> basic monthly -> pro monthly (2021-03-29)
-- Customer 15: trial -> pro monthly -> churn
-- Customer 16: trial -> basic monthly -> pro annual
-- Customer 18: trial -> pro monthly
-- Customer 19: trial -> pro monthly -> pro annual


/*
========================================
HELPER CTE FOR SEQUENTIAL ANALYSIS
========================================
*/

WITH ordered_subscriptions AS (
    SELECT
        s.customer_id,
        s.plan_id,
        p.plan_name,
        p.price,
        s.start_date,
        LEAD(s.plan_id) OVER (
            PARTITION BY s.customer_id
            ORDER BY s.start_date
        ) AS next_plan_id,
        LEAD(p.plan_name) OVER (
            PARTITION BY s.customer_id
            ORDER BY s.start_date
        ) AS next_plan_name,
        LEAD(s.start_date) OVER (
            PARTITION BY s.customer_id
            ORDER BY s.start_date
        ) AS next_start_date,
        ROW_NUMBER() OVER (
            PARTITION BY s.customer_id
            ORDER BY s.start_date
        ) AS plan_order
    FROM subscriptions AS s
    JOIN plans AS p
        ON s.plan_id = p.plan_id
)
SELECT *
FROM ordered_subscriptions
LIMIT 5;


/*
========================================
B. DATA ANALYSIS QUESTIONS
========================================
*/

-- 1. How many customers has Foodie-Fi ever had?
-- Answer: 1000
SELECT COUNT(DISTINCT customer_id) AS total_customers
FROM subscriptions;


-- 2. Monthly distribution of trial starts
SELECT
    DATE_TRUNC('month', start_date)::date AS month_start,
    COUNT(*) AS trial_starts
FROM subscriptions
WHERE plan_id = 0
GROUP BY 1
ORDER BY 1;

-- Expected result
-- 2020-01-01 | 88
-- 2020-02-01 | 68
-- 2020-03-01 | 94
-- 2020-04-01 | 81
-- 2020-05-01 | 88
-- 2020-06-01 | 79
-- 2020-07-01 | 89
-- 2020-08-01 | 88
-- 2020-09-01 | 87
-- 2020-10-01 | 79
-- 2020-11-01 | 75
-- 2020-12-01 | 84


-- 3. Plan start_date events after 2020-12-31
-- Answer:
-- basic monthly = 8
-- pro monthly   = 60
-- pro annual    = 63
-- churn         = 71
SELECT
    p.plan_name,
    COUNT(*) AS event_count
FROM subscriptions AS s
JOIN plans AS p
    ON s.plan_id = p.plan_id
WHERE s.start_date >= DATE '2021-01-01'
GROUP BY p.plan_name
ORDER BY event_count DESC, p.plan_name;


-- 4. Churn count and percentage
-- Answer: 307 customers, 30.7%
SELECT
    COUNT(DISTINCT CASE WHEN plan_id = 4 THEN customer_id END) AS churned_customers,
    ROUND(
        100.0 * COUNT(DISTINCT CASE WHEN plan_id = 4 THEN customer_id END)
        / COUNT(DISTINCT customer_id),
        1
    ) AS churn_pct
FROM subscriptions;


-- 5. Customers who churned straight after trial
-- Answer: 92 customers, 9.2%
WITH ordered_subscriptions AS (
    SELECT
        customer_id,
        plan_id,
        start_date,
        LEAD(plan_id) OVER (
            PARTITION BY customer_id
            ORDER BY start_date
        ) AS next_plan_id
    FROM subscriptions
)
SELECT
    COUNT(DISTINCT customer_id) AS customers,
    ROUND(
        100.0 * COUNT(DISTINCT customer_id)
        / (SELECT COUNT(DISTINCT customer_id) FROM subscriptions),
        1
    ) AS pct_of_customers
FROM ordered_subscriptions
WHERE plan_id = 0
  AND next_plan_id = 4;


-- 6. Number and percentage of customer plans after initial free trial
-- Answer:
-- basic monthly = 546 (54.6%)
-- pro monthly   = 325 (32.5%)
-- pro annual    =  37 (3.7%)
-- churn         =  92 (9.2%)
WITH ranked_plans AS (
    SELECT
        s.customer_id,
        p.plan_name,
        ROW_NUMBER() OVER (
            PARTITION BY s.customer_id
            ORDER BY s.start_date
        ) AS plan_order
    FROM subscriptions AS s
    JOIN plans AS p
        ON s.plan_id = p.plan_id
)
SELECT
    plan_name,
    COUNT(*) AS customer_count,
    ROUND(
        100.0 * COUNT(*)
        / (SELECT COUNT(DISTINCT customer_id) FROM subscriptions),
        1
    ) AS pct_of_customers
FROM ranked_plans
WHERE plan_order = 2
GROUP BY plan_name
ORDER BY customer_count DESC;


-- 7. Customer count and percentage breakdown at 2020-12-31
-- Answer:
-- trial         =  19 (1.9%)
-- basic monthly = 224 (22.4%)
-- pro monthly   = 326 (32.6%)
-- pro annual    = 195 (19.5%)
-- churn         = 235 (23.5%)
WITH dated_plans AS (
    SELECT
        s.customer_id,
        s.plan_id,
        p.plan_name,
        s.start_date,
        LEAD(s.start_date) OVER (
            PARTITION BY s.customer_id
            ORDER BY s.start_date
        ) AS next_start_date
    FROM subscriptions AS s
    JOIN plans AS p
        ON s.plan_id = p.plan_id
)
SELECT
    plan_name,
    COUNT(DISTINCT customer_id) AS customer_count,
    ROUND(
        100.0 * COUNT(DISTINCT customer_id)
        / (SELECT COUNT(DISTINCT customer_id) FROM subscriptions),
        1
    ) AS pct_of_customers
FROM dated_plans
WHERE start_date <= DATE '2020-12-31'
  AND (next_start_date IS NULL OR next_start_date > DATE '2020-12-31')
GROUP BY plan_name
ORDER BY customer_count DESC;


-- 8. Customers upgraded to pro annual in 2020
-- Answer used here: 195
-- Note: some community solutions report 253 because they count the prior row whose next plan became annual.
-- This script counts actual annual plan start events inside calendar year 2020.
SELECT COUNT(DISTINCT customer_id) AS annual_upgrades_2020
FROM subscriptions
WHERE plan_id = 3
  AND start_date >= DATE '2020-01-01'
  AND start_date < DATE '2021-01-01';


-- 9. Average days to reach pro annual from join date
-- Answer: 104.62 days
WITH trial_start AS (
    SELECT customer_id, start_date AS trial_date
    FROM subscriptions
    WHERE plan_id = 0
),
annual_start AS (
    SELECT customer_id, start_date AS annual_date
    FROM subscriptions
    WHERE plan_id = 3
)
SELECT ROUND(AVG(annual_date - trial_date), 2) AS avg_days_to_annual
FROM trial_start AS t
JOIN annual_start AS a
    ON t.customer_id = a.customer_id;


-- 10. 30-day bucket breakdown to annual plan
WITH trial_start AS (
    SELECT customer_id, start_date AS trial_date
    FROM subscriptions
    WHERE plan_id = 0
),
annual_start AS (
    SELECT customer_id, start_date AS annual_date
    FROM subscriptions
    WHERE plan_id = 3
),
diffs AS (
    SELECT
        a.customer_id,
        (a.annual_date - t.trial_date) AS days_to_annual
    FROM trial_start AS t
    JOIN annual_start AS a
        ON t.customer_id = a.customer_id
),
buckets AS (
    SELECT
        WIDTH_BUCKET(days_to_annual, 0, 360, 12) AS bucket_no,
        days_to_annual
    FROM diffs
)
SELECT
    CONCAT((bucket_no - 1) * 30, '-', bucket_no * 30, ' days') AS day_range,
    COUNT(*) AS customer_count
FROM buckets
GROUP BY bucket_no
ORDER BY bucket_no;

-- Expected result
-- 0-30 days   | 48
-- 30-60 days  | 25
-- 60-90 days  | 33
-- 90-120 days | 35
-- 120-150 days| 43
-- 150-180 days| 35
-- 180-210 days| 27
-- 210-240 days| 4
-- 240-270 days| 5
-- 270-300 days| 1
-- 300-330 days| 1
-- 330-360 days| 1


-- 11. Customers downgraded from pro monthly to basic monthly in 2020
-- Answer: 0
WITH ordered_subscriptions AS (
    SELECT
        customer_id,
        plan_id,
        start_date,
        LEAD(plan_id) OVER (
            PARTITION BY customer_id
            ORDER BY start_date
        ) AS next_plan_id,
        LEAD(start_date) OVER (
            PARTITION BY customer_id
            ORDER BY start_date
        ) AS next_start_date
    FROM subscriptions
)
SELECT COUNT(DISTINCT customer_id) AS downgraded_customers
FROM ordered_subscriptions
WHERE plan_id = 2
  AND next_plan_id = 1
  AND next_start_date >= DATE '2020-01-01'
  AND next_start_date < DATE '2021-01-01';

