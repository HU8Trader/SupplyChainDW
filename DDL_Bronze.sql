/*
===============================================================================
DDL Script: Create Bronze Tables
===============================================================================
Script Purpose:
    This script creates tables in the 'bronze' schema (and the 'etl' metadata
    tables), dropping existing tables if they already exist.
	  Run this script to re-define the DDL structure of 'bronze' Tables.
===============================================================================
*/

-- =============================================================
-- bronze.supply_chain_data (Source: SupplyChainData.csv)
-- 180,519 rows x 53 columns | Header present | Win-1252 encoding
-- Raw as-is: all columns loaded as NVARCHAR (types refined in silver)
-- =============================================================
IF OBJECT_ID('bronze.supply_chain_data', 'U') IS NOT NULL
    DROP TABLE bronze.supply_chain_data;
GO

CREATE TABLE bronze.supply_chain_data (
    [Type]                          NVARCHAR(50),
    [Days for shipping (real)]      NVARCHAR(50),
    [Days for shipment (scheduled)] NVARCHAR(50),
    [Benefit per order]             NVARCHAR(100),
    [Sales per customer]            NVARCHAR(100),
    [Delivery Status]               NVARCHAR(100),
    [Late_delivery_risk]            NVARCHAR(10),
    [Category Id]                   NVARCHAR(50),
    [Category Name]                 NVARCHAR(200),
    [Customer City]                 NVARCHAR(200),
    [Customer Country]              NVARCHAR(100),
    [Customer Email]                NVARCHAR(200),
    [Customer Fname]                NVARCHAR(200),
    [Customer Id]                   NVARCHAR(50),
    [Customer Lname]                NVARCHAR(200),
    [Customer Password]             NVARCHAR(200),
    [Customer Segment]              NVARCHAR(100),
    [Customer State]                NVARCHAR(50),
    [Customer Street]               NVARCHAR(300),
    [Customer Zipcode]              NVARCHAR(50),
    [Department Id]                 NVARCHAR(50),
    [Department Name]               NVARCHAR(200),
    [Latitude]                      NVARCHAR(50),
    [Longitude]                     NVARCHAR(50),
    [Market]                        NVARCHAR(100),
    [Order City]                    NVARCHAR(200),
    [Order Country]                 NVARCHAR(100),
    [Order Customer Id]             NVARCHAR(50),
    [order date (DateOrders)]       NVARCHAR(100),
    [Order Id]                      NVARCHAR(50),
    [Order Item Cardprod Id]        NVARCHAR(50),
    [Order Item Discount]           NVARCHAR(100),
    [Order Item Discount Rate]      NVARCHAR(100),
    [Order Item Id]                 NVARCHAR(50),
    [Order Item Product Price]      NVARCHAR(100),
    [Order Item Profit Ratio]       NVARCHAR(100),
    [Order Item Quantity]           NVARCHAR(50),
    [Sales]                         NVARCHAR(100),
    [Order Item Total]              NVARCHAR(100),
    [Order Profit Per Order]        NVARCHAR(100),
    [Order Region]                  NVARCHAR(200),
    [Order State]                   NVARCHAR(200),
    [Order Status]                  NVARCHAR(100),
    [Order Zipcode]                 NVARCHAR(50),
    [Product Card Id]               NVARCHAR(50),
    [Product Category Id]           NVARCHAR(50),
    [Product Description]           NVARCHAR(MAX),
    [Product Image]                 NVARCHAR(MAX),
    [Product Name]                  NVARCHAR(500),
    [Product Price]                 NVARCHAR(100),
    [Product Status]                NVARCHAR(50),
    [shipping date (DateOrders)]    NVARCHAR(100),
    [Shipping Mode]                 NVARCHAR(100)
);
GO

-- =============================================================
-- bronze.tokenized_access_logs (Source: tokenized_access_logs.csv)
-- 469,977 rows x 8 columns | Header present | Win-1252 encoding
-- =============================================================
IF OBJECT_ID('bronze.tokenized_access_logs', 'U') IS NOT NULL
    DROP TABLE bronze.tokenized_access_logs;
GO

CREATE TABLE bronze.tokenized_access_logs (
    [Product]      NVARCHAR(500),
    [Category]     NVARCHAR(300),
    [Date]         NVARCHAR(100),
    [Month]        NVARCHAR(20),
    [Hour]         NVARCHAR(20),
    [Department]   NVARCHAR(300),
    [ip]           NVARCHAR(100),
    [url]          NVARCHAR(MAX)
);
GO

-- =============================================================
-- etl.field_dictionary (Source: Description.csv)
-- Data dictionary: 52 rows x 2 columns | Header present
-- Quoted CSV -> loaded via description_format.xml format file
-- =============================================================
IF OBJECT_ID('etl.field_dictionary', 'U') IS NOT NULL
    DROP TABLE etl.field_dictionary;
GO

CREATE TABLE etl.field_dictionary (
    field_name         NVARCHAR(400),
    field_description  NVARCHAR(MAX)
);
GO

-- =============================================================
-- etl.source_metadata (config registry for each CSV source)
-- Mirrors the EcommerceDW etl.source_metadata table
-- =============================================================
IF OBJECT_ID('etl.source_metadata', 'U') IS NOT NULL
    DROP TABLE etl.source_metadata;
GO

CREATE TABLE etl.source_metadata (
    source_id            INT IDENTITY(1,1) PRIMARY KEY,
    source_name          NVARCHAR(400) NOT NULL,
    source_description   NVARCHAR(1000),
    source_file_name     NVARCHAR(600) NOT NULL,
    source_folder        NVARCHAR(1000),
    file_extension       VARCHAR(10) NOT NULL,
    destination_schema   SYSNAME NOT NULL,
    destination_table    SYSNAME NOT NULL,
    field_terminator     VARCHAR(10) NOT NULL,
    row_terminator       VARCHAR(10) NOT NULL,
    first_row            INT NOT NULL DEFAULT 2,
    text_qualifier       VARCHAR(5),
    file_encoding        VARCHAR(50),
    load_type            VARCHAR(30) NOT NULL DEFAULT 'FULL',
    is_header_present    BIT NOT NULL DEFAULT 1,
    is_active            BIT NOT NULL DEFAULT 1,
    created_date         DATETIME2 NOT NULL DEFAULT GETDATE(),
    created_by           NVARCHAR(400) NOT NULL DEFAULT SUSER_SNAME()
);
GO
