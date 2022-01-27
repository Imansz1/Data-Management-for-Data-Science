/*
1. We want to take a look at all of the orders and the products purchased in every order.
If the order was cancelled, show the amount of refund for that order.
*/
SELECT 
	o.order_id,
    p.product_id,
	p.product_name,
    oir.refund_amount_usd
FROM orders o JOIN order_items oi 
				ON o.order_id = oi.order_id
			JOIN products p 
				ON oi.product_id = p.product_id
            LEFT JOIN order_item_refunds oir 
				ON oi.order_item_id = oir.order_item_id
;


/*
2. We want to provide a list of all the customers who have bought more than 90$,
 along with those who have refunded more than 40$.
*/

SELECT 
	'purchase' AS type,
    user_id,
    SUM(items_purchased) AS total_items,
    SUM(price_usd) AS sum_of_prices,
    AVG(price_usd) AS average_price_of_goods
FROM orders
GROUP BY 2
HAVING SUM(price_usd) > 90

UNION

SELECT
	'refund' AS type,
    o.user_id,
    SUM(oir.order_item_refund_id) AS total_items,
    SUM(oir.refund_amount_usd) AS sum_of_prices,
    AVG(oir.refund_amount_usd) AS average_price_of_goods
FROM orders o, order_item_refunds oir
WHERE o.order_id = oir.order_id 
GROUP BY 2
HAVING SUM(oir.refund_amount_usd) > 40;



/*
3. Here we try to find the top traffic sources.
*/

SELECT
	utm_source,
    utm_campaign,
    http_referer,
    COUNT(website_session_id) AS number_of_sessions
FROM website_sessions
WHERE created_at < '2012-04-12'
GROUP BY
	utm_source,
    utm_campaign,
    http_referer
ORDER BY number_of_sessions DESC
;

/*
4. We like to show how we’ve grown specific channels 
by showing the overall session-to-order conversion rate trends for orders 
from Gsearch nonbrand, Bsearch nonbrand, overall brand search, organic search, and direct type-in, 
by quarter.
*/

SELECT
	YEAR(ws.created_at) AS year,
	QUARTER(ws.created_at) AS quarter, 
    COUNT(CASE WHEN utm_source = 'gsearch' AND utm_campaign = 'nonbrand' THEN o.order_id ELSE NULL END)
		/COUNT(CASE WHEN utm_source = 'gsearch' AND utm_campaign = 'nonbrand' THEN ws.website_session_id ELSE NULL END) AS gsearch_nonbrand_conv_rate, 
    COUNT(CASE WHEN utm_source = 'bsearch' AND utm_campaign = 'nonbrand' THEN o.order_id ELSE NULL END) 
		/COUNT(CASE WHEN utm_source = 'bsearch' AND utm_campaign = 'nonbrand' THEN ws.website_session_id ELSE NULL END) AS bsearch_nonbrand_conv_rate, 
    COUNT(CASE WHEN utm_campaign = 'brand' THEN o.order_id ELSE NULL END) 
		/COUNT(CASE WHEN utm_campaign = 'brand' THEN ws.website_session_id ELSE NULL END) AS brand_search_conv_rate,
    COUNT(CASE WHEN utm_source IS NULL AND http_referer IS NOT NULL THEN o.order_id ELSE NULL END) 
		/COUNT(CASE WHEN utm_source IS NULL AND http_referer IS NOT NULL THEN ws.website_session_id ELSE NULL END) AS organic_search_conv_rate,
    COUNT(CASE WHEN utm_source IS NULL AND http_referer IS NULL THEN o.order_id ELSE NULL END) 
		/COUNT(CASE WHEN utm_source IS NULL AND http_referer IS NULL THEN ws.website_session_id ELSE NULL END) AS direct_type_in_conv_rate
FROM website_sessions ws
	LEFT JOIN orders o
		ON ws.website_session_id = o.website_session_id
GROUP BY 1,2
ORDER BY 1,2
;



/*
5. Now, we want to show our volume growth; by pulling overall session and order volume,
session-to-order conversion rate, revenue per order, and revenue per session.
Trended by quarter for the life of the business.
*/ 
-- SLOW

SELECT 
	YEAR(ws.created_at) AS year,
	MONTH(ws.created_at) AS month, 
	COUNT(DISTINCT ws.website_session_id) AS sessions, 
    COUNT(DISTINCT o.order_id) AS orders,
    COUNT(DISTINCT o.order_id)/COUNT(DISTINCT ws.website_session_id) AS session_to_order_conv_rate, 
    SUM(price_usd)/COUNT(DISTINCT o.order_id) AS revenue_per_order, 
    SUM(price_usd)/COUNT(DISTINCT ws.website_session_id) AS revenue_per_session
FROM website_sessions ws
	LEFT JOIN orders o
		ON ws.website_session_id = o.website_session_id
GROUP BY 1,2
ORDER BY 1,2
;

-- FAST

SELECT 
	YEAR(ws.created_at) AS year,
	MONTH(ws.created_at) AS month, 
	COUNT(ws.website_session_id) AS sessions, 
    COUNT(o.order_id) AS orders,
    COUNT(o.order_id)/COUNT(ws.website_session_id) AS session_to_order_conv_rate, 
    SUM(price_usd)/COUNT(o.order_id) AS revenue_per_order, 
    SUM(price_usd)/COUNT(ws.website_session_id) AS revenue_per_session
FROM website_sessions ws
	LEFT JOIN orders o
		ON ws.website_session_id = o.website_session_id
GROUP BY 1,2
ORDER BY 1,2
;


/*
6. We try to pull monthly trending for revenue 
and margin by product, along with total sales and revenue.
*/
SELECT
	YEAR(created_at) AS year, 
    MONTH(created_at) AS month, 
    SUM(CASE WHEN product_id = 1 THEN price_usd ELSE NULL END) AS mrfuzzy_rev,
    SUM(CASE WHEN product_id = 1 THEN price_usd - cogs_usd ELSE NULL END) AS mrfuzzy_marg,
    SUM(CASE WHEN product_id = 2 THEN price_usd ELSE NULL END) AS lovebear_rev,
    SUM(CASE WHEN product_id = 2 THEN price_usd - cogs_usd ELSE NULL END) AS lovebear_marg,
    SUM(CASE WHEN product_id = 3 THEN price_usd ELSE NULL END) AS birthdaybear_rev,
    SUM(CASE WHEN product_id = 3 THEN price_usd - cogs_usd ELSE NULL END) AS birthdaybear_marg,
    SUM(CASE WHEN product_id = 4 THEN price_usd ELSE NULL END) AS minibear_rev,
    SUM(CASE WHEN product_id = 4 THEN price_usd - cogs_usd ELSE NULL END) AS minibear_marg,
    SUM(price_usd) AS total_revenue,  
    SUM(price_usd - cogs_usd) AS total_margin
FROM order_items
GROUP BY 1,2
ORDER BY 1,2
;


/*
7. We try to compare product refund rate in second half of 2013 and 2014,
by pull monthly product refund rates by product.

*/

-- slow

SELECT
	YEAR(oi.created_at) AS year, 
    MONTH(oi.created_at) AS month, 
    COUNT(CASE WHEN product_id = 1 THEN oi.order_item_id ELSE NULL END) AS P1_orders,
    COUNT(CASE WHEN product_id = 1 THEN oir.order_item_id ELSE NULL END)
		/COUNT(CASE WHEN product_id = 1 THEN oi.order_item_id ELSE NULL END) AS p1_refund_rate,
	COUNT(CASE WHEN product_id = 2 THEN oi.order_item_id ELSE NULL END) AS P2_orders,
    COUNT(CASE WHEN product_id = 2 THEN oir.order_item_id ELSE NULL END)
		/COUNT(CASE WHEN product_id = 2 THEN oi.order_item_id ELSE NULL END) AS p2_refund_rate,
    COUNT(CASE WHEN product_id = 3 THEN oi.order_item_id ELSE NULL END) AS P3_orders,
    COUNT(CASE WHEN product_id = 3 THEN oir.order_item_id ELSE NULL END)
		/COUNT(CASE WHEN product_id = 3 THEN oi.order_item_id ELSE NULL END) AS p3_refund_rate,
	COUNT(CASE WHEN product_id = 4 THEN oi.order_item_id ELSE NULL END) AS P4_orders,
    COUNT(CASE WHEN product_id = 4 THEN oir.order_item_id ELSE NULL END)
		/COUNT(CASE WHEN product_id = 4 THEN oi.order_item_id ELSE NULL END) AS p4_refund_rate
FROM order_items oi
	LEFT JOIN order_item_refunds oir
		ON oi.order_item_id = oir.order_item_id
WHERE oi.created_at BETWEEN '2013-6-1' AND '2013-12-30'
GROUP BY 1,2


UNION

SELECT
	YEAR(oi.created_at) AS year, 
    MONTH(oi.created_at) AS month, 
    COUNT(CASE WHEN product_id = 1 THEN oi.order_item_id ELSE NULL END) AS P1_orders,
    COUNT(CASE WHEN product_id = 1 THEN oir.order_item_id ELSE NULL END)
		/COUNT(CASE WHEN product_id = 1 THEN oi.order_item_id ELSE NULL END) AS p1_refund_rate,
	COUNT(CASE WHEN product_id = 2 THEN oi.order_item_id ELSE NULL END) AS P2_orders,
    COUNT(CASE WHEN product_id = 2 THEN oir.order_item_id ELSE NULL END)
		/COUNT(CASE WHEN product_id = 2 THEN oi.order_item_id ELSE NULL END) AS p2_refund_rate,
    COUNT(CASE WHEN product_id = 3 THEN oi.order_item_id ELSE NULL END) AS P3_orders,
    COUNT(CASE WHEN product_id = 3 THEN oir.order_item_id ELSE NULL END)
		/COUNT(CASE WHEN product_id = 3 THEN oi.order_item_id ELSE NULL END) AS p3_refund_rate,
	COUNT(CASE WHEN product_id = 4 THEN oi.order_item_id ELSE NULL END) AS P4_orders,
    COUNT(CASE WHEN product_id = 4 THEN oir.order_item_id ELSE NULL END)
		/COUNT(CASE WHEN product_id = 4 THEN oi.order_item_id ELSE NULL END) AS p4_refund_rate
FROM order_items oi
	LEFT JOIN order_item_refunds oir
		ON oi.order_item_id = oir.order_item_id
WHERE oi.created_at BETWEEN '2014-6-1' AND '2014-12-30'
GROUP BY 1,2
ORDER BY 1,2
;

-- fast

SELECT
	YEAR(oi.created_at) AS year, 
    MONTH(oi.created_at) AS month, 
    COUNT(CASE WHEN product_id = 1 THEN oi.order_item_id ELSE NULL END) AS P1_orders,
    COUNT(CASE WHEN product_id = 1 THEN oir.order_item_id ELSE NULL END)
		/COUNT(CASE WHEN product_id = 1 THEN oi.order_item_id ELSE NULL END) AS p1_refund_rate,
	COUNT(CASE WHEN product_id = 2 THEN oi.order_item_id ELSE NULL END) AS P2_orders,
    COUNT(CASE WHEN product_id = 2 THEN oir.order_item_id ELSE NULL END)
		/COUNT(CASE WHEN product_id = 2 THEN oi.order_item_id ELSE NULL END) AS p2_refund_rate,
    COUNT(CASE WHEN product_id = 3 THEN oi.order_item_id ELSE NULL END) AS P3_orders,
    COUNT(CASE WHEN product_id = 3 THEN oir.order_item_id ELSE NULL END)
		/COUNT(CASE WHEN product_id = 3 THEN oi.order_item_id ELSE NULL END) AS p3_refund_rate,
	COUNT(CASE WHEN product_id = 4 THEN oi.order_item_id ELSE NULL END) AS P4_orders,
    COUNT(CASE WHEN product_id = 4 THEN oir.order_item_id ELSE NULL END)
		/COUNT(CASE WHEN product_id = 4 THEN oi.order_item_id ELSE NULL END) AS p4_refund_rate
FROM order_items oi
	LEFT JOIN order_item_refunds oir
		ON oi.order_item_id = oir.order_item_id
WHERE oi.created_at BETWEEN '2013-6-1' AND '2013-12-30'
	OR oi.created_at BETWEEN '2014-6-1' AND '2014-12-30'
GROUP BY 1,2
ORDER BY 1,2
;
	


/*
7. We want to dive deeper into the impact of introducing new products. We pull monthly sessions to 
the /products page, and show how the percentage of those sessions clicking through another page has changed 
over time, along with a view of how conversion from /products to placing an order has improved.
*/

-- first, identifying all the views of the /products page
CREATE TEMPORARY TABLE products_pageviews
SELECT
	website_session_id, 
    website_pageview_id, 
    created_at AS saw_product_page_at
FROM website_pageviews 
WHERE pageview_url = '/products'
;
create index createdat on mavenfuzzyfactory.website_pageviews(website_pageview_id);
create index createdat on mavenfuzzyfactory.website_sessions(website_session_id);
create index aaa on mavenfuzzyfactory.products_pageviews(website_session_id);
DROP INDEX createdat ON mavenfuzzyfactory.website_sessions;
SHOW INDEX FROM mavenfuzzyfactory.website_pageviews;
create index abc on products_pageviews(saw_product_page_at);
create index abcd on products_pageviews(website_pageview_id);
create index abcds on products_pageviews(website_session_id);
SHOW INDEX FROM mavenfuzzyfactory.products_pageviews;
create index saw_product_page_at on website_pageviews(created_at);
DROP INDEX abc ON mavenfuzzyfactory.products_pageviews;
DROP INDEX createdat ON mavenfuzzyfactory.website_pageviews;
DROP INDEX createdat ON mavenfuzzyfactory.orders;
---------------------
create index abc on products_pageviews(saw_product_page_at);




SELECT
	YEAR(saw_product_page_at) AS year,
    MONTH(saw_product_page_at) AS month,
    COUNT(DISTINCT pp.website_session_id) AS sessions_to_product_page, 
    COUNT(DISTINCT wp.website_session_id) AS clicked_to_next_page, 
    COUNT(DISTINCT wp.website_session_id)/COUNT(DISTINCT pp.website_session_id) AS clickthrough_rate,
    COUNT(DISTINCT o.order_id) AS orders,
    COUNT(DISTINCT o.order_id)/COUNT(DISTINCT pp.website_session_id) AS products_to_order_rate
FROM products_pageviews pp
	LEFT JOIN website_pageviews wp
		ON wp.website_session_id = pp.website_session_id -- same session
        AND wp.website_pageview_id > pp.website_pageview_id -- they had another page AFTER
	LEFT JOIN orders o
		ON o.website_session_id = pp.website_session_id
GROUP BY 1,2
;


/*
8. We made our 4th product available as a primary product on December 05, 2014 (it was previously only a cross-sell item). 
We pull sales data since then, and show how welorders_website_session_idl each product cross-sells from one another.
*/

-- SLOW

SELECT
	primary_product_id, 
    COUNT(order_id) AS total_orders, 
    COUNT(CASE WHEN cross_sell_product_id = 1 THEN order_id ELSE NULL END) AS _xsold_p1,
    COUNT(CASE WHEN cross_sell_product_id = 2 THEN order_id ELSE NULL END) AS _xsold_p2,
    COUNT(CASE WHEN cross_sell_product_id = 3 THEN order_id ELSE NULL END) AS _xsold_p3,
    COUNT(CASE WHEN cross_sell_product_id = 4 THEN order_id ELSE NULL END) AS _xsold_p4,
    COUNT(CASE WHEN cross_sell_product_id = 1 THEN order_id ELSE NULL END)/COUNT(order_id) AS p1_xsell_rt,
    COUNT(CASE WHEN cross_sell_product_id = 2 THEN order_id ELSE NULL END)/COUNT(order_id) AS p2_xsell_rt,
    COUNT(CASE WHEN cross_sell_product_id = 3 THEN order_id ELSE NULL END)/COUNT(order_id) AS p3_xsell_rt,
    COUNT(CASE WHEN cross_sell_product_id = 4 THEN order_id ELSE NULL END)/COUNT(order_id) AS p4_xsell_rt
FROM(
SELECT
	orders.order_id, 
	orders.primary_product_id, 
	orders.created_at,
	order_items.product_id AS cross_sell_product_id
FROM orders
	LEFT JOIN order_items 
		ON order_items.order_id = orders.order_id
        AND order_items.is_primary_item = 0 -- only bringing in cross-sells
WHERE orders.created_at > '2014-12-05'
) AS primary_w_cross_sell
GROUP BY 1;

-- FAST

-- CREATE TEMPORARY TABLE primary_products
SELECT 
	order_id, 
    primary_product_id, 
    created_at AS ordered_at
FROM orders 
WHERE created_at > '2014-12-05'  -- when the 4th product was added
;

-- CREATE TEMPORARY TABLE primary_w_cross_sell
SELECT
	primary_products.*, 
    order_items.product_id AS cross_sell_product_id
FROM primary_products
	LEFT JOIN order_items 
		ON order_items.order_id = primary_products.order_id
        AND order_items.is_primary_item = 0;


SELECT
	primary_product_id, 
    COUNT(order_id) AS total_orders, 
    COUNT(CASE WHEN cross_sell_product_id = 1 THEN order_id ELSE NULL END) AS _xsold_p1,
    COUNT(CASE WHEN cross_sell_product_id = 2 THEN order_id ELSE NULL END) AS _xsold_p2,
    COUNT(CASE WHEN cross_sell_product_id = 3 THEN order_id ELSE NULL END) AS _xsold_p3,
    COUNT(CASE WHEN cross_sell_product_id = 4 THEN order_id ELSE NULL END) AS _xsold_p4,
    COUNT(CASE WHEN cross_sell_product_id = 1 THEN order_id ELSE NULL END)/COUNT(order_id) AS p1_xsell_rt,
    COUNT(CASE WHEN cross_sell_product_id = 2 THEN order_id ELSE NULL END)/COUNT(order_id) AS p2_xsell_rt,
    COUNT(CASE WHEN cross_sell_product_id = 3 THEN order_id ELSE NULL END)/COUNT(order_id) AS p3_xsell_rt,
    COUNT(CASE WHEN cross_sell_product_id = 4 THEN order_id ELSE NULL END)/COUNT(order_id) AS p4_xsell_rt
FROM primary_w_cross_sell
GROUP BY 1;


/*
9.	We want to quantify the impact of our billing test by analyze the lift generated 
from the test (Sep 10 – Nov 10), in terms of revenue per billing page session, and then pull the number 
of billing page sessions for the past month to understand monthly impact.
*/ 

-- SLOW

SELECT
	billing_version_seen, 
    COUNT(DISTINCT website_session_id) AS sessions, 
    SUM(price_usd)/COUNT(DISTINCT website_session_id) AS revenue_per_billing_page_seen
 FROM( 
SELECT 
	wp.website_session_id, 
    wp.pageview_url AS billing_version_seen, 
    orders.order_id, 
    orders.price_usd
FROM website_pageviews wp
	LEFT JOIN orders
		ON orders.website_session_id = wp.website_session_id
WHERE wp.created_at > '2012-09-10' 
	AND wp.created_at < '2012-11-10' 
    AND wp.pageview_url IN ('/billing','/billing-2')
) AS billing_pageviews_and_order_data
GROUP BY 1
;
-- $22.94 revenue per billing page seen for the old version
-- $31.38 revenue per billing page seen for the new version
-- LIFT: $8.44 per billing page view

SELECT 
	COUNT(website_session_id) AS billing_sessions_past_month
FROM website_pageviews wp
WHERE wp.pageview_url IN ('/billing','/billing-2') 
	AND created_at BETWEEN '2012-10-27' AND '2012-11-27'; -- past month

-- 1,156 billing sessions past month
-- LIFT: $8.44 per billing session
-- VALUE OF BILLING TEST: $9,756 over the past month

-- FAST

-- CREATE TEMPORARY TABLE billing_pageviews_and_order_data
SELECT 
	wp.website_session_id, 
    wp.pageview_url AS billing_version_seen, 
    orders.order_id, 
    orders.price_usd
FROM website_pageviews wp
	LEFT JOIN orders
		ON orders.website_session_id = wp.website_session_id
WHERE wp.created_at > '2012-09-10' 
	AND wp.created_at < '2012-11-10' 
    AND wp.pageview_url IN ('/billing','/billing-2');
    
    
SELECT
	billing_version_seen, 
	COUNT(DISTINCT website_session_id) AS sessions, 
	SUM(price_usd)/COUNT(DISTINCT website_session_id) AS revenue_per_billing_page_seen
 FROM billing_pageviews_and_order_data
GROUP BY 1;

SELECT 
	COUNT(website_session_id) AS billing_sessions_past_month
FROM website_pageviews wp
WHERE wp.pageview_url IN ('/billing','/billing-2') 
	AND created_at BETWEEN '2012-10-27' AND '2012-11-27'; -- past month




/*
10.	For the gsearch lander test, we want to estimate the revenue that test earned us.
*/ 

SELECT
	MIN(website_pageview_id) AS first_test_pv
FROM website_pageviews
WHERE pageview_url = '/lander-1';


-- for this step, we'll find the first pageview id 

-- CREATE TEMPORARY TABLE first_test_pageviews
SELECT
	website_pageviews.website_session_id, 
    MIN(website_pageviews.website_pageview_id) AS min_pageview_id
FROM website_pageviews 
	INNER JOIN website_sessions 
		ON website_sessions.website_session_id = website_pageviews.website_session_id
		AND website_sessions.created_at < '2012-07-28' 
		AND website_pageviews.website_pageview_id >= 23504 -- first page_view
        AND utm_source = 'gsearch'
        AND utm_campaign = 'nonbrand'
GROUP BY 
	website_pageviews.website_session_id;

-- next, we'll bring in the landing page to each session, restricting to home or lander-1 this time
-- CREATE TEMPORARY TABLE nonbrand_test_sessions_w_landing_pages
SELECT 
	first_test_pageviews.website_session_id, 
    website_pageviews.pageview_url AS landing_page
FROM first_test_pageviews
	LEFT JOIN website_pageviews 
		ON website_pageviews.website_pageview_id = first_test_pageviews.min_pageview_id
WHERE website_pageviews.pageview_url IN ('/home','/lander-1'); 

-- SELECT * FROM nonbrand_test_sessions_w_landing_pages;

-- then we make a table to bring in orders
-- CREATE TEMPORARY TABLE nonbrand_test_sessions_w_orders
SELECT
	nonbrand_test_sessions_w_landing_pages.website_session_id, 
    nonbrand_test_sessions_w_landing_pages.landing_page, 
    orders.order_id AS order_id

FROM nonbrand_test_sessions_w_landing_pages
LEFT JOIN orders 
	ON orders.website_session_id = nonbrand_test_sessions_w_landing_pages.website_session_id
;

SELECT * FROM nonbrand_test_sessions_w_orders;

-- to find the difference between conversion rates 
SELECT
	landing_page, 
    COUNT(DISTINCT website_session_id) AS sessions, 
    COUNT(DISTINCT order_id) AS orders,
    COUNT(DISTINCT order_id)/COUNT(DISTINCT website_session_id) AS conv_rate
FROM nonbrand_test_sessions_w_orders
GROUP BY 1; 

-- .0319 for /home, vs .0406 for /lander-1 
-- .0087 additional orders per session

-- finding the most reent pageview for gsearch nonbrand where the traffic was sent to /home
SELECT 
	MAX(website_sessions.website_session_id) AS most_recent_gsearch_nonbrand_home_pageview 
FROM website_sessions 
	LEFT JOIN website_pageviews 
		ON website_pageviews.website_session_id = website_sessions.website_session_id
WHERE utm_source = 'gsearch'
	AND utm_campaign = 'nonbrand'
    AND pageview_url = '/home'
    AND website_sessions.created_at < '2012-11-27'
;
-- max website_session_id = 17145


SELECT 
	COUNT(website_session_id) AS sessions_since_test
FROM website_sessions
WHERE created_at < '2012-11-27'
	AND website_session_id > 17145 -- last /home session
	AND utm_source = 'gsearch'
	AND utm_campaign = 'nonbrand'
;
-- 22,972 website sessions since the test

-- X .0087 incremental conversion = 202 incremental orders since 7/29
	-- roughly 4 months, so roughly 50 extra orders per month. Not bad!

    

/*
11.	For the landing page test we analyzed previously, we want to show a full conversion funnel 
from each of the two pages to orders in same time period (Jun 19 – Jul 28).
*/ 

SELECT
	website_sessions.website_session_id, 
    website_pageviews.pageview_url, 
    -- website_pageviews.created_at AS pageview_created_at, 
    CASE WHEN pageview_url = '/home' THEN 1 ELSE 0 END AS homepage,
    CASE WHEN pageview_url = '/lander-1' THEN 1 ELSE 0 END AS custom_lander,
    CASE WHEN pageview_url = '/products' THEN 1 ELSE 0 END AS products_page,
    CASE WHEN pageview_url = '/the-original-mr-fuzzy' THEN 1 ELSE 0 END AS mrfuzzy_page, 
    CASE WHEN pageview_url = '/cart' THEN 1 ELSE 0 END AS cart_page,
    CASE WHEN pageview_url = '/shipping' THEN 1 ELSE 0 END AS shipping_page,
    CASE WHEN pageview_url = '/billing' THEN 1 ELSE 0 END AS billing_page,
    CASE WHEN pageview_url = '/thank-you-for-your-order' THEN 1 ELSE 0 END AS thankyou_page
FROM website_sessions 
	LEFT JOIN website_pageviews 
		ON website_sessions.website_session_id = website_pageviews.website_session_id
WHERE website_sessions.utm_source = 'gsearch' 
	AND website_sessions.utm_campaign = 'nonbrand' 
    AND website_sessions.created_at < '2012-07-28'
		AND website_sessions.created_at > '2012-06-19'
ORDER BY 
	website_sessions.website_session_id,
    website_pageviews.created_at;


CREATE TEMPORARY TABLE session_level_made_it_flagged
SELECT
	website_session_id, 
    MAX(homepage) AS saw_homepage, 
    MAX(custom_lander) AS saw_custom_lander,
    MAX(products_page) AS product_made_it, 
    MAX(mrfuzzy_page) AS mrfuzzy_made_it, 
    MAX(cart_page) AS cart_made_it,
    MAX(shipping_page) AS shipping_made_it,
    MAX(billing_page) AS billing_made_it,
    MAX(thankyou_page) AS thankyou_made_it
FROM(
SELECT
	website_sessions.website_session_id, 
    website_pageviews.pageview_url, 
    -- website_pageviews.created_at AS pageview_created_at, 
    CASE WHEN pageview_url = '/home' THEN 1 ELSE 0 END AS homepage,
    CASE WHEN pageview_url = '/lander-1' THEN 1 ELSE 0 END AS custom_lander,
    CASE WHEN pageview_url = '/products' THEN 1 ELSE 0 END AS products_page,
    CASE WHEN pageview_url = '/the-original-mr-fuzzy' THEN 1 ELSE 0 END AS mrfuzzy_page, 
    CASE WHEN pageview_url = '/cart' THEN 1 ELSE 0 END AS cart_page,
    CASE WHEN pageview_url = '/shipping' THEN 1 ELSE 0 END AS shipping_page,
    CASE WHEN pageview_url = '/billing' THEN 1 ELSE 0 END AS billing_page,
    CASE WHEN pageview_url = '/thank-you-for-your-order' THEN 1 ELSE 0 END AS thankyou_page
FROM website_sessions 
	LEFT JOIN website_pageviews 
		ON website_sessions.website_session_id = website_pageviews.website_session_id
WHERE website_sessions.utm_source = 'gsearch' 
	AND website_sessions.utm_campaign = 'nonbrand' 
    AND website_sessions.created_at < '2012-07-28'
		AND website_sessions.created_at > '2012-06-19'
ORDER BY 
	website_sessions.website_session_id,
    website_pageviews.created_at
) AS pageview_level

GROUP BY 
	website_session_id
;

 

-- then this would produce the final output, part 1
SELECT
	CASE 
		WHEN saw_homepage = 1 THEN 'saw_homepage'
        WHEN saw_custom_lander = 1 THEN 'saw_custom_lander'
        ELSE 'wrong logic' 
	END AS segment, 
    COUNT(DISTINCT website_session_id) AS sessions,
    COUNT(DISTINCT CASE WHEN product_made_it = 1 THEN website_session_id ELSE NULL END) AS to_products,
    COUNT(DISTINCT CASE WHEN mrfuzzy_made_it = 1 THEN website_session_id ELSE NULL END) AS to_mrfuzzy,
    COUNT(DISTINCT CASE WHEN cart_made_it = 1 THEN website_session_id ELSE NULL END) AS to_cart,
    COUNT(DISTINCT CASE WHEN shipping_made_it = 1 THEN website_session_id ELSE NULL END) AS to_shipping,
    COUNT(DISTINCT CASE WHEN billing_made_it = 1 THEN website_session_id ELSE NULL END) AS to_billing,
    COUNT(DISTINCT CASE WHEN thankyou_made_it = 1 THEN website_session_id ELSE NULL END) AS to_thankyou
FROM session_level_made_it_flagged 
GROUP BY 1
;



-- then this as final output part 2 - click rates

SELECT
	CASE 
		WHEN saw_homepage = 1 THEN 'saw_homepage'
        WHEN saw_custom_lander = 1 THEN 'saw_custom_lander'
        ELSE 'wrong logic' 
	END AS segment, 
	COUNT(DISTINCT CASE WHEN product_made_it = 1 THEN website_session_id ELSE NULL END)/COUNT(DISTINCT website_session_id) AS lander_click_rt,
    COUNT(DISTINCT CASE WHEN mrfuzzy_made_it = 1 THEN website_session_id ELSE NULL END)/COUNT(DISTINCT CASE WHEN product_made_it = 1 THEN website_session_id ELSE NULL END) AS products_click_rt,
    COUNT(DISTINCT CASE WHEN cart_made_it = 1 THEN website_session_id ELSE NULL END)/COUNT(DISTINCT CASE WHEN mrfuzzy_made_it = 1 THEN website_session_id ELSE NULL END) AS mrfuzzy_click_rt,
    COUNT(DISTINCT CASE WHEN shipping_made_it = 1 THEN website_session_id ELSE NULL END)/COUNT(DISTINCT CASE WHEN cart_made_it = 1 THEN website_session_id ELSE NULL END) AS cart_click_rt,
    COUNT(DISTINCT CASE WHEN billing_made_it = 1 THEN website_session_id ELSE NULL END)/COUNT(DISTINCT CASE WHEN shipping_made_it = 1 THEN website_session_id ELSE NULL END) AS shipping_click_rt,
    COUNT(DISTINCT CASE WHEN thankyou_made_it = 1 THEN website_session_id ELSE NULL END)/COUNT(DISTINCT CASE WHEN billing_made_it = 1 THEN website_session_id ELSE NULL END) AS billing_click_rt
FROM session_level_made_it_flagged
GROUP BY 1
;



