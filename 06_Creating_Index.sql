
/*==============================================================================================================
=================================== Creating Indexex on gold layer tables 
================================================================================================================
*/

SET STATISTICS IO ON;
SET STATISTICS TIME ON;

SELECT * FROM gold.vw_CategoryMonthlyRevenue;

SELECT * FROM gold.vw_SellerPerformance; 

CREATE NONCLUSTERED INDEX IX_FactOrderItems_OrderKey
    ON gold.Fact_OrderItems (OrderKey) INCLUDE (ProductKey, SellerKey, Price);

CREATE NONCLUSTERED INDEX IX_FactOrderItems_ProductKey
    ON gold.Fact_OrderItems (ProductKey) INCLUDE (OrderKey, Price);

CREATE NONCLUSTERED INDEX IX_FactOrderItems_SellerKey
    ON gold.Fact_OrderItems (SellerKey) INCLUDE (OrderKey, Price);

CREATE NONCLUSTERED INDEX IX_dimOrders_PurchaseDateKey
    ON gold.dim_Orders (PurchaseDateKey) INCLUDE (OrderKey, CustomerKey, IsLate);

CREATE NONCLUSTERED INDEX IX_dimOrders_CustomerKey
    ON gold.dim_Orders (CustomerKey) INCLUDE (IsLate);

CREATE NONCLUSTERED INDEX IX_FactReviews_OrderKey
    ON gold.Fact_Reviews (OrderKey) INCLUDE (ReviewScore);

CREATE NONCLUSTERED INDEX IX_FactPayments_OrderKey
    ON gold.Fact_Payments (OrderKey) INCLUDE (PaymentValue, PaymentType);

 