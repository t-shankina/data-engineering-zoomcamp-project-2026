{{
  config(
    materialized='incremental',
    incremental_strategy='delete+insert',
    unique_key=['user_id', 'hour'],
    cluster_by=['user_id'],
    partition_by='toYYYYMM(hour)'
  )
}}

select
    user_id,
    toStartOfHour(produced_at)  as hour,
    count()                     as messages_count,
    avg(sog)                    as avg_speed,
    min(sog)                    as min_speed,
    max(sog)                    as max_speed,
    hour < toStartOfHour(now()) as is_complete
from {{ ref('stg_position_reports') }}

{% if is_incremental() %}
where produced_at >= toStartOfHour(now()) - INTERVAL 1 HOUR
{% endif %}

group by user_id, hour
