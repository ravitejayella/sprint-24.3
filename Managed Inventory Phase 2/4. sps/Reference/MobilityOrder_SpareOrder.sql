USE [mobility]
GO
/****** Object:  StoredProcedure [dbo].[MobilityOrder_SpareOrder]    Script Date: 3/20/2024 3:32:14 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================        
-- Author:  Srikanth        
-- ALTER date: <ALTER Date,,>        
-- Description: <Description,,>        
-- =============================================  
-- Author:  Nagasai     
-- ALTER date: 02-12-2021     
-- Description: device catalog changes v21     
-- ============================================= 
-- Author:  Nagasai                            
-- ALTER date: 05-06-2021                           
-- Description:  added ibiller date
-- ============================================= 
-- Author:  Nagasai                            
-- ALTER date: 03-14-2022                           
-- Description: adding carrier account to spare order
-- ============================================= 
-- Author:  Nagasai                            
-- ALTER date: 06-10-2022                           
-- Description: CASE -1712 - Adding sim charges at Order Level
-- ============================================= 
-- Author:  Nagasai Mudara  
-- Modified date: 09.05.2022
-- Description: Overhaul Mobile Order Notifications
-- SD CASE - 1689
-- ================================================= 
-- Author:  Nagasai Mudara  
-- Modified date: 02.09.2023
-- Description: Add Address 3 Field to Shipping Addresses
-- SD CASE - 5743
-- ================================================= 
-- Author:  Geethika/Nagasai            
-- ALTER date: 03-20-2023       
-- Description: SIM charge not in Spare Order (Order 86315) GardaWorld
-- SD Case - 6401
-- =============================================  
/*
EXEC MobilityOrder_SpareOrder @CustomerID = 20, @CarrierAccountID= 14, @CustomerXCarrierAccountsID = 16, @AccountID=135422, @CarrierID=122, @OrderDescription='Spare Device DB Test 1', @DeviceXML='<ROOT><row DeviceTypeID="0" DevicePricingMasterID="0" DeviceID="4801" DeviceVendorID="100" DeviceXCarrierID="7668" DeviceConditionID="100" Qty="2" Cost="1099.99" Margin="0" Price="1099.99" IsInstallmentPlan="0" DownPayment="0" ROIOnCost="0" ROIOnPrice="0" Term="0" MonthlyPaymentOnCost="0" MonthlyPaymentOnPrice="0" CustomerXProductCatalogID="467141" ChargeType="One Time" USOC="MNEQUIP" ChargeDescription="Apple iPhone 13 Pro Max (Graphite 128GB)" /></ROOT>',
@ChargesXML = '<ROOT><row MobilityOrderChargeID="0" CustomerXProductCatalogID="0" CategoryPlanID="0" ProductCatalogCategoryMasterID="0" ChargeType="One Time" USOC="SHIP4" ChargeDescription="Ground Shipping & Handling Charge" Quantity="1" Cost="20" Margin="0" Price="20"/></ROOT>',
@AddedByID= 273    , @ExistingShippingAddressID = 1025
*/
ALTER PROCEDURE [dbo].[MobilityOrder_SpareOrder] @CustomerID INT
	,@AccountID INT
	,@CarrierID INT
	,@CarrierAccountID INT
	,@CustomerXCarrierAccountsID INT = NULL
	,@OrderDescription VARCHAR(255) = NULL
	,@DeviceXML VARCHAR(MAX)
	,@ExistingShippingAddressID INT
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
	@ChargesXML VARCHAR(MAX) = NULL
	,@TicketReferenceNumber VARCHAR(50) = NULL
	,@RequestorID INT = NULL
	,@UserFirstName VARCHAR(250) = NULL
	,@UserLastName VARCHAR(250) = NULL
	,@UserTitle VARCHAR(50) = NULL
	,@UserEmail VARCHAR(250) = NULL
	,@CopyEndUser BIT = 0
AS
BEGIN
	BEGIN TRANSACTION

	DECLARE @IsRetail BIT = 0
		,@MobilityOrderID INT
		,@MobilityOrderItemID INT
		,@OrderTypeID INT
		,@LineStatusMasterID INT

	SELECT @OrderTypeID = OrderTypeMasterID
	FROM OrderTypeMaster
	WHERE OrderType = 'Spare'

	SELECT @IsRetail = CASE 
			WHEN Channel = 'Retail'
				THEN 1
			ELSE 0
			END
	FROM MobilityCarrierMaster
	WHERE CarrierID = @CarrierID

	--SET @CustomerXCarrierAccountsID = ISNULL(@CustomerXCarrierAccountsID, dbo.uspGetCustomerXCarrierAccountID(@CustomerID, @CarrierID, @CarrierAccountID))

	--- INSERT MAIN ORDER ---   
	EXEC [MobilityOrders_InsertNewOrder] @CustomerID = @CustomerID
		,@AccountID = @AccountID
		,@CarrierID = @CarrierID
		,@CarrierAccountID = @CarrierAccountID
		,@TicketReferenceNumber = @TicketReferenceNumber
		,@OrderTypeID = @OrderTypeID
		,@OrderDescription = @OrderDescription
		,@AddedByID = @AddedByID
		,@RequestorID = @RequestorID
		--,@CustomerXCarrierAccountsID = @CustomerXCarrierAccountsID
		,@MobilityOrderID = @MobilityOrderID OUTPUT
		,@MobilityOrderItemID = @MobilityOrderItemID OUTPUT

	SELECT @LineStatusMasterID = LineStatusMasterID
	FROM LineStatusMaster
	WHERE StatusCode = 'MPR'

	---- UPDATE SERVICE INFORMATION ---- (LINE NUMBER/INVENTORY NAME/LINE STATUS TO NEW -----        
	UPDATE MobilityOrderItems
	SET LineStatusMasterID = @LineStatusMasterID
		,ShippingTypeID = @ShippingTypeID
		,UserFirstName = @UserFirstName
		,UserLastName = @UserLastName
		,UserTitle = @UserTitle
		,UserEmail = @UserEmail
		,AttentionToName = @AttentionToName
		,CopyEndUser = @CopyEndUser
		,OrderSubTypeMasterID = 1
		,iBillerDate = (
			CASE 
				WHEN @IsRetail = 0
					THEN dbo.GetBillCycleDate()
				ELSE NULL
				END
			)
	WHERE MobilityOrderItemID = @MobilityOrderItemID

	--EXEC MobilityOrderItemsXUpdateNotificationtype @MobilityOrderID,@MobilityOrderItemID,@LineStatusMasterID    
	EXEC MobileNotificationCriteria_InsertLog @MobilityOrderID = @MobilityOrderID
		,@MobilityOrderItemID = @MobilityOrderItemID
		,@AddedByID = @AddedByID

	IF (ISNULL(@ShippingTypeID, 0) > 0) --- modified by NS, checking shipping type           
	BEGIN
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
	END
	ELSE
	BEGIN --- modified by NS, updating address id and  shipping type  
		DECLARE @AddressRelType CHAR(1)

		SELECT @AddressRelType = RelType
		FROM CustomerAddress
		WHERE CustomerAddressID = @ExistingShippingAddressID

		UPDATE MobilityOrderItems
		SET CustomerShippingAddressID = @ExistingShippingAddressID
			,AttentionToName = @AttentionToName
			,AddressRelType = ISNULL(@AddressRelType, '')
		WHERE MobilityOrderID = @MobilityOrderID
			AND MobilityOrderItemID = @MobilityOrderItemID
	END

	--SELECT @MobilityOrderItemID        
	--- LOOP THROUGH EACH RECORD AND INSERT DEVICE INFORMATION ----         
	DECLARE @Devices TABLE (
		DeviceTypeID INT
		,DevicePricingMasterID INT
		,DeviceID INT
		,DeviceXCarrierID INT
		,DeviceConditionID INT
		,DeviceVendorID INT
		,Qty INT
		,Cost DECIMAL(18, 2)
		,Margin DECIMAL(18, 2)
		,Price DECIMAL(18, 2)
		,IsInstallmentPlan BIT
		,DownPayment DECIMAL(18, 2)
		,ROIOnCost DECIMAL(18, 2)
		,ROIOnPrice DECIMAL(18, 2)
		,Term INT
		,MonthlyPaymentOnCost DECIMAL(18, 2)
		,MonthlyPaymentOnPrice DECIMAL(18, 2)
		,CustomerXProductCatalogID INT
		,ChargeType VARCHAR(50)
		,USOC VARCHAR(50)
		,ChargeDescription VARCHAR(250)
		)
	DECLARE @XMLHandle INT
		,@XMLData NVARCHAR(MAX)

	--SET @XMLData = @DeviceXML        
	SET @XMLData = REPLACE(@DeviceXML, '&', '&amp;');

	--SET @XMLData = REPLACE(@XMLData, '„','&quot;')        
	IF (@XMLData <> '')
	BEGIN
		EXEC sp_xml_preparedocument @XMLHandle OUTPUT
			,@XMLData

		INSERT INTO @Devices
		SELECT DeviceTypeID
			,DevicePricingMasterID
			,DeviceID
			,DeviceXCarrierID
			,DeviceConditionID
			,DeviceVendorID
			,Qty
			,Cost
			,Margin
			,Price
			,IsInstallmentPlan
			,DownPayment
			,ROIOnCost
			,ROIOnPrice
			,Term
			,MonthlyPaymentOnCost
			,MonthlyPaymentOnPrice
			,CustomerXProductCatalogID
			,ChargeType
			,USOC
			,ChargeDescription
		FROM OPENXML(@XMLHandle, '/ROOT/row', 2) WITH (
				DeviceTypeID INT '@DeviceTypeID'
				,DevicePricingMasterID INT '@DevicePricingMasterID'
				,DeviceID INT '@DeviceID'
				,DeviceXCarrierID INT '@DeviceXCarrierID'
				,DeviceConditionID INT '@DeviceConditionID'
				,DeviceVendorID INT '@DeviceVendorID'
				,Qty INT '@Qty'
				,Cost DECIMAL(18, 2) '@Cost'
				,Margin DECIMAL(18, 2) '@Margin'
				,Price DECIMAL(18, 2) '@Price'
				,IsInstallmentPlan BIT '@IsInstallmentPlan'
				,DownPayment DECIMAL(18, 2) '@DownPayment'
				,ROIOnCost DECIMAL(18, 2) '@ROIOnCost'
				,ROIOnPrice DECIMAL(18, 2) '@ROIOnPrice'
				,Term INT '@Term'
				,MonthlyPaymentOnCost DECIMAL(18, 2) '@MonthlyPaymentOnCost'
				,MonthlyPaymentOnPrice DECIMAL(18, 2) '@MonthlyPaymentOnPrice'
				,CustomerXProductCatalogID INT '@CustomerXProductCatalogID'
				,ChargeType VARCHAR(50) '@ChargeType'
				,USOC VARCHAR(50) '@USOC'
				,ChargeDescription VARCHAR(250) '@ChargeDescription'
				)

		EXEC sp_xml_removedocument @XMLHandle
	END

	---- INSERT DEVICES XML ----         
	DECLARE @DeviceTypeID INT
		,@DevicePricingMasterID INT
		,@DeviceID INT
		,@Qty INT
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

	DECLARE DeviceCursor CURSOR
	FOR
	SELECT D.DeviceTypesMasterID
		,dbo.uspGetPricingCategoryID(DD.Price) AS DevicePricingCategoryMasterID
		,DD.DeviceID
		,DD.Qty
		,DD.Cost
		,DD.Margin
		,DD.Price
		,DD.IsInstallmentPlan
		,DD.DownPayment
		,ROIOnCost
		,ROIOnPrice
		,Term
		,MonthlyPaymentOnCost
		,MonthlyPaymentOnPrice
		,CustomerXProductCatalogID
		,ChargeType
		,USOC
		,ChargeDescription
		,HasPreOrder = CASE 
			WHEN DC.DeviceStatusID = 300
				THEN 1
			ELSE 0
			END
		,DC.DeviceXCarrierID
		,DC.DeviceConditionID
		,DD.DeviceVendorID -- 4686
	FROM @Devices DD
	INNER JOIN Devices D ON D.DeviceID = DD.DeviceID
	LEFT JOIN DeviceXCarrier DC ON DC.DeviceXCarrierID = DD.DeviceXCarrierID

	OPEN DeviceCursor

	FETCH NEXT
	FROM DeviceCursor
	INTO @DeviceTypeID
		,@DevicePricingMasterID
		,@DeviceID
		,@Qty
		,@Cost
		,@Margin
		,@Price
		,@IsInstallmentPlan
		,@DownPayment
		,@ROIOnCost
		,@ROIOnPrice
		,@Term
		,@MonthlyPaymentOnCost
		,@MonthlyPaymentOnPrice
		,@CustomerXProductCatalogID
		,@ChargeType
		,@USOC
		,@ChargeDescription
		,@HasPreOrder
		,@DeviceXCarrierID
		,@DeviceConditionID
		,@DeviceVendorID

	---- LOOP THROUGH EACH RECORD AND INSERT MULTIPLE DEVICES IF QUANTITY IS GREATER THAN ONE ------         
	WHILE @@FETCH_STATUS = 0
	BEGIN
		DECLARE @cnt INT = 0;

		IF @MobilityOrderItemID IS NULL
		BEGIN
			--SELECT @HasPreOrder        
			INSERT INTO MobilityOrderItems (
				MobilityOrderID
				,LineStatusMasterID
				,LineSubStatusMasterID
				,AddedByID
				,ChangedByID
				,OrderSubTypeMasterID
				,iBillerDate
				)
			VALUES (
				@MobilityOrderID
				,CASE 
					WHEN @HasPreOrder = 1
						THEN 4001
					ELSE @LineStatusMasterID
					END
				,CASE 
					WHEN @HasPreOrder = 1
						THEN 10001
					ELSE 0
					END
				,@AddedByID
				,@AddedByID
				,1
				,-- New,
				(
					CASE 
						WHEN @IsRetail = 0
							THEN dbo.GetBillCycleDate()
						ELSE NULL
						END
					)
				)

			SET @MobilityOrderItemID = @@IDENTITY

			---- UPDATE SERVICE INFORMATION ---- (LINE NUMBER/INVENTORY NAME/LINE STATUS TO NEW -----      
			---- ADDED BY NS - 2022-06-10 -- for other order details
			UPDATE MobilityOrderItems
			SET ShippingTypeID = @ShippingTypeID
				,UserFirstName = @UserFirstName
				,UserLastName = @UserLastName
				,UserTitle = @UserTitle
				,UserEmail = @UserEmail
				,AttentionToName = @AttentionToName
				,CopyEndUser = @CopyEndUser
				,OrderSubTypeMasterID = 1
				,iBillerDate = (
					CASE 
						WHEN @IsRetail = 0
							THEN dbo.GetBillCycleDate()
						ELSE NULL
						END
					)
			WHERE MobilityOrderItemID = @MobilityOrderItemID

			IF (ISNULL(@ShippingTypeID, 0) > 0) --- modified by NS, checking shipping type           
			BEGIN
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
			END
			ELSE
			BEGIN --- modified by NS, updating address id and  shipping type  
				DECLARE @AddressRelItemType CHAR(1)

				SELECT @AddressRelItemType = RelType
				FROM CustomerAddress
				WHERE CustomerAddressID = @ExistingShippingAddressID

				UPDATE MobilityOrderItems
				SET CustomerShippingAddressID = @ExistingShippingAddressID
					,AttentionToName = @AttentionToName
					,AddressRelType = ISNULL(@AddressRelItemType, '')
				WHERE MobilityOrderID = @MobilityOrderID
					AND MobilityOrderItemID = @MobilityOrderItemID
			END
		END
		ELSE
		BEGIN
			-- Print  @MobilityOrderItemID         
			--SELECT @HasPreOrder         
			EXEC MobilityOrderItemHistory_Insert @LineStatusMasterID = @LineStatusMasterID
				,@LineSubStatusMasterID = 0
				,@MobilityOrderItemID = @MobilityOrderItemID
				,@AddedByID = @AddedByID

			UPDATE MobilityOrderItems
			SET LineStatusMasterID = CASE 
					WHEN @HasPreOrder = 1
						THEN 4001
					ELSE @LineStatusMasterID
					END
				,LineSubStatusMasterID = CASE 
					WHEN @HasPreOrder = 1
						THEN 10001
					ELSE 0
					END
				,ChangedDateTime = getdate()
				,ChangedByID = @AddedByID
				,UserFirstName = @UserFirstName
				,UserLastName = @UserLastName
				,UserTitle = @UserTitle
				,UserEmail = @UserEmail
				,AttentionToName = @AttentionToName
				,CopyEndUser = @CopyEndUser
			WHERE MobilityOrderItemID = @MobilityOrderItemID
		END

		WHILE @cnt < @Qty
		BEGIN
			------------- INSERT INTO THE MOBILITY ORDER X DEVICES -----------        
			INSERT INTO MobilityOrderXDevices (
				OrderDeviceOptionsMasterID
				,MobilityOrderID
				,MobilityOrderItemID
				,DevicePricingCategoryMasterID
				,DeviceID
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
				,DeviceXCarrierID
				,DeviceConditionID
				,DeviceVendorID
				)
			VALUES (
				1
				,@MobilityOrderID
				,@MobilityOrderItemID
				,@DevicePricingMasterID
				,@DeviceID
				,@Cost
				,@Margin
				,@Price
				,@IsInstallmentPlan
				,@DownPayment
				,@Term
				,@ROIOnCost
				,@ROIOnPrice
				,@AddedByID
				,@AddedByID
				,@DeviceXCarrierID
				,@DeviceConditionID
				,@DeviceVendorID
				)

			SET @cnt = @cnt + 1;
		END;

		--------- INSERT INTO MOBILITY ORDER CHARGES -----------------        
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
				,@Qty
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
				,@Qty
				,@Cost
				,@Margin
				,@Price
				,1
				,1
				,@AddedByID
				,@AddedByID
		END

		-- NS - 2022-06-10 - CASE -1712 - INSERT SIM Charges
		IF (@IsRetail = 0) -- ONLY FOR Aggergator Carrier 
		BEGIN
			DECLARE @SimCharges TABLE (
				ChargeID INT
				,USOC VARCHAR(50)
				,ChargeType VARCHAR(50)
				,Name VARCHAR(255)
				,Description VARCHAR(255)
				,Cost DECIMAL(19, 2)
				,Margin DECIMAL(19, 2)
				,Price DECIMAL(19, 2)
				,IsCustom BIT
				,SortOrder INT
				)

			-- delete sim charges
			DELETE
			FROM @SimCharges

			INSERT INTO @SimCharges
			EXEC [Charges_GetOtherOrderCharges] @CustomerID = @CustomerID
				,@CarrierAccountID = @CarrierAccountID
				,@ChannelType = @IsRetail

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
				,0
				,0
				,0
				,ChargeType
				,USOC
				,Description
				,@Qty
				,Cost
				,Margin
				,Price
				,1
				,1
				,@AddedByID
				,@AddedByID
			FROM @SimCharges
			WHERE USOC = CASE 
					WHEN @DeviceTypeID = 15
						THEN 'WWSIM'
					ELSE 'MNSIM'
					END
		END

		SET @MobilityOrderItemID = NULL

		FETCH NEXT
		FROM DeviceCursor
		INTO @DeviceTypeID
			,@DevicePricingMasterID
			,@DeviceID
			,@Qty
			,@Cost
			,@Margin
			,@Price
			,@IsInstallmentPlan
			,@DownPayment
			,@ROIOnCost
			,@ROIOnPrice
			,@Term
			,@MonthlyPaymentOnCost
			,@MonthlyPaymentOnPrice
			,@CustomerXProductCatalogID
			,@ChargeType
			,@USOC
			,@ChargeDescription
			,@HasPreOrder
			,@DeviceXCarrierID
			,@DeviceConditionID
			,@DeviceVendorID
	END

	CLOSE DeviceCursor

	DEALLOCATE DeviceCursor

	---- UPDATE MobilityOrders to Confirm ------        
	UPDATE MobilityOrders
	SET OrderStageID = CASE 
			WHEN ipath.dbo.[GetHasApprovalWorkflow](@RequestorID, @OrderTypeID) = 1
				THEN 8001
			ELSE 2001
			END --- (NEW)                 
	WHERE MobilityOrderID = @MobilityOrderID

	IF (ipath.dbo.[GetHasApprovalWorkflow](@RequestorID, @OrderTypeID) = 1)
	BEGIN
		--Add to email notification LOG --ANIL
		EXEC MobilityOrderItemsXUpdateNotificationtype @MobilityOrderID
			,NULL
			,10 --To set approval notification type     
	END

	DECLARE @AddressID INT

	/*     
  IF(ISNULL(@ExistingShippingAddressID, 0) <= 0)        
   BEGIN        
    EXEC CustomerAddress_Insert  @CustomerID, @AttentionToName,        
      @Address1, @Address2,@Address3, @City, @StateMasterID, @Zipcode, @CountryMasterID, 'S', 1,         
      @AddedByID, @AddressID OUTPUT        
      SELECT @ExistingShippingAddressID = @AddressID    	  
   END        
        
  UPDATE MobilityOrderItems        
   SET CustomerShippingAddressID = @ExistingShippingAddressID, 
    ShippingTypeID = @ShippingTypeID        
  WHERE MobilityOrderID = @MobilityOrderID         
    */
	IF (ISNULL(@ShippingTypeID, 0) > 0) --- modified by NS, checking shipping type           
	BEGIN
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
	END
	ELSE
	BEGIN --- modified by NS, updating address id and  shipping type                      
		UPDATE MobilityOrderItems
		SET CustomerShippingAddressID = @ExistingShippingAddressID
			,AttentionToName = @AttentionToName
			,ShippingTypeID = @ShippingTypeID
		WHERE MobilityOrderID = @MobilityOrderID
			AND MobilityOrderItemID = @MobilityOrderItemID
	END

	--  PRINT @ChargesXML    
	----------- INSERT CHARGES -----------        
	-- SET @XMLData = REPLACE(@ChargesXML, '&', '&amp;'); --@ChargesXML          
	SET @XMLData = REPLACE(@ChargesXML, '&', '&amp;');

	IF (@XMLData <> '')
	BEGIN
		DECLARE @Charges TABLE (
			[ChargeType] VARCHAR(50)
			,[USOC] VARCHAR(50)
			,[ChargeDescription] VARCHAR(250)
			,[Quantity] INT
			,[Cost] DECIMAL(18, 2)
			,[Margin] DECIMAL(18, 2)
			,[Price] DECIMAL(18, 2)
			)

		EXEC sp_xml_preparedocument @XMLHandle OUTPUT
			,@XMLData

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
			,NULL
			,0
			,0
			,0
			,ChargeType
			,USOC
			,ChargeDescription
			,ISNULL(Quantity, 1)
			,Cost
			,Margin
			,Price
			,1
			,1
			,@AddedByID
			,@AddedByID
		FROM OPENXML(@XMLHandle, '/ROOT/row', 2) WITH (
				ChargeType VARCHAR(50) '@ChargeType'
				,USOC VARCHAR(50) '@USOC'
				,ChargeDescription VARCHAR(250) '@ChargeDescription'
				,Quantity INT '@Quantity'
				,Cost DECIMAL(18, 2) '@Cost'
				,Margin DECIMAL(18, 2) '@Margin'
				,Price DECIMAL(18, 2) '@Price'
				)

		--SELECT @@ROWCOUNT
		EXEC sp_xml_removedocument @XMLHandle
	END

	-- Dynamic order description update      
	IF ISNULL(@MobilityOrderID, 0) > 0
	BEGIN
		EXEC OrderDescriptionInsertorUpdate @MobilityOrderID
	END

	IF @@ERROR > 0
	BEGIN
		SET @MobilityOrderID = NULL
		SET @MobilityOrderItemID = NULL

		ROLLBACK TRANSACTION
	END
	ELSE
	BEGIN
		COMMIT TRANSACTION
	END
END
