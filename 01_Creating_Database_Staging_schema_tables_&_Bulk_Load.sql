
/*
Creating Database "OlistDB"

Creating Schema "staging"

Layer 1 — staging (raw, 1:1 with CSVs)--

Creating Tables and Bulk Inserting RAW CSV files, Taking every column as NVARCHAR, 
no type conversion — this layer's only job is to land the CSV exactly as it arrived, so a bad row never breaks the load.
*/

IF DB_ID('OlistDB') IS NULL
BEGIN 
	CREATE DATABASE OlistDB;
END

GO

USE OlistDB;

GO 

IF NOT EXISTS ( SELECT 1 FROM sys.schemas WHERE NAME = 'staging')
	EXEC('CREATE SCHEMA staging');

GO

CREATE TABLE staging.Customers (
	CustomerID NVARCHAR(60), 
	CustomerUniqueID NVARCHAR(60),
	CustomerZipCodePrefix NVARCHAR(60),
	CustomerCity NVARCHAR(60),
	CustomerState NVARCHAR(60)
);

GO

BULK INSERT staging.Customers
FROM 'C:\Users\RAJESH\OneDrive\Desktop\Sumit\1_SQL & PowerBI_Self Made Project\04_Brazillian E-Commerce Dataset\olist_customers_dataset.csv'
WITH (
FIRSTROW = 2,
FORMAT = 'CSV',
FIELDQUOTE = '"',
FIELDTERMINATOR = ',',
ROWTERMINATOR = '0x0a',
CODEPAGE = '65001',
TABLOCK);

GO

SELECT count(*) from staging.Customers --checking numbers of rows inserted

GO

CREATE TABLE staging.Geolocation (
	GeolocationZipCodePrefix NVARCHAR(60),
	GeolocationLat NVARCHAR(60),
	GeolocationIng NVARCHAR(60),
	GeolocationCity NVARCHAR(60),
	GeolocationState NVARCHAR(60)
);

GO

BULK INSERT staging.Geolocation
FROM 'C:\Users\RAJESH\OneDrive\Desktop\Sumit\1_SQL & PowerBI_Self Made Project\04_Brazillian E-Commerce Dataset\olist_geolocation_dataset.csv'
WITH (
	FIRSTROW = 2,
	FORMAT = 'CSV',
	FIELDQUOTE = '"',
	FIELDTERMINATOR = ',',
	ROWTERMINATOR = '0x0a',
	CODEPAGE = 65001,
	TABLOCK
);

GO

SELECT COUNT(*) FROM staging.Geolocation --Checking number of rows inserted

GO

CREATE TABLE staging.OrderItems (
	OrderID NVARCHAR(60),
	OrderItemID NVARCHAR(60),
	ProductID NVARCHAR(60),
	SellerID NVARCHAR(60),
	ShippingLimitDate NVARCHAR(60),
	Price NVARCHAR(60),
	FreightValue NVARCHAR(60)
);

GO

BULK INSERT staging.OrderItems 
FROM 'C:\Users\RAJESH\OneDrive\Desktop\Sumit\1_SQL & PowerBI_Self Made Project\04_Brazillian E-Commerce Dataset\olist_order_items_dataset.csv'
WITH (
	FIRSTROW = 2,
	FORMAT = 'CSV',
	FIELDQUOTE = '"',
	FIELDTERMINATOR = ',',
	ROWTERMINATOR = '0x0a',
	CODEPAGE = '65001',
	TABLOCK
);

GO

SELECT COUNT(*) FROM staging.OrderItems --Checking number of rows inserted

GO

CREATE TABLE staging.OrderPayments (
	OrderID NVARCHAR(60),
	PaymentSequential NVARCHAR(60),
	PaymentType NVARCHAR(60),
	PaymentInstallents NVARCHAR(60),
	PaymentValue NVARCHAR(60)
);

GO

BULK INSERT staging.OrderPayments 
FROM 'C:\Users\RAJESH\OneDrive\Desktop\Sumit\1_SQL & PowerBI_Self Made Project\04_Brazillian E-Commerce Dataset\olist_order_payments_dataset.csv'
WITH (
	FIRSTROW = 2,
	FORMAT = 'CSV',
	FIELDQUOTE = '"',
	FIELDTERMINATOR = ',',
	ROWTERMINATOR = '0x0a',
	CODEPAGE = '65001',
	TABLOCK
);

GO

SELECT COUNT(*) FROM staging.OrderPayments --checking numbers of rows inserted

GO


CREATE TABLE staging.OrderReviews (
	ReviewID NVARCHAR(60),
	OrderID NVARCHAR(60),
	ReviewScore NVARCHAR(60),
	ReviewCommentTitle NVARCHAR(60),
	ReviewCommentMSG NVARCHAR(MAX),
	ReviewCreationDate NVARCHAR(60),
	ReviewAnswerTimestamp NVARCHAR(60),
);

GO

BULK INSERT staging.OrderReviews
FROM 'C:\Users\RAJESH\OneDrive\Desktop\Sumit\1_SQL & PowerBI_Self Made Project\04_Brazillian E-Commerce Dataset\olist_order_reviews_cleaned.csv'
WITH (
    FIRSTROW = 2,
    FORMAT = 'CSV',
    FIELDQUOTE = '"',
    FIELDTERMINATOR = ',',
    CODEPAGE = '65001',
    TABLOCK
);
GO

SELECT COUNT(*) FROM staging.OrderReviews;  --Checking numbers of Rows Inserted 

GO

CREATE TABLE staging.Orders (
	OrderID NVARCHAR(60),
	CustomerID NVARCHAR(60),
	OrderStatus NVARCHAR(60),
	OrderPurchaseTimeStamp NVARCHAR(60),
	OrderApprovedAt NVARCHAR(60),
	OrderDeliveredCarrierDate NVARCHAR(60),
	OrderDeliveredCustomerDate NVARCHAR(60),
	OrderEstimatedDeliveryDate NVARCHAR(60),
);

GO

BULK INSERT staging.Orders 
FROM 'C:\Users\RAJESH\OneDrive\Desktop\Sumit\1_SQL & PowerBI_Self Made Project\04_Brazillian E-Commerce Dataset\olist_orders_dataset.csv'
WITH (
	FIRSTROW = 2,
	FORMAT= 'CSV',
	FIELDQUOTE = '"',
	FIELDTERMINATOR = ',',
	ROWTERMINATOR = '0x0a',
	CODEPAGE ='65001',
	TABLOCK
);

GO

SELECT COUNT(*) FROM staging.Orders -- checking numbers of rows inserted

GO

CREATE TABLE staging.Products (
	ProductID NVARCHAR(60),
	ProductCategoryName NVARCHAR(100),
	ProductNameLength NVARCHAR(60),
	ProductDescriptionLenght NVARCHAR(60),
	ProductPhotosQty NVARCHAR(60),
	ProductWeight_g NVARCHAR(60),
	ProductLenght_cm NVARCHAR(60),
	ProductHieght_cm NVARCHAR(60),
	ProductWidth_cm NVARCHAR(60)
);

GO

BULK INSERT staging.Products 
FROM 'C:\Users\RAJESH\OneDrive\Desktop\Sumit\1_SQL & PowerBI_Self Made Project\04_Brazillian E-Commerce Dataset\olist_products_dataset.csv'
WITH (
	FIRSTROW = 2,
	FORMAT = 'CSV',
	FIELDQUOTE = '"',
	FIELDTERMINATOR = ',',
	ROWTERMINATOR = '0x0a',
	CODEPAGE = '65001',
	TABLOCK
);

GO

SELECT COUNT(*) FROM staging.Products  --checking numbers of rows inserted

GO

CREATE TABLE staging.Sellers (
	SellerID NVARCHAR(60),
	SellerZipCodePrefix NVARCHAR(60),
	SellerCity NVARCHAR(60),
	SellerState NVARCHAR(60)
);

GO

BULK INSERT staging.Sellers 
FROM 'C:\Users\RAJESH\OneDrive\Desktop\Sumit\1_SQL & PowerBI_Self Made Project\04_Brazillian E-Commerce Dataset\olist_sellers_dataset.csv'
WITH (
	FIRSTROW = 2,
	FORMAT = 'CSV',
	FIELDQUOTE = '"',
	FIELDTERMINATOR = ',',
	ROWTERMINATOR = '0x0a',
	CODEPAGE = '65001',
	TABLOCK
);

GO

SELECT COUNT(*) FROM staging.Sellers --checking numbers of rows inserted

GO

CREATE TABLE staging.ProductCategoryNameTranslation (
	ProductCategoryName NVARCHAR(60),
	ProductCategoryNameEnglish NVARCHAR(60)
);

GO

BULK INSERT staging.ProductCategoryNameTranslation 
FROM 'C:\Users\RAJESH\OneDrive\Desktop\Sumit\1_SQL & PowerBI_Self Made Project\04_Brazillian E-Commerce Dataset\product_category_name_translation.csv'
WITH (
	FIRSTROW = 2,
	FORMAT = 'CSV',
	FIELDQUOTE = '"',
	FIELDTERMINATOR = ',',
	ROWTERMINATOR = '0x0a',
	CODEPAGE = '65001',
	TABLOCK
);

GO

SELECT COUNT(*) FROM staging.ProductCategoryNameTranslation --checking numbers of rows inserted 


/* Successfully Created "Staging" Layer tables and Bulk Loaded Data into tables*/



