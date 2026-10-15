-- total orders, average item price, and revenue generated along with percentage of total revenue
SELECT COALESCE(t.product_category_name_english, p.product_category_name, 'unknown') AS category,
       COUNT(DISTINCT oi.order_id) AS orders,
       ROUND(AVG(oi.price), 2) AS avg_item_price,
       ROUND(SUM(oi.price), 2) AS revenue
FROM order_items oi
JOIN orders o ON oi.order_id = o.order_id
JOIN products p ON oi.product_id = p.product_id
LEFT JOIN product_category_name_translation t
       ON p.product_category_name = t.product_category_name
WHERE o.order_status = 'delivered'
GROUP BY category
ORDER BY revenue DESC
LIMIT 10;

-- product category count
SELECT COUNT(DISTINCT product_category_name) AS products
FROM products;

--variation of products in each category
SELECT 
    t.product_category_name_english AS category,
    COUNT(DISTINCT p.product_id) AS product_count
FROM products p
JOIN product_category_name_translation t 
    ON p.product_category_name = t.product_category_name
GROUP BY t.product_category_name_english
ORDER BY product_count DESC;

-- percentage of revenue affected by NULL values
SELECT ROUND(100.0 * SUM(CASE WHEN p.product_category_name IS NULL THEN oi.price ELSE 0 END)
             / SUM(oi.price), 2) AS pct_revenue_unknown
FROM order_items oi
JOIN orders o ON oi.order_id = o.order_id
JOIN products p ON oi.product_id = p.product_id
WHERE o.order_status = 'delivered';