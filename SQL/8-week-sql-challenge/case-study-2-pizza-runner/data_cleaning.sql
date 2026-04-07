/*
====================================
STEP ZERO - Data analysis & cleaning
====================================
*/

SELECT * 
FROM customer_orders;

/*
When we take our first look at the dataset, a few things stand out immediately:
blank cells, multiple attempts at showing us NULL values ('null', '[null]')..
*/

-- How many of each "null-like" value exists in exclusions and extras?
SELECT
  exclusions,
  COUNT(*) AS count
FROM pizza_runner.customer_orders
GROUP BY exclusions
ORDER BY count DESC;

SELECT
  extras,
  COUNT(*) AS count
FROM pizza_runner.customer_orders
GROUP BY extras
ORDER BY count DESC;

/*
Our search reveals: both of those tables have "null" values, but
formatted as strings, not actual NULL values. ALso, both tables have
blank cells as well. Let's deal with both!
*/ 

UPDATE pizza_runner.customer_orders
SET
  exclusions = CASE WHEN exclusions IN ('', 'null', 'NaN') THEN NULL ELSE exclusions END,
  extras     = CASE WHEN extras     IN ('', 'null', 'NaN') THEN NULL ELSE extras     END;

-- Quickly verify no null-like imposters remain in either column:
SELECT
  exclusions,
  extras,
  COUNT(*) AS count
FROM customer_orders_cleaned
GROUP BY exclusions, extras
ORDER BY exclusions, extras;


-- Everything looks nice and tidy here, so let's take a look at the other
-- suspicious table, runner_orders: 

SELECT
  pickup_time,
  distance,
  duration,
  cancellation
FROM pizza_runner.runner_orders
ORDER BY order_id;

-- Geez! Now here, on top of not-so-null NULL values and blank cells, we also have mixed
-- formats in columns pickup_time, distance and duration!

-- Let's go column by column, and start with pickup time:
SELECT
  pickup_time,
  COUNT(*) AS count
FROM pizza_runner.runner_orders
GROUP BY pickup_time;

-- So here we have two instances of string "null" values which we have to replace with the
-- REAL ones: 

-- Replace 'null' strings with real NULLs in pickup_time:
UPDATE pizza_runner.runner_orders
SET pickup_time = CASE
  WHEN pickup_time = 'null' THEN NULL
  ELSE pickup_time
END;

-- Checking if the column is ok
SELECT * FROM runner_orders;

-- Now lets go on to distance!
SELECT
  distance,
  COUNT(*) AS count
FROM pizza_runner.runner_orders
GROUP BY distance;

-- Distance is all over the place:
-- '20km', '13.4km', '25km', '10km'  → unit glued to the number, no space
-- '23.4 km'                         → unit glued with a space
-- '23.4', '10'                      → numeric string, no unit at all
--  'null'                           → string, not real NULL (2 cancelled orders)

-- Let's fix this as well: 

-- Strip everything non-numeric and cast to NUMERIC:
UPDATE pizza_runner.runner_orders
SET distance = CASE
  WHEN distance = 'null' THEN NULL
  ELSE REGEXP_REPLACE(distance, '[^0-9.]', '', 'g')
END;

-- Checking if the column is ok
SELECT * FROM runner_orders;

-- Let's go on to location: 
SELECT duration, 
COUNT(*) 
FROM pizza_runner.runner_orders 
GROUP BY duration;

-- Strip all unit variations and 'null' strings from duration, cast to numeric:
UPDATE pizza_runner.runner_orders
SET duration = CASE
  WHEN duration = 'null' THEN NULL
  ELSE REGEXP_REPLACE(duration, '[^0-9]', '', 'g')
END;

-- Verifying: 
SELECT * FROM runner_orders

-- All we have left to clean is the cancellation column: 
SELECT cancellation, 
COUNT(*) 
FROM pizza_runner.runner_orders 
GROUP BY cancellation;

-- Replace 'null' strings with real NULLs in cancellation:
UPDATE pizza_runner.runner_orders
SET cancellation = CASE
  WHEN cancellation IN ('', 'null', 'NaN') THEN NULL
  ELSE cancellation
END;

-- Verify the results: 
SELECT * FROM customer_orders
