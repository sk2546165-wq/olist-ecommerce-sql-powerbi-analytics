
USE OlistDB;

/*========================================================================================================
====== Revenue & Growth
====== Monthly revenue trend with MoM growth
*/

CREATE OR ALTER VIEW gold.vw_MomGrowth_Revenue AS
WITH MonthlyTrend AS (
	SELECT 
		d.[Year],
		d.[Month],
		SUM(foi.Price) AS Revenue
	FROM gold.Fact_OrderItems foi
		JOIN gold.dim_Orders o ON foi.OrderKey = o.OrderKey
		JOIN gold.dim_DateTable d ON o.PurchaseDateKey = d.DateKey
	GROUP BY d.[Year], d.[Month]
),
PrevMonth AS (
	SELECT
		[Year],
		[Month],
		Revenue,
		LAG(Revenue) OVER(ORDER BY [Year], [Month]) AS PreviousMonthRevenue
	FROM MonthlyTrend
)
	SELECT
		[Year],
		[Month],
		Revenue,
		PreviousMonthRevenue,
		CAST((((Revenue - PreviousMonthRevenue) * 100) / NULLIF(PreviousMonthRevenue, 0) ) AS DECIMAL(10,2)) MomGrowthPct
	FROM PrevMonth;

GO

	SELECT * FROM gold.vw_MomGrowth_Revenue
	ORDER BY [Year], [Month];   --Calling VIEW

GO

/*============================================================================================================
========= Cumulative Revenue Order BY Year & Month 
==============================================================================================================
*/

CREATE OR ALTER VIEW gold.vw_CumulativeRevenue AS
WITH sum_revenue AS 
(
	SELECT 
		d.[Year],
		d.[Month],
		SUM(foi.Price) AS Revenue
	FROM gold.Fact_OrderItems foi
		JOIN gold.dim_Orders o ON o.OrderKey = foi.OrderKey
		JOIN gold.dim_DateTable d ON o.PurchaseDateKey = d.DateKey
	GROUP BY 
		d.[Year], d.[Month]
)
	SELECT
		[Year],
		[Month],
		Revenue,
		SUM(Revenue) OVER( ORDER BY [Year], [Month] ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS Cumulative_Revenue
	FROM sum_revenue;

GO

	SELECT TOP (100) * FROM gold.vw_CumulativeRevenue; -- Calling the VIEW

GO

/*===========================================================================================================
======= Calculating Late Delivery Rate Per State by Dividing No. Late Order by Total No. of Orders 
=============================================================================================================
*/

CREATE OR ALTER VIEW gold.vw_LateDeliveryRate_PerState AS
WITH OrderCount AS (
	
	SELECT 
		c.State,
		COUNT(*) as Total_Orders,
		SUM(CAST(o.Islate AS INT)) Late_Orders
	FROM gold.dim_Orders o
		JOIN gold.dim_Customers c
			ON o.CustomerKey = c.CustomerKey 
	GROUP BY 
		c.State
)
SELECT 
	state,
	Total_Orders,
	Late_Orders,
	CAST(((Late_Orders * 100.00) / Total_Orders) AS DECIMAL(10,2)) LateDeliveryRatePct_PerState
FROM OrderCount;

GO

SELECT * FROM gold.vw_LateDeliveryRate_PerState; --Calling the View

GO

/*==================================================================================================
====================== Calculating Average Delivery Delay  Days by Seller in Each State
====================================================================================================
*/

CREATE OR ALTER VIEW gold.vw_AvgDeliveryDelayDays AS
WITH OrderDelay AS (
	
	SELECT DISTINCT
		foi.SellerKey,
		o.OrderKey,
		DATEDIFF(DAY, d_del.FullDate,d_est.FullDate) DelayDays
	FROM gold.Fact_OrderItems foi
		JOIN gold.dim_Orders o ON foi.OrderKey = o.OrderKey 
		JOIN gold.dim_DateTable d_del ON o.DeliveredCustomerDateKey = d_del.DateKey
		JOIN gold.dim_DateTable d_est ON o.EstimatedDeliveryDateKey = d_est.DateKey
)
	SELECT
		s.SellerID,
		s.State,
		Count(*) AS Count_Of_Delivered_Orders,
		CAST(AVG(CAST(od.DelayDays AS DECIMAL(10,2))) AS DECIMAL(10,2)) Avg_Delivery_Delay_Days
	FROM OrderDelay od 
		JOIN gold.dim_Sellers s ON od.SellerKey = s.SellerKey
	GROUP BY 
		s.SellerID,
		s.State;

GO

SELECT * FROM gold.vw_AvgDeliveryDelayDays; -- Calling the View

/*================================================================================================================
============== TOP Customers by Spending for each state 
==================================================================================================================
*/

GO

CREATE OR ALTER VIEW gold.vw_TopCustomersBySpending_StateWise AS

WITH CustomerSpending AS (

	SELECT 
		c.CustomerKey,
		c.State,
		SUM(foi.Price) Total_spending
	FROM gold.Fact_OrderItems foi
		JOIN gold.dim_Orders o ON foi.OrderKey = o.OrderKey
		JOIN gold.dim_Customers c ON o.CustomerKey = c.CustomerKey
	GROUP BY
		c.CustomerKey, c.State
)
	SELECT 
		CustomerKey,
		State,
		Total_spending,
		RANK() OVER( PARTITION BY state ORDER BY Total_spending DESC) spending_rank
	FROM CustomerSpending;

GO

	SELECT * FROM gold.vw_TopCustomersBySpending_StateWise 
	WHERE spending_rank <= 3;                               --- Selecting top customers for each state

GO

/*=======================================================================================================
============================Checking the count of Regular Customer and One Time Customers
=========================================================================================================
*/

CREATE OR ALTER VIEW gold.vw_Regular_Vs_OneTimeCustomers AS 

SELECT
	c.CustomerUniqueID,
	COUNT(DISTINCT o.OrderKey) OrderCount,
	CASE WHEN COUNT(DISTINCT o.OrderKey) > 1 THEN 'Regular or Repeated' ELSE 'One Time Customer' 
		END CustomerType 
FROM gold.dim_Orders o
	JOIN gold.dim_Customers c
		ON o.CustomerKey = c.CustomerKey
GROUP BY 
	c.CustomerUniqueID;

GO

-- Checking count of Regular and One Time Customers

SELECT
	CustomerType,  
	COUNT(*)
FROM gold.vw_Regular_Vs_OneTimeCustomers
GROUP BY 
	CustomerType;

GO

/*============================================================================================================
=========== Seller Performance : Revenue and Average Review Score 
==============================================================================================================
*/

CREATE OR ALTER VIEW gold.vw_SellerPerformance AS

WITH SellerRevenue_OrderCount AS (
	SELECT 
		SellerKey,
		SUM(Price) TotalRevenue,
		COUNT(DISTINCT OrderKey) OrderCount
	FROM gold.Fact_OrderItems
	GROUP BY
		SellerKey
),
AvgReviewScore AS (
	SELECT
		foi.SellerKey,
		CAST(AVG(CAST(r.ReviewScore AS DECIMAL(10,2))) AS DECIMAL(10,2) ) AvgReviewScore
	FROM gold.Fact_OrderItems foi
		JOIN gold.Fact_Reviews r
			ON foi.OrderKey = r.OrderKey
	GROUP BY 
		foi.SellerKey
)
SELECT
	s.SellerID,
	s.State,
	sr.TotalRevenue,
	sr.OrderCount,
	ars.AvgReviewScore,
	RANK() OVER(ORDER BY sr.TotalRevenue DESC) RevenueRank
FROM SellerRevenue_OrderCount sr 
	JOIN gold.dim_Sellers s
		ON sr.SellerKey = s.SellerKey
	JOIN AvgReviewScore ars
		ON sr.SellerKey = ars.SellerKey;

GO

SELECT * FROM gold.vw_SellerPerformance; ---Calling the View

GO

SELECT * FROM gold.vw_SellerPerformance 
WHERE RevenueRank <=50 AND AvgReviewScore < 3.5
ORDER BY TotalRevenue DESC;

GO

/*=============================================================================================================
======================== Review and Delivery Correlation: Checking Average Score for Late Orders 
===============================================================================================================
*/

CREATE OR ALTER VIEW gold.vw_Review_Delivery_Correlation AS
WITH OrderDelivery AS (
	SELECT 
		OrderKey,
		CASE WHEN IsLate = 0 THEN 'NO' ELSE 'YES' END Is_Late
	FROM gold.dim_Orders
)
SELECT 
	od.Is_Late,
	AVG(CAST(r.ReviewScore AS DECIMAL(10,2))) Avg_Score,
	COUNT(*) Review_Count
FROM OrderDelivery od
	JOIN gold.Fact_Reviews r
		ON od.OrderKey = r.OrderKey
GROUP BY
	od.Is_Late 

GO

SELECT * FROM gold.vw_Review_Delivery_Correlation; --Calling the view

GO


/*===================================================================================================================
============ Analysing MOM Growth % for Each Category,
============ Created MonthIndex to Avoid months where a particular category didn't made any sales
=====================================================================================================================
*/

CREATE OR ALTER VIEW gold.vw_CategoryMonthlyRevenue AS
WITH MonthlyRevenue AS (
	SELECT
		p.CategoryName_eng,
		d.[Year],
		d.[Month],
		d.[Year] * 12 + d.[Month] AS MonthIndex,
		SUM(foi.Price) Revenue
	FROM gold.Fact_OrderItems foi
		JOIN gold.dim_Products p 
			ON foi.ProductKey = p.ProductKey 
		JOIN gold.dim_Orders o	
			ON foi.OrderKey = o.OrderKey
		JOIN gold.dim_DateTable d
			ON o.PurchaseDateKey = d.DateKey
	GROUP BY
		p.CategoryName_eng, 
		d.[Year],
		d.[Month]
),
PreviousMonthRevnue AS (
	SELECT
		CategoryName_eng,
		[Year],
		[Month],
		MonthIndex,
		Revenue,
		LAG(MonthIndex) OVER(PARTITION BY CategoryName_eng ORDER BY MonthIndex) PreviousMonthIndex,
		LAG(Revenue) OVER(PARTITION BY CategoryName_eng ORDER BY MonthIndex) Previous_Month_Revenue
	FROM MonthlyRevenue
)
SELECT
	CategoryName_eng,
	[Year],
	[Month],
	Revenue,
	CASE WHEN MonthIndex - PreviousMonthIndex = 1 THEN Previous_Month_Revenue END PreviousMonthRevenue,
	CASE WHEN MonthIndex - PreviousMonthIndex = 1 THEN 
	CAST(((Revenue - Previous_Month_Revenue) / NULLIF(Previous_Month_Revenue,0) *100) AS DECIMAL(10,2)) END MOM_GrowthPct
FROM PreviousMonthRevnue

GO

SELECT * FROM gold.vw_CategoryMonthlyRevenue; --Calling the view

s










