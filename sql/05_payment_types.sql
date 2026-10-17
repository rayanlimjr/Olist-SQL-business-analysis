--payment type usage against average size of order
WITH order_type AS (
  SELECT order_id, payment_type, SUM(payment_value) AS paid
  FROM order_payments
  GROUP BY order_id, payment_type
)
SELECT ot.payment_type,
       COUNT(*) AS orders,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_of_orders,
       ROUND(AVG(ot.paid), 2) AS avg_order_value
FROM order_type ot
JOIN orders o ON ot.order_id = o.order_id
WHERE o.order_status = 'delivered'
GROUP BY ot.payment_type
ORDER BY orders DESC;

--payment type usage across different categories
WITH item_rows AS (
  SELECT COALESCE(t.product_category_name_english,
                  p.product_category_name, 'unknown') AS category,
         oi.price, s.primary_type
  FROM order_items oi
  JOIN orders o ON oi.order_id = o.order_id
  JOIN products p ON oi.product_id = p.product_id
  LEFT JOIN product_category_name_translation t
         ON p.product_category_name = t.product_category_name
  JOIN order_payment_summary s ON oi.order_id = s.order_id
  WHERE o.order_status = 'delivered'
),
top_cats AS (
  SELECT category FROM item_rows
  GROUP BY category ORDER BY SUM(price) DESC LIMIT 10
)
SELECT category,
       ROUND(SUM(price), 0) AS revenue,
       ROUND(100.0 * SUM(CASE WHEN primary_type = 'credit_card' THEN price ELSE 0 END) / SUM(price), 1) AS pct_credit_card,
       ROUND(100.0 * SUM(CASE WHEN primary_type = 'boleto' THEN price ELSE 0 END) / SUM(price), 1) AS pct_boleto,
       ROUND(100.0 * SUM(CASE WHEN primary_type = 'voucher' THEN price ELSE 0 END) / SUM(price), 1) AS pct_voucher,
       ROUND(100.0 * SUM(CASE WHEN primary_type = 'debit_card' THEN price ELSE 0 END) / SUM(price), 1) AS pct_debit_card
FROM item_rows
WHERE category IN (SELECT category FROM top_cats)
GROUP BY category
ORDER BY revenue DESC;

--instalment usage across all categories
WITH card AS (
  SELECT order_id, MAX(payment_installments) AS max_inst
  FROM order_payments
  WHERE payment_type = 'credit_card'
  GROUP BY order_id
),
cat_orders AS (
  SELECT oi.order_id,
         COALESCE(t.product_category_name_english,
                  p.product_category_name, 'unknown') AS category,
         SUM(oi.price) AS category_spend
  FROM order_items oi
  JOIN orders o ON oi.order_id = o.order_id
  JOIN products p ON oi.product_id = p.product_id
  LEFT JOIN product_category_name_translation t
         ON p.product_category_name = t.product_category_name
  WHERE o.order_status = 'delivered'
  GROUP BY oi.order_id, category
)
SELECT c.category,
       COUNT(*) AS card_orders,
       ROUND(AVG(c.category_spend), 2) AS avg_spend_per_order,
       ROUND(AVG(k.max_inst), 1) AS avg_instalments,
       ROUND(100.0 * SUM(CASE WHEN k.max_inst >= 4 THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_4plus_instalments
FROM cat_orders c
JOIN card k ON c.order_id = k.order_id
GROUP BY c.category
HAVING card_orders >= 300
ORDER BY avg_instalments DESC;

--distribution of bolete usage as prices go up (computer accessories vs others)
WITH cat_flag AS (
  SELECT oi.order_id,
         MAX(CASE WHEN COALESCE(t.product_category_name_english, p.product_category_name)
                       = 'computers_accessories' THEN 1 ELSE 0 END) AS is_ca
  FROM order_items oi
  JOIN products p ON oi.product_id = p.product_id
  LEFT JOIN product_category_name_translation t
         ON p.product_category_name = t.product_category_name
  GROUP BY oi.order_id
)
SELECT CASE WHEN s.order_total < 50 THEN '1. Under 50'
            WHEN s.order_total < 100 THEN '2. 50-99'
            WHEN s.order_total < 200 THEN '3. 100-199'
            WHEN s.order_total < 500 THEN '4. 200-499'
            ELSE '5. 500+' END AS value_band,
       CASE WHEN f.is_ca = 1 THEN 'computers_accessories' ELSE 'all other' END AS grp,
       COUNT(*) AS orders,
       ROUND(100.0 * SUM(CASE WHEN s.primary_type = 'boleto' THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_boleto
FROM order_payment_summary s
JOIN orders o ON s.order_id = o.order_id
JOIN cat_flag f ON s.order_id = f.order_id
WHERE o.order_status = 'delivered'
GROUP BY value_band, grp
ORDER BY value_band, grp;

--failure rates of payment methods in computer accessories
WITH cat_flag AS (
  SELECT oi.order_id,
         MAX(CASE WHEN COALESCE(t.product_category_name_english, p.product_category_name)
                       = 'computers_accessories' THEN 1 ELSE 0 END) AS is_ca
  FROM order_items oi
  JOIN products p ON oi.product_id = p.product_id
  LEFT JOIN product_category_name_translation t
         ON p.product_category_name = t.product_category_name
  GROUP BY oi.order_id
)
SELECT s.primary_type,
       COUNT(*) AS orders,
       ROUND(100.0 * SUM(CASE WHEN o.order_status IN ('canceled', 'unavailable') THEN 1 ELSE 0 END) / COUNT(*), 2) AS failed_pct
FROM order_payment_summary s
JOIN orders o ON s.order_id = o.order_id
JOIN cat_flag f ON s.order_id = f.order_id
WHERE f.is_ca = 1
GROUP BY s.primary_type
ORDER BY orders DESC;