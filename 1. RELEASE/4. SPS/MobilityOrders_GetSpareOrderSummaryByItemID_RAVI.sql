USE mobility
GO 

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================            
-- Author:  SP            
-- ALTER date: <ALTER Date,,>            
-- Description: <Description,,>            
-- =============================================   
-- Author:  Nagasai      
-- Modified date: 2021-01-26       
-- Description: device pricing category changes       
-- ============================================= 
-- Author:  Nagasai                            
-- ALTER date: 05-06-2021                           
-- Description:  added ibiller date
-- ============================================= 
-- Author:  Nagasai                            
-- ALTER date: 03-14-2022                           
-- Description: adding carrier account to spare summary
-- ============================================= 
-- Author:		Nagasai Mudara
-- ALTER date:  2022.05.20
-- Description:	removed sim charges which are added at item level
-- =============================================
-- Author:  Nagasai                              
-- ALTER date: 07-11-2022                             
-- Description: Spare ORDER GET for estimatedship date and requiredorderinfo
-- SD CASE : CASE - 1689 - Overhaul Mobile Order Notifications
-- =============================================
-- Author:  Nagasai Mudara  
-- Modified date: 02.09.2023
-- Description: Add Address 3 Field to Shipping Addresses
-- SD CASE - 5743
-- ================================================= 
-- Author:  Nagasai Mudara  
-- Modified date: 04.05.2023
-- Description: eSim Changes
-- SD CASE - 6533 - Add Support for eSIM (QuantumShift & vCom)
-- SD CASE - 6534 - Add Support for eSIM (vCom)
-- SD CASE - 6532 - Add Support for eSIM (QuantumShift) 
-- ================================================= 
-- =============================================
-- Altered By : Geethika Yedla 
-- Altered Date date: 10/10/2023 
-- Description: CaseID#9987 Order#105803 Spare Order issue
-- ================================================= 
-- Author:  AkhilM
-- Modified date: 2024-02-15
-- Description: Getting Vendor Name by Carrier and Vendor ID  SD -- 4686    
-- =============================================
-- Author:  Ravi Teja Yella
-- Modified date: 03/28/2024
-- Description: Moving IsActive condition for DeviceVendor to JOIN statement instead of at WHERE condition
-- =============================================

-- =============================================    
-- Altered By :  Geethika Yedla    
-- Altered date: 04/12/24    
-- Description: Replace Shipping Type Text   
-- SD Case: 11755 - QMobile Update "Next Day or Overnight" Shipping to "Expedited"     
-- =============================================  

-- EXEC [MobilityOrders_GetSpareOrderSummaryByItemID] 118610, 353914       
ALTER PROCEDURE [dbo].[MobilityOrders_GetSpareOrderSummaryByItemID] @MobilityOrderID INT,
	@MobilityOrderItemID INT
AS
BEGIN
	------------------- ITEM INFORMATION & STATUS INFORMATION --------------------------------  
	DECLARE @CustomerID INT,
		@CarrierAccountID INT
	DECLARE @addressID INT,
		@CarrierID INT,
		@AddrType VARCHAR(50),
		@IsRetail BIT

	SELECT @CarrierID = MO.CarrierID,
		@addressID = MOI.CustomerShippingAddressID,
		@AddrType = MOI.AddressRelType,
		@customerID = MO.CustomerID,
		@CarrierAccountID = MO.CarrierAccountID,
		@IsRetail = CASE 
			WHEN MCM.Channel = 'Retail'
				THEN 1
			ELSE 0
			END
	FROM MobilityOrderItems MOI(NOLOCK)
	INNER JOIN MobilityOrders MO(NOLOCK)
		ON MO.MobilityOrderID = MOI.MobilityOrderID
	INNER JOIN MobilityCarrierMaster MCM(NOLOCK)
		ON MCM.CarrierID = MO.CarrierID
	WHERE MobilityOrderItemID = @MobilityOrderItemID
		AND MOI.IsActive = 1

	DECLARE @AddrTable TABLE (
		AddressID INT,
		AttentionToName VARCHAR(200),
		Address1 VARCHAR(500),
		Address2 VARCHAR(500),
		Address3 VARCHAR(500),
		City VARCHAR(150),
		StateMasterID INT,
		Zipcode VARCHAR(10),
		CountryMasterID INT,
		StateName VARCHAR(200),
		CountryName VARCHAR(200),
		AddressRelType VARCHAR(1),
		AddressAccountID INT
		)

	IF (@AddrType = 'l')
	BEGIN
		INSERT INTO @AddrTable (
			AddressID,
			AttentionToName,
			Address1,
			Address2,
			Address3,
			City,
			StateMasterID,
			Zipcode,
			CountryMasterID,
			StateName,
			CountryName,
			AddressRelType,
			AddressAccountID
			)
		SELECT C.CustomerAddressID,
			ISNULL(location_name, '') AS AttentionToName,
			isnull(l.address_1, '') Address1,
			isnull(l.address_2, '') Address2,
			isnull(l.address3, '') Address3,
			isnull(l.city, '') City,
			S.StateMasterID,
			isnull(l.zip, '') Zipcode,
			Co.CountryMasterID,
			S.StateName,
			ISNULL(Co.CountryName, 'US'),
			ISNULL(RelType, '') AddressRelType,
			AccountID
		FROM CustomerAddress C(NOLOCK)
		INNER JOIN ipath..location l(NOLOCK)
			ON l.location_id = C.AccountID
				AND RelType = 'l'
		LEFT JOIN StateMaster S(NOLOCK)
			ON S.StateCode = l.STATE
		LEFT JOIN CountryMaster Co(NOLOCK)
			ON Co.CountryName = 'US'
		WHERE CustomerID = @customerID
			AND is_active = 1
			AND C.CustomerAddressID = @addressID
	END
	ELSE IF (@AddrType = 'a')
	BEGIN
		INSERT INTO @AddrTable (
			AddressID,
			AttentionToName,
			Address1,
			Address2,
			Address3,
			City,
			StateMasterID,
			Zipcode,
			CountryMasterID,
			StateName,
			CountryName,
			AddressRelType,
			AddressAccountID
			)
		SELECT C.CustomerAddressID,
			ISNULL(a.account_name, '') AS AttentionToName,
			isnull(a.address_1, '') Address1,
			isnull(a.address_2, '') Address2,
			isnull(a.address3, '') Address3,
			isnull(a.city, '') City,
			S.StateMasterID,
			isnull(a.zip, '') Zipcode,
			Co.CountryMasterID,
			S.StateName,
			ISNULL(Co.CountryName, 'US'),
			ISNULL(RelType, '') AddressRelType,
			AccountID
		FROM CustomerAddress C(NOLOCK)
		INNER JOIN ipath..Account a(NOLOCK)
			ON a.account_id = C.AccountID
				AND RelType = 'a'
		LEFT JOIN StateMaster S(NOLOCK)
			ON S.StateCode = a.STATE
		LEFT JOIN CountryMaster Co(NOLOCK)
			ON Co.CountryName = a.country
		WHERE CustomerID = @customerID
			AND a.STATUS = 'A'
			AND C.CustomerAddressID = @addressID
	END
	ELSE
	BEGIN
		INSERT INTO @AddrTable (
			AddressID,
			AttentionToName,
			Address1,
			Address2,
			Address3,
			City,
			StateMasterID,
			Zipcode,
			CountryMasterID,
			StateName,
			CountryName,
			AddressRelType,
			AddressAccountID
			)
		SELECT C.CustomerAddressID,
			ISNULL(C.AttentionToName, '') AS AttentionToName,
			C.Address1,
			C.Address2,
			C.Address3,
			C.City,
			S.StateMasterID,
			C.Zipcode,
			Co.CountryMasterID,
			S.StateName,
			ISNULL(Co.CountryName, 'US'),
			ISNULL(RelType, '') AddressRelType,
			ISNULL(AccountID, 0) AccountID
		FROM CustomerAddress C(NOLOCK)
		LEFT JOIN StateMaster S(NOLOCK)
			ON S.StateMasterID = C.StateMasterID
		LEFT JOIN CountryMaster Co(NOLOCK)
			ON Co.CountryMasterID = C.CountryMasterID
		WHERE CustomerID = @CustomerID
			AND C.IsActive = 1
			AND AccountID IS NULL
			AND C.CustomerAddressID = @addressID
	END

	---------------- HEADER INFORMATION ----------------------------------   
	SELECT DISTINCT MOXD.MobilityOrderID,
		MOXD.MobilityOrderItemID,
		DeviceType,
		ModelName,
		PriceCategory,
		COUNT(*) AS Quantity,
		SUM(PlanCost) AS Cost,
		PlanMargin AS Margin,
		SUM(PlanPrice) Price,
		CAST(SUM(PlanCost) / COUNT(*) AS DECIMAL(38, 2)) AS PerDeviceCost,
		CAST(SUM(PlanPrice) / COUNT(*) AS DECIMAL(38, 2)) AS PerDevicePrice,
		IsInstallmentPlan,
		PlanMonths AS Tenure,
		DownPayment,
		ROIOnCost,
		ROIOnPrice,
		--dbo.uspGetPricingCategoryID(MOXD.PlanPrice) DevicePricingCategoryMasterID,
		(
			CASE 
				WHEN (ISNULL(sp.SpecialPrice, 0) > 0)
					AND sp.PriceExpiryDate > GETDATE()
					AND BillingEntityID = - 1
					THEN dbo.uspGetPricingCategoryID(ISNULL(NULLIF(sp.SpecialPrice, 0), DxC.Price))
				WHEN (ISNULL(sp.SpecialPrice, 0) > 0)
					AND BillingEntityID > 1
					THEN dbo.uspGetPricingCategoryID(ISNULL(NULLIF(sp.SpecialPrice, 0), DxC.Price))
				ELSE dbo.uspGetPricingCategoryID(DxC.Price)
				END
			) AS DevicePricingCategoryMasterID,
		D.DeviceID,
		DTM.DeviceTypeMasterID,
		MOI.LineStatusMasterID,
		MOI.LineSubStatusMasterID,
		LineStatus,
		LineSubStatus,
		MO.CustomerID,
		MO.CarrierID,
		CPC.CustomerXProductCatalogID,
		CPC.USOC,
		CPC.Description,
		CPC.ChargeType,
		MOI.CustomerShippingAddressID,
		MOI.ShippingTypeID,
		(
			SELECT SUM(Price * Quantity)
			FROM MobilityOrderCharges(NOLOCK)
			WHERE MobilityOrderID = @MobilityOrderID
				AND MobilityOrderItemID = MOXD.MobilityOrderItemID
				AND IsActive = 1
				AND ChargeType = 'Monthly'
			) MRC,
		(
			SELECT SUM(Price * Quantity) + ISNULL((
						SELECT SUM(Price)
						FROM MobilityOrderCharges(NOLOCK)
						WHERE MobilityOrderID = @MobilityOrderID
							AND MobilityOrderItemID = MOXD.MobilityOrderItemID
							AND IsActive = 1
							AND ChargeType = 'One Time'
							AND USOC IN (
								'MNSIM',
								'WWSIM'
								)
						), 0)
			FROM MobilityOrderCharges(NOLOCK)
			WHERE MobilityOrderID = @MobilityOrderID
				AND MobilityOrderItemID = MOXD.MobilityOrderItemID
				AND IsActive = 1
				AND ChargeType = 'One Time'
				AND USOC NOT IN (
					'MNSIM',
					'WWSIM'
					)
			) NRC,
		D.HasESN,
		MO.OrderReferenceNumber,
		Coalesce(MOI.AttentionToName, isnull(CUSTA.AttentionToName, '')) AttentionToName,
		CUSTA.Address1 AS ShippingAddress1,
		CUSTA.Address2 AS ShippingAddress2,
		CUSTA.Address3 AS ShippingAddress3,
		CUSTA.City AS ShippingCity,
		CUSTA.StateName AS ShippingStateName,
		CUSTA.ZipCode AS ShippingZipCode,
		CUSTA.CountryName AS ShippingCountryName,
		CASE 
			WHEN @IsRetail = 0
				AND MOI.ShippingTypeID = 3
				THEN 'Expedited'
			ELSE STM.ShippingType
			END ShippingType, -- AlteredBy: GY Dated: 03/21/2024 CaseID#11755  		,LSM.LineStatus
		LSSM.LineSubStatus,
		MOI.TrackingNumber,
		OTM.OrderTypeMasterID,
		OTM.OrderType,
		MO.AccountID,
		A.account_name,
		MO.TicketReferenceNumber,
		HasPreOrder = CASE 
			WHEN DXC.DeviceStatusID = 400
				OR DXC.DeviceStatusID = 300
				THEN CAST(1 AS BIT)
			ELSE CAST(0 AS BIT)
			END,
		DXC.PreOrderEnddate,
		MOI.ContractStartDate,
		MOI.ContractEndDate,
		MOI.TermMasterID,
		MOI.AppleID,
		CASE 
			WHEN MCM.Channel = 'Retail'
				THEN 1
			ELSE 0
			END AS IsRetail,
		TM.Term AS ContractTerm,
		MOI.ShipDate,
		EST.IsEquipmentReady,
		MOI.ShippingVendor,
		CUSTA.AddressRelType,
		CUSTA.AddressAccountID,
		MOI.UserFirstName,
		MOI.UserLastName,
		MOI.UserTitle,
		MOI.UserEmail,
		MOI.CopyEndUser,
		MOXD.DeviceXCarrierID,
		MOXD.DeviceConditionID,
		MOXD.DeviceVendorID,
		MOXD.SpecialPrice,
		MOXD.HasSpecialPrice,
		dbo.GetDeviceVendorByCarrier(MOXD.DeviceVendorID, MO.CarrierID) AS VendorName -- AddedBy AkhilM as per case 4686
		--,DV.VendorName -- CommentedBy AkhilM as per case 4686
		,
		DCC.ConditionName,
		MOI.iBillerDate,
		MOCA.HasCharged,
		CASE 
			WHEN dbo.MobilityCharges_IsEquipmentReady(ISNULL(@MobilityOrderItemID, 0)) = 1
				THEN 1
			ELSE 0
			END AS IsEquipmentCharged,
		MO.CarrierAccountID,
		CASE 
			WHEN isnull(caa.AccountName, '') = ''
				THEN caa.AccountFAN + ' - ' + caa.AccountBAN
			ELSE caa.AccountName
			END AS CarrierAccountName,
		MO.CustomerXCarrierAccountsID,
		MOI.EstimatedShipDate,
		CAST(MOI.RequiredOrderInfo AS VARCHAR(MAX)) RequiredOrderInfo
	FROM MobilityOrderXDevices MOXD(NOLOCK)
	INNER JOIN MobilityOrders MO(NOLOCK)
		ON MO.MobilityOrderID = MOXD.MobilityOrderID
	INNER JOIN MobilityCarrierMaster MCM(NOLOCK)
		ON MCM.CarrierID = MO.CarrierID
	INNER JOIN OrderTypeMaster OTM(NOLOCK)
		ON OTM.OrderTypeMasterID = MO.OrderTypeID
	INNER JOIN account A(NOLOCK)
		ON A.account_id = MO.accountID
	INNER JOIN MobilityOrderItems MOI(NOLOCK)
		ON MOI.MobilityOrderItemID = MOXD.MobilityOrderItemID
	INNER JOIN LineStatusMaster LSM(NOLOCK)
		ON LSM.LineStatusMasterID = MOI.LineStatusMasterID
	LEFT JOIN LineSubStatusMaster LSSM(NOLOCK)
		ON LSSM.LineSubStatusMasterID = MOI.LineSubStatusMasterID
	LEFT JOIN TermMaster TM(NOLOCK)
		ON TM.TermMasterID = MOI.TermMasterID
	INNER JOIN Devices D(NOLOCK)
		ON D.DeviceID = MOXD.DeviceID
	LEFT JOIN CustomerXCarrierAccounts caa(NOLOCK)
		ON caa.CarrierAccountID = MO.CarrierAccountID
			AND MO.CustomerID = caa.CustomerID
	--INNER JOIN DeviceXCarrier DXC on DXC.CarrierID = MO.CarrierID AND DXC.DeviceID = MOXD.DeviceID
	LEFT JOIN DeviceXCarrier DxC(NOLOCK)
		ON DxC.DeviceID = MOXD.DeviceID
			AND DXC.CarrierID = MO.CarrierID
			AND DXC.DeviceVendorID = ISNULL(NULLIF(MOXD.DeviceVendorID, 0), 100)
			AND DXC.DeviceConditionID = ISNULL(NULLIF(MOXD.DeviceConditionID, 0), 100)
	LEFT JOIN CustomerXDeviceSpecialPrice sp(NOLOCK)
		ON sp.DeviceXCarrierID = DxC.DeviceXCarrierID
			AND sp.CustomerID = MO.CustomerID
			AND sp.IsActive = 1
	INNER JOIN DeviceTypeMaster DTM(NOLOCK)
		ON DTM.DeviceTypeMasterID = D.DeviceTypesMasterID
	INNER JOIN DevicePricingCategoryMaster DPCM(NOLOCK)
		ON DPCM.DevicePricingCategoryMasterID = -- dbo.uspGetPricingCategoryID(MOXD.PlanPrice)--D.DevicePricingCategoryMasterID            
			(
				CASE 
					WHEN (ISNULL(sp.SpecialPrice, 0) > 0)
						AND sp.PriceExpiryDate > GETDATE()
						AND BillingEntityID = - 1
						THEN dbo.uspGetPricingCategoryID(ISNULL(NULLIF(sp.SpecialPrice, 0), DxC.Price))
					WHEN (ISNULL(sp.SpecialPrice, 0) > 0)
						AND BillingEntityID > 1
						THEN dbo.uspGetPricingCategoryID(ISNULL(NULLIF(sp.SpecialPrice, 0), DxC.Price))
					ELSE dbo.uspGetPricingCategoryID(DxC.Price)
					END
				)
	INNER JOIN CustomerXProductCatalog CPC(NOLOCK)
		ON CPC.CategoryPlanID = D.DeviceID
			AND CPC.ProductCatalogCategoryMasterID = 5
			AND CPC.CustomerID = MO.CustomerID
			AND ISNULL(CPC.CarrierID, MO.CarrierID) = MO.CarrierID
			AND cpc.isDeleted = 0 -- Added By: GY CaseID#9987
			--INNER JOIN DeviceXCarrier DC ON DC.DeviceID = D.DeviceID and DC.CarrierID =CPC.CarrierID    
	LEFT JOIN DeviceCondition DCC(NOLOCK)
		ON DCC.DeviceConditionID = MOXD.DeviceConditionID
	LEFT JOIN DeviceVendor DV(NOLOCK)
		ON DV.DeviceVendorID = MOXD.DeviceVendorID
			AND DV.IsActive = 1 -- AddedBy AkhilM as per case 4686
	LEFT JOIN @AddrTable CUSTA
		ON CUSTA.AddressID = MOI.CustomerShippingAddressID
	LEFT JOIN (
		SELECT (
				CASE 
					WHEN count(*) >= 1
						THEN 1
					ELSE 0
					END
				) AS IsEquipmentReady,
			MOI.MobilityOrderID
		FROM MobilityOrderItemHistory MOIH(NOLOCK)
		INNER JOIN MobilityOrderItems MOI(NOLOCK)
			ON MOI.MobilityOrderItemID = MOIH.MobilityOrderItemID
		WHERE MOIH.MobilityOrderItemID = ISNULL(@MobilityOrderItemID, MOIH.MobilityOrderItemID)
			AND ChangeTo = 'Equipment Shipped'
		GROUP BY MOI.MobilityOrderID
		) AS EST
		ON EST.MobilityOrderID = MO.MobilityOrderID
	LEFT JOIN ShippingTypeMaster STM(NOLOCK)
		ON STM.ShippingTypeMasterID = MOI.ShippingTypeID
	LEFT JOIN (
		SELECT TOP 1 CASE 
				WHEN ISNULL(MOC.HasCharged, 0) = 2
					THEN 1
				ELSE 0
				END HasCharged,
			MOI.MobilityOrderItemID
		FROM MobilityOrderCharges MOC(NOLOCK)
		INNER JOIN MobilityOrderItems MOI(NOLOCK)
			ON MOI.MobilityOrderItemID = MOC.MobilityOrderItemID
		WHERE MOI.IsActive = 1
			AND MOC.IsActive = 1
			--AND MOI.LineStatusMasterID = 5051
			AND MOC.ProductCatalogCategoryMasterID IN (
				0,
				5
				)
			AND MOI.MobilityOrderItemID = ISNULL(@MobilityOrderItemID, 0)
		) MOCA
		ON MOCA.MobilityOrderItemID = MOI.MobilityOrderItemID
	WHERE MOXD.MobilityOrderItemID = @MobilityOrderItemID
	GROUP BY MOXD.MobilityOrderID,
		MOXD.MobilityOrderItemID,
		DeviceType,
		ModelName,
		PriceCategory,
		IsInstallmentPlan,
		PlanMonths,
		PlanMargin,
		DownPayment,
		ROIOnCost,
		ROIOnPrice,
		(
			CASE 
				WHEN (ISNULL(sp.SpecialPrice, 0) > 0)
					AND sp.PriceExpiryDate > GETDATE()
					AND BillingEntityID = - 1
					THEN dbo.uspGetPricingCategoryID(ISNULL(NULLIF(sp.SpecialPrice, 0), DxC.Price))
				WHEN (ISNULL(sp.SpecialPrice, 0) > 0)
					AND BillingEntityID > 1
					THEN dbo.uspGetPricingCategoryID(ISNULL(NULLIF(sp.SpecialPrice, 0), DxC.Price))
				ELSE dbo.uspGetPricingCategoryID(DxC.Price)
				END
			),
		D.DeviceID,
		DTM.DeviceTypeMasterID,
		MOI.LineStatusMasterID,
		MOI.LineSubStatusMasterID,
		LineStatus,
		LineSubStatus,
		MO.CustomerID,
		MO.CarrierID,
		CPC.CustomerXProductCatalogID,
		CPC.USOC,
		CPC.Description,
		CPC.ChargeType,
		MOI.CustomerShippingAddressID,
		MOI.ShippingTypeID,
		D.HasESN,
		MO.OrderReferenceNumber,
		CUSTA.AttentionToName,
		CUSTA.Address1,
		CUSTA.Address2,
		CUSTA.Address3,
		CUSTA.City,
		CUSTA.StateName,
		CUSTA.ZipCode,
		CUSTA.CountryName,
		STM.ShippingType,
		LSM.LineStatus,
		LSSM.LineSubStatus,
		MOI.TrackingNumber,
		OTM.OrderTypeMasterID,
		OTM.OrderType,
		MO.AccountID,
		A.account_name,
		MO.TicketReferenceNumber,
		CASE 
			WHEN DXC.DeviceStatusID = 400
				OR DXC.DeviceStatusID = 300
				THEN CAST(1 AS BIT)
			ELSE CAST(0 AS BIT)
			END,
		DXC.PreOrderEnddate,
		MOI.ContractStartDate,
		MOI.ContractEndDate,
		MOI.TermMasterID,
		MOI.AppleID,
		MCM.Channel,
		TM.Term,
		MOI.ShipDate,
		EST.IsEquipmentReady,
		MOI.ShippingVendor,
		CUSTA.AddressRelType,
		CUSTA.AddressAccountID,
		MOI.UserFirstName,
		MOI.UserLastName,
		MOI.UserTitle,
		MOI.UserEmail,
		MOI.CopyEndUser,
		MOI.AttentionToName,
		MOXD.DeviceXCarrierID,
		MOXD.DeviceConditionID,
		MOXD.DeviceVendorID,
		MOXD.SpecialPrice,
		MOXD.HasSpecialPrice,
		VendorName,
		DCC.ConditionName,
		MOI.iBillerDate,
		MOCA.HasCharged,
		MO.CarrierAccountID,
		CASE 
			WHEN isnull(caa.AccountName, '') = ''
				THEN caa.AccountFAN + ' - ' + caa.AccountBAN
			ELSE caa.AccountName
			END,
		MO.CustomerXCarrierAccountsID,
		MOI.EstimatedShipDate,
		CAST(MOI.RequiredOrderInfo AS VARCHAR(MAX))

	---------------- DEVICE INFORMATION ----------------------------------            
	SELECT DISTINCT MOXD.MobilityOrderXDeviceID,
		MOXD.DeviceID,
		InventoryDeviceRelID,
		EquipmentInventoryID,
		IMEI,
		ESN,
		ICCID,
		SIM,
		IsExistingSIM,
		COALESCE(DeviceProvider, dbo.GetDeviceVendorByCarrier(ISNULL(NULLIF(MOXD.DeviceVendorID, 0), 100), @CarrierID)) AS DeviceProvider -- ModifiedBY AkhilM as per case 4686
		,
		MOXD.DeviceSellerID,
		MOXD.DeviceWarrantyTypeMasterID,
		MOXD.DeviceWarrantyTermMasterID,
		InvoiceNumber,
		D.ModelName,
		DTM.DeviceType,
		DTM.DeviceTypeMasterID,
		-- dbo.uspGetPricingCategoryID(MOXD.PlanPrice) DevicePricingCategoryMasterID, 
		(
			CASE 
				WHEN (ISNULL(sp.SpecialPrice, 0) > 0)
					AND sp.PriceExpiryDate > GETDATE()
					AND BillingEntityID = - 1
					THEN dbo.uspGetPricingCategoryID(ISNULL(NULLIF(sp.SpecialPrice, 0), DxC.Price))
				WHEN (ISNULL(sp.SpecialPrice, 0) > 0)
					AND BillingEntityID > 1
					THEN dbo.uspGetPricingCategoryID(ISNULL(NULLIF(sp.SpecialPrice, 0), DxC.Price))
				ELSE dbo.uspGetPricingCategoryID(DxC.Price)
				END
			) AS DevicePricingCategoryMasterID,
		PriceCategory,
		MOXD.MobilityOrderID,
		MOXD.MobilityOrderItemID,
		D.HasESN,
		DWTM.WarrantyTerm,
		DWTM.[Days] AS WarrantyDays,
		DS.SellerName,
		DWTyM.DeviceWarrantyType,
		DXC.Cost AS PlanCost,
		DXC.Margin AS PlanMargin,
		DXC.Price AS PlanPrice,
		MOXD.DeviceXCarrierID,
		MOXD.DeviceConditionID,
		MOXD.DeviceVendorID,
		MOXD.SpecialPrice,
		MOXD.HasSpecialPrice,
		dbo.GetDeviceVendorByCarrier(MOXD.DeviceVendorID, MO.CarrierID) AS VendorName -- AddedBy AkhilM as per case 4686
		--,DV.VendorName -- CommentedBy AkhilM as per case 4686
		,
		DC.ConditionName,
		DTM.ServiceID,
		MOXD.IMEI2,
		MOXD.eSim,
		MOXD.IseSimSelected,
		D.HaseSim,
		D.eSimOnly
	FROM MobilityOrderXDevices MOXD(NOLOCK)
	INNER JOIN MobilityOrders MO(NOLOCK)
		ON MO.MobilityOrderID = MOXD.MobilityOrderID
	INNER JOIN MobilityCarrierMaster MCM(NOLOCK)
		ON MCM.CarrierID = MO.CarrierID
	INNER JOIN Devices D(NOLOCK)
		ON D.DeviceID = MOXD.DeviceID
	INNER JOIN CustomerXProductCatalog CPC(NOLOCK)
		ON CPC.CategoryPlanID = MOXD.DeviceID
			AND CPC.ProductCatalogCategoryMasterID = 5
			AND CPC.CustomerID = @customerID
			AND CPC.CarrierID = @CarrierID
	INNER JOIN DeviceTypeMaster DTM(NOLOCK)
		ON DTM.DeviceTypeMasterID = D.DeviceTypesMasterID
	--INNER JOIN DeviceXCarrier DXC on DXC.CarrierID = MO.CarrierID AND DXC.DeviceID = MOXD.DeviceID
	LEFT JOIN DeviceXCarrier DxC(NOLOCK)
		ON DxC.DeviceID = MOXD.DeviceID
			AND DXC.CarrierID = MO.CarrierID
			AND DXC.DeviceVendorID = ISNULL(NULLIF(MOXD.DeviceVendorID, 0), 100)
			AND DXC.DeviceConditionID = ISNULL(NULLIF(MOXD.DeviceConditionID, 0), 100)
	LEFT JOIN CustomerXDeviceSpecialPrice sp(NOLOCK)
		ON sp.DeviceXCarrierID = DxC.DeviceXCarrierID
			AND sp.CustomerID = MO.CustomerID
			AND sp.IsActive = 1
	INNER JOIN DevicePricingCategoryMaster DPCM(NOLOCK)
		ON DPCM.DevicePricingCategoryMasterID = --dbo.uspGetPricingCategoryID(MOXD.PlanPrice)-- D.DevicePricingCategoryMasterID            
			(
				CASE 
					WHEN (ISNULL(sp.SpecialPrice, 0) > 0)
						AND sp.PriceExpiryDate > GETDATE()
						AND BillingEntityID = - 1
						THEN dbo.uspGetPricingCategoryID(ISNULL(NULLIF(sp.SpecialPrice, 0), DxC.Price))
					WHEN (ISNULL(sp.SpecialPrice, 0) > 0)
						AND BillingEntityID > 1
						THEN dbo.uspGetPricingCategoryID(ISNULL(NULLIF(sp.SpecialPrice, 0), DxC.Price))
					ELSE dbo.uspGetPricingCategoryID(DxC.Price)
					END
				)
	LEFT JOIN DeviceWarrantyTermMaster DWTM(NOLOCK)
		ON DWTM.DeviceWarrantyTermMasterID = MOXD.DeviceWarrantyTermMasterID
	LEFT JOIN DeviceSellers DS(NOLOCK)
		ON DS.DeviceSellerID = MOXD.DeviceSellerID
	LEFT JOIN DeviceWarrantyTypeMaster DWTyM(NOLOCK)
		ON DWTyM.DeviceWarrantyTypeMasterID = MOXD.DeviceWarrantyTypeMasterID
	LEFT JOIN DeviceCondition DC(NOLOCK)
		ON DC.DeviceConditionID = MOXD.DeviceConditionID
	LEFT JOIN DeviceVendor DV(NOLOCK)
		ON DV.DeviceVendorID = MOXD.DeviceVendorID
			AND DV.IsActive = 1 -- AddedBy AkhilM as per case 4686
	WHERE MobilityOrderItemID = @MobilityOrderItemID

	------------------- CHARGES INFORMATION  -------------------            
	SELECT MO.MobilityOrderChargeID,
		MO.USOC,
		MO.ChargeDescription,
		MO.ChargeType,
		TimesToBill,
		MO.Cost,
		MO.Margin,
		MO.Price,
		MO.Quantity,
		1 SortOrder,
		MO.CustomerXProductCatalogID,
		MO.IsActive,
		MO.CategoryPlanID,
		MO.ProductCatalogCategoryMasterID,
		ISNULL(MO.HasCharged, 0) HasCharged,
		CASE 
			WHEN ISNULL(MO.HasCharged, 0) = 2
				THEN 'Billed'
			ELSE ''
			END EquipmentCharge
	FROM MobilityOrderCharges MO(NOLOCK)
	WHERE (MobilityOrderItemID = @MobilityOrderItemID)
		AND MO.IsActive = 1

	--UNION          
	-- SELECT  MO.MobilityOrderChargeID, MO.USOC, MO.ChargeDescription, MO.ChargeType,            
	--    TimesToBill,            
	--    MO.Cost, MO.Margin, MO.Price, MO.Quantity, 1 SortOrder, MO.CustomerXProductCatalogID, MO.IsActive ,            
	--   MO.CategoryPlanID, MO.ProductCatalogCategoryMasterID,
	--ISNULL(MO.HasCharged,0) HasCharged , CASE WHEN ISNULL(MO.HasCharged,0) = 2 THEN 'Billed' ELSE '' END EquipmentCharge
	--   FROM MobilityOrderCharges MO  (NOLOCK)             
	--WHERE MobilityOrderID = @MobilityOrderID AND CategoryPlanID = 0     
	--AND (isnuLL(MobilityOrderItemID, 0) = 0)
	-- AND  MO.IsActive = 1          
	----------------- Order Task Information --------------------------------              
	SELECT --*,          
		--OrderItemTaskId,            
		t.Task_ID AS TaskID,
		t.type AS TaskType,
		t.Priority AS TaskPriority,
		tot.stage AS TaskStage,
		tot.age TaskAge,
		tot.OWNER AS TaskOwner
	FROM MobilityOrderItemsTask oit(NOLOCK)
	INNER JOIN MobilityOrders MO(NOLOCK)
		ON MO.MobilityORderID = OIT.MobilityORderID
	INNER JOIN MobilityCarrierMaster MCM(NOLOCK)
		ON MCM.CarrierID = MO.CarrierID
	LEFT JOIN iPath..task t(NOLOCK)
		ON t.task_id = oit.task_id
	LEFT JOIN ipath..tot_summary tot(NOLOCK)
		ON tot.target_id = t.task_id
	WHERE tot.target_type = CASE 
			WHEN MCM.Channel = 'Retail'
				THEN 'vTask'
			ELSE 'qTask'
			END -- and t.is_active = 1          
		AND OIT.MobilityOrderID = @MobilityOrderID
		AND OIT.MobilityOrderItemId = @MobilityOrderItemID
END
GO
