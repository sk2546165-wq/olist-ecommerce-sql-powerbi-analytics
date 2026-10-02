
/*
===Creating Silver Layer Schema & Tables with one Audit log table=======================================
*/

USE OlistDB;

GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE NAME = 'silver')
	EXEC('CREATE SCHEMA silver');

/*
===Creating Audit Log for Silver Layer ========================================================
*/

CREATE TABLE silver.LoadAuditLog (
	LogID INT IDENTITY(1,1) PRIMARY KEY,
	TableName NVARCHAR(60),
	LoadStart DATETIME2,
	LoadEnd DATETIME2,
	RowsCount INT,
	Status NVARCHAR(60),
	ErrorMsg NVARCHAR(MAX)
);

GO

CREATE TABLE silver.Customers (
	CustomerID NVARCHAR(60) PRIMARY KEY,
	CustomerUniqueID NVARCHAR(60),
	ZipCodePrefix NVARCHAR(60),
	City NVARCHAR(60),
	State NVARCHAR(60)
);

GO

CREATE OR ALTER PROCEDURE silver.Load_Customers
AS
BEGIN
	
	SET NOCOUNT ON;
	DECLARE @start DATETIME2 = SYSDATETIME(), @rows INT = 0;

	BEGIN TRY 
		
		TRUNCATE TABLE silver.Customers;

		INSERT INTO silver.Customers (CustomerID, CustomerUniqueID, ZipCodePrefix, City, State)
		SELECT DISTINCT 
			TRIM(CustomerID),
			TRIM(CustomerUniqueID),
			TRIM(CustomerZipCodePrefix),
			TRIM(CustomerCity),
			TRIM(CustomerState)
		FROM staging.Customers
		WHERE TRIM(CustomerID) IS NOT NULL;

		SET @rows = @@ROWCOUNT;

		INSERT INTO silver.LoadAuditLog ( TableName, LoadStart, LoadEnd, RowsCount, Status, ErrorMsg)
		VALUES ('Customers', @start, SYSDATETIME(), @rows, 'Success', NULL);

	END TRY
	BEGIN CATCH
		INSERT INTO silver.LoadAuditLog (TableName, LoadStart, LoadEnd, RowsCount, Status, ErrorMsg)
		VALUES ('Customers', @start, SYSDATETIME(), @rows, 'Failed', ERROR_MESSAGE());
		THROW;
	END CATCH

END

GO

EXEC silver.Load_Customers --Executing STORED PROCEDURE

GO

SELECT * FROM silver.LoadAuditLog; -- checking Audit Logs

SELECT COUNT(*) FROM silver.Customers; -- Checking numbers of rows inserted rows

GO

CREATE TABLE silver.Orders (
	OrderID NVARCHAR(60) PRIMARY KEY,
	CustomerID NVARCHAR(60),
	OrderStatus NVARCHAR(60),
	Purchase_ts DATETIME2,
	Approved_ts DATETIME2,
	DeliveredCarrier_ts DATETIME2,
	DeliveredCustomer_ts DATETIME2,
	EstimatedDelivery_ts DATETIME2,
	IsLate BIT
);

GO

CREATE OR ALTER PROCEDURE silver.Load_Orders
AS 
BEGIN
	
	SET NOCOUNT ON;
	DECLARE @start DATETIME2 = SYSDATETIME(), @rows INT = 0;

	BEGIN TRY 
		
		TRUNCATE TABLE silver.Orders;

		INSERT INTO silver.Orders ( OrderID, CustomerID, OrderStatus, Purchase_ts, Approved_ts, DeliveredCarrier_ts, DeliveredCustomer_ts, EstimatedDelivery_ts, 
									IsLate)
		SELECT DISTINCT
			TRIM(OrderID),
			TRIM(CustomerID),
			LOWER(TRIM(OrderStatus)),
			TRY_CONVERT(DATETIME2, OrderPurchaseTimeStamp),
			TRY_CONVERT(DATETIME2, OrderApprovedAt),
			TRY_CONVERT(DATETIME2, OrderDeliveredCarrierDate),
			TRY_CONVERT(DATETIME2, OrderDeliveredCustomerDate),
			TRY_CONVERT(DATETIME2, OrderEstimatedDeliveryDate),
			CASE WHEN TRY_CONVERT(DATETIME2, OrderDeliveredCustomerDate) >
					  TRY_CONVERT(DATETIME2, OrderEstimatedDeliveryDate)
					  THEN 1 ELSE 0 END
		FROM staging.Orders
		WHERE TRIM(OrderID) IS NOT NULL;

		SET @rows = @@ROWCOUNT;

		INSERT INTO silver.LoadAuditLog ( TableName, LoadStart, LoadEnd, RowsCount, Status, ErrorMsg)
		VALUES ( 'Orders', @start, SYSDATETIME(), @rows, 'Success', NULL);

	END TRY
	BEGIN CATCH
		INSERT INTO silver.LoadAuditLog ( TableName, LoadStart, LoadEnd, RowsCount, Status, ErrorMsg)
		VALUES ('Orders', @start, SYSDATETIME(), @rows, 'Failed', ERROR_MESSAGE());
		THROW;
	END CATCH
END 

GO

EXEC silver.Load_Orders --Executing Stores Procedure

GO

SELECT * FROM silver.LoadAuditLog -- Checking Audit Logs

SELECT COUNT(*) FROM silver.Orders -- Checking numbers of rows inserted

GO

CREATE TABLE silver.OrderItems (
	OrderID NVARCHAR(60),
	OrderItemID INT,
	ProductID NVARCHAR(60),
	SellerID NVARCHAR(60),
	ShippingLimitDate DATETIME2,
	Price DECIMAL(10,2),
	FrieghtValue DECIMAL(10,2),
	PRIMARY KEY (OrderID, OrderItemID)
);

GO

CREATE OR ALTER PROCEDURE silver.Load_OrderItems 
AS 
BEGIN 
	
	SET NOCOUNT ON;
	DECLARE @start DATETIME2 = SYSDATETIME(), @rows INT = 0;

	BEGIN TRY 
		
		TRUNCATE TABLE silver.OrderItems;

		INSERT INTO silver.OrderItems (OrderID, OrderItemID, ProductID, SellerID, ShippingLimitDate, Price, FrieghtValue) 
		SELECT 
			TRIM(OrderID),
			TRY_CAST(TRIM(OrderItemID) as INT),
			TRIM(ProductID),
			TRIM(SellerID),
			TRY_CONVERT(DATETIME2, ShippingLimitDate),
			TRY_CAST(Price as DECIMAL(10,2)),
			TRY_CAST(FreightValue as DECIMAL(10,2))
		FROM staging.OrderItems
		WHERE TRIM(OrderID) IS NOT NULL AND 
			  TRY_CAST(Price AS DECIMAL(10,2)) IS NOT NULL;

		SET @rows = @@ROWCOUNT;
		
		INSERT INTO silver.LoadAuditLog (TableName, LoadStart, LoadEnd, RowsCount, Status, ErrorMsg)
		VALUES ('OrderItems', @start, SYSDATETIME(), @rows, 'Success', NULL);
	END TRY
	BEGIN CATCH
		INSERT INTO silver.LoadAuditLog ( TableName, LoadStart, LoadEnd, RowsCount, Status, ErrorMsg)
		VALUES ('OrderItems', @start, SYSDATETIME(), @rows, 'Failed', ERROR_MESSAGE());
		THROW;
	END CATCH
END 

GO

EXEC silver.Load_OrderItems --Executing Stored Procedure

GO

SELECT * FROM silver.LoadAuditLog --Checking Audit Logs

SELECT COUNT(*) FROM silver.OrderItems; --Checking numbers of rows inserted

GO

CREATE TABLE silver.OrderPayments (
	OrderID NVARCHAR(60),
	PaymentSequential INT,
	PaymentType NVARCHAR(60),
	PaymentInstallments INT,
	PaymentValue DECIMAL(10,2),
	PRIMARY KEY (OrderID, PaymentSequential)
);

GO

CREATE OR ALTER PROCEDURE silver.Load_OrderPayments 
AS 
BEGIN
	
	SET NOCOUNT ON;
	DECLARE @start DATETIME2 = SYSDATETIME(), @rows INT = 0;

	BEGIN TRY

		TRUNCATE TABLE silver.OrderPayments;

		INSERT INTO silver.OrderPayments (OrderID, PaymentSequential, PaymentType, PaymentInstallments, PaymentValue)
		SELECT 
			TRIM(OrderID),
			TRY_CAST(TRIM(PaymentSequential) as INT),
			LOWER(TRIM(PaymentType)),
			TRY_CAST(TRIM(PaymentInstallments) as INT),
			TRY_CAST(PaymentValue as DECIMAL(10,2))
		FROM staging.OrderPayments
		WHERE TRIM(OrderID) IS NOT NULL AND
			  TRY_CAST(PaymentValue as DECIMAL(10,2)) IS NOT NULL;

		SET @rows = @@ROWCOUNT;

		INSERT INTO silver.LoadAuditLog (TableName, LoadStart, LoadEnd, RowsCount, Status, ErrorMsg)
		VALUES ('OrderPayments', @start, SYSDATETIME(), @rows, 'Success', NULL);

	END TRY
	BEGIN CATCH
		INSERT INTO silver.LoadAuditLog (TableName, LoadStart, LoadEnd, RowsCount, Status, ErrorMsg)
		VALUES ('OrderPayments', @start, SYSDATETIME(), @rows, 'Failed', ERROR_MESSAGE());
		THROW;
	END CATCH
END 

GO

EXEC silver.Load_OrderPayments; --Executing Stored Procedure

GO

SELECT * FROM silver.LoadAuditLog; -- Checking Audit logs

SELECT COUNT(*) FROM silver.OrderPayments; --Checking Numbers of rows inserted

GO

CREATE TABLE silver.OrderReviews (
	ReviewID NVARCHAR(60),
	OrderID NVARCHAR(60),
	ReviewScore TINYINT,
	ReviewCommentTitle NVARCHAR(200),
	ReviewCommentMSG NVARCHAR(MAX),
	ReviewCreation_ts DATETIME2,
	ReviewAnswer_ts DATETIME2,
	hasComment BIT
);

GO

CREATE OR ALTER PROCEDURE silver.Load_OrderReviews 
AS
BEGIN
	
	SET NOCOUNT ON;
	DECLARE @start DATETIME2 = SYSDATETIME(), @rows INT = 0;

	BEGIN TRY 
		
		TRUNCATE TABLE silver.OrderReviews;

		WITH Ranked AS (
			SELECT *,
				ROW_NUMBER() 
					OVER( PARTITION BY ReviewID, OrderID
						ORDER BY TRY_CONVERT(DATETIME2, ReviewAnswerTimestamp) DESC) AS rn
			FROM staging.OrderReviews
		)
		INSERT INTO silver.OrderReviews (ReviewID, OrderID, ReviewScore, ReviewCommentTitle, ReviewCommentMSG, ReviewCreation_ts, ReviewAnswer_ts, 
											hasComment)
		SELECT 
			TRIM(ReviewID),
			TRIM(OrderID),
			TRY_CAST(ReviewScore AS tinyint),
			NULLIF(NULLIF(TRIM(ReviewCommentTitle), ''), 'nan'),
			NULLIF(NULLIF(TRIM(ReviewCommentMSG), ''), 'nan'),
			TRY_CONVERT(DATETIME2, ReviewCreationDate),
			TRY_CONVERT(DATETIME2, ReviewAnswerTimestamp),
			CASE WHEN NULLIF(NULLIF(TRIM(ReviewCommentMSG),''), 'nan') IS NOT NULL THEN 1 ELSE 0 END
		FROM Ranked
		WHERE rn = 1 AND TRIM(OrderiD) IS NOT NULL;

		SET @rows = @@ROWCOUNT;

		INSERT INTO silver.LoadAuditLog (TableName, LoadStart, LoadEnd, RowsCount, Status, ErrorMsg)
		VALUES ('OrderReviews', @start, SYSDATETIME(), @rows, 'Success', NULL);
	END TRY	
	BEGIN CATCH
		INSERT INTO silver.LoadAuditLog (TableName, LoadStart, LoadEnd, RowsCount, Status, ErrorMsg)
		VALUES ('OrderReviews', @start, SYSDATETIME(), @rows, 'Failed', ERROR_MESSAGE());
		THROW;
	END CATCH
END 

GO

EXEC silver.Load_OrderReviews; --Executing Stored Procedure 

GO

SELECT * FROM silver.LoadAuditLog; --checking audit logs

SELECT COUNT(*) FROM silver.OrderReviews; -- checking numbers of rows inserted

GO

CREATE TABLE silver.Products (
    ProductID NVARCHAR(50) PRIMARY KEY,
    CategoryName_pt NVARCHAR(100),
    CategoryName_eng NVARCHAR(100),
    Weight_g INT,
    Length_cm INT,
    Height_cm INT,
    Width_cm INT,
    Photos_qty INT
);

GO

CREATE OR ALTER PROCEDURE silver.Load_Products 
AS 
BEGIN
	
	SET NOCOUNT ON;
	DECLARE @start DATETIME2 = SYSDATETIME(), @rows INT = 0;

	BEGIN TRY

			TRUNCATE TABLE silver.Products;

			INSERT INTO silver.Products (ProductID, CategoryName_pt, CategoryName_eng, Weight_g, Length_cm, Height_cm, Width_cm, Photos_qty)
			SELECT 
				TRIM(p.ProductID),
				TRIM(p.ProductCategoryName),
				ISNULL(t.ProductCategoryNameEnglish, 'unknown'),
				TRY_CAST(p.ProductWeight_g AS INT),
				TRY_CAST(p.ProductLength_cm AS INT),
				TRY_CAST(p.ProductHeight_cm AS INT),
				TRY_CAST(p.ProductWidth_cm AS INT),
				TRY_CAST(p.ProductPhotosQty AS INT)
			FROM staging.Products p
			LEFT JOIN staging.ProductCategoryNameTranslation t
				ON p.ProductCategoryName = t.ProductCategoryName
			WHERE p.ProductID IS NOT NULL;

			SET @rows =@@ROWCOUNT;

			INSERT INTO silver.LoadAuditLog (TableName, LoadStart, LoadEnd, RowsCount, Status, ErrorMsg)
			VALUES ('Products', @start, SYSDATETIME(), @rows, 'Success', NULL);

	END TRY
	BEGIN CATCH	
			INSERT INTO silver.LoadAuditLog (TableName, LoadStart, LoadEnd, RowsCount, Status, ErrorMsg)
			VALUES ('Products', @start, SYSDATETIME(), @rows, 'Failed', ERROR_MESSAGE());
			THROW;
	END CATCH

END

GO

EXEC silver.Load_Products; --Executing Stored Procedure

GO

SELECT * FROM silver.LoadAuditLog; --Checking Audit Logs 

SELECT COUNT(*) FROM silver.Products; --Chekcing numbers of rows inserted

GO


CREATE TABLE silver.Sellers (
	SellerID NVARCHAR(60) PRIMARY KEY,
	ZipCodePrefix NVARCHAR(60),
	City NVARCHAR(60),
	State NVARCHAR(60)
);

GO

CREATE OR ALTER PROCEDURE silver.Load_Sellers
AS
BEGIN 

	SET NOCOUNT ON;
	DECLARE @start DATETIME2 =SYSDATETIME(), @rows INT = 0;

	BEGIN TRY 
		
		TRUNCATE TABLE silver.Sellers;

		INSERT INTO silver.Sellers (SellerID, ZipCodePrefix, City, State)
		SELECT 
			TRIM(SellerID),
			TRIM(SellerZipCodePrefix),
			TRIM(SellerCity),
			TRIM(SellerState)
		FROM staging.Sellers
		WHERE TRIM(SellerID) IS NOT NULL;

		SET @rows = @@ROWCOUNT;

		INSERT INTO silver.LoadAuditLog (TableName, LoadStart, LoadEnd, RowsCount, Status, ErrorMsg)
		VALUES ('Sellers', @start, SYSDATETIME(), @rows, 'Success', NULL);

	END TRY
	BEGIN CATCH
		INSERT INTO silver.LoadAuditLog (TableName, LoadStart, LoadEnd, RowsCount, Status, ErrorMsg)
		VALUES ('Sellers', @start, SYSDATETIME(), @rows, 'Failed', ERROR_MESSAGE());
		THROW;
	END CATCH
END

GO

EXEC silver.Load_Sellers; --Executing Stored Procedure

GO

SELECT * FROM silver.LoadAuditLog; --checking audit logs

SELECT COUNT(*) FROM silver.Sellers; -- Checking numbers of rows Inserted

GO

---Checking number of rows per ZipCodePrefix in staging.Geolocation tables

SELECT 
GeolocationZipCodePrefix,
Count(*) AS RowCount_PerZip
FROM staging.Geolocation
GROUP BY 
GeolocationZipCodePrefix
ORDER BY RowCount_PerZip DESC;

GO

CREATE TABLE silver.Geolocation (
	ZipCodePrefix NVARCHAR(60) PRIMARY KEY,
	Latitude DECIMAL(9,6),
	Longtitude DECIMAL(9,6),
	City NVARCHAR(100),
	State NVARCHAR(100)
);

GO

CREATE OR ALTER PROCEDURE silver.Load_Geolocation
AS
BEGIN 
		
		SET NOCOUNT ON;
		DECLARE @start DATETIME2 = SYSDATETIME(), @rows INT = 0;

		BEGIN TRY 
			
			TRUNCATE TABLE silver.Geolocation;

			;WITH avg_lat_long AS (
				
				SELECT 
					GeolocationZipCodePrefix AS ZipCodePrefix,
					AVG(TRY_CAST(GeolocationLat AS DECIMAL(9,6))) Latitude,
					AVG(TRY_CAST(GeolocationLng AS DECIMAL(9,6))) AS Longtitude
				FROM staging.Geolocation
				GROUP BY GeolocationZipCodePrefix
			),
			CitySate_pick AS (
				SELECT 
					GeolocationZipCodePrefix AS ZipCodePrefix,
					GeolocationCity,
					GeolocationState,
					ROW_NUMBER() OVER(PARTITION BY GeolocationZipCodePrefix ORDER BY (SELECT NULL)) as rn
				FROM staging.Geolocation
			)
			INSERT INTO silver.Geolocation (ZipCodePrefix, Latitude, Longtitude, City, State)
			SELECT 
				a.ZipCodePrefix,
				a.Latitude,
				a.Longtitude,
				c.GeolocationCity,
				c.GeolocationState
			FROM avg_lat_long a 
			JOIN CitySate_pick c
			ON a.ZipCodePrefix = c.ZipCodePrefix AND rn = 1;

			SET @rows = @@ROWCOUNT;

			INSERT INTO silver.LoadAuditLog ( TableName, LoadStart, LoadEnd, RowsCount, Status, ErrorMsg)
			VALUES ('Geolocation', @start, SYSDATETIME(), @rows, 'Success', NULL);
		END TRY
		BEGIN CATCH
			INSERT INTO silver.LoadAuditLog (TableName, LoadStart, LoadEnd, RowsCount, Status, ErrorMsg)
			VALUES ('Geolocation', @start, SYSDATETIME(), @rows, 'Failed', ERROR_MESSAGE());
			THROW;
		END CATCH
END

GO

EXEC silver.Load_Geolocation; --Executing Stored Procedure

GO

SELECT * FROM silver.LoadAuditLog --Checking Audit Logs

SELECT ZipCodePrefix, 
COUNT(*) 
FROM silver.Geolocation
GROUP BY ZipCodePrefix -- Chekcing Numbers of Inserted Per ZipCode
HAVING COUNT(*) > 1; --Checking if any ZipCode has two rows

GO

/*====================================================================================================
============ CREATING A MASTER STORED PROCEDURE TO EXECUTE ALL PROCEDURE IN ONE QUERY=================
*/

CREATE OR ALTER PROCEDURE silver.Load_ALL
AS
BEGIN
	
	EXEC silver.Load_Customers;
	EXEC silver.Load_Geolocation;
	EXEC silver.Load_OrderItems;
	EXEC silver.Load_OrderPayments;
	EXEC silver.Load_OrderReviews;
	EXEC silver.Load_Orders;
	EXEC silver.Load_Products;
	EXEC silver.Load_Sellers;
END 

GO

EXEC silver.Load_ALL;

GO

SELECT * FROM silver.LoadAuditLog;

