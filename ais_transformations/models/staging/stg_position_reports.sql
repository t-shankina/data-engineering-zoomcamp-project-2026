-- Cleaned and validated AIS position reports.
-- Filters invalid coordinates and replaces special values with NULL.
{{
  config(
    materialized='incremental',
    incremental_strategy='delete+insert',
    unique_key=['user_id', 'produced_at'],
    cluster_by=['user_id'],
    ttl='produced_at + INTERVAL 1 YEAR'
  )
}}

with source as (
    select
        produced_at,
        consumed_at,
        user_id,
        longitude,
        latitude,
        position_accuracy,
        raim,
        timestamp                                               as utc_second,
        message_id,
        navigational_status,
        special_manoeuvre_indicator,
        true_heading,
        rate_of_turn,
        cog,
        sog
    from {{ source('ais_db', 'position_reports') }}

    {% if is_incremental() %}
    where produced_at >= (select max(produced_at) from {{ this }})
    {% endif %}
),

deduplicated as (
    select
        *,
        row_number() over (
            partition by user_id, produced_at
            order by consumed_at desc
        ) as _row_num
    from source
)

select
    produced_at,
    consumed_at,
    dateDiff('millisecond', produced_at, consumed_at) as pipeline_lag_ms,
    user_id,
    longitude,
    latitude,
    position_accuracy,
    raim,
    utc_second,
    message_id,
    navigational_status,
    special_manoeuvre_indicator,
    nullIf(cog, 360)                                  as cog,
    nullIf(sog, 102.3)                                as sog,
    nullIf(true_heading, 511)                         as true_heading,
    nullIf(rate_of_turn, -128)                        as rate_of_turn
from deduplicated
where _row_num = 1
