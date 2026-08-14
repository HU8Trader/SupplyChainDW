/*
===============================================================================
DDL Script: Create Silver Tables
===============================================================================
Script Purpose:
    This script creates tables in the 'silver' schema, dropping existing tables
    if they already exist.
	  Run this script to re-define the DDL structure of 'silver' Tables
===============================================================================
*/

-- =============================================================
-- silver.dim_customer
-- Grain: 1 row per Customer Id (source: bronze.supply_chain_data)
-- Cleansed names (most frequent variant), segment, geo attributes
-- =============================================================
IF OBJECT_ID('silver.dim_customer', 'U') IS NOT NULL
    DROP TABLE silver.dim_customer;
GO

CREATE TABLE silver.dim_customer (
    customer_id        INT          PRIMARY KEY,
    first_name         NVARCHAR(200),
    last_name          NVARCHAR(200),
    customer_segment   NVARCHAR(100),
    customer_city      NVARCHAR(200),
    customer_state     NVARCHAR(50),
    customer_country   NVARCHAR(100),
    customer_zipcode   NVARCHAR(50),
    latitude           DECIMAL(9,6),
    longitude          DECIMAL(9,6),
    dwh_create_date    DATETIME2 DEFAULT GETDATE()
);
GO

-- =============================================================
-- silver.dim_department
-- Grain: 1 row per department (source: bronze.supply_chain_data)
-- =============================================================
IF OBJECT_ID('silver.dim_department', 'U') IS NOT NULL
    DROP TABLE silver.dim_department;
GO

CREATE TABLE silver.dim_department (
    department_id     INT          PRIMARY KEY,
    department_name   NVARCHAR(200),
    dwh_create_date   DATETIME2 DEFAULT GETDATE()
);
GO

-- =============================================================
-- silver.dim_product
-- Grain: 1 row per product
-- Source: bronze.supply_chain_data (118) UNION
--         bronze.tokenized_access_logs log-only products (4)
-- product_key = surrogate; product_card_id NULL for log-only products
-- =============================================================
IF OBJECT_ID('silver.dim_product', 'U') IS NOT NULL
    DROP TABLE silver.dim_product;
GO

CREATE TABLE silver.dim_product (
    product_key        INT          IDENTITY(1,1) PRIMARY KEY,
    product_card_id    INT,
    product_name       NVARCHAR(500),
    product_price      DECIMAL(18,2),
    product_desc       NVARCHAR(MAX),
    category_id        INT,
    category_name      NVARCHAR(200),
    department_id      INT,
    department_name    NVARCHAR(200),
    is_in_catalog      BIT          NOT NULL DEFAULT 1,
    dwh_create_date    DATETIME2 DEFAULT GETDATE()
);
GO

-- =============================================================
-- silver.dim_date
-- Grain: 1 row per day (generated calendar 2015-01-01 -> 2018-02-06)
-- Covers both order/shipping dates and access-log dates
-- =============================================================
IF OBJECT_ID('silver.dim_date', 'U') IS NOT NULL
    DROP TABLE silver.dim_date;
GO

CREATE TABLE silver.dim_date (
    date_key         INT           PRIMARY KEY,  -- YYYYMMDD
    full_date        DATE          NOT NULL,
    year             SMALLINT,
    quarter          TINYINT,
    month            TINYINT,
    month_name       NVARCHAR(20),
    week_of_year     TINYINT,
    day_of_month     TINYINT,
    day_of_week      TINYINT,      -- 1=Sunday ... 7=Saturday
    day_name         NVARCHAR(20),
    is_weekend       BIT
);
GO

-- =============================================================
-- silver.fact_sales
-- Grain: 1 row per order line item (Order Id + Order Item Id)
-- Source: bronze.supply_chain_data (180,519 rows)
-- All monetary values rounded to 2 dp (source has float artifacts)
-- =============================================================
IF OBJECT_ID('silver.fact_sales', 'U') IS NOT NULL
    DROP TABLE silver.fact_sales;
GO

CREATE TABLE silver.fact_sales (
    sales_id                  INT          IDENTITY(1,1) PRIMARY KEY,
    order_id                  INT,
    order_item_id             INT,
    customer_id               INT,
    product_key               INT,
    order_date_key            INT,
    shipping_date_key         INT,
    days_for_shipping_real    INT,
    days_for_shipping_scheduled INT,
    late_delivery_risk        BIT,
    delivery_status           NVARCHAR(100),
    order_status              NVARCHAR(100),
    shipping_mode             NVARCHAR(100),
    market                    NVARCHAR(100),
    order_region              NVARCHAR(200),
    order_state               NVARCHAR(200),
    order_city                NVARCHAR(200),
    order_country             NVARCHAR(100),
    order_zipcode             NVARCHAR(50),
    benefit_per_order         DECIMAL(18,2),
    sales_per_customer        DECIMAL(18,2),
    product_price             DECIMAL(18,2),
    quantity                  INT,
    discount_amount           DECIMAL(18,2),
    discount_rate             DECIMAL(18,4),
    sales_amount              DECIMAL(18,2),
    item_total                DECIMAL(18,2),
    profit_per_order          DECIMAL(18,2),
    profit_ratio              DECIMAL(18,4),
    dwh_create_date           DATETIME2 DEFAULT GETDATE()
);
GO

-- =============================================================
-- silver.fact_access_log
-- Grain: 1 row per log event (source: bronze.tokenized_access_logs)
-- Linked to dim_product by product name (via dim_product.product_name)
-- =============================================================
IF OBJECT_ID('silver.fact_access_log', 'U') IS NOT NULL
    DROP TABLE silver.fact_access_log;
GO

CREATE TABLE silver.fact_access_log (
    log_id            INT          IDENTITY(1,1) PRIMARY KEY,
    product_key       INT,
    event_timestamp   DATETIME,
    date_key          INT,
    hour              TINYINT,
    ip                NVARCHAR(100),
    url               NVARCHAR(MAX),
    dwh_create_date   DATETIME2 DEFAULT GETDATE()
);
GO
