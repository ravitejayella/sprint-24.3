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
-- ALTER date: 02-12-2021     
-- Description: device catalog changes v21     
-- ============================================= 
-- Author:  Nagasai                            
-- ALTER date: 05-06-2021                           
-- Description: adding biller date                          
-- ============================================= 
-- Author:  Nagasai                            
-- ALTER date: 07-30-2021                           
-- Description: equipment shipmented charges 
-- ============================================= 
-- Author:  Nagasai                              
-- ALTER date: 06-17-2022                             
-- Description: CASE-1188 -- history for additional records
-- =============================================   
-- Author:  Nagasai                              
-- ALTER date: 07-11-2022                             
-- Description: SPare order changes
-- SD CASE : CASE - 1689 - Overhaul Mobile Order Notifications
-- =============================================   
-- Author:  SP                              
-- ALTER date: 01/19/2023
-- Description: Spare and SIM Only Orders - Item Closed Field - Fix ItemClosed DateTime.
-- SD CASE : CASE - 5535 - Spare and SIM Only Orders - Item Closed Field not populated 
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
-- Author:  Ravi Teja Yella
-- Modified date: 03/19/2024
-- Description: Avoiding special characters while parsing DevicesXML
-- Case# 12677 : Order# 121327 - Order details getting wiped after saving
-- ================================================= 
-- Author:  Ravi Teja Yella
-- Modified date: 03/28/2024
-- Description: Adding devices to vCom store upon completion based on Replenishment flag
-- Case# 11432 : QS Managed Inventory - Phase 2 
-- ================================================= 
ALTER PROCEDURE [dbo].[MobilityOrders_SpareOrderConfig] @MobilityOrderID INT
	,@MobilityOrderItemID INT
	,@CustomerID INT
	,@LineStatusMasterID INT
	,@LineSubStatusMasterID INT = NULL
	,@DevicePricingCategoryMasterID INT
	,@DeviceID INT
	,@CustomerXProductCatalogID INT
	,@USOC VARCHAR(150)
	,@ChargeType VARCHAR(150)
	,@ChargeDescription VARCHAR(150)
	,@IsInstallmentPlan BIT = NULL
	,@DownPayment DECIMAL(18, 2) = NULL
	,@Quantity INT = 1
	,@Cost DECIMAL(18, 2) = NULL
	,@Margin DECIMAL(18, 2) = NULL
	,@Price DECIMAL(18, 2) = NULL
	,@Term INT = NULL
	,@ROIOnCost DECIMAL(18, 2) = NULL
	,@ROIOnPrice DECIMAL(18, 2) = NULL
	,@MonthlyPaymentOnCost DECIMAL(18, 2) = NULL
	,@MonthlyPaymentOnPrice DECIMAL(18, 2) = NULL
	,@DeviceXML TEXT
	,-- EDITED ON 03/19/2024
	@ExistingShippingAddressID INT = NULL
	,@AttentionToName VARCHAR(200) = NULL
	,@Address1 VARCHAR(500) = NULL
	,@Address2 VARCHAR(500) = NULL
	,@Address3 VARCHAR(500) = NULL
	,@City VARCHAR(150) = NULL
	,@StateMasterID INT = NULL
	,@Zipcode VARCHAR(10) = NULL
	,@CountryMasterID INT = NULL
	,@ShippingTypeID INT = NULL
	,@AddedByID INT
	,
	--- charges XML -----        
	@ChargesXML TEXT = NULL
	,@TrackingNumber VARCHAR(150) = NULL
	,@ContractStartDate DATETIME = NULL
	,@ContractEndDate DATETIME = NULL
	,@TermMasterID INT = NULL
	,@AppleID VARCHAR(250) = NULL
	,@StatusMessage VARCHAR(250) OUTPUT
	,@ShipDate DATETIME = NULL
	,@IsAutoProvisioned BIT = 0
	,@ShippingVendor VARCHAR(50) = NULL
	,@SetEquipmentStatus BIT = 0
	,@UserFirstName VARCHAR(250) = NULL
	,@UserLastName VARCHAR(250) = NULL
	,@UserTitle VARCHAR(50) = NULL
	,@UserEmail VARCHAR(250) = NULL
	,@CopyEndUser BIT = 0
	,@iBillerDate DATETIME = NULL
	,@AdditionalFieldsXML TEXT = NULL
AS
BEGIN
	BEGIN TRY
		SET NOCOUNT ON;

		BEGIN TRANSACTION

		DECLARE @Channel VARCHAR(250)
			,@OldAttentionToName VARCHAR(200)

		SELECT @OldAttentionToName = AttentionToName
		FROM MobilityOrderItems(NOLOCK)
		WHERE MobilityOrderID = @MobilityOrderID
			AND MobilityOrderItemID = @MobilityOrderItemID

		-- NS- 2022-06-17 CASE-1188 -- history for additional records
		EXEC MobilityOrderItemHistory_Update2 @MobilityOrderItemID = @MobilityOrderItemID
			,@AttentionToName = @OldAttentionToName
			,@ShippingVendor = @ShippingVendor
			,@AddedByID = @AddedByID

		-- update tracking number        
		UPDATE MobilityOrderItems
		SET TrackingNumber = @TrackingNumber
			,ShipDate = @ShipDate
			,ShippingVendor = @ShippingVendor
			,UserFirstName = @UserFirstName
			,UserLastName = @UserLastName
			,UserTitle = @UserTitle
			,UserEmail = @UserEmail
			,CopyEndUser = @CopyEndUser
			,iBillerDate = @iBillerDate
		WHERE MobilityOrderID = @MobilityOrderID
			AND MobilityOrderItemID = @MobilityOrderItemID

		SELECT @Channel = Channel
		FROM MobilityOrders MO
		INNER JOIN MobilityCarrierMaster MCM ON MCM.carrierID = MO.CarrierID
		WHERE MobilityOrderID = @MobilityOrderID

		/************************************************************        
			INSERT ORDER ITEM HISTORT FOR LINE STATUS/SUB STATUS        
			*********************************************************/
		IF @LineSubStatusMasterID = 0
		BEGIN
			SET @LineSubStatusMasterID = NULL
		END

		/* IF ORDER IS SENT TO CLOSED AND THE CHANNEL IS "AGGREGATOR" AND IF A HOLD RECORD EXIST THEN MOVE THE ORDER ITEM TO "PENDING BILLING" */
		IF @LineStatusMasterID = 7001
			AND @Channel = 'Wholesale Aggregator'
			AND EXISTS (
				SELECT *
				FROM billingValidationTime
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

		--/* CAPTURE ORDER ITEM HISTORY */       
		IF (@SetEquipmentStatus = 1)
		BEGIN
			EXEC MobilityOrderItemHistory_Insert @LineStatusMasterID = 5051
				,@LineSubStatusMasterID = @LineSubStatusMasterID
				,@MobilityOrderItemID = @MobilityOrderItemID
				,@AddedByID = @AddedByID
		END

		EXEC MobilityOrderItemHistory_Insert @LineStatusMasterID = @LineStatusMasterID
			,@LineSubStatusMasterID = @LineSubStatusMasterID
			,@MobilityOrderItemID = @MobilityOrderItemID
			,@AddedByID = @AddedByID

		--- LOOP THROUGH EACH RECORD AND INSERT DEVICE INFORMATION ----         
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
			)
		DECLARE @XMLHandle INT
			,@XMLData VARCHAR(MAX)
			,@newDeviceVendorID INT
			,@newDeviceConditionID INT

		SET @XMLData = @DeviceXML

		--SET @XMLData = REPLACE(@XMLData, 'â€ž','&quot;')         
		IF (@XMLData <> '')
		BEGIN
			/******** START REGION : REPLACE SPECIAL CHARACTERS ******/
			DECLARE @specialChars TABLE (
				originalChar VARCHAR(1)
				,replacementChar VARCHAR(10)
				)

			INSERT INTO @specialChars (
				originalChar
				,replacementChar
				)
			VALUES (
				'&'
				,'&amp;'
				)
				,(
				''''
				,'&apos;'
				)
				,(
				'"'
				,'&quot;'
				)
				,(
				'<'
				,'&lt;'
				)
				,(
				'>'
				,'&gt;'
				);

			DECLARE @start INT = 1
			DECLARE @end INT
			DECLARE @attributeValue VARCHAR(MAX)
			DECLARE @pattern VARCHAR(100) = '="(.*?)"'

			WHILE @start > 0
			BEGIN
				-- Find the next '=' assuming there is atleast one attribute and value.
				SET @start = CHARINDEX('=', @XMLData, @start)

				IF @start > 0
				BEGIN
					-- Attribute values can be inside either double quotes (") or 2 single quotes ('')
					IF SUBSTRING(@XMLData, @start + 1, 1) = '"' -- Double quotes
					BEGIN
						SET @end = CHARINDEX('"', @XMLData, @start + 2)
					END
					ELSE IF SUBSTRING(@XMLData, @start + 1, 1) = '''' -- Single quotes
					BEGIN
						SET @end = CHARINDEX('''', @XMLData, @start + 2)
					END

					IF @end > 0 -- if end exists.
					BEGIN
						-- Extract the attribute value without quotes
						SET @attributeValue = SUBSTRING(@XMLData, @start + 2, @end - @start - 2)

						-- Replace special characters in attribute value
						SELECT @attributeValue = REPLACE(@attributeValue, originalChar, replacementChar)
						FROM @specialChars

						-- Update the XML
						SET @XMLData = STUFF(@XMLData, @start + 1, @end - @start, '"' + @attributeValue + '"')
						SET @start = @end + 1
					END
				END
			END

			/******** END REGION : REPLACE SPECIAL CHARACTERS ******/
			EXEC sp_xml_preparedocument @XMLHandle OUTPUT
				,@XMLData

			INSERT INTO @Devices
			SELECT MobilityOrderXDeviceID
				,DeviceID
				,DeviceXCarrierID
				,DeviceConditionID
				,DeviceVendorID
				,InventoryDeviceRelID
				,EquipmentInventoryID
				,IMEI
				,ESN
				,REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(DeviceProvider, '&amp;', '&'), '&apos;', ''''), '&gt;', '>'), '&lt;', '<'), '&quot;', '\"') AS DeviceProvider
				,DeviceSellerID
				,DeviceWarrantyTypeMasterID
				,DeviceWarrantyTermMasterID
				,InvoiceNumber
				,IMEI2
				,eSIM
				,IseSimSelected
			FROM OPENXML(@XMLHandle, '/ROOT/row', 2) WITH (
					MobilityOrderXDeviceID INT '@MobilityOrderXDeviceID'
					,DeviceID INT '@DeviceID'
					,DeviceXCarrierID INT '@DeviceXCarrierID'
					,DeviceConditionID INT '@DeviceConditionID'
					,DeviceVendorID INT '@DeviceVendorID'
					,InventoryDeviceRelID INT '@InventoryDeviceRelID'
					,EquipmentInventoryID INT '@EquipmentInventoryID'
					,IMEI VARCHAR(50) '@IMEI'
					,ESN VARCHAR(50) '@ESN'
					,DeviceProvider VARCHAR(150) '@DeviceProvider'
					,DeviceSellerID INT '@DeviceSellerID'
					,DeviceWarrantyTypeMasterID INT '@DeviceWarrantyTypeMasterID'
					,DeviceWarrantyTermMasterID INT '@DeviceWarrantyTermMasterID'
					,InvoiceNumber VARCHAR(100) '@InvoiceNumber'
					,IMEI2 VARCHAR(50) '@IMEI2'
					,eSIM VARCHAR(50) '@eSIM'
					,IseSimSelected INT '@IseSimSelected'
					)

			EXEC sp_xml_removedocument @XMLHandle
		END

		------ UPDATE DEVICE INFORMATION -------        
		UPDATE MOXD
		SET MOXD.InventoryDeviceRelID = D.InventoryDeviceRelID
			,MOXD.EquipmentInventoryID = D.EquipmentInventoryID
			,MOXD.IMEI = D.IMEI
			,MOXD.ESN = D.ESN
			,MOXD.DeviceProvider = D.DeviceProvider
			,MOXD.DeviceSellerID = D.DeviceSellerID
			,MOXD.DeviceWarrantyTypeMasterID = D.DeviceWarrantyTypeMasterID
			,MOXD.DeviceWarrantyTermMasterID = D.DeviceWarrantyTermMasterID
			,MOXD.InvoiceNumber = D.InvoiceNumber
			,ChangedByID = @AddedByID
			,ChangedDateTime = GETDATE()
			,DeviceID = D.DeviceID
			,MOXD.DeviceXCarrierID = D.DeviceXCarrierID
			,MOXD.DeviceVendorID = D.DeviceVendorID
			,MOXD.DeviceConditionID = D.DeviceConditionID
			,MOXD.IMEI2 = D.IMEI2
			,MOXD.eSIM = D.eSIM
			,MOXD.IseSimSelected = D.IseSimSelected
		FROM MobilityOrderXDevices MOXD
		INNER JOIN @Devices D ON D.MobilityOrderXDeviceID = MOXD.MobilityOrderXDeviceID

		----- DELETE IF DEVICE HAS BEEN REMOVED -----------------        
		DELETE
		FROM MobilityOrderXDevices
		WHERE MobilityOrderXDeviceID NOT IN (
				SELECT MobilityOrderXDeviceID
				FROM @Devices
				)
			AND MobilityOrderID = @MobilityOrderID
			AND MobilityOrderItemID = @MobilityOrderItemID

		------------ INSERT IF NEW DEVICE ------------------        
		INSERT INTO MobilityOrderXDevices (
			OrderDeviceOptionsMasterID
			,MobilityOrderID
			,MobilityOrderItemID
			,DevicePricingCategoryMasterID
			,DeviceID
			,EquipmentInventoryID
			,InventoryDeviceRelID
			,IMEI
			,ESN
			,DeviceProvider
			,DeviceSellerID
			,DeviceWarrantyTypeMasterID
			,DeviceWarrantyTermMasterID
			,InvoiceNumber
			,AddedByID
			,ChangedByID
			,DeviceXCarrierID
			,DeviceVendorID
			,DeviceConditionID
			,IMEI2
			,eSIM
			,IseSimSelected
			)
		SELECT 1
			,@MobilityOrderID
			,@MobilityOrderItemID
			,@DevicePricingCategoryMasterID
			,@DeviceID
			,EquipmentInventoryID
			,InventoryDeviceRelID
			,IMEI
			,ESN
			,DeviceProvider
			,DeviceSellerID
			,DeviceWarrantyTypeMasterID
			,DeviceWarrantyTermMasterID
			,InvoiceNumber
			,@AddedByID
			,@AddedByID
			,DeviceXCarrierID
			,DeviceVendorID
			,DeviceConditionID
			,IMEI2
			,eSIM
			,IseSimSelected
		FROM @Devices
		WHERE MobilityOrderXDeviceID = 0

		SELECT @newDeviceVendorID = DeviceVendorID
			,@newDeviceConditionID = DeviceConditionID
		FROM MobilityOrderXDevices
		WHERE MobilityOrderItemID = @MobilityOrderItemID

		-- device history
		EXEC MobilityOrderItemHistory_DevicesInsert @MobilityOrderItemID = @MobilityOrderItemID
			,@DeviceID = @DeviceID
			,@IsInstallmentPlan = @IsInstallmentPlan
			,@DownPayment = @DownPayment
			,@PlanCost = @Cost
			,@PlanMargin = @Margin
			,@PlanPrice = @Price
			,@PlanMonths = @Term
			,@ROIOnCost = @ROIOnCost
			,@ROIOnPrice = @ROIOnPrice
			,@AddedByID = @AddedByID
			,@MonthlyCost = @MonthlyPaymentOnCost
			,@MonthlyPrice = @MonthlyPaymentOnPrice
			,@DeviceVendorID = @newDeviceVendorID
			,@DeviceConditionID = @newDeviceConditionID

		------------ UPDATE INSTALLMENT PLAN/PRICING INFORMATION TO DEVICE TABLE TOO -------------------        
		UPDATE MobilityOrderXDevices
		SET IsInstallmentPlan = @IsInstallmentPlan
			,DownPayment = @DownPayment
			,PlanCost = @Cost
			,PlanMargin = @Margin
			,PlanPrice = @Price
			,PlanMonths = @Term
			,ROIOnCost = @ROIOnCost
			,ROIOnPrice = @ROIOnPrice
			,ChangedDateTime = GETDATE()
		WHERE MobilityOrderID = @MobilityOrderID
			AND MobilityOrderItemID = @MobilityOrderItemID

		--/* NS-2021-08-27 -- fixed to set devicetypemaster & order description
		DECLARE @DeviceTypeMasterID INT

		SELECT @DeviceID = DeviceID
		FROM MobilityOrderXDevices
		WHERE MobilityOrderID = @MobilityOrderID
			AND MobilityOrderItemID = @MobilityOrderItemID

		IF (ISNULL(@DeviceID, 0) > 0)
		BEGIN
			SELECT @DeviceTypeMasterID = DTM.DeviceTypeMasterID
			FROM Devices D
			INNER JOIN DeviceTypeMaster DTM ON DTM.DeviceTypeMasterID = D.DeviceTypesMasterID
			WHERE DeviceID = @DeviceID

			UPDATE MobilityOrderXDevices
			SET DeviceTypeMasterID = @DeviceTypeMasterID
			WHERE MobilityOrderID = @MobilityOrderID
				AND MobilityOrderItemID = @MobilityOrderItemID
		END

		-- Dynamic order description update            
		IF ISNULL(@MobilityOrderID, 0) > 0
		BEGIN
			EXEC OrderDescriptionInsertorUpdate @MobilityOrderID
		END

		--*/
		DECLARE @IsEquipmentReady BIT

		SELECT @IsEquipmentReady = dbo.MobilityCharges_IsEquipmentReady(@MobilityOrderItemID);

		/* DISABLE ONLY THE CHARGES THAT ARE NOT CHARGED - SP 08/06/20201 */
		UPDATE MobilityOrderCharges
		SET IsActive = 0
			,ChangedByID = @AddedByID
			,ChangedDateTime = GETDATE()
		WHERE MobilityOrderItemID = @MobilityOrderItemID
			AND HasCharged < 2

		/* RE-INSERT EQUIPMENT CHARGES IF THEY ARE NOT SHIPPED YET - SP 08/06/20201 */
		IF @IsEquipmentReady = 0
		BEGIN
			IF @IsInstallmentPlan = 1
			BEGIN
				--- INSERT DOWN PAYMENT AND MONTHLY EMI CHARGES ----        
				---- DOWN PAYMENT -----        
				IF @DownPayment > 0
				BEGIN
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
					SELECT @MobilityOrderID
						,@MobilityOrderItemID
						,@CustomerXProductCatalogID
						,@DeviceID
						,5
						,'One Time'
						,'DWNPAY'
						,dbo.GetInstallmentNDownPaymentChargeDescByDevice(@DeviceID, 0, 'DWNPAY')
						,1
						,@DownPayment
						,NULL
						,@DownPayment
						,1
						,1
						,@AddedByID
						,@AddedByID
				END

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
					)
				SELECT @MobilityOrderID
					,@MobilityOrderItemID
					,@CustomerXProductCatalogID
					,@DeviceID
					,5
					,'Monthly'
					,'MINSTPLAN'
					,dbo.GetInstallmentNDownPaymentChargeDescByDevice(@DeviceID, @Term, 'MINSTPLAN')
					,@Quantity
					,@MonthlyPaymentOnCost
					,NULL
					,@MonthlyPaymentOnPrice
					,@Term
					,1
					,@AddedByID
					,@AddedByID
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
					)
				SELECT @MobilityOrderID
					,@MobilityOrderItemID
					,@CustomerXProductCatalogID
					,@DeviceID
					,5
					,@ChargeType
					,@USOC
					,@ChargeDescription
					,@Quantity
					,@Cost
					,@Margin
					,@Price
					,1
					,1
					,@AddedByID
					,@AddedByID
			END
		END

		-- COMMENTED BY NS        
		--EXEC [MobilityOrders_UpdateShipping]  @MobilityOrderID, @MobilityOrderItemID,         
		--  @ExistingShippingAddressID, @CustomerID, @AttentionToName,        
		--  @Address1, @Address2,  Address3, @City, @StateMasterID, @Zipcode,        
		--  @CountryMasterID, @AddedByID,        
		--  @ShippingTypeID, 1          
		----------- INSERT CHARGES -----------        
		SET @XMLData = @ChargesXML

		IF (@XMLData <> '')
		BEGIN
			-- order item plans/addons and additional charge history
			EXEC [MobilityOrderItemHistory_ChargesInsert] @MobilityOrderItemID = @MobilityOrderItemID
				,@OrderPlans = ''
				,@ChargesXML = @ChargesXML
				,@AddedByID = @AddedByID

			DECLARE @Charges TABLE (
				MobilityOrderID INT
				,MobilityOrderItemID INT
				,CustomerXProductCatalogID INT
				,CategoryPlanID INT
				,ProductCatalogCategoryMasterID INT
				,[ChargeType] VARCHAR(50)
				,[USOC] VARCHAR(50)
				,[ChargeDescription] VARCHAR(250)
				,[Quantity] INT
				,[Cost] DECIMAL(18, 2)
				,[Margin] DECIMAL(18, 2)
				,[Price] DECIMAL(18, 2)
				,TimesToBill INT
				,IsActive BIT
				,AddedByID INT
				,ChangedByID INT
				,HasCharged INT
				)

			EXEC sp_xml_preparedocument @XMLHandle OUTPUT
				,@XMLData

			INSERT INTO @Charges
			SELECT @MobilityOrderID
				,@MobilityOrderItemID
				,0
				,0
				,0
				,ChargeType
				,USOC
				,ChargeDescription
				,Quantity
				,Cost
				,Margin
				,Price
				,1
				,1
				,@AddedByID
				,@AddedByID
				,ISNULL(HasCharged, 0)
			FROM OPENXML(@XMLHandle, '/ROOT/row', 2) WITH (
					ChargeType VARCHAR(50) '@ChargeType'
					,USOC VARCHAR(50) '@USOC'
					,ChargeDescription VARCHAR(250) '@ChargeDescription'
					,Quantity INT '@Quantity'
					,Cost DECIMAL(18, 2) '@Cost'
					,Margin DECIMAL(18, 2) '@Margin'
					,Price DECIMAL(18, 2) '@Price'
					,HasCharged INT '@HasCharged'
					)

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
			SELECT MobilityOrderID
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
			FROM @Charges
			WHERE HasCharged < 2

			EXEC sp_xml_removedocument @XMLHandle
		END

		IF (ISNULL(CAST(@AdditionalFieldsXML AS VARCHAR), '') <> '')
		BEGIN
			EXEC uspAdditionalFieldsByMobilityOrderItemAndDevices @AdditionalFieldsXML
				,@MobilityOrderItemID
				,@AddedByID
				,1
		END

		----- UPDATE LINE STATUS ---------        
		IF @LineStatusMasterID < 7000
		BEGIN
			---- OTHER THAN CLOSED ----------        
			UPDATE MobilityOrderItems
			SET LineStatusMasterID = @LineStatusMasterID
				,LineSubStatusMasterID = @LineSubStatusMasterID
				,ChangedByID = @AddedByID
				,ContractStartDate = @ContractStartDate
				,ContractEndDate = @ContractEndDate
				,TermMasterID = @TermMasterID
				,AppleID = @AppleID
				,ChangedDateTime = GETDATE()
				,invoiceDate = (
					CASE 
						WHEN @Channel = 'Wholesale Aggregator'
							THEN dbo.GetBillCycleDate()
						ELSE NULL
						END
					)
				,iBillerDate = @iBillerDate
			WHERE MobilityOrderItemID = @MobilityOrderItemID

			-- SET HAS CHARGED TO TRUE WHEN EQUIPMENT SHIPMNET READY ---
			IF (
					@LineStatusMasterID = 5051
					AND @IsEquipmentReady = 0
					AND @Channel = 'Wholesale Aggregator'
					)
			BEGIN
				EXEC MobilityOrderCharges_SetHasChargedFlag @MobilityOrderItemID = @MobilityOrderItemID
					,@AddedByID = @AddedByID

				-- Inventory generation for Device charges capture
				EXEC Inventory_Generation @MobilityOrderID
					,@MobilityOrderItemID
					,@AddedByID
			END
		END
		ELSE
		BEGIN
			---- WHEN ORDER IS CLOSED -----------              
			IF @IsAutoProvisioned = 0
			BEGIN
				-- get substatus when LineStatus is completed   
				IF (ISNULL(@LineSubStatusMasterID, 0) = 0)
				BEGIN
					SELECT @LineSubStatusMasterID = LineSubStatusMasterID
					FROM LineSubStatusMaster
					WHERE LineStatusMasterID = 7001
						AND LineSubStatus = 'Manual'
				END
			END

			UPDATE MobilityOrderItems
			SET LineStatusMasterID = @LineStatusMasterID
				,LineSubStatusMasterID = @LineSubStatusMasterID
				,ChangedByID = @AddedByID
				,ContractStartDate = @ContractStartDate
				,ContractEndDate = @ContractEndDate
				,TermMasterID = @TermMasterID
				,AppleID = @AppleID
				,ChangedDateTime = GETDATE()
				,invoiceDate = (
					CASE 
						WHEN @Channel = 'Wholesale Aggregator'
							THEN dbo.GetBillCycleDate()
						ELSE NULL
						END
					)
				,iBillerDate = @iBillerDate
				,ItemClosedDateTime = GETDATE() -- Update the Closed Date Time. 01/19/23 by SP
			WHERE MobilityOrderItemID = @MobilityOrderItemID

			/* Order Completed  */
			INSERT INTO orderBillingTransistionLog (
				mobilityOrderItemID
				,stateDescription
				,addedByID
				)
			SELECT @MobilityOrderItemID
				,'Order Item - Completed'
				,@AddedByID

			--- GENERATE SPARE DEVICE INVENTORY FOR THIS CUSTOMER ---        
			EXEC Inventory_Generation @MobilityOrderID
				,@MobilityOrderItemID
				,@AddedByID

			-- CHECK for vCom Service Provider account and Replensihment flag to add device to store
			DECLARE @vComSPCustomerID INT
				,@ReplenishmentCCAID INT
				,@orderForCustomer INT

			SELECT TOP 1 @vComSPCustomerID = customer_id
			FROM customer c(NOLOCK)
			WHERE c.customer_name = 'vCom Solutions - Service Provider'

			IF @CustomerID = @vComSPCustomerID
				AND EXISTS (
					SELECT TOP 1 1
					FROM MobilityOrderItems
					WHERE MobilityOrderItemID = @MobilityOrderItemID
						AND ISNULL(ReplenishmentCCAID, 0) <> 0
					)
			BEGIN
				INSERT INTO EquipmentInventory (
					[InventoryType]
					,[DeviceTypeMasterID]
					,[EquipmentStatusMasterID]
					,[ModelName]
					,[Make]
					,[ModelNumber]
					,[Storage]
					,[Color]
					,[SIM]
					,[Cost]
					,[Margin]
					,[Price]
					,[AddedByID]
					,[AddedDateTime]
					,[IsActive]
					,
					--nullable
					[InventoryTypeID]
					,[DeviceID]
					,[Size]
					,[Shelf]
					,[ESN]
					,[MEID]
					,[ICCID]
					,[ShippingCost]
					,[ShippingPrice]
					,[DeviceSellerID]
					,[DeviceWarrantyTypeMasterID]
					,[DeviceWarrantyTermMasterID]
					,[InvoiceNumber]
					,[MobilityOrderID]
					,[MobilityOrderItemID]
					,[vManagerTicketNumber]
					,[OrderNumber]
					,[OrderDate]
					,[Note]
					,[CarrierID]
					,IsUnlocked
					,DeviceXCarrierID
					,DeviceConditionID
					,DeviceVendorID
					,CustomerID
					,CustomerXCarrierAccountsID
					,DEPValue
					--,IsEnrolled
					,EquipmentOrderedDate
					,EquipmentPurchasedDate
					,WarrantyDate
					,IseSimSelected
					,EID
					,IMEI2
					,VendorDesc 
					)
				SELECT '' AS [InventoryType]
					,0 AS [DeviceTypeMasterID]
					,1 AS [EquipmentStatusMasterID] -- AVAILABLE
					,'' AS [ModelName]
					,NULL AS [Make]
					,NULL AS [ModelNumber]
					,NULL AS [Storage]
					,NULL AS [Color]
					,'' AS [Sim] -- ask
					,PlanCost AS Cost
					,PlanMargin AS Margin
					,PlanPrice AS Price
					,@AddedByID AS [AddedByID]
					,GETDATE() AS [AddedDateTime]
					,1 AS [IsActive]
					,
					--nullable
					NULL AS [InventoryTypeID]
					,moxd.DeviceID
					,NULL AS [Size]
					,'' AS [Shelf]
					,ESN
					,IMEI AS MEID
					,ICCID
					,0 AS [ShippingCost]
					,0 AS [ShippingPrice]
					,DeviceSellerID
					,DeviceWarrantyTypeMasterID
					,moxd.DeviceWarrantyTermMasterID
					,InvoiceNumber
					,NULL AS MobilityOrderID
					,NULL AS MobilityOrderItemID
					,NULL AS [vManagerTicketNumber]
					,moxd.MobilityOrderID AS [OrderNumber] -- ASK
					,NULL AS [OrderDate]
					,NULL AS [Note]
					,mo.CarrierID
					,CASE 
						WHEN mo.CarrierID IS NULL
							THEN 1
						ELSE 0
						END AS IsUnlocked
					,moxd.DeviceXCarrierID
					,moxd.DeviceConditionID
					,moxd.DeviceVendorID
					,cca.CustomerID AS CustomerID
					,cca.CustomerXCarrierAccountsID AS CustomerXCarrierAccountsID
					,DEPValue
					--,IsEnrolled
					,mo.AddedDateTime AS EquipmentOrderedDate
					,GETDATE() AS EquipmentPurchasedDate -- ASK
					,DATEADD(DAY, ISNULL(dtm.Days, 0), GETDATE()) AS WarrantyDate
					,IseSimSelected
					,eSIM AS EID
					,IMEI2
					,dbo.GetDeviceVendorByCarrier(dxc.DeviceVendorID, mo.CarrierID) AS VendorDesc
				FROM MobilityOrderXDevices moxd(NOLOCK)
				JOIN MobilityOrderItems moi(NOLOCK) ON moi.MobilityOrderItemID = moxd.MobilityOrderItemID
					AND moi.IsActive = 1
				JOIN MobilityOrders mo(NOLOCK) ON mo.MobilityOrderID = moi.MobilityOrderID
				JOIN CustomerXCarrierAccounts cca(NOLOCK) ON cca.CustomerXCarrierAccountsID = moi.ReplenishmentCCAID
					AND cca.IsActive = 1
				LEFT JOIN DeviceWarrantyTermMaster dtm (NOLOCK) ON moxd.DeviceWarrantyTermMasterID = dtm.DeviceWarrantyTermMasterID
					AND dtm.IsActive = 1
				LEFT JOIN DeviceXCarrier dxc (NOLOCK)  ON dxc.DeviceXCarrierID = moxd.DeviceXCarrierID
				--LEFT JOIN DeviceVendor dv on dv.deviceVendorID = dxc.DeviceVendorID
				WHERE moxd.MobilityOrderID = @MobilityOrderID
					AND moxd.MobilityOrderItemID = @MobilityOrderItemID

					
				-- Check if Device exists in DeviceXCarrier and add if not exists.
			END
		END

		-- Capture booking information : Sridhar: Dt: 03/03/2020  
		EXEC uspManageBookingAgainstOrderItem @MobilityOrderItemID
			,@LineStatusMasterID

		--------- AUTO UPDATE ORDER STAGE --------         
		EXEC OrderStage_AutoUpdate @MobilityOrderID
			,@MobilityOrderItemID
			,@AddedByID

		---------------------------------------------        
		COMMIT TRANSACTION

		SET @StatusMessage = 'success'
	END TRY

	BEGIN CATCH
		IF @@TRANCOUNT > 0
		BEGIN
			ROLLBACK TRANSACTION

			SET @StatusMessage = 'something went wrong!'
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

		EXEC dbo.uspSendDBErrorEmail @Subject = 'MobilityOrders_SpareOrderConfig'
			,@ErrorMessage = @eMessage
			,@ErrorProcedure = @eProcedure
			,@ErrorLine = @eLine
			,@QueryParams = @XMLData
			,@UserID = @AddedByID
	END CATCH

	SELECT @StatusMessage AS StatusMessage
END
GO
