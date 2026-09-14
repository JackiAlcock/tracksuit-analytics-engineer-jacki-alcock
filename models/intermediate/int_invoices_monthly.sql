-- There's no MRR/contract-value field anywhere in the raw data — invoices
-- are the only dollar figures available, so monthly revenue has to be
-- derived from them. We attribute each invoice to the calendar month of
-- invoice_date (billing is ~monthly for almost all subscriptions — see
-- SUBMISSION.md) and sum in total_nzd, which is already currency-normalised.

with

invoices as (

    select * from {{ ref('stg_subskribe__invoices') }}

),

billed_invoices as (

    -- VOIDED invoices are reversed and aren't real billed revenue. PAID and
    -- POSTED are both treated as billed (accrual) revenue — see
    -- SUBMISSION.md for why we don't restrict this to PAID only.
    select *
    from invoices
    where status != 'VOIDED'

),

monthly as (

    select
        subscription_id,
        account_id,
        {{ month_start('invoice_date') }}::date as invoice_month,
        sum(total_nzd) as revenue_nzd

    from billed_invoices
    group by 1, 2, 3

)

select * from monthly
