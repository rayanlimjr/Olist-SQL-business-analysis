
SELECT strftime('%Y-%m', order_purchase_timestamp) AS month, 
       COUNT(DISTINCT o.order_id) AS orders,
       ROUND(SUM(oi.price), 2) AS revenue,
       ROUND(SUM(oi.price) / COUNT(DISTINCT o.order_id), 2) AS avg_order_value
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY month
ORDER BY month;

SELECT DATE(order_purchase_timestamp) AS day,
       COUNT(DISTINCT order_id) AS orders
FROM orders
WHERE order_status = 'delivered'
  AND order_purchase_timestamp >= '2017-11-01'
  AND order_purchase_timestamp <  '2017-12-01'
GROUP BY day
ORDER BY day;