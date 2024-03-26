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

		DECLARE @MoveUnUsedDevicesFromStore TABLE (
			CustomerID INT
			,CustomerXCarrierAccountsID INT
			,DeviceID INT
			,UnUsedDeviceCount INT

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
			,IMEI2 VARCHAR(50)
			,eSIM VARCHAR(50)
			,IseSimSelected BIT
			)

		INSERT INTO @MoveUnUsedDevicesFromStore
		SELECT mica.CustomerID
			,cca.CustomerXCarrierAccountsID
			,mica.DeviceID
			,COUNT(*) AS UnUsedDeviceCount
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

		IF EXISTS (
				SELECT 1
				FROM @MoveUnUsedDevicesFromStore
				WHERE UnUsedDeviceCount > 0
				)
		BEGIN
			DECLARE @CustomerID INT
				,@CustomerXCarrierAccountsID INT
				,@DeviceID INT
				,@DeviceCount INT
				,@DeviceXCarrierID INT
				,@DeviceConditionID INT
				,@DeviceVendorID INT
				,@InventoryDeviceRelID INT
				,@EquipmentInventoryID INT
				,@IMEI VARCHAR(50)
				,@ESN VARCHAR(50)
				,@DeviceProvider VARCHAR(150)
				,@DeviceSellerID INT
				,@DeviceWarrantyTypeMasterID INT
				,@DeviceWarrantyTermMasterID INT
				,@InvoiceNumber VARCHAR(100)
				,@IMEI2 VARCHAR(50)
				,@eSIM VARCHAR(50)
				,@IseSimSelected BIT

			IF CURSOR_STATUS('global', 'SpareOrderInfoCursor') >= 0
			BEGIN
				CLOSE SpareOrderInfoCursor;

				DEALLOCATE SpareOrderInfoCursor;
			END

			BEGIN TRANSACTION

			DECLARE SpareOrderInfoCursor CURSOR
			FOR
			SELECT *
			FROM @MoveUnUsedDevicesFromStore

			OPEN SpareOrderInfoCursor

			FETCH NEXT
			FROM SpareOrderInfoCursor
			INTO @CustomerID
				,@CustomerXCarrierAccountsID
				,@DeviceID
				,@DeviceCount

				,@DeviceXCarrierID
				,@DeviceConditionID
				,@DeviceVendorID
				,@InventoryDeviceRelID
				,@EquipmentInventoryID
				,@IMEI
				,@ESN
				,@DeviceProvider
				,@DeviceSellerID
				,@DeviceWarrantyTypeMasterID
				,@DeviceWarrantyTermMasterID
				,@InvoiceNumber
				,@IMEI2
				,@eSIM
				,@IseSimSelected

			WHILE @@FETCH_STATUS = 0
			BEGIN
				DECLARE @MobilityOrderID INT
					,@MobilityOrderItemID INT

				-- DECLARE Device variables
				DECLARE @DeviceTypeID INT = 0
					,@DevicePricingMasterID INT = 0
					,@Cost DECIMAL(18, 2)
					,@Margin DECIMAL(18, 2)
					,@Price DECIMAL(18, 2)
					,@IsInstallmentPlan BIT
					,@DownPayment DECIMAL(18, 2)
					,@ROIOnCost DECIMAL(18, 2)
					,@ROIOnPrice DECIMAL(18, 2)
					,@Term INT
					,@MonthlyPaymentOnCost DECIMAL(18, 2)
					,@MonthlyPaymentOnPrice DECIMAL(18, 2)
					,@CustomerXProductCatalogID INT
					,@ChargeType VARCHAR(50)
					,@USOC VARCHAR(50)
					,@ChargeDescription VARCHAR(250)
					,@HasPreOrder BIT
					,@DeviceXCarrierID INT
					,@DeviceConditionID INT
					,@DeviceVendorID INT

				-- DECLARE Shipping variables
				DECLARE @AccountID INT
					,@ExistingShippingAddressID INT
					,@AttentionToName VARCHAR(MAX) = ''
					,@Address1 VARCHAR(MAX)
					,@Address2 VARCHAR(100) = ''
					,@Address3 VARCHAR(100) = ''
					,@City VARCHAR(100) = 'Mechanicsville'
					,@StateMasterID INT = 38
					,@Zipcode VARCHAR(10)
					,@CountryMasterID INT = 1
					,@ShippingTypeID INT = 1

				FETCH NEXT
				FROM SpareOrderInfoCursor
				INTO @CustomerID
					,@CustomerXCarrierAccountsID
					,@DeviceID
					,@DeviceCount

					,@DeviceXCarrierID
					,@DeviceConditionID
					,@DeviceVendorID
					,@InventoryDeviceRelID
					,@EquipmentInventoryID
					,@IMEI
					,@ESN
					,@DeviceProvider
					,@DeviceSellerID
					,@DeviceWarrantyTypeMasterID
					,@DeviceWarrantyTermMasterID
					,@InvoiceNumber
					,@IMEI2
					,@eSIM
					,@IseSimSelected
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
