USE [mobility]
GO

/****** Object:  StoredProcedure [dbo].[CustomerCarrierAccounts_SpareOrdersForUnusedDevices]    Script Date: 3/26/2024 10:39:58 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author: Ravi Teja Yella
-- Create date: 03/26/2024
-- Description:	Moved unused devices from vCom Store to Customer Spare after inventory period
-- =============================================
ALTER PROCEDURE [dbo].[CustomerCarrierAccounts_SpareOrdersForUnusedDevices]
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
			)

		INSERT INTO @MoveUnUsedDevicesFromStore (
			CustomerID
			,CustomerXCarrierAccountsID
			,DeviceID
			,UnUsedDeviceCount
			,EquipmentInventoryIDs
			)
		SELECT mica.CustomerID AS CustomerID
			,cca.CustomerXCarrierAccountsID AS CustomerXCarrierAccountsID
			,mica.DeviceID AS DeviceID
			,COUNT(*) AS UnUsedDeviceCount
			,STRING_AGG(CAST(ei.EquipmentInventoryMasterID AS VARCHAR(100)), '|') AS EquipmentInventoryIDs
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

		SELECT '@MoveUnUsedDevicesFromStore', * FROM @MoveUnUsedDevicesFromStore		-- REMOVE

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

			BEGIN TRANSACTION

			DECLARE @CustomerID INT
				,@CustomerXCarrierAccountsID INT
				,@DeviceID INT
				,@DeviceCount INT
				,@CarrierID INT
				,@CarrierAccountID INT
				,@EquipmentInventoryIDs VARCHAR(100)

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
				,@CarrierID
				,@CarrierAccountID

			WHILE @@FETCH_STATUS = 0
			BEGIN
				
				SELECT @CustomerID				-- REMOVE
					,@CustomerXCarrierAccountsID
					,@DeviceID
					,@DeviceCount
					,@EquipmentInventoryIDs
					,@CarrierID
					,@CarrierAccountID

				DECLARE @MobilityOrderID INT
					,@MobilityOrderItemID INT
					,@LineStatusMasterID INT = 1001 -- ASSIGNED

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
					,DeviceProvider VARCHAR(150)
					,DeviceSellerID INT
					,DeviceWarrantyTypeMasterID INT
					,DeviceWarrantyTermMasterID INT
					,InvoiceNumber VARCHAR(100)
					,IMEI2 VARCHAR(100)
					,eSIM VARCHAR(100)
					,IseSimSelected BIT
					,DEPValue VARCHAR(150)
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

				-- GET DEVICE VALUES
				DELETE FROM @Devices	-- CLEAR existing

				INSERT INTO @Devices
				SELECT NULL AS MobilityOrderXDeviceID
					,@DeviceID
					,ei.DeviceXCarrierID
					,ei.DeviceConditionID
					,ei.DeviceVendorID
					,NULL AS InventoryDeviceRelID
					,ei.EquipmentInventoryMasterID AS EquipmentInventoryID
					,ei.MEID AS IMEI
					,ei.ESN AS ESN
					,'vCom' AS DeviceProvider -- ASK
					,ei.DeviceSellerID AS DeviceSellerID
					,ei.DeviceWarrantyTypeMasterID AS DeviceWarrantyTypeMasterID
					,ei.DeviceWarrantyTermMasterID AS DeviceWarrantyTermMasterID
					,ei.InvoiceNumber AS InvoiceNumber
					,ei.IMEI2 AS IMEI2
					,ei.EID AS eSIM
					,ei.IseSimSelected AS IseSimSelected
					,ei.DEPValue AS DEPValue
				FROM EquipmentInventory ei(NOLOCK)
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


				SELECT 'Devices', * FROM @Devices		-- REMOVE

				-------------------------- CREATE Spare Order ----------------------------
				-- create Spare Order
				--EXEC [MobilityOrders_InsertNewOrder] @CustomerID = @CustomerID
				--	,@AccountID = @AccountID
				--	,@CarrierID = @CarrierID
				--	,@CarrierAccountID = @CarrierAccountID
				--	,@TicketReferenceNumber = ''
				--	,@OrderTypeID = @OrderTypeID
				--	,@OrderDescription = ''
				--	,@AddedByID = @AddedByID
				--	,@RequestorID = @RequestorID
				--	--,@CustomerXCarrierAccountsID = @CustomerXCarrierAccountsID
				--	,@MobilityOrderID = @MobilityOrderID OUTPUT
				--	,@MobilityOrderItemID = @MobilityOrderItemID OUTPUT

				--UPDATE MobilityOrderItems
				--SET LineStatusMasterID = @LineStatusMasterID
				--	,OrderSubTypeMasterID = 1
				--	,iBillerDate = (
				--		CASE 
				--			WHEN @IsRetail = 0
				--				THEN dbo.GetBillCycleDate()
				--			ELSE NULL
				--			END
				--		)
				--WHERE MobilityOrderItemID = @MobilityOrderItemID

				--EXEC MobileNotificationCriteria_InsertLog @MobilityOrderID = @MobilityOrderID
				--	,@MobilityOrderItemID = @MobilityOrderItemID
				--	,@AddedByID = @AddedByID

				--EXEC [MobilityOrders_UpdateShipping] @MobilityOrderID
				--	,@MobilityOrderItemID
				--	,@ExistingShippingAddressID
				--	,@CustomerID
				--	,@AttentionToName
				--	,@Address1
				--	,@Address2
				--	,@Address3
				--	,@City
				--	,@StateMasterID
				--	,@Zipcode
				--	,@CountryMasterID
				--	,@AddedByID
				--	,@ShippingTypeID
				--	,1

				--EXEC MobilityOrderItemHistory_Insert @LineStatusMasterID = @LineStatusMasterID
				--	,@LineSubStatusMasterID = 0
				--	,@MobilityOrderItemID = @MobilityOrderItemID
				--	,@AddedByID = @AddedByID

				------------------------ ADD DEVICES -----------------------
				-- DECLARE Device PRICING variables
				DECLARE @DeviceTypeID INT = 0
					,@DevicePricingMasterID INT = 0
					,@Cost DECIMAL(18, 2)
					,@Margin DECIMAL(18, 2)
					,@Price DECIMAL(18, 2)
					,@IsInstallmentPlan BIT
					,@Term INT
					,@MonthlyPaymentOnCost DECIMAL(18, 2)
					,@MonthlyPaymentOnPrice DECIMAL(18, 2)
					,@CustomerXProductCatalogID INT
					,@ChargeType VARCHAR(50)
					,@USOC VARCHAR(50)
					,@ChargeDescription VARCHAR(250)
					,@HasPreOrder BIT

				-- QMOBILE ENVIRONMENT VARIABLES
				DECLARE @ROIOnCost DECIMAL(18, 2) = 10
					,@ROIOnPrice DECIMAL(18, 2) = 10
					,@PlanMonths INT
					,@DownPayment DECIMAL(18, 2) = 0
					,@MonthlyDeviceInstallmentPlanCharge DECIMAL(18, 2)

				/************ calculate installment charge for Device : START ******************/
				SELECT TOP 1 @PlanMonths = CAST(RTRIM(LTRIM(substring(Installment, 1, 3))) AS INT)
				FROM ManagedInventoryXCarrierAccounts(NOLOCK)
				WHERE CustomerID = @CustomerID
					AND IsActive = 1
					AND CustomerXCarrierAccountsID = @CustomerXCarrierAccountsID

				DECLARE @ci DECIMAL(18, 2)
					,@pi DECIMAL(18, 2)
					,@DCCost DECIMAL(18, 2)
					,@DCPrice DECIMAL(18, 2)

				SELECT TOP 1 @Cost = dc.Cost
					,@Price = dc.Price
				FROM @Devices d
				JOIN DeviceXCarrier dc(NOLOCK) ON dc.DeviceID = d.DeviceID
					AND dc.CarrierID = @CarrierID

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
						SET @MonthlyDeviceInstallmentPlanCharge = (@Cost * @ci * POWER(1 + @ci, @PlanMonths)) / (POWER(1 + @ci, @PlanMonths) - 1)
					END
					ELSE
					BEGIN
						SET @MonthlyDeviceInstallmentPlanCharge = @Cost / @PlanMonths
					END
				END
				ELSE
				BEGIN
					SET @MonthlyDeviceInstallmentPlanCharge = NULL
				END

				SELECT @MonthlyDeviceInstallmentPlanCharge AS MonthlyDeviceInstallmentPlanCharge
				/************ calculate installment charge for Device : END ******************/

				--INSERT INTO MobilityOrderXDevices (
				--	OrderDeviceOptionsMasterID
				--	,MobilityOrderID
				--	,MobilityOrderItemID
				--	,DeviceID
				
				--	-- Values
				--	,EquipmentInventoryID
				--	,InventoryDeviceRelID
				--	,IMEI
				--	,ESN
				--	,DeviceProvider
				--	,DeviceSellerID
				--	,DeviceWarrantyTypeMasterID
				--	,DeviceWarrantyTermMasterID
				--	,InvoiceNumber
				--	,IMEI2
				--	,eSIM
				--	,IseSimSelected
				--	,DeviceXCarrierID
				--	,DeviceConditionID
				--	,DeviceVendorID
				
				--	-- Pricing
				--	,DevicePricingCategoryMasterID
				--	,PlanCost
				--	,PlanMargin
				--	,PlanPrice
				--	,IsInstallmentPlan
				--	,DownPayment
				--	,PlanMonths
				--	,ROIOnCost
				--	,ROIOnPrice
				--	,AddedByID
				--	,ChangedByID
				--	)
				SELECT 1 AS OrderDeviceOptionsMasterID
					,@MobilityOrderID AS MobilityOrderID
					,@MobilityOrderItemID AS MobilityOrderItemID
					,@DeviceID AS DeviceID

					-- Values
					,d.EquipmentInventoryID
					,d.InventoryDeviceRelID
					,d.IMEI
					,d.ESN
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
					,dbo.uspGetPricingCategoryID(dc.Price)
					,dc.Cost
					,dc.Margin
					,dc.Price
					,1 AS IsInstallmentPlan
					,@DownPayment AS DownPayment
					,@PlanMonths AS PlanMonths
					,@ROIOnCost AS ROIOnCost
					,@ROIOnPrice AS ROIOnPrice
					,@AddedByID AS AddedByID
					,@AddedByID AS ChangedByID
				FROM @Devices d
				JOIN DeviceXCarrier dc(NOLOCK) ON dc.DeviceID = d.DeviceID
					AND dc.CarrierID = @CarrierID


				select '******************', '******************','******************','******************','******************','******************' -- REMOVE
				-- UPDATE Order Description
				IF ISNULL(@MobilityOrderID, 0) > 0
				BEGIN
					EXEC OrderDescriptionInsertorUpdate @MobilityOrderID
				END

				-------------------------- INSERT Charges into MobilityOrderCharges ----------------------------
				-------------------------- COMPLETE Spare Order ----------------------------
				-------------------------- Update Store ----------------------------
				-------------------------- Send Notification to OM ----------------------------

				FETCH NEXT
				FROM SpareOrderInfoCursor
				INTO @CustomerID
					,@CustomerXCarrierAccountsID
					,@DeviceID
					,@DeviceCount
					,@EquipmentInventoryIDs
					,@CarrierID
					,@CarrierAccountID
			END

			CLOSE SpareOrderInfoCursor;

			DEALLOCATE SpareOrderInfoCursor;

			COMMIT TRANSACTION
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
