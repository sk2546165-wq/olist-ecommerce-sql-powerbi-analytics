
USE OlistDB;

GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE NAME = 'gold')
	EXEC ('CREATE SCHEMA gold');

GO


CREATE TABLE gold.dim_DateTable (
	DateKey INT PRIMARY KEY,
	FullDate DATE,
	[Year] INT,
	[Quarter] INT,
	[Month] INT,
	[MonthName] NVARCHAR(15),
	[DayOfWeek] NVARCHAR(15),
	IsWeekend BIT
);

GO

CREATE TABLE gold.dim_Customers (
	CustomerKey INT IDENTITY PRIMARY KEY,
	CustomerID NVARCHAR(100),
	CustomerUniqueID NVARCHAR(100),
	City NVARCHAR(100),
	State NVARCHAR(50),
	ZipPrefix NVARCHAR(50),
	Latitude DECIMAL(9,6),
	Longitude DECIMAL(9,6)
);

GO

CREATE TABLE gold.dim_Sellers (
	SellerKey INT IDENTITY PRIMARY KEY,
	SellerID NVARCHAR(50),
	City NVARCHAR(100),
	State NVARCHAR(50),
	ZipPrefix NVARCHAR(50),
	Latitude DECIMAL(9,6),
	Longitude DECIMAL(9,6)
);

GO

CREATE TABLE gold.dim_Products (
	ProductKey INT IDENTITY PRIMARY KEY,
	ProductID NVARCHAR(60),
	CategoryName_pt NVARCHAR(100),
	CategoryName_eng NVARCHAR(100),
	Weight_g INT,
	Length_cm INT,
	Height_cm INT,
	Width_cm INT,
	PhotosQty INT
);

GO

CREATE TABLE gold.dim_Orders (
	OrderKey INT IDENTITY PRIMARY KEY,
	OrderID NVARCHAR(50),
	CustomerKey INT REFERENCES gold.dim_Customers,
	OrderStatus NVARCHAR(20),
	PurchaseDateKey INT REFERENCES gold.dim_DateTable(DateKey),
	ApprovedDateKey INT REFERENCES gold.dim_DateTable(DateKey),
	DeliveredCarrierDateKey INT REFERENCES gold.dim_DateTable(Datekey),
	DeliveredCustomerDateKey INT REFERENCES gold.dim_DateTable(DateKey),
	EstimatedDeliveryDateKey INT REFERENCES gold.dim_DateTable(DateKey),
	IsLate TINYINT
);

GO

CREATE TABLE gold.Fact_OrderItems (
	OrderItemKey BIGINT IDENTITY PRIMARY KEY,
	OrderKey INT REFERENCES gold.dim_Orders,
	ProductKey INT REFERENCES gold.dim_Products,
	SellerKey INT REFERENCES gold.dim_Sellers,
	OrderItemID INT,
	Price DECIMAL(10,2),
	FreightValue DECIMAL(10,2)
);

GO

CREATE TABLE gold.Fact_Payments (
	PaymentKey BIGINT IDENTITY PRIMARY KEY,
	OrderKey INT REFERENCES gold.dim_Orders,
	PaymentSequential INT,
	PaymentType NVARCHAR(30),
	PaymentInstallments INT,
	PaymentValue DECIMAL(10,2)
);

GO

CREATE TABLE gold.Fact_Reviews (
	ReviewKey BIGINT IDENTITY PRIMARY KEY,
	OrderKey INT REFERENCES gold.dim_Orders,
	ReviewScore TINYINT,
	ReviewCreationDateKey INT,
	ReviewAnswerDateKey INT,
	hasComment BIT
);


