{{ config(materialized='incremental', unique_key='id', file_format='iceberg') }}

select
    id,
    agency_id,
    fiscal_year,
    amount,
    currency,
    cast(updated_at as timestamp) as updated_at
from {{ source('bronze', 'agency_budget') }}

{% if is_incremental() %}
where updated_at > (select coalesce(max(updated_at), timestamp '1970-01-01') from {{ this }})
{% endif %}
