# Senior Analytics Engineer — Take-Home Brief

Hello, and thanks for taking the time to interview with us at Tracksuit! This is a take home exercise we'd like you to complete. This shouldn't be hard and shouldn't take very long. If it takes more than a few hours, you're overthinking it!

> 💡 **Note:** This task is meant to give us something to talk over in your technical interview. It should feel similar to the kind of day-to-day work you'd be doing at Tracksuit. We're not trying to trick you. You're also more than welcome to use AI tools (Cursor, Claude, Copilot) to speed up your work. If you have any questions, please reach out!

> ⚙️ **Setting up?** All instructions for getting dbt running locally are in the `SETUP.md`. The project runs against DuckDB, so you don't need a Snowflake account or any cloud credentials.

---

## Background

As Tracksuit moves from startup to scale-up, the next chapter of growth depends less on new customers and more on keeping the ones we have. **Gross Revenue Retention (GRR)**, how much of our existing customer revenue we've kept before expansion, is the metric we use to measure that.

GRR isn't just a Finance number. It shows up in board reporting, GTM planning, how Customer Success prioritises at-risk accounts, and where Product decides to invest. Almost every team at Tracksuit has a stake in it.

Today it's calculated semi-manually each month, stitched across spreadsheets and ad hoc SQL. That won't hold up as we scale. We need a properly modelled source of truth the whole business can trust—one that gives consistent answers no matter which month you ask about.

In this task, imagine you're a Senior Analytics Engineer at Tracksuit who's been asked to build it end to end: from raw data to a trustworthy metric. The data team has cobbled together a sample of raw data from our CRM (HubSpot) and our billing system (Subskribe) for you to model. It's not in perfect shape, and that's part of the job.

---

## The Task

Your task has two parts, building on each other:

1. **A dimensional model** representing our customer subscriptions over time. It should be the kind of thing analysts, finance, and even product can build on top of, not a one-off pipeline that produces a single number. It should give an accurate picture of our subscriptions as of any given month, not just today.

2. **A reporting model** built on your dimensional model that produces **monthly Gross Revenue Retention, segmented by customer size, for the last 12 months**, as a proof point that your dimensional model is actually usable.

### Defining GRR

GRR can be defined a few ways. For this exercise, start from Tracksuit's working definition:

> **GRR for month M** = revenue at month M from the cohort of customers who were paying at month M-12, divided by that cohort's revenue at month M-12, expressed as a percentage.
>
> The cohort is fixed at month M-12, so customers acquired after M-12 don't count towards GRR for month M. Expansion is excluded: if a customer in the cohort is paying *more* at month M than at M-12, cap their retained revenue at the M-12 amount. That cap is what makes the metric "gross" rather than "net".

As with any real-world metric, you may find the data raises questions the definition doesn't answer. Where something isn't clear, make a sensible call, note it in your `SUBMISSION.md`, and keep moving.

> 💡 **A note on scope:** This is a take-home, not production. If there's anything you'd handle differently in a production build, a short note in your `SUBMISSION.md` explaining what and why is just as good as building it. Spend the time where it counts.

---

## Your Deliverable

A dbt project, committed to this repo, containing:

- **A dimensional model** representing our customer subscriptions over time, designed for reuse across the business beyond just GRR. It should be able to give an accurate picture of our subscriptions as of any given month, not just today.

- **A reporting model** built on top of your dimensional model that returns monthly Gross Revenue Retention by customer size segment for the last 12 months.

- **A short `SUBMISSION.md`** (a new file—please don't overwrite the brief) covering:
  - How to run the project
  - Your key assumptions
  - The metric definition calls you made and why
  - A brief note on any data quality issues you found and how you handled them

- **A `PROMPTS.md`** (or equivalent: Cursor chat export, screenshots, whatever works) capturing the meaningful AI prompts you used along the way. We don't need a raw transcript, just the prompts that shaped real decisions.

### Time & Assessment Weighting

- About **80%** of your time and assessment weight is on the dimensional model
- About **20%** on the reporting model and the metric definition decisions behind it

The raw data is in this repository (see **Data Description** below, and the `SETUP.md` for how to load it).

---

## What "Done" Looks Like

We care more about the structure of your project and the quality of your reasoning than the elegance of any single query. A well-shaped dimensional model and a clearly defined, documented metric is a much stronger submission than a clever query with a sprawling structure.

Since we'll be reviewing your work asynchronously and discussing it in your technical interview, please ensure **all your work is committed to this repository**. Please also ensure your work is **reproducible**: after loading the raw data, we should be able to run `dbt build` and see your reporting model produce numbers.

---

## Using AI Tools

You're more than welcome to use AI tools (Cursor, Claude, Copilot) to help, just as you would as an employee at Tracksuit. We use AI heavily here, and how senior engineers use it well is something we're actively interested in.

That's why we ask you to commit a `PROMPTS.md` (or equivalent) alongside your code. We're not looking for a polished log or a full transcript, just the prompts that shaped meaningful decisions. What you chose to delegate to AI, how you framed the ask, and how you verified the output are all part of the signal.

As with any code you'd ship at Tracksuit, you'll be responsible for the quality of what you commit. Be ready to walk us through every decision in your technical interview.

---

## Data Description

We've provided four raw CSVs in the `data/raw/` directory. They're simplified versions of data we actually have flowing in from HubSpot (our CRM) and Subskribe (our billing system) via Fivetran. Columns have been reduced for brevity, but they're otherwise representative of what you'd be working with at Tracksuit.

> 💡 **Feel free to make assumptions.** Real-world source data is messy, and you'll spot ambiguities here too. Where something isn't clear, just make a reasonable assumption, note it in your `SUBMISSION.md`, and keep moving. We'd much rather see you make a defensible call than spend an hour chasing an edge case.

### HubSpot

**`hubspot_companies.csv`**: Company records from our CRM.

| Column | Description |
|--------|-------------|
| `company_id` | The unique HubSpot company ID |
| `company_name` | The company's display name |
| `size_grouped` | The customer's size segment (e.g. `Enterprise`, `Mid-Market`, `SMB`, `Startup`). This is the dimension you'll use to segment GRR. |
| `industry` | Industry classification |
| `country` | HQ country |
| `merged_object_ids` | A semicolon-separated list of old HubSpot company IDs that have been merged into this record |
| `created_at` | When the company record was created in HubSpot |

### Subskribe

**`subskribe_accounts.csv`**: Billing accounts.

| Column | Description |
|--------|-------------|
| `account_id` | The unique Subskribe account ID |
| `company_name` | The billing account's name (often, but not always, matches the HubSpot company name) |
| `crmid` | A reference to the HubSpot `company_id` this account is linked to |
| `currency` | The account's billing currency (e.g. `NZD`, `USD`, `GBP`, `AUD`) |
| `created_at` | When the account was created in Subskribe |

**`subskribe_subscriptions.csv`**: Subscriptions per account.

| Column | Description |
|--------|-------------|
| `subscription_id` | The unique subscription ID |
| `account_id` | Foreign key to `subskribe_accounts` |
| `subscription_state` | Current state (`ACTIVE`, `CANCELED`, `EXPIRED`, etc.) |
| `start_date` | When the subscription started |
| `end_date` | When the subscription ended (or is scheduled to end) |
| `cancelled_date` | When the subscription was cancelled, if applicable |
| `renewed_from_subscription_id` | If this subscription was renewed from a previous one, its ID. Useful for following a customer's subscription history. |
| `creation_time` | When the row was first written |
| `updated_at` | When the row was last modified in the source |

**`subskribe_invoices.csv`**: Issued invoices.

| Column | Description |
|--------|-------------|
| `invoice_id` | The unique invoice ID |
| `account_id` | Foreign key to `subskribe_accounts` |
| `subscription_id` | Foreign key to `subskribe_subscriptions` |
| `invoice_date` | When the invoice was issued |
| `total` | Invoice amount in the account's billing currency |
| `total_nzd` | Invoice amount converted to NZD (Tracksuit's functional currency) |
| `currency` | Invoice currency |
| `status` | `POSTED`, `PAID`, `VOIDED`, etc. |

---

## Set Up Your Repository

1. On the top right of the repository page, click the **"Use this template"** button.
2. Select **"Create a new repository"** from the dropdown.
3. Give the repository a name under your GitHub account and click **"Create a new repository"**.
4. Follow the instructions in the `SETUP.md` to set up dbt locally and load the raw data. The project is pre-configured to run against DuckDB, so you don't need a Snowflake account.

---

## Submit Your Work

Once you've completed the task, please:

1. Add the `tracksuit-technical-test` GitHub user as a collaborator
2. Share the repo link with the Talent Manager

Good luck! We look forward to reviewing your work.

---

## Questions?

If you have any questions during the task, please reach out. We're here to help!
