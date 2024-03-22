use mobility
go

select * from Devices where DeviceID = 4750
select * from ManagedInventoryXCarrierAccounts where customerID = 20
select * from ReplenishmentOrdersLog
select * from EquipmentInventory
SELECT TOP 10 * FROM SpareInventory
select top 100 * from customer
where is_active = 1


SELECT top 10 * FROM Mobilityorders order by 1 desc

select * from sys.tables where name like '%shipping%'


select top 10 * 
FROM Devices d (NOLOCK)
				JOIN DeviceXCarrier dc (NOLOCK) ON dc.DeviceID = d.DeviceID
				WHERE  d.IsActive = 1
					AND dc.IsActive = 1


					select top 10 * from CustomerXProductCatalog where CustomerID = 20 and productcatalogcategorymasterid = 5


DECLARE @CustomerID INT = 20, @CarrierID INT = 122, @DeviceID int = 4750, @DeviceXML varchar(max)
SELECT @DeviceXML = '<ROOT>
<row 
	DeviceTypeID="0" 
	DevicePricingMasterID="0" 
	DeviceID="' + CAST(@DeviceID AS VARCHAR(20)) +'" 
	DeviceVendorID="100" 
	DeviceXCarrierID="' + CAST(dc.DeviceXCarrierID AS VARCHAR(20)) +'" 
	DeviceConditionID="100" 
	Qty="1" 
	Cost="' + CAST(dc.Cost AS VARCHAR(20)) +'" 
	Margin="-100"
	Price="0" 
	IsInstallmentPlan="0" 
	DownPayment="0" 
	ROIOnCost="0" 
	ROIOnPrice="0" 
	Term="0" 
	MonthlyPaymentOnCost="0" 
	MonthlyPaymentOnPrice="0" 
	CustomerXProductCatalogID="' + CAST(cpc.CustomerXProductCatalogID AS VARCHAR(20)) + '" 
	ChargeType="' + cpc.ChargeType + '" 
	USOC="' + cpc.USOC + '" 
	ChargeDescription="' + cpc.Description + '" 
/></ROOT>'
FROM Devices d (NOLOCK)
JOIN DeviceXCarrier dc (NOLOCK) ON dc.DeviceID = d.DeviceID
LEFT JOIN CustomerXProductCatalog cpc (NOLOCK) ON cpc.CategoryPlanID = d.DeviceID 
	AND cpc.CarrierID = dc.CarrierID
	AND cpc.ProductCatalogCategoryMasterID = 5
	AND cpc.CustomerID = @CustomerID
	AND cpc.StatusID = 1		-- ask
WHERE d.DeviceID = @DeviceID
	AND dc.CarrierID = @CarrierID

PRINT @DeviceXML

----------------------------------------------- ship
SELECT * FROM sys.tables where name like '%location%'


select top 100 * from users order by user_id desc

sp_helptext CustomerAddress_GetByCustomerIDAddressType


select iscorp, * from CustomerAddress c
LEFT JOIN StateMaster S(NOLOCK) ON S.StateMasterID = c.StateMasterID
LEFT JOIN CountryMaster Co(NOLOCK) ON Co.CountryMasterID = c.CountryMasterID
where customerID = 20 and address1 is not null and iscorp = 1 

select * from CustomerAddress c 
LEFT JOIN StateMaster S(NOLOCK) ON S.StateMasterID = c.StateMasterID
LEFT JOIN CountryMaster Co(NOLOCK) ON Co.CountryMasterID = c.CountryMasterID
where customerID = 112275 and address1 is not null and iscorp = 1
like '%Meadowbridge%' or address2 like '%Meadowbridge%' or address3 like '%Meadowbridge%'


select * from customer cwhere customer_name like 'vcom%'


select top 10 * from ipath..account where customer_id = 112275


SELECT a.customer_id AS CustomerID
		,'S' AS AddressType
		,a.is_corp IsCorp
		,1 AS isViewable
		,1 isActive
		,99999 AddedByID
		,99999 ChangedByID
		,a.account_id AS AccountID
		,'a' AS RelType
	FROM ipath..account a(NOLOCK)
	LEFT JOIN CustomerAddress c(NOLOCK) ON c.AccountID = a.account_id
		AND a.customer_id = c.CustomerID
		AND AccountID IS NOT NULL
		AND RelType = 'a'
	WHERE Customer_Id = 112275
		AND CustomerAddressID IS NULL
		AND STATUS = 'A'



SELECT l.customer_id AS CustomerID
		,'S' AS AddressType
		,0 IsCorp
		,1 AS isViewable
		,1 isActive
		,99999 AddedByID
		,99999 ChangedByID
		,l.location_id AS AccountID
		,'l' AS RelType
	FROM ipath.dbo.[location] l(NOLOCK)
	LEFT JOIN CustomerAddress c(NOLOCK) ON c.AccountID = l.location_id
		AND l.customer_id = c.CustomerID
		AND AccountID IS NOT NULL
		AND RelType = 'l'
	WHERE CustomerId = 112275
		AND l.location_id IS NULL
		AND is_active = 1


-- CHECKKKKKKKKKKKKK
select top 10 * from ipath..account where address_1 like '%Meadowbridge%' or address_2 like '%Meadowbridge%' --or address_3 like '%Meadowbridge%' --where customer_id = 112275 and is_corp = 1

select top 10 * from  ipath.dbo.[location] where location_name like '%Meadowbridge%'

select * from CustomerAddress where (address1 like '%Meadowbridge%' or address2 like '%Meadowbridge%' or address3 like '%Meadowbridge%')
and customerID = 112275


---------------------------------------- NOTES
SELECT TOP 1 222222
	,'Managed Inventory for ' + customer_name
	,'Reupping Managed Inventory for ' + customer_name + '. Configured Minimum Qty for ' + ModelName + ' is ' + CAST(5 AS VARCHAR(20)) + ' and Replenishment Qty is ' + CAST(15 AS VARCHAR(20)) + '.'
	,1
	,1
	,GETDATE()
	,9999
	,GETDATE()
	,9999
FROM customer c(NOLOCK)
CROSS JOIN Devices d
WHERE customer_id = 20
	AND d.DeviceID = 4750


SELECT * FROM Mobilityorders where MobilityOrderID = 118857
sp_helptext CustomerCarrierAccounts_CreateReplenishmentOrders
sp_helptext Charges_GetOtherOrderCharges
sp_helptext GetAllFullfilmentFeesByCarrierAccount



-- =============================================    
-- Author:  SP    
-- Create date: <Create Date,,>    
-- Description: <Description,,>    
-- Author:  Kiranmai  /Srikanth  
-- Create date: 12-08-2022    
-- Description: Removed vSuite  
-- ============================================  
-- Modified By : LOKESH GOGINENI  
-- Modified Date : 05/Feb/2024  
-- Description : Fixed duplicate Charges -> USOC NOT IN Added by Lokesh Gogineni on 05-Feb-2024  
-- =============================================    
-- Modified By : AkhilM  
-- Modified Date : 20/Feb/2024  
-- Description : Added the new Fulfillment Fees as per case 4686  
-- =============================================   
-- EXEC Charges_GetOtherOrderCharges 20, 14, 100    
CREATE PROCEDURE [dbo].[Charges_GetOtherOrderCharges] @CustomerID INT
	,@CarrierAccountID INT = NULL
	,@DeviceVendorID INT = NULL
	,@ChannelType BIT = 0
AS
BEGIN
	DECLARE @CustomerXCarrierAccountsID INT
		,@CarrierID INT

	SELECT @CustomerXCarrierAccountsID = CustomerXCarrierAccountsID
		,@CarrierID = CarrierID
	FROM CustomerXCarrierAccounts(NOLOCK)
	WHERE CustomerID = @CustomerID
		AND CarrierAccountID = @CarrierAccountID
		AND IsActive = 1

	DECLARE @OtherOrderCharges TABLE (
		ChargeID INT
		,USOC VARCHAR(50)
		,ChargeType VARCHAR(50)
		,NAME VARCHAR(255)
		,Description VARCHAR(255)
		,Cost DECIMAL(19, 2)
		,Margin DECIMAL(19, 2)
		,Price DECIMAL(19, 2)
		,IsCustom BIT
		,SortOrder INT
		)
	DECLARE @AddlOrderCharges TABLE (
		ChargeID INT
		,USOC VARCHAR(50)
		,ChargeType VARCHAR(50)
		,NAME VARCHAR(255)
		,Description VARCHAR(255)
		,Cost DECIMAL(19, 2)
		,Margin DECIMAL(19, 2)
		,Price DECIMAL(19, 2)
		,IsCustom BIT
		,SortOrder INT
		)
	DECLARE @FulfillmentFees TABLE (
		FulfillmentVendorID INT
		,FulfillmentVendorDescription VARCHAR(100)
		,FulfillmentUSOC VARCHAR(50)
		,FulfillmentChargeType VARCHAR(75)
		,FulfillmentCost DECIMAL(38, 2)
		,FulfillmentMargin DECIMAL(38, 2)
		,FulfillmentPrice DECIMAL(38, 2)
		,SortOrder INT
		)

	INSERT INTO @FulfillmentFees
	EXEC [dbo].[GetAllFullfilmentFeesByCarrierAccount] @CustomerXCarrierAccountsID = @CustomerXCarrierAccountsID

	INSERT INTO @OtherOrderCharges
	SELECT C.ChargeID
		,C.USOC
		,C.ChargeType
		,C.USOC + ' - ' + C.Description AS NAME
		,C.Description
		,CC.Cost
		,CC.Margin
		,CC.Price
		,CAST(1 AS BIT) IsCustom
		,1 AS SortOrder
	FROM CustomerCharges cc(NOLOCK)
	JOIN Charges C(NOLOCK) ON C.ChargeID = CC.ChargeID
		AND C.IsActive = 1
		AND CC.IsActive = 1
	WHERE CC.CustomerID = @CustomerID
		AND CC.CategoryPlanID = @CarrierAccountID

	INSERT INTO @AddlOrderCharges
	SELECT 0
		,usoc
		,'One Time'
		,usoc + ' - ' + billDescription AS NAME
		,description
		,0.0 AS Cost
		,0.0 AS Margin
		,0.0 AS Price
		,CAST(0 AS BIT) IsCustom
		,2
	FROM BillingDB..usoc_master(NOLOCK)
	WHERE --vSuite = 2  AND   
		is_active = 1
		AND USOC IN (
			'WWACT'
			,'WWANFUL'
			,'WWANRTC'
			,'DWNPAY'
			,'MNKITTING'
			,'MNIOSUPD'
			,'MNEQUP_ACC'
			,'SHIP4FF'
			,'MNACTAPN'
			)
		AND USOC NOT IN (
			SELECT C.USOC
			FROM CustomerCharges cc(NOLOCK)
			JOIN Charges C(NOLOCK) ON C.ChargeID = CC.ChargeID
				AND C.IsActive = 1
				AND CC.IsActive = 1
			WHERE CC.CustomerID = @CustomerID
				AND CC.CategoryPlanID = @CarrierAccountID
			) --USOC NOT IN Added by Lokesh Gogineni on 05-Feb-2024  
		--UNION    
		--SELECT   0 ,  usoc,  'One Time', usoc + ' - ' + billDescription as name, description,    
		--0.0 as Cost, 0.0 as Margin, 0.0 as Price, CAST(0 as BIT) IsCustom, 2     
		--FRoM BillingDB..usoc_master    
		--WHERE vSuite = 1  AND is_active = 1  and usocType = 'I' -- TO DO: NEED to modify     
		--AND USOC IN ('WWANFUL', 'WWANRTC')    

	IF ISNULL(@DeviceVendorID, 0) = 0
	BEGIN
		INSERT INTO @AddlOrderCharges
		SELECT 0
			,FulfillmentUSOC
			,FulfillmentChargeType
			,FulfillmentUSOC + ' - ' + 'Fulfillment Fee' + ' - ' + FulfillmentVendorDescription
			,'Fulfillment Fee'
			,FulfillmentCost
			,FulfillmentMargin
			,FulfillmentPrice
			,CAST(1 AS BIT) IsCustom
			,1 AS SortOrder
		FROM @FulfillmentFees
	END
	ELSE
	BEGIN
		IF @CarrierID = 122
		BEGIN
			INSERT INTO @AddlOrderCharges
			SELECT 0
				,FulfillmentUSOC
				,FulfillmentChargeType
				,FulfillmentUSOC + ' - ' + 'Fulfillment Fee' + ' - ' + FulfillmentVendorDescription
				,'Fulfillment Fee'
				,FulfillmentCost
				,FulfillmentMargin
				,FulfillmentPrice
				,CAST(1 AS BIT) IsCustom
				,SortOrder
			FROM @FulfillmentFees
			WHERE FulfillmentVendorDescription IN (
					SELECT CASE 
							WHEN @DeviceVendorID = 100
								THEN 'AT&T-Apex'
							WHEN @DeviceVendorID = 600
								THEN 'Appogee'
							WHEN @DeviceVendorID = 200
								THEN 'CDW'
							WHEN @DeviceVendorID = 300
								THEN 'CSG'
							END
					)
		END
		ELSE IF @CarrierID = 178
		BEGIN
			INSERT INTO @AddlOrderCharges
			SELECT 0
				,FulfillmentUSOC
				,FulfillmentChargeType
				,FulfillmentUSOC + ' - ' + 'Fulfillment Fee' + ' - ' + FulfillmentVendorDescription
				,'Fulfillment Fee'
				,FulfillmentCost
				,FulfillmentMargin
				,FulfillmentPrice
				,CAST(1 AS BIT) IsCustom
				,SortOrder
			FROM @FulfillmentFees
			WHERE FulfillmentVendorDescription IN (
					SELECT CASE 
							WHEN @DeviceVendorID = 100
								THEN 'Verizon-Telespire'
							WHEN @DeviceVendorID = 600
								THEN 'Appogee'
							WHEN @DeviceVendorID = 200
								THEN 'CDW'
							WHEN @DeviceVendorID = 300
								THEN 'CSG'
							END
					)
		END
		ELSE IF @CarrierID = 229
		BEGIN
			INSERT INTO @AddlOrderCharges
			SELECT 0
				,FulfillmentUSOC
				,FulfillmentChargeType
				,FulfillmentUSOC + ' - ' + 'Fulfillment Fee' + ' - ' + FulfillmentVendorDescription
				,'Fulfillment Fee'
				,FulfillmentCost
				,FulfillmentMargin
				,FulfillmentPrice
				,CAST(1 AS BIT) IsCustom
				,SortOrder
			FROM @FulfillmentFees
			WHERE FulfillmentVendorDescription IN (
					SELECT CASE 
							WHEN @DeviceVendorID = 100
								THEN 'Webbing'
							WHEN @DeviceVendorID = 600
								THEN 'Appogee'
							WHEN @DeviceVendorID = 200
								THEN 'CDW'
							WHEN @DeviceVendorID = 300
								THEN 'CSG'
							END
					)
		END
		ELSE
		BEGIN
			INSERT INTO @AddlOrderCharges
			SELECT 0
				,FulfillmentUSOC
				,FulfillmentChargeType
				,FulfillmentUSOC + ' - ' + 'Fulfillment Fee' + ' - ' + FulfillmentVendorDescription
				,'Fulfillment Fee'
				,FulfillmentCost
				,FulfillmentMargin
				,FulfillmentPrice
				,CAST(1 AS BIT) IsCustom
				,SortOrder
			FROM @FulfillmentFees
			WHERE FulfillmentVendorDescription IN ('Carrier')
		END
	END

	IF @CarrierID IN (
			122
			,178
			,229
			)
	BEGIN
		SELECT *
		FROM @OtherOrderCharges
		WHERE USOC <> 'SHIP4F'
		
		UNION
		
		SELECT *
		FROM @AddlOrderCharges
		ORDER BY SortOrder
	END
	ELSE
	BEGIN
		SELECT *
		FROM @OtherOrderCharges
		
		UNION
		
		SELECT *
		FROM @AddlOrderCharges
		ORDER BY SortOrder
	END
END



SELECT * FROM users where user_id = 99999