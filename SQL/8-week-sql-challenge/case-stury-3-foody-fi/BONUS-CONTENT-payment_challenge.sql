-- Foodie-Fi payment challenge
-- PostgreSQL solution with a recursive monthly payment generator.
-- This file is intentionally separated from solution.sql because it is the most complex part.

SET search_path = foodie_fi;

WITH ordered AS (
    SELECT
        s.customer_id,
        s.plan_id,
        p.plan_name,
        p.price,
        s.start_date,
        LEAD(s.start_date) OVER (
            PARTITION BY s.customer_id
            ORDER BY s.start_date
        ) AS next_start_date,
        LAG(s.plan_id) OVER (
            PARTITION BY s.customer_id
            ORDER BY s.start_date
        ) AS prev_plan_id,
        LAG(p.price) OVER (
            PARTITION BY s.customer_id
            ORDER BY s.start_date
        ) AS prev_price
    FROM subscriptions AS s
    JOIN plans AS p
        ON s.plan_id = p.plan_id
),
paid_plans AS (
    SELECT *
    FROM ordered
    WHERE plan_id IN (1, 2, 3)
),
recursive_payments AS (
    -- seed rows
    SELECT
        customer_id,
        plan_id,
        plan_name,
        start_date AS payment_date,
        CASE
            WHEN plan_id IN (1, 2)
                 AND prev_plan_id = 1
                 AND start_date = next_start_date THEN price - COALESCE(prev_price, 0)
            ELSE price
        END::numeric(10,2) AS amount,
        start_date,
        next_start_date,
        1 AS payment_order
    FROM paid_plans

    UNION ALL

    -- future monthly renewals for monthly plans
    SELECT
        rp.customer_id,
        rp.plan_id,
        rp.plan_name,
        (rp.payment_date + INTERVAL '1 month')::date AS payment_date,
        rp.amount,
        rp.start_date,
        rp.next_start_date,
        rp.payment_order + 1
    FROM recursive_payments AS rp
    WHERE rp.plan_id IN (1, 2)
      AND (rp.payment_date + INTERVAL '1 month')::date <= COALESCE(rp.next_start_date - INTERVAL '1 day', DATE '2020-12-31')
      AND (rp.payment_date + INTERVAL '1 month')::date <= DATE '2020-12-31'
)
SELECT
    customer_id,
    plan_id,
    plan_name,
    payment_date,
    amount,
    payment_order
FROM recursive_payments
WHERE payment_date <= DATE '2020-12-31'
ORDER BY customer_id, payment_date;
