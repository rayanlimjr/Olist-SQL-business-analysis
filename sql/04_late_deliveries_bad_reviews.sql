--average review rating and percentage of scores 2 or below for late deliveries vs on time deliveries
WITH review_per_order AS (
  SELECT order_id, AVG(review_score) AS score
  FROM order_reviews
  GROUP BY order_id
)
SELECT CASE WHEN DATE(o.order_delivered_customer_date) > DATE(o.order_estimated_delivery_date)
            THEN 'Late' ELSE 'On time' END AS delivery,
       COUNT(*) AS orders,
       ROUND(AVG(r.score), 2) AS avg_review,
       ROUND(100.0 * SUM(CASE WHEN r.score <= 2 THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_low_scores
FROM orders o
JOIN review_per_order r ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
GROUP BY delivery;

--distribution of ratings based on number of days late
WITH review_per_order AS (
  SELECT order_id, AVG(review_score) AS score
  FROM order_reviews
  GROUP BY order_id
),
d AS (
  SELECT order_id,
         julianday(DATE(order_delivered_customer_date))
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
       ROUND(AVG(r.score), 2) AS avg_score,
       ROUND(100.0 * SUM(CASE WHEN r.score <= 2 THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_low
FROM d
JOIN review_per_order r ON d.order_id = r.order_id
GROUP BY bucket
ORDER BY bucket;