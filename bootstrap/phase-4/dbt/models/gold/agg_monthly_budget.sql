{{ config(materialized='table', file_format='iceberg') }}

select
    agency_id,
    date_trunc('month', updated_at) as month,
    sum(amount) as monthly_amount,
    currency
from {{ ref('stg_agency_budget') }}
group by 1, 2, 4
