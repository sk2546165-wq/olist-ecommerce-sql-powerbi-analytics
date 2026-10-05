
Use OlistDB;

GO

CREATE OR ALTER PROCEDURE gold.Load_DateTable
AS 
BEGIN
	
	SET NOCOUNT ON;
	DECLARE @start DATETIME2 = SYSDATETIME(), @rows INT = 0;
		
		BEGIN TRY
			
			 DELETE FROM gold.dim_DateTable;
			
			;WITH dates as (
				
				SELECT CAST('2016-01-01' AS DATE) AS FullDate
				UNION ALL
				SELECT 
					DATEADD(DAY, 1, FullDate)
				FROM dates
				WHERE FullDate < '2019-12-31'
			)
			INSERT INTO gold.dim_DateTable ( DateKey, FullDate, [Year], [Quarter], [Month], [MonthName], [DayOfWeek], IsWeekend)
			SELECT 
				CAST(FORMAT(FullDate, 'yyyyMMdd') as INT) AS DateKey,
				FullDate,
				Year(FullDate),
				DATEPART(Quarter, FullDate),
				Month(FullDate),
				DATENAME(Month, FullDate),
				DATENAME(WEEKDAY, FullDate),
				CASE WHEN DATENAME(WEEKDAY, FullDate) IN ('Saturday', 'Sunday') THEN 1 ELSE 0 END

			FROM dates
			OPTION (MAXRECURSION 0);

			SET @rows = @@ROWCOUNT;

			INSERT INTO silver.LoadAuditLog ( TableName, LoadStart, LoadEnd, RowsCount, Status, ErrorMsg)
			VALUES ('gold.dim_DateTable', @start, SYSDATETIME(), @rows, 'Success', NULL);
		END TRY
		BEGIN CATCH 
			INSERT INTO silver.LoadAuditLog (TableName,LoadStart, LoadEnd, RowsCount, Status, ErrorMsg)
			VALUES ('gold.dim_DateTable', @start, SYSDATETIME(), @rows, 'Failed', ERROR_MESSAGE());
			THROW;
		END CATCH
END

GO

EXEC gold.Load_DateTable; --Executing Stored Procedure

GO

SELECT * FROM silver.LoadAuditLog --Checking Audit Logs

SELECT COUNT(*) FROM gold.dim_DateTable; --Checking the number of rows inserted

GO

CREATE OR ALTER PROCEDURE gold.Load_dim_Customers
AS 
BEGIN

	SET NOCOUNT ON;
	DECLARE @start DATETIME2 = SYSDATETIME(), @rows INT = 0;

		BEGIN TRY
			
			DELETE FROM gold.dim_Customers;

			INSERT INTO gold.dim_Customers (CustomerID, CustomerUniqueID, City, State, ZipPrefix, Latitude, Longitude)
			SELECT
				c.CustomerID,
				c.CustomerUniqueID,
				c.City,
				c.State,
				c.ZipCodePrefix,
				g.Latitude,
				g.Longtitude
			FROM silver.Customers c
			LEFT JOIN silver.Geolocation g
				ON c.ZipCodePrefix = g.ZipCodePrefix;

			SET @rows = @@ROWCOUNT;

			INSERT INTO silver.LoadAuditLog (TableName, LoadStart, LoadEnd, RowsCount, Status, ErrorMsg)
			VALUES ('gold.dim_customers', @start, SYSDATETIME(), @rows, 'Success', NULL);
		END TRY
		BEGIN CATCH
			INSERT INTO silver.LoadAuditLog (TableName, LoadStart, LoadEnd, RowsCount, Status, ErrorMsg)
			VALUES ('gold.dim_Customers', @start, SYSDATETIME(), @rows, 'Failed', ERROR_MESSAGE());
			THROW;
		END CATCH
END

GO

EXEC gold.Load_dim_Customers; --Executing Stored Procedure

GO

SELECT * FROM silver.LoadAuditLog --Checking Audit Logs

SELECT COUNT(*) FROM gold.dim_Customers; --Checking the number of rows inserted

GO

CREATE OR ALTER PROCEDURE gold.Load_dim_Sellers
AS 
BEGIN
	
	SET NOCOUNT ON;
	DECLARE @start DATETIME2 = SYSDATETIME(), @rows INT = 0;

		BEGIN TRY 
			
			DELETE FROM gold.dim_Sellers;

			INSERT INTO gold.dim_Sellers (SellerID, City, State, ZipPrefix, Latitude, Longitude)
			SELECT 
				s.SellerID,
				s.City,
				s.State,
				s.ZipCodePrefix, 
				g.Latitude, 
				g.Longtitude
			FROM silver.Sellers s
			LEFT JOIN silver.Geolocation g
				ON s.ZipCodePrefix = g.ZipCodePrefix;

			SET @rows = @@ROWCOUNT;

			INSERT INTO silver.LoadAuditLog (TableName, LoadStart, LoadEnd, RowsCount, Status, ErrorMsg)
			VALUES ('gold.dim_Sellers', @start, SYSDATETIME(), @rows, 'Success', NULL);
		END TRY
		BEGIN CATCH
			INSERT INTO silver.LoadAuditLog (TableName, LoadStart, LoadEnd, RowsCount, Status, ErrorMsg)
			VALUES ('gold.dim_Sellers', @start, SYSDATETIME(), @rows, 'Failed', ERROR_MESSAGE());
			THROW;
		END CATCH
END

GO

EXEC gold.Load_dim_Sellers; --Executing Stored Procedure

GO

SELECT * FROM silver.LoadAuditLog --Checking Audit Logs

SELECT COUNT(*) FROM gold.dim_Sellers; --Checking the number of rows inserted

GO

CREATE OR ALTER PROCEDURE gold.Load_dim_Products 
AS 
BEGIN
	
	SET NOCOUNT ON;
	DECLARE @start DATETIME2 = SYSDATETIME(), @rows INT = 0;

	BEGIN TRY
		
		DELETE FROM gold.dim_Products;

		INSERT INTO gold.dim_Products (ProductID, CategoryName_pt, CategoryName_eng, Weight_g, Length_cm, Height_cm, Width_cm, PhotosQty)
		SELECT
			ProductID,
			CategoryName_pt,
			CategoryName_eng,
			Weight_g,
			Length_cm,
			Height_cm,
			Width_cm,
			Photos_qty
		FROM silver.Products;

		SET @rows = @@ROWCOUNT;

		INSERT INTO silver.LoadAuditLog (TableName, LoadStart, LoadEnd, RowsCount, Status, ErrorMsg)
		VALUES ('gold.dim_Products', @start, SYSDATETIME(), @rows, 'Success', NULL);
	END TRY
	BEGIN CATCH
		INSERT INTO silver.LoadAuditLog (TableName, LoadStart, LoadEnd, RowsCount, Status, ErrorMsg)
		VALUES ('gold.dim_Products', @start, SYSDATETIME(), @rows, 'Failed', ERROR_MESSAGE());
		THROW;
	END CATCH
END

GO

EXEC gold.Load_dim_Products; --Executing Stored Procedure

GO

SELECT * FROM silver.LoadAuditLog --Checking Audit Logs

SELECT COUNT(*) FROM gold.dim_Products; --Checking the number of rows inserted

GO

CREATE OR ALTER PROCEDURE gold.Load_dim_Orders 
AS
BEGIN
	
	SET NOCOUNT ON;
	DECLARE @start DATETIME2 = SYSDATETIME(), @rows INT = 0;

	BEGIN TRY
		
		DELETE FROM gold.dim_Orders;

		INSERT INTO gold.dim_Orders (OrderID, CustomerKey, OrderStatus, PurchaseDateKey, ApprovedDateKey, DeliveredCarrierDateKey, 
									DeliveredCustomerDateKey, EstimatedDeliveryDateKey, IsLate)
		SELECT 
			o.OrderID,
			c.CustomerKey,
			o.OrderStatus,
			CAST(FORMAT(o.Purchase_ts, 'yyyyMMdd') AS INT),
			CAST(FORMAT(o.Approved_ts, 'yyyyMMdd') AS INT),
			CAST(FORMAT(o.DeliveredCarrier_ts, 'yyyyMMdd') AS INT),
			CAST(FORMAT(o.DeliveredCustomer_ts, 'yyyyMMdd') AS INT),
			CAST(FORMAT(o.EstimatedDelivery_ts, 'yyyyMMdd') AS INT),
			o.IsLate
		FROM silver.Orders o
		JOIN gold.dim_Customers c
			ON o.CustomerID = c.CustomerID;

		SET @rows = @@ROWCOUNT;

		INSERT INTO silver.LoadAuditLog (TableName, LoadStart, LoadEnd, RowsCount, Status, ErrorMsg)
		VALUES ('gold.dim_Orders', @start, SYSDATETIME(), @rows, 'Success', NULL);
	
	END TRY
	BEGIN CATCH
		INSERT INTO silver.LoadAuditLog (TableName, LoadStart, LoadEnd, RowsCount, Status, ErrorMsg)
		VALUES ('gold.dim_Orders', @start, SYSDATETIME(), @rows, 'Failed', ERROR_MESSAGE());
		THROW;
	END CATCH
END		

GO

EXEC gold.Load_dim_Orders; --Executing Stored Procedure

GO

SELECT * FROM silver.LoadAuditLog --Checking Audit Logs

SELECT COUNT(*) FROM gold.dim_Orders; --Checking the number of rows inserted

GO

CREATE OR ALTER PROCEDURE gold.Load_Fact_OrderItems 
AS 
BEGIN
	
	SET NOCOUNT ON;
	DECLARE @start DATETIME2 = SYSDATETIME(), @rows INT = 0;

	BEGIN TRY 
		
		DELETE FROM gold.Fact_OrderItems;

		INSERT INTO gold.Fact_OrderItems (OrderKey, ProductKey, SellerKey, OrderItemID, Price, FreightValue)
		SELECT 
			o.OrderKey,
			p.ProductKey,
			s.SellerKey,
			oi.OrderItemID,
			oi.Price,
			oi.FrieghtValue
		FROM silver.OrderItems oi
		JOIN gold.dim_Orders o
			ON oi.OrderID = o.OrderID
		JOIN gold.dim_Products p
			ON oi.ProductID = p.ProductID
		JOIN gold.dim_Sellers s
			ON oi.SellerID = s.SellerID;

		SET @rows = @@ROWCOUNT;

		INSERT INTO silver.LoadAuditLog (TableName, LoadStart, LoadEnd, RowsCount, Status, ErrorMsg)
		VALUES ('gold.Fact_OrderItems', @start, SYSDATETIME(), @rows, 'Success', NULL);

	END TRY
	BEGIN CATCH
		INSERT INTO silver.LoadAuditLog ( TableName, LoadStart, LoadEnd, RowsCount, Status, ErrorMsg)
		VALUES ('gold.Fact_OrderItems', @start, SYSDATETIME(), @rows, 'Failed', ERROR_MESSAGE());
		THROW;
	END CATCH
END

GO

EXEC gold.Load_Fact_OrderItems; --Executing Stored Procedure

GO

SELECT * FROM silver.LoadAuditLog --Checking Audit Logs

SELECT COUNT(*) FROM gold.Fact_OrderItems; --Checking the number of rows inserted

GO

CREATE OR ALTER PROCEDURE gold.Load_Fact_Payments 
AS 
BEGIN

	SET NOCOUNT ON;
	DECLARE @start DATETIME2 = SYSDATETIME(), @rows INT = 0;

	BEGIN TRY 
		
		DELETE FROM gold.Fact_Payments;

		INSERT INTO gold.Fact_Payments (OrderKey, PaymentSequential, PaymentType, PaymentInstallments, PaymentValue)
		SELECT 
			o.OrderKey,
			op.PaymentSequential,
			op.PaymentType,
			op.PaymentInstallments,
			op.PaymentValue
		FROM silver.OrderPayments op
		JOIN gold.dim_Orders o
			ON op.OrderID = o.OrderID;
		
		SET @rows = @@ROWCOUNT;

		INSERT INTO silver.LoadAuditLog (TableName, LoadStart, LoadEnd, RowsCount, Status, ErrorMsg)
		VALUES ('gold.Fact_Payments', @start, SYSDATETIME(), @rows, 'Success', NULL);
	END TRY
	BEGIN CATCH
		INSERT INTO silver.LoadAuditLog (TableName, LoadStart, LoadEnd, RowsCount, Status, ErrorMsg)
		VALUES ('gold.Fact_Payments', @start, SYSDATETIME(), @rows, 'Failed', ERROR_MESSAGE());
		THROW;
	END CATCH
END

GO

EXEC gold.Load_Fact_Payments; -- Executing Stored Procedure 

GO

SELECT * FROM silver.LoadAuditLog; --Checking Audit Logs

SELECT count(*) from gold.Fact_Payments; --Checking numbers of rows inserted

GO

CREATE OR ALTER PROCEDURE gold.Load_Fact_Reviews
AS 
BEGIN
	
	SET NOCOUNT ON;
	DECLARE @start DATETIME2 = SYSDATETIME(), @rows INT = 0;

	BEGIN TRY
		
		DELETE FROM gold.Fact_Reviews;

		INSERT INTO gold.Fact_Reviews (OrderKey, ReviewScore, ReviewCreationDateKey, ReviewAnswerDateKey, hasComment)
		SELECT 
			o.OrderKey,
			r.ReviewScore,
			CAST(FORMAT(r.ReviewCreation_ts, 'yyyyMMdd') as INT),
			CAST(FORMAT(r.ReviewAnswer_ts, 'yyyyMMdd') AS INT),
			r.hasComment
		FROM silver.OrderReviews r
		JOIN gold.dim_Orders o
			ON r.OrderID = o.OrderID;

		SET @rows = @@ROWCOUNT;

		INSERT INTO silver.LoadAuditLog (TableName, LoadStart, LoadEnd, RowsCount, Status, ErrorMsg)
		VALUES ('gold.Fact_Reviews', @start, SYSDATETIME(), @rows, 'Success', NULL);
	END TRY
	BEGIN CATCH
		INSERT INTO silver.LoadAuditLog (TableName, LoadStart, LoadEnd, RowsCount, Status, ErrorMsg)
		VALUES ('gold.Fact_Reviews', @start, SYSDATETIME(), @rows, 'Failed', ERROR_MESSAGE());
		THROW;
	END CATCH
END

GO

EXEC gold.Load_Fact_Reviews; --Executing Stored Procedure 

GO

SELECT * FROM silver.LoadAuditLog; --Checking audit logs 

SELECT COUNT(*) FROM gold.Fact_Reviews; --Checking numbers of rows inserted

GO

/*==================================================================================================================
======================= CREATING MASTER PROCEDURE TO CLEAR AND LOAD EVERYTHING IN RIGHT ORDER=======================
*/

CREATE OR ALTER PROCEDURE gold.Load_ALL
AS 
BEGIN

/*===================== Fist Deleting Date from all tables in reverse order, KILLING CHILD BEFORE PARENT to aviod FK Constraints Error
*/
	
	DELETE FROM gold.Fact_Reviews;
	DELETE FROM gold.Fact_Payments;
	DELETE FROM gold.Fact_OrderItems;
	DELETE FROM gold.dim_Orders;
	DELETE FROM gold.dim_Products;
	DELETE FROM gold.dim_Sellers;
	DELETE FROM gold.dim_Customers;
	DELETE FROM gold.dim_DateTable;

/*====================== After Cleaning Data Executing Every Procedure to Reload Data 
*/
	EXEC gold.Load_DateTable;
	EXEC gold.Load_dim_Customers;
	EXEC gold.Load_dim_Sellers;
	EXEC gold.Load_dim_Products;
	EXEC gold.Load_dim_Orders;
	EXEC gold.Load_Fact_OrderItems;
	EXEC gold.Load_Fact_Payments;
	EXEC gold.Load_Fact_Reviews;

END

GO

EXEC gold.Load_ALL; --Executing Master PROCEDURE 

GO

SELECT * FROM silver.LoadAuditLog; --Checking Audit Logs