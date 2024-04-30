USE mobility
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author: Ravi Teja Yella
-- Create date: 03/26/2024
-- Description:	Moved unused devices from vCom Store to Customer Spare after inventory period
-- =============================================
CREATE PROCEDURE [dbo].[CustomerCarrierAccounts_SpareOrdersForUnusedDevices]
AS
BEGIN
	BEGIN TRY
		SET NOCOUNT ON;

		-- Check for devices in all MI for all Customers
		-- For those devices, check if they exist in store with same Customer (even if CCAID is null but Customer has MI) and above inventory period
		-- Create Spare Orders for that customer AND matching CCAID (if exists) or TOP 1 CCAID with MI (if not exists)
		-- Auto complete these Spare Orders (add them to customer Spare Inventory)
		-- Remove items from Store (adding MobilityOrderID & MobilityOrderItemID)

		DECLARE @OrderTypeID INT
			,@IsRetail BIT = 0 -- Only QS has managed Inventory
			,@RequestorID INT = - 5 -- Inventory Management (hardcoded in API)
			,@AddedByID INT = 99999 -- System User

		SELECT TOP 1 @OrderTypeID = OrderTypeMasterID
		FROM OrderTypeMaster(NOLOCK)
		WHERE OrderType = 'Spare'

		DECLARE @MoveUnUsedDevicesFromStore TABLE (
			CustomerID INT
			,CustomerXCarrierAccountsID INT
			,DeviceID INT
			,UnUsedDeviceCount INT
			,EquipmentInventoryIDs VARCHAR(200)
			,DEPValue VARCHAR(50)
			,DeviceConditionID INT
			,InventoryPeriod VARCHAR(50)
			)

		INSERT INTO @MoveUnUsedDevicesFromStore (
			CustomerID
			,CustomerXCarrierAccountsID
			,DeviceID
			,UnUsedDeviceCount
			,EquipmentInventoryIDs
			,DEPValue
			,DeviceConditionID
			,InventoryPeriod
			)
		SELECT mica.CustomerID AS CustomerID
			,cca.CustomerXCarrierAccountsID AS CustomerXCarrierAccountsID
			,mica.DeviceID AS DeviceID
			,COUNT(*) AS UnUsedDeviceCount
			,STRING_AGG(CAST(ei.EquipmentInventoryMasterID AS VARCHAR(100)), '|') AS EquipmentInventoryIDs
			,ei.DEPValue
			,100 --ei.DeviceConditionID
			,ISNULL(cca.InventoryPeriod, '0 days')
		FROM ManagedInventoryXCarrierAccounts mica(NOLOCK)
		INNER JOIN CustomerXCarrierAccounts cca(NOLOCK) ON mica.CustomerXCarrierAccountsID = cca.CustomerXCarrierAccountsID
		INNER JOIN EquipmentInventory ei(NOLOCK) ON ei.DeviceID = mica.DeviceID
			AND ISNULL(ei.CustomerID, 0) = mica.CustomerID
			AND ISNULL(mica.CustomerXCarrierAccountsID, 0) = ISNULL(ei.CustomerXCarrierAccountsID, 0)
			AND ISNULL(ei.MobilityOrderID, 0) = 0
			AND ISNULL(ei.MobilityOrderItemID, 0) = 0
		WHERE mica.IsActive = 1
			AND cca.IsActive = 1
			AND ISNULL(cca.IsManagedInventory, 0) <> 0
			AND ei.EquipmentPurchasedDate IS NOT NULL
			AND GETDATE() > DATEADD(day, CAST(RTRIM(LTRIM(substring(cca.InventoryPeriod, 1, 3))) AS INT), CAST(ei.EquipmentPurchasedDate AS DATE))
		GROUP BY mica.CustomerID
			,mica.DeviceID
			,cca.CustomerXCarrierAccountsID
			,ei.DEPValue
			,ei.DeviceConditionID
			,cca.InventoryPeriod

		SELECT '@MoveUnUsedDevicesFromStore'
			,*
		FROM @MoveUnUsedDevicesFromStore -- REMOVE

		IF EXISTS (
				SELECT 1
				FROM @MoveUnUsedDevicesFromStore
				WHERE UnUsedDeviceCount > 0
				)
		BEGIN
			IF CURSOR_STATUS('global', 'SpareOrderInfoCursor') >= 0
			BEGIN
				CLOSE SpareOrderInfoCursor;

				DEALLOCATE SpareOrderInfoCursor;
			END

			

			DECLARE @CustomerID INT
				,@CustomerXCarrierAccountsID INT
				,@DeviceID INT
				,@DeviceCount INT
				,@CarrierID INT
				,@CarrierAccountID INT
				,@EquipmentInventoryIDs VARCHAR(100)
				,@DEPValue VARCHAR(50)
				,@InventoryPeriod VARCHAR(50)
				,@DeviceConditionID INT

			DECLARE SpareOrderInfoCursor CURSOR
			FOR
			SELECT mud.*
				,cca.CarrierID
				,cca.CarrierAccountID
			FROM @MoveUnUsedDevicesFromStore mud
			JOIN CustomerXCarrierAccounts cca(NOLOCK) ON cca.CustomerXCarrierAccountsID = mud.CustomerXCarrierAccountsID
			WHERE cca.IsActive = 1

			OPEN SpareOrderInfoCursor

			FETCH NEXT
			FROM SpareOrderInfoCursor
			INTO @CustomerID
				,@CustomerXCarrierAccountsID
				,@DeviceID
				,@DeviceCount
				,@EquipmentInventoryIDs
				,@DEPValue
				,@DeviceConditionID
				,@InventoryPeriod
				,@CarrierID
				,@CarrierAccountID

			WHILE @@FETCH_STATUS = 0
			BEGIN
				SELECT @CustomerID -- REMOVE
					,@CustomerXCarrierAccountsID
					,@DeviceID
					,@DeviceCount
					,@EquipmentInventoryIDs
					,@DEPValue
					,@DeviceConditionID
					,@InventoryPeriod
					,@CarrierID
					,@CarrierAccountID

				DECLARE @MobilityOrderID INT
					,@MobilityOrderItemID INT
					,@LineStatusMasterID INT = 1001 -- ASSIGNED
					,@LineSubStatusMasterID INT = NULL
				
				-- DEVICE VALUES variables
				DECLARE @Devices TABLE (
					MobilityOrderXDeviceID INT
					,DeviceID INT
					,DeviceXCarrierID INT
					,DeviceConditionID INT
					,DeviceVendorID INT
					,InventoryDeviceRelID INT
					,EquipmentInventoryID INT
					,IMEI VARCHAR(50)
					,ESN VARCHAR(50)
                    ,ICCID VARCHAR(100)
					,DeviceProvider VARCHAR(150)
					,DeviceSellerID INT
					,DeviceWarrantyTypeMasterID INT
					,DeviceWarrantyTermMasterID INT
					,InvoiceNumber VARCHAR(100)
					,IMEI2 VARCHAR(100)
					,eSIM VARCHAR(100)
					,IseSimSelected BIT
					,DEPValue VARCHAR(150)
					
					-- PRICING 
					,Cost DECIMAL(18, 2) NULL
					,Margin DECIMAL(18, 2) NULL
					,Price DECIMAL(18, 2) NULL
					)

				-- DECLARE Shipping variables
				DECLARE @AccountID INT
					,@ExistingShippingAddressID INT
					,@AttentionToName VARCHAR(10) = 'N/A'
					,@Address1 VARCHAR(MAX)
					,@Address2 VARCHAR(MAX)
					,@Address3 VARCHAR(100) = ''
					,@City VARCHAR(100)
					,@StateMasterID INT
					,@Zipcode VARCHAR(10)
					,@CountryMasterID INT = 1
					,@ShippingTypeID INT = 1

				-- CHECK for DEPValue
				IF ISNULL(@DEPValue, '') = ''
				BEGIN
					SELECT TOP 1 @DEPValue = DEPValue
					FROM CarrierAccounts (NOLOCK)
					WHERE CarrierAccountID = @CarrierAccountID
				END

				-- GET DEVICE VALUES
				DELETE
				FROM @Devices -- CLEAR existing

				-- GET Default Vendor for a carrier
				DECLARE @DefaultDeviceVendorID INT
				SELECT TOP 1 @DefaultDeviceVendorID = CASE 
						WHEN EXISTS (
								SELECT 1
								FROM DeviceXCarrier (NOLOCK)
								WHERE DeviceID = @DeviceID
									AND CarrierID IN (
										122
										,229
										)
								)
							THEN 100
						WHEN EXISTS (
								SELECT 1
								FROM DeviceXCarrier dc (NOLOCK)
								JOIN Devices d ON dc.DeviceID = d.DeviceID
								WHERE dc.DeviceID = @DeviceID
									AND dc.CarrierID = 178
									AND d.Make <> 'Apple'
								)
							THEN 100
						WHEN EXISTS (
								SELECT 1
								FROM DeviceXCarrier dc (NOLOCK)
								JOIN Devices d ON dc.DeviceID = d.DeviceID
								WHERE dc.DeviceID = @DeviceID
									AND dc.CarrierID = 178
									AND d.Make = 'Apple'
								)
							THEN 600
						ELSE (
								SELECT TOP 1 DeviceVendorID
								FROM DeviceXCarrier (NOLOCK)
								WHERE DeviceID = @DeviceID
								ORDER BY Margin DESC
									,AddedDateTime DESC
								)
						END
 
				SELECT @DefaultDeviceVendorID AS '@DefaultDeviceVendorID'	-- REMOVE

				IF NOT EXISTS (
					SELECT TOP 1 1 FROM DeviceXCarrier (NOLOCK)
					WHERE DeviceID = @DeviceID
						AND CarrierID = @CarrierID
						AND DeviceVendorID = @DefaultDeviceVendorID
						AND DeviceConditionID = @DeviceConditionID
				)
				BEGIN
					SELECT TOP 1 @DefaultDeviceVendorID = DeviceVendorID
					FROM DeviceXCarrier (NOLOCK)
					WHERE DeviceID = @DeviceID
						AND CarrierID = @CarrierID	
						AND DeviceConditionID = @DeviceConditionID 
					ORDER BY Margin DESC
				END

				INSERT INTO @Devices
				SELECT NULL AS MobilityOrderXDeviceID
					,@DeviceID
					,ei.DeviceXCarrierID
					,100 -- ei.DeviceConditionID
					,@DefaultDeviceVendorID AS DeviceVendorID
					,NULL AS InventoryDeviceRelID
					,ei.EquipmentInventoryMasterID AS EquipmentInventoryID
					,ei.MEID AS IMEI
					,ei.ESN AS ESN
                    ,ei.ICCID AS ICCID
					,ISNULL(fv.FulfillmentVendor, 'vCom') AS DeviceProvider
					,ei.DeviceSellerID AS DeviceSellerID
					,ei.DeviceWarrantyTypeMasterID AS DeviceWarrantyTypeMasterID
					,ei.DeviceWarrantyTermMasterID AS DeviceWarrantyTermMasterID
					,ei.InvoiceNumber AS InvoiceNumber
					,ei.IMEI2 AS IMEI2
					,ei.EID AS eSIM
					,ei.IseSimSelected AS IseSimSelected
					,ei.DEPValue AS DEPValue
					
					--pricing
					,dc.Cost
					,dc.Margin
					,CASE 
						WHEN (
								cdp.PriceExpiryDate IS NOT NULL
								AND GETDATE() <= cdp.PriceExpiryDate
								AND ISNULL(cdp.SpecialPrice, 0) <> 0
								)
							THEN cdp.SpecialPrice
						ELSE dc.Price
						END AS Price
				FROM EquipmentInventory ei(NOLOCK)
				LEFT JOIN DeviceXCarrier dc(NOLOCK) ON dc.DeviceID = ei.DeviceID
					AND dc.CarrierID = @CarrierID
					AND dc.DeviceVendorID = @DefaultDeviceVendorID
					AND dc.DeviceConditionID = 100 --ei.DeviceConditionID
				LEFT JOIN CustomerXDeviceSpecialPrice cdp(NOLOCK) ON cdp.CustomerID = @CustomerID
					AND cdp.DeviceXCarrierID = dc.DeviceXCarrierID
					AND cdp.IsActive = 1
				LEFT JOIN FulfillmentVendor fv(NOLOCK) ON fv.DeviceVendorID = dc.DeviceVendorID
					AND fv.IsQMobile = 1
					AND fv.FulfillmentVendor = CASE 
						WHEN (
								@DefaultDeviceVendorID = 100
								AND @CarrierID = 122
								)
							THEN 'AT&T-Apex'
						WHEN (
								@DefaultDeviceVendorID = 100
								AND @CarrierID = 178
								)
							THEN 'Verizon-Telespire'
						WHEN (
								@DefaultDeviceVendorID = 100
								AND @CarrierID NOT IN (
									122
									,178
									)
								)
							THEN 'Webbing'
						ELSE fv.FulfillmentVendor
						END
				WHERE ei.DeviceID = @DeviceID
					AND ei.EquipmentInventoryMasterID IN (
						SELECT CAST(Value AS INT)
						FROM [dbo].SplitValue(@EquipmentInventoryIDs, '|')
						)


				-- GET SHIPPING INFORMATION
				SELECT TOP 1 @AccountID = account_id
					,@ExistingShippingAddressID = c.CustomerAddressID
					,@Address1 = a.address_1
					,@Address2 = a.address_2
					,@City = a.city
					,@StateMasterID = sa.StateMasterID
					,@ZipCode = a.zip
					,@CountryMasterID = cm.CountryMasterID
				FROM customer cus(NOLOCK)
				LEFT JOIN ipath..account a(NOLOCK) ON cus.customer_id = a.customer_id
				LEFT JOIN CustomerAddress c(NOLOCK) ON c.CustomerID = cus.customer_id
					AND c.AccountID = a.account_id
					AND c.IsActive = 1
					AND c.AddressType = 'S'
				LEFT JOIN StateMaster sa(NOLOCK) ON sa.StateCode = a.STATE
					AND sa.IsActive = 1
				LEFT JOIN CountryMaster cm(NOLOCK) ON cm.CountryCode = a.country
					AND cm.IsActive = 1
				WHERE a.STATUS = 'A'
					AND cus.customer_id = @CustomerID
					AND a.is_corp = 1

				SELECT 'Devices'
					,*
				FROM @Devices -- REMOVE

				BEGIN TRANSACTION
				-------------------------- CREATE Spare Order ----------------------------
				-- create Spare Order
				EXEC [MobilityOrders_InsertNewOrder] @CustomerID = @CustomerID
					,@AccountID = @AccountID
					,@CarrierID = @CarrierID
					,@CarrierAccountID = @CarrierAccountID
					,@TicketReferenceNumber = ''
					,@OrderTypeID = @OrderTypeID
					,@OrderDescription = ''
					,@AddedByID = @AddedByID
					,@RequestorID = @RequestorID
					--,@CustomerXCarrierAccountsID = @CustomerXCarrierAccountsID
					,@MobilityOrderID = @MobilityOrderID OUTPUT
					,@MobilityOrderItemID = @MobilityOrderItemID OUTPUT

				UPDATE MobilityOrderItems
				SET LineStatusMasterID = @LineStatusMasterID
					,OrderSubTypeMasterID = 1
					,iBillerDate = (
						CASE 
							WHEN @IsRetail = 0
								THEN dbo.GetBillCycleDate()
							ELSE NULL
							END
						)
					,DEPValue = @DEPValue
				WHERE MobilityOrderItemID = @MobilityOrderItemID

				EXEC MobileNotificationCriteria_InsertLog @MobilityOrderID = @MobilityOrderID
					,@MobilityOrderItemID = @MobilityOrderItemID
					,@AddedByID = @AddedByID

				EXEC [MobilityOrders_UpdateShipping] @MobilityOrderID
					,@MobilityOrderItemID
					,@ExistingShippingAddressID
					,@CustomerID
					,@AttentionToName
					,@Address1
					,@Address2
					,@Address3
					,@City
					,@StateMasterID
					,@Zipcode
					,@CountryMasterID
					,@AddedByID
					,@ShippingTypeID
					,1

				EXEC MobilityOrderItemHistory_Insert @LineStatusMasterID = @LineStatusMasterID
					,@LineSubStatusMasterID = 0
					,@MobilityOrderItemID = @MobilityOrderItemID
					,@AddedByID = @AddedByID

				------------------------ ADD DEVICES -----------------------
				-- DECLARE Device PRICING variables
				DECLARE @DeviceTypeID INT = 0
					,@DevicePricingMasterID INT = 0
					,@Cost DECIMAL(18, 2)
					,@Margin DECIMAL(18, 2)
					,@Price DECIMAL(18, 2)
					,@IsInstallmentPlan BIT
					,@ChargeType VARCHAR(50)
					,@USOC VARCHAR(50)
					,@ChargeDescription VARCHAR(250)
					,@HasPreOrder BIT

				-- QMOBILE ENVIRONMENT VARIABLES
				DECLARE @ROIOnCost DECIMAL(18, 2) = 10
					,@ROIOnPrice DECIMAL(18, 2) = 10
					,@PlanMonths INT
					,@DownPayment DECIMAL(18, 2) = 0
					,@MonthlyDeviceInstallmentPlanCost DECIMAL(18, 2)
					,@MonthlyDeviceInstallmentPlanPrice DECIMAL(18, 2)

				/************ calculate installment charge for Device : START ******************/
				SELECT TOP 1 @PlanMonths = CASE 
						WHEN Installment = 'none'
							THEN NULL
						ELSE CAST(RTRIM(LTRIM(substring(Installment, 1, 3))) AS INT)
						END
					,@IsInstallmentPlan = CASE 
						WHEN Installment = 'none'
							THEN 0
						ELSE 1
						END
				FROM ManagedInventoryXCarrierAccounts(NOLOCK)
				WHERE CustomerID = @CustomerID
					AND IsActive = 1
					AND CustomerXCarrierAccountsID = @CustomerXCarrierAccountsID
                    AND DeviceID = @DeviceID

				DECLARE @ci DECIMAL(18, 2)
					,@pi DECIMAL(18, 2)
					,@DCCost DECIMAL(18, 2)
					,@DCPrice DECIMAL(18, 2)

				SELECT TOP 1 @Cost = d.Cost
					,@Price = d.Price
				FROM @Devices d

				SELECT @ci = @ROIOnCost / (12 * 100)
					,@pi = @ROIOnPrice / (12 * 100)

				SET @Cost = CASE 
						WHEN @Cost - @DownPayment < 0
							THEN 0
						ELSE @Cost - @DownPayment
						END
				SET @Price = CASE 
						WHEN @Price - @DownPayment < 0
							THEN 0
						ELSE @Price - @DownPayment
						END

				IF @Cost >= 0
					AND @Price >= 0
					AND @ROIOnCost >= 0
					AND @ROIOnPrice >= 0
					AND @PlanMonths IS NOT NULL
				BEGIN
					IF @ci > 0
						AND @pi > 0
					BEGIN
						SET @MonthlyDeviceInstallmentPlanCost = dbo.[GetMonthlyPaymentOnCostPriceCalcuation](@Cost, @Price, @ROIOnCost, @PlanMonths, 1)
						SET @MonthlyDeviceInstallmentPlanPrice = dbo.[GetMonthlyPaymentOnCostPriceCalcuation](@Cost, @Price, @ROIOnCost, @PlanMonths, 0)
					END
					ELSE
					BEGIN
						SET @MonthlyDeviceInstallmentPlanCost = @Cost / @PlanMonths
						SET @MonthlyDeviceInstallmentPlanPrice = @Price / @PlanMonths
					END
				END
				ELSE
				BEGIN
					SET @MonthlyDeviceInstallmentPlanCost = NULL
					SET @MonthlyDeviceInstallmentPlanPrice = NULL
				END

				-- Why do we need the below step??
				SELECT @MonthlyDeviceInstallmentPlanCost AS MonthlyDeviceInstallmentPlanCharge

				/************ calculate installment charge for Device : END ******************/
				INSERT INTO MobilityOrderXDevices (
					OrderDeviceOptionsMasterID
					,MobilityOrderID
					,MobilityOrderItemID
					,DeviceID
					
					-- Values
					,EquipmentInventoryID
					,InventoryDeviceRelID
					,IMEI
					,ESN
                    ,ICCID
					,DeviceProvider
					,DeviceSellerID
					,DeviceWarrantyTypeMasterID
					,DeviceWarrantyTermMasterID
					,InvoiceNumber
					,IMEI2
					,eSIM
					,IseSimSelected
					,DeviceXCarrierID
					,DeviceConditionID
					,DeviceVendorID
					
					-- Pricing
					,DevicePricingCategoryMasterID
					,PlanCost
					,PlanMargin
					,PlanPrice
					,IsInstallmentPlan
					,DownPayment
					,PlanMonths
					,ROIOnCost
					,ROIOnPrice
					,AddedByID
					,ChangedByID
					)
				SELECT 1 AS OrderDeviceOptionsMasterID
					,@MobilityOrderID AS MobilityOrderID
					,@MobilityOrderItemID AS MobilityOrderItemID
					,@DeviceID AS DeviceID
					
					-- Values
					,d.EquipmentInventoryID
					,d.InventoryDeviceRelID
					,d.IMEI
					,d.ESN
                    ,d.ICCID
					,d.DeviceProvider
					,d.DeviceSellerID
					,d.DeviceWarrantyTypeMasterID
					,d.DeviceWarrantyTermMasterID
					,d.InvoiceNumber
					,d.IMEI2
					,d.eSIM
					,d.IseSimSelected
					,d.DeviceXCarrierID
					,d.DeviceConditionID
					,d.DeviceVendorID
					
					-- Pricing
					,dbo.uspGetPricingCategoryID(d.Price)
					,d.Cost
					,d.Margin
					,d.Price
					,1 AS IsInstallmentPlan
					,@DownPayment AS DownPayment
					,@PlanMonths AS PlanMonths
					,@ROIOnCost AS ROIOnCost
					,@ROIOnPrice AS ROIOnPrice
					,@AddedByID AS AddedByID
					,@AddedByID AS ChangedByID
				FROM @Devices d

                SELECT 'MobilityOrderXDevices', * from MobilityOrderXDevices WHERE MobilityOrderID = @MobilityOrderID       -- REMOVE

				-- UPDATE Order Description
				IF ISNULL(@MobilityOrderID, 0) > 0
				BEGIN
					EXEC OrderDescriptionInsertorUpdate @MobilityOrderID
				END

				-------------------------- INSERT Charges into MobilityOrderCharges ----------------------------
				SELECT @IsInstallmentPlan AS '@IsInstallmentPlan' -- REMOVE
					-- INSERT DEVICE charge

				IF @IsInstallmentPlan = 1
				BEGIN
					----- EMI CHARGES -----------        
					INSERT INTO MobilityOrderCharges (
						MobilityOrderID
						,MobilityOrderItemID
						,CustomerXProductCatalogID
						,CategoryPlanID
						,ProductCatalogCategoryMasterID
						,ChargeType
						,USOC
						,ChargeDescription
						,Quantity
						,Cost
						,Margin
						,Price
						,TimesToBill
						,IsActive
						,AddedByID
						,ChangedByID
                        ,HasCharged
						)
					SELECT @MobilityOrderID
						,@MobilityOrderItemID
						,0 AS CustomerXProductCatalogID
						,@DeviceID
						,5
						,'Monthly'
						,'MINSTPLAN'
						,dbo.GetInstallmentNDownPaymentChargeDescByDevice(@DeviceID, @PlanMonths, 'MINSTPLAN')
						,@DeviceCount
						,@MonthlyDeviceInstallmentPlanCost
						,NULL
						,@MonthlyDeviceInstallmentPlanPrice
						,@PlanMonths
						,1
						,@AddedByID
						,@AddedByID
                        ,1          -- set this to 1 to propogate to bill.chargemaster?
					FROM @Devices d
				END
				ELSE
				BEGIN
					--- INSERT EQUIPMENT CHARGE  ----        
					INSERT INTO MobilityOrderCharges (
						MobilityOrderID
						,MobilityOrderItemID
						,CustomerXProductCatalogID
						,CategoryPlanID
						,ProductCatalogCategoryMasterID
						,ChargeType
						,USOC
						,ChargeDescription
						,Quantity
						,Cost
						,Margin
						,Price
						,TimesToBill
						,IsActive
						,AddedByID
						,ChangedByID
                        ,HasCharged
						)
					SELECT @MobilityOrderID
						,@MobilityOrderItemID
						,ISNULL(cpc.CustomerXProductCatalogID, 0) AS CustomerXProductCatalogID
						,@DeviceID
						,5
						,cpc.ChargeType
						,cpc.USOC
						,cpc.Description
						,@DeviceCount
						,d.Cost
						,d.Margin
						,d.Price
						,1
						,1
						,@AddedByID
						,@AddedByID
                        ,1          -- set this to 1 to propogate to bill.chargemaster?
					FROM @Devices d
					LEFT JOIN CustomerXProductCatalog cpc(NOLOCK) ON cpc.CategoryPlanID = d.DeviceID
						AND cpc.ProductCatalogCategoryMasterID = 5 -- Device
						AND cpc.StatusID = 1
						AND cpc.CarrierID = @CarrierID
						AND cpc.CustomerID = @CustomerID
				END

                DELETE FROM @Devices        -- NEW REMOVE

                SELECT 'MobilityOrderCharges', * FROM MobilityOrderCharges WHERE MobilityOrderId = @MobilityOrderID -- REMOVE LATER

				--- INSERT SHIPMENT & DEP charge  ---
				INSERT INTO MobilityOrderCharges (
					MobilityOrderID
					,MobilityOrderItemID
					,CustomerXProductCatalogID
					,CategoryPlanID
					,ProductCatalogCategoryMasterID
					,ChargeType
					,USOC
					,ChargeDescription
					,Quantity
					,Cost
					,Margin
					,Price
					,TimesToBill
					,IsActive
					,AddedByID
					,ChangedByID
					)
				SELECT TOP 1 @MobilityOrderID
					,NULL -- Set NULL for Spare to get charges in order details level instead of configure item level
					,0
					,0
					,0
					,s.ShippingChargeType AS [ChargeType]
					,s.ShippingUSOC AS USOC
					,s.ShippingDescription AS [ChargeDescription]
					,1 AS ChargeDescription
					,CASE 
						WHEN ISNULL(smxc.ShippingCost, 0) = 0
							THEN s.ShippingCost
						ELSE smxc.ShippingCost
						END AS Cost
					,ISNULL(smxc.ShippingMargin, s.ShippingMargin) AS Margin
					,ISNULL(smxc.ShippingPrice, s.ShippingPrice) AS Price
					,1 AS TimesToBill
					,1 AS IsActive
					,@AddedByID
					,@AddedByID
				FROM ShippingTypeMaster s(NOLOCK)
				LEFT JOIN ShippingTypeMasterXCustomer smxc(NOLOCK) ON smxc.ShippingTypeMasterID = s.ShippingTypeMasterID
					AND smxc.CustomerXCarrierAccountsID = @CustomerXCarrierAccountsID
				WHERE s.IsActive = 1
					AND smxc.IsActive = 1
					AND s.ShippingType = 'Ground'
				
				UNION
				
				SELECT TOP 1 @MobilityOrderID
					,NULL -- Set NULL for Spare to get charges in order details level instead of configure item level
					,0
					,0
					,0
					,CASE 
						WHEN timesToBill = '1'
							THEN 'One Time'
						ELSE 'Monthly'
						END AS chargeType
					,u.usoc AS USOC
					,billDescription AS [ChargeDescription]
					,1 AS ChargeDescription
					,ISNULL(CC.Cost, C.Cost) AS Cost
					,ISNULL(CC.Margin, C.Margin) AS Margin
					,ISNULL(CC.Price, C.Price) AS Price
					,1 AS TimesToBill
					,1 AS IsActive
					,@AddedByID
					,@AddedByID
				FROM Charges C(NOLOCK)
				LEFT JOIN CustomerCharges CC(NOLOCK) ON C.CategoryPlanID = CC.CategoryPlanID
					AND C.ProductCatalogCategoryMasterID = CC.ProductCatalogCategoryMasterID --AND C.IsActive = 1            
					AND CC.ChargeID = C.ChargeID
					AND CC.CustomerID = @CustomerID
				LEFT JOIN BillingDb..usoc_master(NOLOCK) U ON U.usoc = C.usoc
				WHERE C.ProductCatalogCategoryMasterID = 8
					AND c.CategoryPlanID = @CarrierAccountID
					AND U.usoc = 'MNDEP'
					AND BillDescription = 'Device Enrollment Program'
					AND ISNULL(@DEPValue, 'none') NOT LIKE 'none'

				-------------------------- Update Store ----------------------------
				IF ISNULL(@MobilityOrderID, 0) <> 0
				BEGIN
					UPDATE EquipmentInventory
					SET MobilityOrderID = @MobilityOrderID
						,MobilityOrderItemID = @MobilityOrderItemID
					WHERE EquipmentInventoryMasterID IN (
							SELECT CAST(Value AS INT)
							FROM [dbo].SplitValue(@EquipmentInventoryIDs, '|')
							)
				END

				-------------------------- COMPLETE Spare Order ----------------------------
				SELECT TOP 1 @LineStatusMasterID = lm.LineStatusMasterID
					,@LineSubStatusMasterID = lsm.LineSubStatusMasterID
				FROM LineStatusMaster lm(NOLOCK)
				LEFT JOIN LineSubStatusMaster lsm(NOLOCK) ON lsm.LineStatusMasterID = lm.LineStatusMasterID
				WHERE lm.LineStatus = 'Complete'
					AND lsm.LineSubStatus = 'Automated'
					AND lm.IsActive = 1
					AND lsm.IsActive = 1

				EXEC MobilityOrderItemHistory_Insert @LineStatusMasterID = @LineStatusMasterID
					,@LineSubStatusMasterID = @LineSubStatusMasterID
					,@MobilityOrderItemID = @MobilityOrderItemID
					,@AddedByID = @AddedByID

				-------------------------------------- UPDATE OrderItemLevel
				/* IF ORDER IS SENT TO CLOSED AND THE CHANNEL IS "AGGREGATOR" AND IF A HOLD RECORD EXIST THEN MOVE THE ORDER ITEM TO "PENDING BILLING" */
				IF @LineStatusMasterID = 7001
					--AND @Channel = 'Wholesale Aggregator'			-- always Wholesale for Managed Inventory
					AND EXISTS (
						SELECT 1
						FROM billingValidationTime(NOLOCK)
						WHERE IsCompleted = 0
						)
				BEGIN
					SET @LineStatusMasterID = dbo.GetLineStatusMasterByCode('PB')

					INSERT INTO orderBillingTransistionLog (
						mobilityOrderItemID
						,stateDescription
						,addedByID
						)
					SELECT @MobilityOrderItemID
						,'Order Item moved to Pending Billing (Change)'
						,@AddedByID
				END

				UPDATE MobilityOrderItems
				SET LineStatusMasterID = @LineStatusMasterID
					,LineSubStatusMasterID = @LineSubStatusMasterID
					,ChangedByID = @AddedByID
					,ChangedDateTime = GETDATE()
					,invoiceDate = dbo.GetBillCycleDate()
					--,iBillerDate = @iBillerDate			-- ASK
					,ItemClosedDateTime = GETDATE() -- Update the Closed Date Time.
				WHERE MobilityOrderItemID = @MobilityOrderItemID

				INSERT INTO orderBillingTransistionLog (
					mobilityOrderItemID
					,stateDescription
					,addedByID
					)
				SELECT @MobilityOrderItemID
					,'Order Item - Completed'
					,@AddedByID

				-------------------------------------- UPDATE Inventory level
				-- DECLARE necessary variables
				DECLARE @ActivationDate DATETIME
					,@DeviceChargeCapture BIT = 0

				--,@IsEquipmentReady BIT = 1
				--,@IsEquipmentCharged BIT
				--SELECT @IsEquipmentReady = (				-- ASK
				--		CASE 
				--			WHEN count(*) >= 1
				--				THEN 1
				--			ELSE 0
				--			END
				--		)
				--FROM MobilityOrderItemHistory moih(NOLOCK)
				--INNER JOIN MobilityOrderItems moi(NOLOCK) ON moi.MobilityOrderItemID = moih.MobilityOrderItemID
				--WHERE moih.MobilityOrderItemID = ISNULL(@MobilityOrderItemID, moih.MobilityOrderItemID)
				--	AND ChangeTo = 'Equipment Shipped'
				--SELECT @IsEquipmentCharged = dbo.MobilityCharges_IsEquipmentReady(@MobilityOrderItemID);

				SELECT @ActivationDate = ISNULL(ActivationDate, GETDATE())
				FROM MobilityOrderItems(NOLOCK)
				WHERE MobilityOrderID = @MobilityOrderID
					AND MobilityOrderItemID = @MobilityOrderItemID
					AND IsActive = 1

				IF @OrderTypeID = 3
					AND @LineStatusMasterID = 7001
				BEGIN
					SET @DeviceChargeCapture = 1
				END

				SELECT @ActivationDate AS 'ActivationDate'
					,@DeviceChargeCapture AS 'DeviceChargeCapture' -- REMOVE

				INSERT INTO SpareInventory (
					CustomerID
					,DeviceID
					,EquipmentInventoryID
					,ESN
					,MEID
					,ICCID
					,PurchasedDate
					,DeviceProvider
					,DeviceSellerID
					,DeviceWarrantyTypeMasterID
					,DeviceWarrantyTermMasterID
					,InvoiceNumber
					,Cost
					,Margin
					,Price
					,MobilityOrderID
					,MobilityOrderItemID
					,AddedByID
					,ChangedByID
					,CarrierID
					,IMEI2
					,eSIM
					,DEPValue
					)
				SELECT @CustomerID
					,MOrD.DeviceID
					,MOrD.EquipmentInventoryID
					,MOrD.ESN
					,MOrD.IMEI
					,MOrD.ICCID
					,@ActivationDate
					,MOrD.DeviceProvider
					,MOrD.DeviceSellerID
					,MOrD.DeviceWarrantyTypeMasterID
					,MOrD.DeviceWarrantyTermMasterID
					,MOrD.InvoiceNumber
					,MOrD.PlanCost
					,MOrD.PlanMargin
					,MOrD.PlanPrice
					,NULL AS MobilityOrderID
					,NULL AS MobilityOrderItemID
					,@AddedByID
					,@AddedByID
					,DC.CarrierID
					,MOrD.IMEI2
					,MOrD.eSIM
					,@DEPValue
				FROM MobilityOrderXDevices MOrD(NOLOCK)
				INNER JOIN MobilityOrderItems MOI(NOLOCK) ON MOI.MobilityOrderItemID = MOrD.MobilityOrderItemID
					AND MOI.IsActive = 1
				INNER JOIN DeviceXCarrier DC(NOLOCK) ON DC.DeviceID = MOrD.DeviceID
					AND ISNULL(DC.DeviceConditionID, '') = COALESCE(MOrD.DeviceConditionID, DC.DeviceConditionID, '')
					AND ISNULL(dc.DeviceVendorID, '') = COALESCE(MOrD.DeviceVendorID, dc.DeviceVendorID, '')
				WHERE MOrD.MobilityOrderID = @MobilityOrderID
					AND MOrD.MobilityOrderItemID = @MobilityOrderItemID
					AND DC.CarrierID = @CarrierID
					AND MOI.LineStatusMasterID = 7001
                    

				------ UPDATE EQUIPMENT INVENTORY STATUS FOR VCOM STORE as sent to Customer  ----------                
				IF ISNULL(@EquipmentInventoryIDs, '') <> ''
				BEGIN
					DECLARE @EquipmentStatusMasterID INT

					SELECT @EquipmentStatusMasterID = EquipmentStatusMasterID
					FROM EquipmentStatusMaster
					WHERE [StatusCode] = 'S'

					UPDATE EquipmentInventory
					SET EquipmentStatusMasterID = @EquipmentStatusMasterID
					WHERE EquipmentInventoryMasterID IN (
							SELECT EquipmentInventoryID
							FROM MobilityOrderXDevices
							WHERE MobilityOrderID = @MobilityOrderID
								AND MobilityOrderItemID = @MobilityOrderItemID
								AND EquipmentInventoryID <> 0
							)
				END

				/************************* BILLING PROPAGATION HAPPENING HERE IN CASE OF SPARE ORDERS **************************************/
				EXEC Billing_Propagation @MobilityOrderItemID = @MobilityOrderItemID
					,@AddedByID = @AddedByID
					,@DeviceChargeCapture = @DeviceChargeCapture

				--------- Capture booking information 
				EXEC uspManageBookingAgainstOrderItem @MobilityOrderItemID
					,@LineStatusMasterID

				--------- AUTO UPDATE ORDER STAGE --------         
				EXEC OrderStage_AutoUpdate @MobilityOrderID
					,@MobilityOrderItemID
					,@AddedByID

				-------------------------- Add Note to Order & send EMAIL to Order Manager ----------------------------
				DECLARE @Subject NVARCHAR(500)
					,@EmailBody NVARCHAR(MAX)
					,@ParserTo VARCHAR(255)
					,@ParserEmailFrom VARCHAR(255)
					,@ServerName VARCHAR(200)
					,@OrderManagerEmail VARCHAR(200)
					,@CustomerName NVARCHAR(500)
					,@ModelName VARCHAR(MAX)

				SELECT TOP 1 @ModelName = ModelName
				FROM Devices(NOLOCK)
				WHERE DeviceID = @DeviceID

				SELECT TOP 1 @OrderManagerEmail = u.user_email
					,@CustomerName = c.customer_name
				FROM MobilityOrders mo(NOLOCK)
				INNER JOIN Users u(NOLOCK) ON u.user_id = mo.OrderOwnerID -- OrderOwner ~ OrderManager
				INNER JOIN customer c(NOLOCK) ON c.customer_id = mo.CustomerID
				WHERE mo.MobilityOrderID = @MobilityOrderID
					AND u.is_active = 1

				IF (ISNULL(@MobilityOrderID, 0) <> 0)
				BEGIN
					-- Notes
					INSERT INTO MobilityOrderNotes (
						MobilityOrderID
						,[Subject]
						,Comment
						,IsActive
						,IsCustomerViewable
						,AddedDateTime
						,AddedByID
						,ChangedDateTime
						,ChangedByID
						)
					SELECT @MobilityOrderID
						,'Inventory Management for ' + @CustomerName
						,'Order to move ' + CAST(@DeviceCount AS VARCHAR(20)) + ' ' + @ModelName + ' to Spare inventory was placed because they haven''t been purchased within the agreed upon timeframe of ' + @InventoryPeriod + '.'
						,1
						,1
						,GETDATE()
						,@AddedByID
						,GETDATE()
						,@AddedByID

					COMMIT TRANSACTION

					--- Emails
					SET @ServerName = CAST(SERVERPROPERTY('ServerName') AS VARCHAR(200))
					SET @Subject = 'Aging Managed Inventory for ' + @CustomerName + ' Order ' + CAST(@MobilityOrderID AS VARCHAR(20)) + ' to be billed'
					SET @EmailBody = 'Order # ' + CAST(@MobilityOrderID AS VARCHAR(20)) + ' for ' + @CustomerName + ' was created on ' + FORMAT(GETDATE(), 'MM/dd/yyyy') + ' for ' + CAST(@DeviceCount AS VARCHAR(20)) + ' ' + @ModelName + ' for billing. Deferred hardware billing has reached the agreed upon timeframe of ' + @InventoryPeriod + ' and the remaining stagnant inventory is being billed per standard terms.'

					IF (@ServerName = 'vcomazwe1ldb01')
					BEGIN
						SET @ParserEmailFrom = 'iPathMobile@vComsolutions.com'
						SET @ParserTo = @OrderManagerEmail
					END
					ELSE IF (@ServerName = 'vcomazwe1udb01')
					BEGIN
						SET @ParserEmailFrom = 'iPathMobileUAT@vComsolutions.com'
						SET @ParserTo = @OrderManagerEmail + ',' + 'spalepu@vcomsolutions.com,raviteja.yella@codebees.com,gopi.pagadala@codebees.com,lokesh.gogineni@codebees.com'
					END
					ELSE
					BEGIN
						SET @ParserEmailFrom = 'iPathMobileDev@vComsolutions.com'
						SET @ParserTo = @OrderManagerEmail + ',' + 'spalepu@vcomsolutions.com,raviteja.yella@codebees.com,gopi.pagadala@codebees.com,lokesh.gogineni@codebees.com'
					END

					EXEC ipath.dbo.send_cdomail @ParserEmailFrom
						,@ParserTo
						,@Subject
						,@EmailBody
						,'' --cc 

					SELECT @EmailBody
						,@Subject
				END

				SELECT '******************'
					,'******************'
					,'******************'
					,'******************'
					,'******************'
					,'******************' -- REMOVE

				FETCH NEXT
				FROM SpareOrderInfoCursor
				INTO @CustomerID
					,@CustomerXCarrierAccountsID
					,@DeviceID
					,@DeviceCount
					,@EquipmentInventoryIDs
					,@DEPValue
					,@DeviceConditionID
					,@InventoryPeriod
					,@CarrierID
					,@CarrierAccountID
			END

			CLOSE SpareOrderInfoCursor;

			DEALLOCATE SpareOrderInfoCursor;

			
		END
	END TRY

	BEGIN CATCH
		IF @@TRANCOUNT > 0
		BEGIN
			ROLLBACK TRANSACTION
		END

		DECLARE @eMessage VARCHAR(800)
			,@eProcedure VARCHAR(800)
			,@eLine VARCHAR(800)

		SELECT @eMessage = ''
			,@eProcedure = ''
			,@eLine = ''

		SELECT @eMessage = ERROR_MESSAGE()
			,@eProcedure = ERROR_PROCEDURE()
			,@eLine = ERROR_LINE()

		EXEC dbo.uspSendDBErrorEmail @Subject = 'CustomerCarrierAccounts_SpareOrdersForUnusedDevices'
			,@ErrorMessage = @eMessage
			,@ErrorProcedure = @eProcedure
			,@ErrorLine = @eLine
			,@QueryParams = ''
			,@UserID = 0
	END CATCH
END
GO
