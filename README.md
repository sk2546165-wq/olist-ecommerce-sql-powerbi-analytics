# Olist E-Commerce Analytics: SQL Server to Power BI

An end-to-end analytics project on the Brazilian Olist e-commerce dataset. Raw CSV files are loaded into **MS SQL Server**, cleaned through a **staging → silver → gold** pipeline built with stored procedures, analysed with **advanced T-SQL**, and then modelled and visualised in **Power BI with DAX**.

The same business questions are answered twice, once in T-SQL and once in DAX, and the results are cross-checked against each other.

---

## Overview

| | |
|---|---|
| **Goal** | Show the full analytics workflow: ingestion, ETL, data modelling, SQL analytics, DAX and dashboarding |
| **Data** | Olist Brazilian E-Commerce dataset: 9 CSV files, about 100K orders (2016 to 2018) |
| **Database** | MS SQL Server (Express), database `OlistDB` |
| **BI** | Power BI Desktop (Import mode) |
| **Scripting** | Python (pandas) for one pre-cleaning step |

## Business questions answered

1. How is revenue trending month over month, and what is the cumulative total?
2. Which states have the highest late-delivery rates, and which sellers deliver late on average?
3. Do late deliveries lower customer review scores?
4. Which sellers earn the most revenue, and do any combine high revenue with poor reviews?
5. Who are the top customers per state, and how many customers are repeat buyers?
6. Which product categories drive revenue, and how fast are they growing?

---

## Architecture

```
CSV files (9)
    │  BULK INSERT
    ▼
staging   raw text, 1:1 with the CSVs
    │  stored procedures: type conversion, trimming, deduplication, TRY/CATCH, audit log
    ▼
silver    typed and cleaned tables
    │  stored procedures: surrogate keys, joins, date keys
    ▼
gold      star schema (5 dimensions, 3 facts)
    │
    ├── T-SQL analytics views (CTEs, window functions, subqueries)
    └── Power BI model + DAX measures + dashboard
```

## Tech stack

MS SQL Server, T-SQL, SSMS, Python (pandas), Power BI, DAX, Git

## Dataset

[Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) on Kaggle. Please check the dataset page for license terms. The raw CSV files are **not included** in this repository; download them from Kaggle.

Files used: customers, orders, order items, order payments, order reviews, products, sellers, geolocation, product category name translation.

---

## Data model (gold layer)

```
dim_Customers ─┐                      ┌─ dim_Products
               ├─< dim_Orders ─< Fact_OrderItems >─┤
dim_DateTable ─┘        │                           └─ dim_Sellers
                        ├─< Fact_Payments
                        └─< Fact_Reviews
```

| Table | Type | Grain |
|---|---|---|
| `dim_DateTable` | Dimension | One row per calendar day |
| `dim_Customers` | Dimension | One row per `CustomerID` (with geolocation) |
| `dim_Sellers` | Dimension | One row per seller (with geolocation) |
| `dim_Products` | Dimension | One row per product (with English category name) |
| `dim_Orders` | Dimension | One row per order (status, 5 date keys, `IsLate` flag) |
| `Fact_OrderItems` | Fact | One row per order item (price, freight) |
| `Fact_Payments` | Fact | One row per payment record |
| `Fact_Reviews` | Fact | One row per review |

Design decisions:
- **Surrogate keys** (`IDENTITY`) on every dimension; facts resolve them by joining on business keys.
- **`DateKey` is a meaningful `yyyymmdd` integer**, not an identity, so fact loads can compute it directly from any date.
- **`dim_Orders` holds five date keys** (purchase, approved, carrier, delivered, estimated), a role-playing date dimension. An order has no measure of its own; the money lives in the item and payment facts.
- **`CustomerUniqueID` is kept alongside `CustomerID`.** Olist issues a new `CustomerID` for every order, so repeat-customer analysis only works on the unique ID.

---

## ETL highlights

- **Staging:** every column loaded as `NVARCHAR`, so a bad value never breaks the load.
- **Silver:** one stored procedure per table, each with `TRY...CATCH`, `THROW`, and a row written to an audit table (`silver.LoadAuditLog`: table, start, end, row count, status, error message).
- Safe type conversion with `TRY_CAST` / `TRY_CONVERT`; rows with an unusable measure (for example a price that won't convert) are excluded instead of loaded as `NULL`.
- Reviews are deduplicated on `(ReviewID, OrderID)` with `ROW_NUMBER()`, keeping the latest answer timestamp. `ReviewID` alone is not unique per order.
- Geolocation is reduced to one row per zip prefix (averaged coordinates, one representative city and state) so it can be joined without duplicating rows.
- Products are joined to the category translation table; missing categories default to `unknown`.
- **Gold:** dimensions load first and facts last; a master procedure `gold.Load_ALL` runs everything in dependency order.
- `DELETE` is used instead of `TRUNCATE` for reloads, because foreign keys block `TRUNCATE`. Tables are cleared children-first.

---

## Analytics in T-SQL

Each analysis is a reusable view in the `gold` schema (see `/sql/05_analytics`):

| Analysis | Techniques |
|---|---|
| Monthly revenue and month-over-month growth | CTE, `LAG()` |
| Cumulative revenue | `SUM() OVER (ORDER BY ... ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)` |
| Late-delivery rate by state | CTE, conditional aggregation |
| Average delivery delay per seller | CTE, `DISTINCT` at order grain, `DATEDIFF` |
| Top customers per state | `RANK() OVER (PARTITION BY State ...)` |
| Repeat vs one-time customers | `GROUP BY CustomerUniqueID`, `CASE` |
| Seller revenue rank with average review score | Multiple CTEs, window function |
| Late delivery vs review score | Aggregation on the `IsLate` flag |
| Category revenue growth by month | `LAG() OVER (PARTITION BY category)` with a month-gap check |

## Performance: indexing

Nonclustered indexes were added on the fact-table foreign keys and key join columns, with `INCLUDE` columns so the queries are covered. Measured with `SET STATISTICS IO, TIME ON` and the actual execution plan.

| Query | Logical reads before | Logical reads after | Plan change |
|---|---|---|---|
| `[query name]` | `[X]` | `[Y]` | `[Scan → Seek]` |

*(Fill in from your own results. On a dataset this small the plan shape and logical reads show the improvement more clearly than elapsed time.)*

---

## Power BI and DAX

- **Import mode** from the gold tables, with a star-schema model and one-to-many relationships.
- `dim_DateTable` is marked as the date table. The purchase date is the active relationship; the other four date relationships are inactive and are activated per measure with `USERELATIONSHIP`.
- **40+ measures**, grouped by topic:
  - Core: revenue, orders, average order value, freight share
  - Time intelligence: `SAMEPERIODLASTYEAR`, `DATEADD`, `TOTALYTD`, rolling 3 months
  - Delivery: late-delivery %, average delay days, orders by delivery date
  - Reviews: average score, 5-star %, negative %, score gap between on-time and late orders
  - Customers: unique and repeat customers (`SUMMARIZE` + `ADDCOLUMNS`)
  - Sellers and categories: `RANKX` with `ALLSELECTED`, revenue share, and `CROSSFILTER` to carry seller filters to orders and reviews without making the model relationship bidirectional
- **SQL and DAX are cross-validated:** each view has a matching DAX measure, and the totals are compared.

| SQL view | DAX measure |
|---|---|
| Monthly revenue growth | `Revenue MoM %` |
| Cumulative revenue | `Cumulative Revenue` |
| Late-delivery rate by state | `Late Delivery %` |
| Seller delay and reviews | `Seller Avg Delay Days`, `Seller Avg Review Score` |
| Repeat customers | `Repeat Customer %` |

---

## Key findings

*(Values below marked `[ ]` should be filled in from your final dashboard.)*

- Dashboard totals: about R$14M revenue across about 99K orders, an average order value near R$138, an average review score of 4.09, a late-delivery rate near 8%, and freight at about 16.6% of revenue.
- Top revenue categories: health & beauty, watches & gifts, bed/bath/table. São Paulo (SP) is the largest state by revenue.
- Late deliveries score lower on reviews: `[X]` average for late orders vs `[Y]` for on-time orders.
- Only `[X]%` of customers place more than one order.
- `[N]` of the top 50 sellers by revenue have an average review score below 3.5.

## Challenges and how they were solved

| Problem | Cause | Fix |
|---|---|---|
| `BULK INSERT` of `order_reviews` failed with Msg 7301 (`IID_IColumnsInfo`) | Free-text comments with embedded line breaks, plus an explicit `ROWTERMINATOR` combined with `FORMAT = 'CSV'` | Pre-cleaned the file with pandas, then loaded with `FORMAT = 'CSV'` and no `ROWTERMINATOR`; row count verified (99,224) |
| Reloads failed on foreign keys | `TRUNCATE` and parent `DELETE`s blocked by child tables | Cleared children first, reloaded in dependency order |
| Percentages came out rounded | Integer division | Multiplied by `100.0` before dividing |
| Category growth compared the wrong months | `LAG()` compares rows, and sparse categories skip months | Added `MonthIndex = Year * 12 + Month` and only computed growth when the gap is 1 |
| DAX seller metrics showed the same value for every seller | One-way relationships stop the filter before it reaches orders and reviews | `CROSSFILTER` inside the measure |
| Monthly chart sorted by revenue | Text month labels and default measure sort | Numeric `YearMonthNum` sort column |
| `String or binary data would be truncated` on sellers | Free-text city values longer than the column | Widened the column |

---

## Repository structure

```
/sql
  /01_setup          database and schemas
  /02_staging        table definitions and BULK INSERT scripts
  /03_silver         tables and load procedures
  /04_gold           tables, load procedures, Load_ALL
  /05_analytics      T-SQL views
  /06_indexes        index scripts and before/after results
/python              clean_order_reviews.py
/powerbi             Olist.pbix and DAX measures
/docs                architecture diagram and screenshots
README.md
```

## How to run

**Requirements:** SQL Server (Express is enough), SSMS, Python 3 with pandas, Power BI Desktop.

1. Download the dataset from Kaggle and place the CSV files in a local folder.
2. Run the setup script to create `OlistDB` and the `staging`, `silver` and `gold` schemas.
3. Run `python/clean_order_reviews.py` (edit the file paths first) to create the cleaned reviews file.
4. Run the staging scripts. **Edit the file paths in each `BULK INSERT` to match your machine**, and load the cleaned reviews file for `order_reviews`.
5. Run the silver load procedures, then `EXEC gold.Load_ALL;`.
6. Check `silver.LoadAuditLog` and the row counts.
7. Open `powerbi/Olist.pbix`, update the data source to your server name, and refresh.

## Assumptions and limitations

- Data covers roughly September 2016 to August 2018, so 2016 and 2018 are partial years and month-of-year comparisons across years can mislead.
- Values are in Brazilian reais.
- A review belongs to the whole order, so a seller-level review score credits every seller on that order.
- Loads are full refreshes, not incremental. `MERGE`-based incremental loading would be the next step.
- Latitude and longitude are averaged per zip prefix, so they are approximate.

## Dashboard

<img width="1796" height="787" alt="PowerBi_Delivery   Review Page" src="https://github.com/user-attachments/assets/bc31653e-ad24-48ab-814c-f875ed73296e" />
<img width="1787" height="777" alt="PowerBi_Executive Page" src="https://github.com/user-attachments/assets/89bdca5a-b887-4de1-bb1a-4c3506e747a4" />
<img width="1820" height="782" alt="PowerBi_Sellers   Revenue Page" src="https://github.com/user-attachments/assets/86e36e9f-90b0-4cc2-ad32-6ed7be05f4e0" />

---

## Author

**Sumit Kumar Mandal**, Data / MIS Analyst
www.linkedin.com/in/sumit-kumar-mandal-24545220a
