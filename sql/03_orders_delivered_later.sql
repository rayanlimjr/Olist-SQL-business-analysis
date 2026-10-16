--amount of late orders and its percentage
SELECT COUNT(*) AS delivered_orders,
       SUM(CASE WHEN DATE(order_delivered_customer_date) > DATE(order_estimated_delivery_date)
                THEN 1 ELSE 0 END) AS late_orders,
       ROUND(100.0 * SUM(CASE WHEN DATE(order_delivered_customer_date) > DATE(order_estimated_delivery_date)
                              THEN 1 ELSE 0 END) / COUNT(*), 2) AS late_pct
FROM orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL;

--how late are the late orders on average
SELECT ROUND(AVG(julianday(order_delivered_customer_date)
                 - julianday(order_estimated_delivery_date)), 1) AS avg_days_late
FROM orders
WHERE order_status = 'delivered'
  AND DATE(order_delivered_customer_date) > DATE(order_estimated_delivery_date);

--percetange of late orders by state
SELECT 
    c.customer_state,
    COUNT(o.order_id) AS total_delivered_orders,
    SUM(CASE WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 1 ELSE 0 END) AS late_orders,
    ROUND(
        100.0 * SUM(CASE WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 1 ELSE 0 END) 
        / COUNT(o.order_id), 
    2) AS late_percentage
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_state
ORDER BY late_percentage DESC;

--percentage of sellers in each state and their late orders
SELECT 
    s.seller_state,
    COUNT(o.order_id) AS total_orders,
    ROUND(
        100.0 * COUNT(o.order_id) / (SELECT COUNT(*) 
            FROM orders o2 
            JOIN order_items oi2 ON o2.order_id = oi2.order_id 
            WHERE o2.order_status = 'delivered'), 
    2) AS pct_of_all_orders,
    COUNT(DISTINCT s.seller_id) AS total_sellers,
    SUM(CASE 
        WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date 
        THEN 1 ELSE 0 
    END) AS late_orders,
    ROUND(
        100.0 * SUM(CASE 
            WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date 
            THEN 1 ELSE 0 
        END) / COUNT(o.order_id), 
    2) AS late_percentage
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
JOIN sellers s ON oi.seller_id = s.seller_id
WHERE o.order_status = 'delivered'
GROUP BY s.seller_state
ORDER BY total_orders DESC;

--percentage of late orders by cross-state and same-state deliveries
WITH order_flags AS (
  SELECT o.order_id,
         MAX(CASE WHEN s.seller_state <> c.customer_state THEN 1 ELSE 0 END) AS cross_state,
         MAX(CASE WHEN DATE(o.order_delivered_customer_date) > DATE(o.order_estimated_delivery_date)
                  THEN 1 ELSE 0 END) AS late
  FROM orders o
  JOIN customers c ON o.customer_id = c.customer_id
  JOIN order_items oi ON o.order_id = oi.order_id
  JOIN sellers s ON oi.seller_id = s.seller_id
  WHERE o.order_status = 'delivered'
    AND o.order_delivered_customer_date IS NOT NULL
  GROUP BY o.order_id
)
SELECT cross_state, COUNT(*) AS orders,
       ROUND(100.0 * SUM(late) / COUNT(*), 1) AS late_pct
FROM order_flags
GROUP BY cross_state;

--actual days taken for delivery vs estimated days given by Olist
SELECT c.customer_state,
       COUNT(*) AS orders,
       ROUND(100.0 * SUM(CASE WHEN DATE(o.order_delivered_customer_date) > DATE(o.order_estimated_delivery_date)
                              THEN 1 ELSE 0 END) / COUNT(*), 1) AS late_pct,
       ROUND(AVG(julianday(o.order_delivered_customer_date) - julianday(o.order_purchase_timestamp)), 1) AS avg_actual_days,
       ROUND(AVG(julianday(o.order_estimated_delivery_date) - julianday(o.order_purchase_timestamp)), 1) AS avg_estimated_days
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
GROUP BY c.customer_state
HAVING orders >= 100
ORDER BY late_pct DESC;

--distribution of late orders
WITH d AS (
  SELECT julianday(DATE(order_delivered_customer_date))
       - julianday(DATE(order_estimated_delivery_date)) AS days_late
  FROM orders
  WHERE order_status = 'delivered'
    AND order_delivered_customer_date IS NOT NULL
)
SELECT CASE WHEN days_late <= 0 THEN '1. On time or early'
            WHEN days_late <= 3 THEN '2. 1-3 days late'
            WHEN days_late <= 7 THEN '3. 4-7 days late'
            WHEN days_late <= 14 THEN '4. 8-14 days late'
            ELSE '5. 15+ days late' END AS bucket,
       COUNT(*) AS orders,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct
FROM d
GROUP BY bucket
ORDER BY bucket;

--time spent from seller to carrier vs from carrier to customer
SELECT CASE WHEN DATE(order_delivered_customer_date) > DATE(order_estimated_delivery_date)
            THEN 'Late' ELSE 'On time' END AS delivery,
       COUNT(*) AS orders,
       ROUND(AVG(julianday(order_delivered_carrier_date) - julianday(order_purchase_timestamp)), 1) AS days_to_carrier,
       ROUND(AVG(julianday(order_delivered_customer_date) - julianday(order_delivered_carrier_date)), 1) AS days_in_transit
FROM orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL
  AND order_delivered_carrier_date IS NOT NULL
GROUP BY delivery;
