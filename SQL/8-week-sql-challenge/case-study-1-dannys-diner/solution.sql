/*
=============================
CASE STUDY #1 - Danny's Diner
=============================
*/



/*
===================================================================
Q1: What is the total amount each customer spent at the restaurant?
===================================================================
*/

SELECT 
	s.customer_id AS Customer, 
	SUM(m.price) AS Total_amount_spent
FROM sales s 
	JOIN menu m
		ON s.product_id = m.product_id
GROUP BY s.customer_id
ORDER BY s.customer_id 



/*
===========================================================
Q2: How many days has each customer visited the restaurant?
===========================================================
*/

SELECT
	customer_id AS Customer,
	COUNT(DISTINCT order_date) AS Days_visited
FROM sales
GROUP BY customer_id



/*
=====================================================================
Q3: What was the first item from the menu purchased by each customer?
=====================================================================
*/

-- CTE for first date / customer
WITH first_date_per_customer AS
(
	SELECT
		customer_id, 
		MIN(order_date) AS order_date
	FROM SALES
	GROUP BY customer_id
)

-- Selecting the data
SELECT 
	s.customer_id AS Customer, 
	m.product_name AS First_items_bought
FROM first_date_per_customer AS fdpc
	JOIN sales s
		ON fdpc.customer_id = s.customer_id
	JOIN menu m
		ON s.product_id = m.product_id
WHERE s.order_date = fdpc.order_date
GROUP BY s.customer_id, m.product_name
ORDER BY s.customer_id, m.product_name



/*
=====================================================================================================
Q4: What is the most purchased item on the menu and how many times was it purchased by all customers?
=====================================================================================================
*/

SELECT
	m.product_name AS Dish_name, 
	COUNT(s.product_id) AS Times_ordered
FROM sales s
	JOIN menu m
		ON s.product_id = m.product_id
GROUP BY m.product_name
ORDER BY times_ordered DESC



/*
======================================================
Q5: Which item was the most popular for each customer?
======================================================
*/

-- Creating a CTE to count how many times each customer ordered each dish
WITH customer_orders AS 
(
SELECT
	s.customer_id AS Customer,
	m.product_name AS Dish_name, 
	COUNT(s.product_id) AS Times_ordered
FROM sales s
	JOIN menu m
		ON s.product_id = m.product_id
GROUP BY s.customer_id, m.product_name
), 

-- Using DENSE_RANK () to rank dishes per customer by order count (highest = rank 1)
ranked AS 
(
SELECT 
	*, 
	DENSE_RANK() OVER(
		PARTITION BY Customer 
		ORDER BY times_ordered DESC) 
			AS rank
FROM customer_orders
)

-- Keep only the top ranked dish(es) per customer
SELECT 
	Customer, 
	Dish_name
FROM ranked
WHERE rank = 1
ORDER BY Customer


/*
==============================================================================
Q6: Which item was purchased first by the customer after they became a member?
==============================================================================
*/

-- Writing a CTE showing the purchases of customers AFTER becoming a member
WITH purchases_after_membership AS
(
SELECT
	s.customer_id AS Customer,
	s.order_date,
	m.product_name AS Dish_name
FROM sales s
	JOIN members mb
		ON s.customer_id = mb.customer_id
	JOIN menu m
		ON s.product_id = m.product_id
WHERE s.order_date >= mb.join_date
),

-- Rank purchases per customer by order date (earliest = rank 1)
ranked AS
(
SELECT
	*,
	DENSE_RANK() OVER(
		PARTITION BY Customer
		ORDER BY order_date ASC) 
			AS rank
FROM purchases_after_membership
)

-- Keep only the first purchase per customer
SELECT
	Customer,
	Dish_name
FROM ranked
WHERE rank = 1
ORDER BY Customer


/*
======================================================================
Q7: Which item was purchased just before the customer became a member?
======================================================================
*/

-- This is basically the same question as Q6, only reversed. Here is the modified CTE:
-- (I have used s.order_date >= mb.join_date in Q6, so to prevent any duplications here, 
-- I use < instead of <= )

WITH purchases_before_membership AS
(
SELECT
	s.customer_id AS Customer,
	s.order_date,
	m.product_name AS Dish_name
FROM sales s
	JOIN members mb
		ON s.customer_id = mb.customer_id
	JOIN menu m
		ON s.product_id = m.product_id
WHERE s.order_date < mb.join_date
),

-- Rank purchases per customer by order date (earliest = rank 1)
-- Changing line: ORDER BY order_date ASC -> DESC
ranked AS
(
SELECT
	*,
	DENSE_RANK() OVER(
		PARTITION BY Customer
		ORDER BY order_date DESC) 
			AS rank
FROM purchases_before_membership
)

-- Keep only the first purchase per customer
SELECT
	Customer,
	Dish_name
FROM ranked
WHERE rank = 1
ORDER BY Customer


/*
=========================================================================================
Q8: What is the total items and amount spent for each member before they became a member?
=========================================================================================
*/

-- No CTE needed here as we just need to filter, join and aggregate in one step
SELECT
	s.customer_id AS Customer, 
	COUNT(s.producT_id) AS Total_items_ordered, 
	SUM(m.price) AS Total_amount_spent
FROM sales s
	JOIN menu m
		ON s.product_id = m.product_id
	JOIN members mb
		ON s.customer_id = mb.customer_id
WHERE s.order_date < mb.join_date
GROUP BY s.customer_id
ORDER BY s.customer_id


/*
==============================================================================
Q9: If each $1 spent equates to 10 points and sushi has a 2x points multiplier
- how many points would each customer have?
==============================================================================
*/

SELECT
	s.customer_id AS Customer, 
	SUM(CASE 
		WHEN s.product_id = 1 THEN price * 20
		ELSE price * 10
	END) AS customer_points
FROM sales s
	JOIN menu m
		ON s.product_id = m.product_id
GROUP BY s.customer_id
ORDER BY s.customer_id


/*
=====================================================================================
Q10: In the first week after a customer joins the program (including their join date) 
they earn 2x points on all items, not just sushi 
- how many points do customer A and B have at the end of January?
=====================================================================================
*/

-- Create a "first week" CTE:
WITH first_week AS
(
SELECT
	customer_id, 
	join_date, 
	join_date + 6 AS first_week_ending
FROM members
)

-- Select all the neccessary data & calculating points
SELECT
	s.customer_id AS Customer, 
	SUM(
		CASE
        -- multiplier 20 for first week orders
			WHEN s.order_date BETWEEN fw.join_date AND fw.first_week_ending
				THEN m.price * 20
        -- multiplier 20 for all sushi orders
			WHEN m.product_name = 'sushi'
				THEN m.price * 20
        -- multiplier 10 for the rest
			ELSE m.price * 10
		END) AS customer_points
FROM sales s
	JOIN first_week fw
		ON s.customer_id = fw.customer_id
	JOIN menu m
		ON s.product_id = m.product_id
-- select data only until the the end of January
WHERE s.order_date <= '2021-01-31'
GROUP BY s.customer_id;


/*
====================================================================================================
BONUS QUESTION #1: Join All The Things

The following questions are related creating basic data tables that Danny and 
his team can use to quickly derive insights without needing to join the underlying tables using SQL.

Recreate the following table output using the available data:

customer_id order_date  product_name    price	member
A	        2021-01-01	curry	        15	    N
A	        2021-01-01	sushi	        10	    N
A	        2021-01-07	curry	        15	    Y
A	        2021-01-10	ramen	        12	    Y
====================================================================================================
*/

SELECT
	s.customer_id AS Customer, 
	s.order_date AS Order_date, 
	m.product_name AS Product_name, 
	m.price AS Price,
	CASE 
		WHEN s.order_date >= mb.join_date
			THEN 'Y'
			ELSE 'N'
		END AS Member
FROM sales s
	JOIN menu m
		ON s.product_id = m.product_id
	LEFT JOIN members mb
		ON s.customer_id = mb.customer_id
ORDER BY s.customer_id, s.order_date


/*
====================================================================================================
BONUS QUESTION #2: Rank All The Things

Danny also requires further information about the ranking of customer products, 
but he purposely does not need the ranking for non-member purchases so he expects null ranking values 
for the records when customers are not yet part of the loyalty program.

customer_id	order_date	product_name	price	member	ranking
A	        2021-01-01	curry	        15	    N	    null
A	        2021-01-01	sushi	        10	    N	    null
A	        2021-01-07	curry	        15	    Y	    1
A	        2021-01-10	ramen	        12	    Y	    2
A	        2021-01-11	ramen	        12	    Y	    3
====================================================================================================
*/

-- Creating a "members only" CTE
WITH member_table AS 
(
SELECT 
	s.customer_id AS Customer, 
	s.order_date AS Order_date,
	m.product_name AS Product_name, 
	m.price AS Product_price,
	CASE 
		WHEN s.order_date >= mb.join_date
			THEN 'Y'
			ELSE 'N'
		END AS member
FROM sales s
	LEFT JOIN members mb
		ON s.customer_id = mb.customer_id
	JOIN menu m
		ON s.product_id = m.product_id
)
-- Selecting all the data, with emphasis on DENSE RANK() PARTITION BY Customer AND Member
SELECT
    *,
    CASE
        WHEN member = 'N' THEN NULL
        ELSE DENSE_RANK() OVER(
            PARTITION BY Customer, Member
            ORDER BY Order_date
        )
    END AS ranking
FROM member_table
