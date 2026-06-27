with customers as (

    select * from {{ ref('stg_customers') }}

),

orders as (

    select * from {{ ref('fct_orders') }}

),

customer_orders as (

    select
        customer_key,
        count(*)          as total_orders,
        sum(order_revenue) as total_revenue,
        min(order_date)   as first_order_date,
        max(order_date)   as last_order_date

    from orders
    group by customer_key

)

select
    customers.customer_key,
    customers.name,
    customers.address,
    customers.phone,
    customers.account_balance,
    customers.market_segment,
    coalesce(customer_orders.total_orders, 0)    as total_orders,
    coalesce(customer_orders.total_revenue, 0)   as total_revenue,
    customer_orders.first_order_date,
    customer_orders.last_order_date

from customers
left join customer_orders
    on customers.customer_key = customer_orders.customer_key
