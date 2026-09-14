-- Resolves each Subskribe billing account to its current HubSpot company_id.
-- A small number of accounts (2 in the current dataset) reference a crmid
-- that doesn't resolve even after following merges — these are flagged via
-- is_unresolved_company rather than silently dropped, so downstream models
-- can decide how to handle them explicitly.

with

accounts as (

    select * from {{ ref('stg_subskribe__accounts') }}

),

id_map as (

    select * from {{ ref('int_company_id_map') }}

),

resolved as (

    select
        accounts.account_id,
        accounts.company_name as billing_company_name,
        accounts.crmid,
        id_map.resolved_company_id,
        accounts.currency,
        accounts.created_at,
        (id_map.resolved_company_id is null) as is_unresolved_company

    from accounts
    left join id_map
        on accounts.crmid = id_map.source_id

)

select * from resolved
