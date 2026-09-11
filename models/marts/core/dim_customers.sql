-- One row per customer. "Customer" = resolved HubSpot company where one
-- exists; for the handful of accounts with no resolvable company we fall
-- back to the account_id as the identity and label the segment 'Unknown'
-- rather than dropping the revenue entirely.
--
-- Note: this is a Type 1 (current-state) dimension. The raw data gives us
-- no history of segment changes, so there's nothing to version — if
-- HubSpot starts tracking segment changes over time, this would become a
-- Type 2 dimension instead (see SUBMISSION.md).

with

accounts_resolved as (

    select * from {{ ref('int_accounts_resolved') }}

),

companies as (

    select * from {{ ref('stg_hubspot__companies') }}

),

customers as (

    select
        coalesce(accounts_resolved.resolved_company_id, accounts_resolved.account_id) as customer_id,
        accounts_resolved.account_id,
        accounts_resolved.billing_company_name,
        coalesce(companies.company_name, accounts_resolved.billing_company_name) as company_name,
        coalesce(companies.size_grouped, 'Unknown') as size_grouped,
        companies.industry,
        companies.country,
        accounts_resolved.currency,
        accounts_resolved.is_unresolved_company

    from accounts_resolved
    left join companies
        on accounts_resolved.resolved_company_id = companies.company_id

)

select * from customers
