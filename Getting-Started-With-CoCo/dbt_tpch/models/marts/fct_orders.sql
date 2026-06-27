with orders as (

    select * from {{ ref('stg_orders') }}

),

line_items as (

    select * from {{ ref('stg_lineitem') }}

),

order_revenue as (

    select
        order_key,
        sum(extended_price * (1 - discount) * (1 + tax)) as order_revenue,
        count(*) as line_item_count

    from line_items
    group by order_key

)

select
    orders.order_key,
    orders.customer_key,
    orders.order_status,
    orders.order_date,
    orders.order_priority,
    order_revenue.order_revenue,
    order_revenue.line_item_count

from orders
inner join order_revenue
    on orders.order_key = order_revenue.order_key
