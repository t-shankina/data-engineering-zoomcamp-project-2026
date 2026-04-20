{{
  config(
    materialized='incremental',
    incremental_strategy='delete+insert',
    unique_key='user_id',
    cluster_by=['user_id'],
  )
}}

select
    user_id,
    argMax(latitude, produced_at)            as latitude,
    argMax(longitude, produced_at)           as longitude,
    argMax(sog, produced_at)                 as sog,
    argMax(cog, produced_at)                 as cog,
    argMax(navigational_status, produced_at) as navigational_status,
    argMax(true_heading, produced_at)        as true_heading,
    max(produced_at)                         as last_seen_at,
    count()                                  as total_messages
from {{ ref('stg_position_reports') }}

{% if is_incremental() %}
where produced_at >= (select max(last_seen_at) from {{ this }})
{% endif %}

group by user_id
