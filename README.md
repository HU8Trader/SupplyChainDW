# SupplyChainDW — Supply Chain Data Warehouse

An end-to-end, GitHub-ready SQL Server data warehouse project built with the **medallion architecture** (Bronze → Silver → Gold) and a fully interactive, self-contained HTML dashboard on top of the Gold layer.

Built on SQL Server 2025 (17.x) Enterprise Developer Edition, following the conventions of the `HUDataWareHouseProjectSQLScripts` reference project.

---

## Project Structure

```
SupplyChainDW_SQLScripts/
├── CreateDatabase-SupplyChainDW.sql      # Create database + bronze/silver/gold/etl schemas (destructive)
├── DDL_Bronze.sql                        # Bronze layer DDL + load_bronze stored procedure
├── Bronze_Data_Bulk_Insert.sql           # Bronze load orchestration (bulk insert + metadata logging)
├── description_format.xml                # XML format file for loading Description.csv
├── DDL_Silver_Layer.sql                  # Silver layer DDL (dimensions + facts)
├── Silver_Data_Load.sql                  # Silver load orchestration (load_silver stored procedure)
├── Quality_Chack_Silver_Layer.sql        # Silver layer quality checks
├── DDL_GOLD_Layer.sql                    # Gold layer views (dim + fact views)
├── source_data/
│   └── Description.csv                   # Copy of the data dictionary (reference)
└── SupplyChainDW_Dashboard.html          # Self-contained interactive dashboard (Gold layer)
```

> The raw source datasets (`SupplyChainData.csv`, `tokenized_access_logs.csv`) live outside the repo at
> `C:\Users\pc\documents\HiLyst DataSets\SUPPLYCHAIN\`. `Description.csv` is shipped here as a reference copy.

---

## Architecture

### Bronze Layer (raw ingestion)
- `bronze.supply_chain_data` — **180,519 rows** of transactional order lines.
- `bronze.tokenized_access_logs` — **469,977 rows** of product-view / access logs.
- `etl.field_dictionary` — 52-row data dictionary loaded from `Description.csv` via the XML format file.
- `etl.source_metadata` — source file registry (name, row counts, load timestamp).

### Silver Layer (cleaned, conformed)
- `silver.dim_customer` — 20,652 customers (masked emails, `is_in_catalog` flags).
- `silver.dim_department` — 11 departments.
- `silver.dim_product` — 122 products (118 catalog + 4 log-only, matched by name).
- `silver.dim_date` — 1,461 dates (2015-01-01 → 2018-12-31).
- `silver.fact_sales` — 180,519 rows (verified `Sales = Price × Qty`, 0 mismatches).
- `silver.fact_access_log` — 469,977 rows (validated IPs).

### Gold Layer (semantic, report-ready)
- `gold.dim_customers`, `gold.dim_products`, `gold.dim_departments`, `gold.dim_dates`
- `gold.fact_sales`, `gold.fact_access_logs`

Gold-layer headline metrics: **$36.78M revenue · $3.97M profit · 65,752 orders · 20,652 customers · 118 catalog products**.

---

## How to Run

1. **Create the database & schemas**
   ```sql
   -- Run: CreateDatabase-SupplyChainDW.sql  (WARNING: drops SupplyChainDW if it exists)
   ```
2. **Load Bronze** — run `Bronze_Data_Bulk_Insert.sql` (calls `bronze.load_bronze`).
   - Source CSV paths are Windows-1252 encoded; bulk load uses `CODEPAGE = '1252'`.
   - Update the file paths in the script if your datasets live elsewhere.
3. **Build Silver** — run `Silver_Data_Load.sql` (calls `silver.load_silver`).
4. **Validate** — run `Quality_Chack_Silver_Layer.sql` (all checks should pass with 0 violations).
5. **Build Gold** — run `DDL_GOLD_Layer.sql` (creates the gold views).
6. **Open the dashboard** — double-click `SupplyChainDW_Dashboard.html` (no server required; data is embedded).

### Dashboard
- 9 modules: Home, Executive, Financial, Sales, Customer & Marketing, Digital, Supply Chain & Operations, Product & Catalog, Geographic Intelligence.
- Role-based views (CEO/CFO/Marketing/Sales/Ops), live filters (market / year / segment / shipping), bookmarks, conditional-formatted matrix, and hover-only chart tooltips.
- Charts: Chart.js + chartjs-plugin-datalabels via CDN — internet required for chart rendering.

---

## Key Design Decisions

| Decision | Rationale |
| --- | --- |
| Windows-1252 `CODEPAGE` for CSV loads | Source files are NOT UTF-8; avoids mojibake in text columns |
| XML format file for `Description.csv` | Quoted fields contain embedded commas; needs `,` + `\r\n` terminators |
| Product dim = catalog ∪ log-only products (122) | Lets access logs join to the product dimension by name |
| `is_in_catalog` flag | Distinguishes the 118 browsable catalog products from 4 log-only artifacts |
| `ROUND(...,2)` on float artifacts | Removes FP noise; `Sales = Price × Qty` re-verified post-rounding (0 mismatches) |
| Masked `Customer Email` | PII hygiene in the silver layer |
| Star-schema fact pre-aggregation | Joining `fact_sales × fact_access_logs` fans out to billions — always aggregate the log fact first |

---

## Recommended Next Steps
- Columnstore indexes on the gold fact views for analytics workloads.
- Row-Level Security on customer/market data.
- Orchestration (SSIS/Azure Data Factory) and automated refresh scheduling.
- Localization layer (translated field dictionary for multi-language dashboards).
- CI/CD pipeline (GitHub Actions) for script validation against a build database.

---

## Author
Himanshu Upadhyay — data engineering / data warehousing practice.
