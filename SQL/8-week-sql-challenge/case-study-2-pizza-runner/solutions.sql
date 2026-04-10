/*
=============================
CASE STUDY #2 - Pizza Metrics
=============================
*/

-- ================
-- A. Pizza Metrics
-- ================

SET search_path = pizza_runner;

-- A.1. How many pizzas were ordered?

SELECT 
	COUNT(pizza_id) 
FROM customer_orders;



-- A.2. How many unique customer orders were made?

SELECT 
	COUNT(DISTINCT order_id)
FROM customer_orders;



-- A.3. How many successful orders were delivered by each runner?

SELECT 
	runner_id AS Runner,
	COUNT(DISTINCT order_id) AS Succesful_orders
FROM runner_orders
WHERE cancellation IS NULL
GROUP BY runner_id;



-- A.4. How many of each type of pizza was delivered?

SELECT 
	pn.pizza_name AS Pizza, 
	COUNT(co.pizza_id) AS Total_deliveries
FROM customer_orders co
	JOIN pizza_names pn
		ON co.pizza_id = pn.pizza_id
	JOIN runner_orders ro
		ON co.order_id = ro.order_id
WHERE ro.cancellation IS NULL
GROUP BY pn.pizza_id, pn.pizza_name;



-- A.5. How many Vegetarian and Meatlovers were ordered by each customer?

SELECT
	co.customer_id AS Customer, 
	pn.pizza_name AS Pizza,
	COUNT(co.pizza_id) AS Total_orders
FROM customer_orders co
	JOIN pizza_names pn
		ON co.pizza_id = pn.pizza_id
GROUP BY pn.pizza_name, co.customer_id
ORDER BY co.customer_id;



-- A.6. What was the maximum number of pizzas delivered in a single order?

-- Create "max_order" CTE
WITH max_order AS(
SELECT 
	order_id AS Orders,
	COUNT(pizza_id) AS Pizza_count
FROM customer_orders
GROUP BY order_id)
-- Select data from CTE
SELECT 
	MAX(Pizza_count) AS Most_pizzas_ordered
FROM max_order



-- A.7. For each customer, how many delivered pizzas had at least 1 change and how many had no changes?

-- CTE for pizza changes (exlusions and extras)
WITH changes AS(
SELECT 
	co.customer_id AS Customer, 
	ro.order_id AS Pizza_order, 
	ro.cancellation,
	CASE 
		WHEN exclusions IS NOT NULL OR extras IS NOT NULL
			THEN 'YES' ELSE 'NO'
		END AS Changes
FROM customer_orders co
	JOIN runner_orders ro
		ON co.order_id = ro.order_id
)
-- Selecting from CTE
SELECT 
	Customer,  
	Changes, 
	COUNT(*) AS Total
FROM changes
WHERE cancellation IS NULL
GROUP BY Customer, Changes
ORDER BY Customer, Changes



-- A.8. How many pizzas were delivered that had both exclusions and extras?

SELECT COUNT(*)
FROM customer_orders co
	JOIN runner_orders ro
		ON co.order_id = ro.order_id
WHERE co.exclusions IS NOT NULL
	AND co.extras IS NOT NULL
	AND ro.cancellation IS NOT NULL;



-- A.9.: What was the total volume of pizzas ordered for each hour of the day?

SELECT 
	COUNT(order_id) AS Pizzas_ordered,
	EXTRACT(HOUR FROM order_time) AS Hour_of_day
FROM customer_orders
GROUP BY Hour_of_day
ORDER BY Hour_of_day;



-- A10: What was the volume of orders for each day of the week?

SELECT 
	COUNT(order_id) AS Pizzas_ordered,
	TO_CHAR(order_time, 'DAY') AS Day_of_week
FROM customer_orders
GROUP BY Day_of_week;

-- =================================
-- B. Runner and Customer Experience
-- =================================



-- B.1. How many runners signed up for each 1 week period? (i.e. week starts 2021-01-01)

SELECT  
	FLOOR((registration_date - '2021-01-01'::date) / 7) + 1 AS Week_no, 
	COUNT(runner_id) AS Runners_signed_up
FROM runners
GROUP BY Week_no
ORDER BY Week_no;



-- B.2. What was the average time in minutes it took for each runner to arrive at the Pizza Runner HQ to pick up the order?

SELECT 
	ro.runner_id AS Runner, 
-- 1. pickup_time is still stored as VARCHAR — I replaced the 'null' strings with real NULLs when cleaning, 
-- but never cast the column to an actual TIMESTAMP type
-- 2. formatting the output with EXTRACT EPOCH & ROUND
	ROUND(EXTRACT (EPOCH FROM AVG(ro.pickup_time::timestamp - co.order_time)) / 60, 2) AS Avg_minutes_to_arrive
FROM customer_orders co
	JOIN runner_orders ro
		ON co.order_id = ro.order_id
GROUP BY Runner;



-- B.3. Is there any relationship between the number of pizzas and how long the order takes to prepare?
-- This question is similar to B.2., exept it's more analytical — in addition to calculating  the 
-- preparation time per order, we also need the number of pizzas per order.

SELECT 
    co.order_id AS Order_no,
    COUNT(pizza_id) AS Pizzas_ordered,
    ROUND(EXTRACT(EPOCH FROM (ro.pickup_time::timestamp - co.order_time)) / 60, 2) AS Prep_time_minutes, 
	ROUND(((EXTRACT(EPOCH FROM (ro.pickup_time::timestamp - co.order_time)) / 60)
		/
	COUNT(pizza_id)), 2) AS Prep_time_per_pizza
	
FROM customer_orders co
JOIN runner_orders ro
    ON co.order_id = ro.order_id
WHERE ro.cancellation IS NULL
GROUP BY co.order_id, ro.pickup_time, co.order_time
ORDER BY pizzas_ordered DESC;

-- ANSWER: there is a clear positive relationship:
-- more pizzas in an order correlates with longer preparation time. 
-- Each additional pizza adds roughly 10 minutes of prep time.



-- B.4. What was the average distance travelled for each customer?

-- We only want successful deliveries and we need 1 row per order,
-- otherwise orders with multiple pizzas would duplicate the travelled distance.

SELECT 
	co.customer_id AS Customer,
	ROUND(AVG(ro.distance::numeric), 2) AS Avg_distance_km
FROM (
	SELECT DISTINCT customer_id, order_id
	FROM customer_orders
) co
	JOIN runner_orders ro
		ON co.order_id = ro.order_id
WHERE ro.cancellation IS NULL
GROUP BY co.customer_id
ORDER BY co.customer_id;



-- B.5. What was the difference between the longest and shortest delivery times for all orders?

SELECT 
	MAX(duration::numeric) - MIN(duration::numeric) AS Delivery_time_difference_minutes
FROM runner_orders
WHERE cancellation IS NULL;



-- B.6. What was the average speed for each runner for each delivery and do you notice any trend for these values?

SELECT 
	order_id AS Order_no,
	runner_id AS Runner,
	ROUND((distance::numeric / duration::numeric) * 60, 2) AS Avg_speed_kmh
FROM runner_orders
WHERE cancellation IS NULL
ORDER BY runner_id, order_id;

-- ANSWER: there is no consistent runner-specific trend.
-- Most speeds fall into a realistic range, but runner 2 has one unusually high value,
-- which suggests either inconsistent delivery conditions or a data quality issue in the duration/distance fields.



-- B.7. What is the successful delivery percentage for each runner?

SELECT 
	runner_id AS Runner,
	ROUND(100.0 * COUNT(CASE WHEN cancellation IS NULL THEN 1 END) / COUNT(*), 2) AS Successful_delivery_pct
FROM runner_orders
GROUP BY runner_id
ORDER BY runner_id;



-- ==========================
-- C. Ingredient Optimisation
-- ==========================



-- C.1. What are the standard ingredients for each pizza?

SELECT 
	pn.pizza_name AS Pizza,
	STRING_AGG(pt.topping_name, ', ' ORDER BY pt.topping_name) AS Standard_ingredients
FROM pizza_names pn
	JOIN pizza_recipes pr
		ON pn.pizza_id = pr.pizza_id
	CROSS JOIN LATERAL UNNEST(STRING_TO_ARRAY(pr.toppings, ', ')) AS topping_id
	JOIN pizza_toppings pt
		ON topping_id::int = pt.topping_id
GROUP BY pn.pizza_name
ORDER BY pn.pizza_name;



-- C.2. What was the most commonly added extra?

SELECT 
	pt.topping_name AS Most_common_extra,
	COUNT(*) AS Times_added
FROM customer_orders co
	CROSS JOIN LATERAL UNNEST(STRING_TO_ARRAY(co.extras, ', ')) AS extra_id
	JOIN pizza_toppings pt
		ON extra_id::int = pt.topping_id
WHERE co.extras IS NOT NULL
GROUP BY pt.topping_name
ORDER BY Times_added DESC
LIMIT 1;



-- C.3. What was the most common exclusion?

SELECT 
	pt.topping_name AS Most_common_exclusion,
	COUNT(*) AS Times_excluded
FROM customer_orders co
	CROSS JOIN LATERAL UNNEST(STRING_TO_ARRAY(co.exclusions, ', ')) AS exclusion_id
	JOIN pizza_toppings pt
		ON exclusion_id::int = pt.topping_id
WHERE co.exclusions IS NOT NULL
GROUP BY pt.topping_name
ORDER BY Times_excluded DESC
LIMIT 1;



-- C.4. Generate an order item for each record in the customer_orders table.

WITH order_details AS(
SELECT 
	co.order_id,
	co.customer_id,
	pn.pizza_name,
	(
		SELECT STRING_AGG(pt.topping_name, ', ' ORDER BY pt.topping_name)
		FROM UNNEST(STRING_TO_ARRAY(co.exclusions, ', ')) AS exclusion_id
			JOIN pizza_toppings pt
				ON exclusion_id::int = pt.topping_id
	) AS exclusion_list,
	(
		SELECT STRING_AGG(pt.topping_name, ', ' ORDER BY pt.topping_name)
		FROM UNNEST(STRING_TO_ARRAY(co.extras, ', ')) AS extra_id
			JOIN pizza_toppings pt
				ON extra_id::int = pt.topping_id
	) AS extra_list
FROM customer_orders co
	JOIN pizza_names pn
		ON co.pizza_id = pn.pizza_id
)
SELECT 
	order_id AS Order_no,
	customer_id AS Customer,
	CASE 
		WHEN exclusion_list IS NULL AND extra_list IS NULL
			THEN pizza_name
		WHEN exclusion_list IS NOT NULL AND extra_list IS NULL
			THEN pizza_name || ' - Exclude ' || exclusion_list
		WHEN exclusion_list IS NULL AND extra_list IS NOT NULL
			THEN pizza_name || ' - Extra ' || extra_list
		ELSE pizza_name || ' - Exclude ' || exclusion_list || ' - Extra ' || extra_list
	END AS Order_item
FROM order_details
ORDER BY order_id, customer_id;



-- C.5. Generate an alphabetically ordered comma separated ingredient list for each pizza order
-- and add a 2x in front of any relevant ingredients.

WITH base_toppings AS(
	SELECT 
		co.order_id,
		co.customer_id,
		pn.pizza_name,
		pt.topping_name
	FROM customer_orders co
		JOIN pizza_names pn
			ON co.pizza_id = pn.pizza_id
		JOIN pizza_recipes pr
			ON co.pizza_id = pr.pizza_id
		CROSS JOIN LATERAL UNNEST(STRING_TO_ARRAY(pr.toppings, ', ')) AS topping_id
		JOIN pizza_toppings pt
			ON topping_id::int = pt.topping_id
	WHERE NOT EXISTS(
		SELECT 1
		FROM UNNEST(STRING_TO_ARRAY(co.exclusions, ', ')) AS exclusion_id
		WHERE exclusion_id::int = pt.topping_id
	)
),
extra_toppings AS(
	SELECT 
		co.order_id,
		co.customer_id,
		pn.pizza_name,
		pt.topping_name
	FROM customer_orders co
		JOIN pizza_names pn
			ON co.pizza_id = pn.pizza_id
		CROSS JOIN LATERAL UNNEST(STRING_TO_ARRAY(co.extras, ', ')) AS extra_id
		JOIN pizza_toppings pt
			ON extra_id::int = pt.topping_id
	WHERE co.extras IS NOT NULL
),
all_toppings AS(
	SELECT * FROM base_toppings
	UNION ALL
	SELECT * FROM extra_toppings
),
counted_toppings AS(
	SELECT 
		order_id,
		customer_id,
		pizza_name,
		topping_name,
		COUNT(*) AS topping_count
	FROM all_toppings
	GROUP BY order_id, customer_id, pizza_name, topping_name
)
SELECT 
	order_id AS Order_no,
	customer_id AS Customer,
	pizza_name || ': ' || STRING_AGG(
		CASE 
			WHEN topping_count > 1 THEN topping_count || 'x' || topping_name
			ELSE topping_name
		END,
		', ' ORDER BY topping_name
	) AS Ingredient_list
FROM counted_toppings
GROUP BY order_id, customer_id, pizza_name
ORDER BY order_id, customer_id;



-- C.6. What is the total quantity of each ingredient used in all delivered pizzas sorted by most frequent first?

WITH delivered_base_toppings AS(
	SELECT 
		pt.topping_name
	FROM customer_orders co
		JOIN runner_orders ro
			ON co.order_id = ro.order_id
		JOIN pizza_recipes pr
			ON co.pizza_id = pr.pizza_id
		CROSS JOIN LATERAL UNNEST(STRING_TO_ARRAY(pr.toppings, ', ')) AS topping_id
		JOIN pizza_toppings pt
			ON topping_id::int = pt.topping_id
	WHERE ro.cancellation IS NULL
		AND NOT EXISTS(
			SELECT 1
			FROM UNNEST(STRING_TO_ARRAY(co.exclusions, ', ')) AS exclusion_id
			WHERE exclusion_id::int = pt.topping_id
		)
),
delivered_extra_toppings AS(
	SELECT 
		pt.topping_name
	FROM customer_orders co
		JOIN runner_orders ro
			ON co.order_id = ro.order_id
		CROSS JOIN LATERAL UNNEST(STRING_TO_ARRAY(co.extras, ', ')) AS extra_id
		JOIN pizza_toppings pt
			ON extra_id::int = pt.topping_id
	WHERE ro.cancellation IS NULL
		AND co.extras IS NOT NULL
),
all_delivered_toppings AS(
	SELECT topping_name FROM delivered_base_toppings
	UNION ALL
	SELECT topping_name FROM delivered_extra_toppings
)
SELECT 
	topping_name AS Ingredient,
	COUNT(*) AS Total_quantity_used
FROM all_delivered_toppings
GROUP BY topping_name
ORDER BY Total_quantity_used DESC, topping_name;



-- ======================
-- D. Pricing and Ratings
-- ======================



-- D.1. If a Meat Lovers pizza costs $12 and Vegetarian costs $10 and there were no charges for changes -
-- how much money has Pizza Runner made so far if there are no delivery fees?

SELECT 
	SUM(
		CASE 
			WHEN pizza_id = 1 THEN 12
			WHEN pizza_id = 2 THEN 10
		END
	) AS Revenue
FROM customer_orders co
	JOIN runner_orders ro
		ON co.order_id = ro.order_id
WHERE ro.cancellation IS NULL;



-- D.2. What if there was an additional $1 charge for any pizza extras?
-- Add cheese is $1 extra.

SELECT 
	SUM(
		CASE 
			WHEN pizza_id = 1 THEN 12
			WHEN pizza_id = 2 THEN 10
		END
	)
	+
	SUM(
		CASE 
			WHEN extras IS NOT NULL THEN CARDINALITY(STRING_TO_ARRAY(extras, ', '))
			ELSE 0
		END
	) AS Revenue_with_extras
FROM customer_orders co
	JOIN runner_orders ro
		ON co.order_id = ro.order_id
WHERE ro.cancellation IS NULL;



-- D.3. The Pizza Runner team now wants to add an additional ratings system that allows customers
-- to rate their runner. Generate a schema for this new table and insert your own data for ratings
-- for each successful customer order between 1 to 5.

CREATE TABLE runner_ratings (
	order_id INTEGER PRIMARY KEY,
	customer_id INTEGER NOT NULL,
	runner_id INTEGER NOT NULL,
	rating INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
	rating_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO runner_ratings (order_id, customer_id, runner_id, rating)
VALUES
	(1, 101, 1, 5),
	(2, 101, 1, 5),
	(3, 102, 1, 4),
	(4, 103, 2, 3),
	(5, 104, 3, 4),
	(7, 105, 2, 3),
	(8, 102, 2, 4),
	(10, 104, 1, 5);



-- D.4. Using your newly generated table - can you join all of the information together to form a table
-- which has the following information for successful deliveries?
-- customer_id
-- order_id
-- runner_id
-- rating
-- order_time
-- pickup_time
-- Time between order and pickup
-- Delivery duration
-- Average speed
-- Total number of pizzas

WITH order_summary AS(
SELECT 
	co.order_id,
	co.customer_id,
	MIN(co.order_time) AS order_time,
	COUNT(*) AS total_pizzas
FROM customer_orders co
GROUP BY co.order_id, co.customer_id
)
SELECT 
	os.customer_id,
	os.order_id,
	ro.runner_id,
	rr.rating,
	os.order_time,
	ro.pickup_time,
	ROUND(EXTRACT(EPOCH FROM (ro.pickup_time::timestamp - os.order_time)) / 60, 2) AS Minutes_between_order_and_pickup,
	ro.duration AS Delivery_duration_minutes,
	ROUND((ro.distance::numeric / ro.duration::numeric) * 60, 2) AS Avg_speed_kmh,
	os.total_pizzas
FROM order_summary os
	JOIN runner_orders ro
		ON os.order_id = ro.order_id
	JOIN runner_ratings rr
		ON os.order_id = rr.order_id
WHERE ro.cancellation IS NULL
ORDER BY os.order_id;



-- D.5. If a Meat Lovers pizza was $12 and Vegetarian $10 fixed prices with no cost for extras
-- and each runner is paid $0.30 per kilometre traveled - how much money does Pizza Runner have left over
-- after these deliveries?

WITH revenue AS(
	SELECT 
		SUM(
			CASE 
				WHEN co.pizza_id = 1 THEN 12
				WHEN co.pizza_id = 2 THEN 10
			END
		) AS total_revenue
	FROM customer_orders co
		JOIN runner_orders ro
			ON co.order_id = ro.order_id
	WHERE ro.cancellation IS NULL
),
runner_costs AS(
	SELECT 
		SUM(distance::numeric * 0.30) AS total_runner_cost
	FROM runner_orders
	WHERE cancellation IS NULL
)
SELECT 
	r.total_revenue,
	rc.total_runner_cost,
	ROUND(r.total_revenue - rc.total_runner_cost, 2) AS Money_left_over
FROM revenue r
	CROSS JOIN runner_costs rc;



-- =================
-- E. Bonus Question
-- =================


-- E.1. If Danny wants to expand his range of pizzas - how would this impact the existing data design?
-- Write an INSERT statement to demonstrate what would happen if a new Supreme pizza with all the toppings
-- was added to the Pizza Runner menu?

-- The current design handles this change well:
-- 1. add the new pizza to pizza_names
-- 2. add its topping recipe to pizza_recipes
-- No structural redesign is required.

INSERT INTO pizza_names (pizza_id, pizza_name)
VALUES (3, 'Supreme');

INSERT INTO pizza_recipes (pizza_id, toppings)
VALUES (3, '1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12');
