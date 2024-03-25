-- =============================================  
-- Author:  Ravi Teja Yella  
-- Create date: 03/21/2024  
-- Description: Create Replenishment orders  
-- =============================================  
CREATE PROCEDURE [dbo].[CustomerCarrierAccounts_CreateReplenishmentOrders]
AS
BEGIN
	BEGIN TRY
		DECLARE @Count INT
		DECLARE @ReplishmentOrdersCreated TABLE (
			MobilityOrderID INT
			,MobilityOrderItemID INT
			) -- Record orders created in batches  

		SELECT @Count = COUNT(*)
		FROM ReplenishmentOrdersLog(NOLOCK)
		WHERE IsActive = 1
			AND ISNULL(IsReplenished, 0) = 0

		DECLARE @OrderTypeID INT
			,@IsRetail BIT = 0 -- Only QS has managed Inventory  
			,@LineStatusMasterID INT
			,@RequestorID INT = - 5 -- Inventory Management (hardcoded in API)  
			,@AddedByID INT = 99999 -- System User  

		SELECT TOP 1 @OrderTypeID = OrderTypeMasterID
		FROM OrderTypeMaster(NOLOCK)
		WHERE OrderType = 'Spare'

		SELECT @LineStatusMasterID = LineStatusMasterID
		FROM LineStatusMaster
		WHERE StatusCode = 'MPR'

		WHILE ISNULL(@Count, 0) > 0
		BEGIN
			DECLARE @ReplenishmentOrdersLogID INT
				,@DeviceID INT
				,@CarrierID INT
				,@CustomerID INT
				,@CustomerXCarrierAccountsID INT
				,@RefillQty INT
				,@MinimumQty INT
				,@ReplenishQty INT

			BEGIN TRANSACTION

			IF CURSOR_STATUS('global', 'ReplenishOrdersCursor') >= 0
			BEGIN
				CLOSE ReplenishOrdersCursor;

				DEALLOCATE ReplenishOrdersCursor;
			END

			DECLARE ReplenishOrdersCursor CURSOR
			FOR
			SELECT TOP 5 ReplenishmentOrdersLogID -- limiting 5 as batch size  
				,DeviceID
				,CarrierID
				,CustomerID
				,CustomerXCarrierAccountsID
				,RefillQty
				,MinimumQty
				,ReplenishQty
			FROM ReplenishmentOrdersLog(NOLOCK)
			WHERE IsActive = 1
				AND ISNULL(IsReplenished, 0) = 0

			OPEN ReplenishOrdersCursor

			FETCH NEXT
			FROM ReplenishOrdersCursor
			INTO @ReplenishmentOrdersLogID
				,@DeviceID
				,@CarrierID
				,@CustomerID
				,@CustomerXCarrierAccountsID
				,@RefillQty
				,@MinimumQty
				,@ReplenishQty

			WHILE @@FETCH_STATUS = 0
			BEGIN
				--SELECT @ReplenishmentOrdersLogID AS '@ReplenishmentOrdersLogID'   -- REMOVE   
				-- ,@DeviceID AS '@DeviceID'  
				-- ,@CarrierID AS '@CarrierID'  
				-- ,@CustomerID AS '@CustomerID'  
				-- ,@CustomerXCarrierAccountsID AS '@CustomerXCarrierAccountsID'  
				-- ,@RefillQty AS '@RefillQty'  
				-- ,@MinimumQty AS '@MinimumQty'  
				-- ,@ReplenishQty AS '@ReplenishQty'  
				DECLARE @vComSPCustomerID INT
					,@vComSPCarrierAccountID INT
					,@vComSPCustomerXCarrierAccountsID INT
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

				-- GET Customer, CarrierAccount Info  
				SELECT TOP 1 @vComSPCustomerID = customer_id -- ONLY 1 CarrierAccount exists for vCom Service Provider per carrier  
					,@vComSPCarrierAccountID = cca.CarrierAccountID
					,@vComSPCustomerXCarrierAccountsID = cca.CustomerXCarrierAccountsID
				FROM customer c(NOLOCK)
				JOIN CustomerXCarrierAccounts cca(NOLOCK) ON cca.CustomerID = c.customer_id
					AND cca.CustomerID = c.customer_id
					AND cca.CarrierID = @CarrierID
					AND cca.IsActive = 1
				WHERE c.customer_name = 'vCom Solutions - Service Provider'

				-- GET SHIPPING INFO  
				SELECT TOP 1 @AccountID = account_id
					,@ExistingShippingAddressID = c.CustomerAddressID
					,@Address1 = a.address_1
					,@City = a.city
					,@StateMasterID = sa.StateMasterID
					,@ZipCode = a.zip
				FROM customer cus(NOLOCK)
				LEFT JOIN ipath..account a(NOLOCK) ON cus.customer_id = a.customer_id
				LEFT JOIN CustomerAddress c(NOLOCK) ON c.CustomerID = cus.customer_id
					AND c.AccountID = a.account_id
					AND c.IsActive = 1
					AND c.AddressType = 'S'
				LEFT JOIN StateMaster sa(NOLOCK) ON sa.StateCode = a.STATE
					AND sa.IsActive = 1
				WHERE a.STATUS = 'A'
					AND cus.customer_name = 'vCom Solutions - Service Provider'
					AND a.account_name = 'vCom - Pre-Purchased Hardware'
				ORDER BY 1 DESC

				--GET DEVICE INFO  
				SELECT @DeviceTypeID = 0
					,@DevicePricingMasterID = 0
					,@Cost = dc.Cost
					,@Margin = - 100
					,@Price = 0
					,@IsInstallmentPlan = 0
					,@DownPayment = 0
					,@ROIOnCost = 0
					,@ROIOnPrice = 0
					,@Term = 0
					,@MonthlyPaymentOnCost = 0
					,@MonthlyPaymentOnPrice = 0
					,@CustomerXProductCatalogID = cpc.CustomerXProductCatalogID
					,@ChargeType = cpc.ChargeType
					,@USOC = cpc.USOC
					,@ChargeDescription = cpc.Description
					,@HasPreOrder = CASE 
						WHEN dc.DeviceStatusID = 300
							THEN 1
						ELSE 0
						END
					,@DeviceXCarrierID = dc.DeviceXCarrierID
					,@DeviceConditionID = 100
					,@DeviceVendorID = 100
				FROM Devices d(NOLOCK)
				JOIN DeviceXCarrier dc(NOLOCK) ON dc.DeviceID = d.DeviceID
				LEFT JOIN CustomerXProductCatalog cpc(NOLOCK) ON cpc.CategoryPlanID = d.DeviceID
					AND cpc.CarrierID = dc.CarrierID
					AND cpc.ProductCatalogCategoryMasterID = 5
					AND cpc.CustomerID = @vComSPCustomerID
					AND cpc.StatusID = 1 -- ask  
				WHERE d.DeviceID = @DeviceID
					AND dc.CarrierID = @CarrierID

				------------------------------------- CREATE ORDER --------------------------------  
				EXEC [MobilityOrders_InsertNewOrder] @CustomerID = @vComSPCustomerID
					,@AccountID = @AccountID
					,@CarrierID = @CarrierID
					,@CarrierAccountID = @vComSPCarrierAccountID
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
				WHERE MobilityOrderItemID = @MobilityOrderItemID

				EXEC MobileNotificationCriteria_InsertLog @MobilityOrderID = @MobilityOrderID
					,@MobilityOrderItemID = @MobilityOrderItemID
					,@AddedByID = @AddedByID

				EXEC [MobilityOrders_UpdateShipping] @MobilityOrderID -- PENDING  
					,@MobilityOrderItemID
					,@ExistingShippingAddressID
					,@vComSPCustomerID
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
				WHERE MobilityOrderItemID = @MobilityOrderItemID

				-- INSERT Devices INTO MobilityOrderXDevices  
				DECLARE @cnt INT = 1

				WHILE @cnt <= @RefillQty
				BEGIN
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
				END

				-- INSERT SIM Charges  
				--DECLARE @SimCharges TABLE (  
				-- ChargeID INT  
				-- ,USOC VARCHAR(50)  
				-- ,ChargeType VARCHAR(50)  
				-- ,Name VARCHAR(255)  
				-- ,Description VARCHAR(255)  
				-- ,Cost DECIMAL(19, 2)  
				-- ,Margin DECIMAL(19, 2)  
				-- ,Price DECIMAL(19, 2)  
				-- ,IsCustom BIT  
				-- ,SortOrder INT  
				-- )  
				---- delete sim charges  
				--DELETE  
				--FROM @SimCharges  
				--INSERT INTO @SimCharges  
				--EXEC [Charges_GetOtherOrderCharges] @CustomerID = @vComSPCustomerID  
				-- ,@CarrierAccountID = @vComSPCarrierAccountID  
				-- ,@ChannelType = @IsRetail  
				--INSERT INTO MobilityOrderCharges (  
				-- MobilityOrderID  
				-- ,MobilityOrderItemID  
				-- ,CustomerXProductCatalogID  
				-- ,CategoryPlanID  
				-- ,ProductCatalogCategoryMasterID  
				-- ,ChargeType  
				-- ,USOC  
				-- ,ChargeDescription  
				-- ,Quantity  
				-- ,Cost  
				-- ,Margin  
				-- ,Price  
				-- ,TimesToBill  
				-- ,IsActive  
				-- ,AddedByID  
				-- ,ChangedByID  
				-- )  
				--SELECT @MobilityOrderID  
				-- ,@MobilityOrderItemID  
				-- ,0  
				-- ,0  
				-- ,0  
				-- ,ChargeType  
				-- ,USOC  
				-- ,Description  
				-- ,@RefillQty  
				-- ,Cost  
				-- ,Margin  
				-- ,0 -- price as '0'  
				-- ,1  
				-- ,1  
				-- ,@AddedByID  
				-- ,@AddedByID  
				--FROM @SimCharges  
				--WHERE USOC = CASE   
				--  WHEN @DeviceTypeID = 15  
				--   THEN 'WWSIM'  
				--  ELSE 'MNSIM'  
				--  END  
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

				-- INSERT Shipping Charge INTO MobilityOrderCharges table  
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
					,NULL -- Set NULL for Spare to get charges in order details level instead of configure item level  
					,0
					,0
					,0
					,'One Time'
					,'SHIP4'
					,'Ground Shipping & Handling Charge'
					,1
					,0
					,0
					,0
					,1
					,1
					,@AddedByID
					,@AddedByID

				-- Update Order Description   
				IF ISNULL(@MobilityOrderID, 0) > 0
				BEGIN
					EXEC OrderDescriptionInsertorUpdate @MobilityOrderID
				END

				-- UPDATE record as IsReplenished   
				UPDATE ReplenishmentOrdersLog
				SET IsReplenished = 1
					,UpdatedByID = @AddedByID
					,UpdatedDateTime = GETDATE()
				WHERE ReplenishmentOrdersLogID = @ReplenishmentOrdersLogID

				INSERT INTO @ReplishmentOrdersCreated
				SELECT @MobilityOrderID
					,@MobilityOrderItemID

				--SELECT * FROM @ReplishmentOrdersCreated   -- REMOVE  
				-- notifications / notes etc  
				IF (ISNULL(@MobilityOrderID, 0) <> 0)
				BEGIN
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
					SELECT TOP 1 @MobilityOrderID
						,'Managed Inventory for ' + customer_name
						,'Reupping Managed Inventory for ' + customer_name + '. Configured Minimum Qty for ' + ModelName + ' is ' + CAST(@MinimumQty AS VARCHAR(20)) + ' and Replenishment Qty is ' + CAST(@ReplenishQty AS VARCHAR(20)) + '.'
						,1
						,1
						,GETDATE()
						,@AddedByID
						,GETDATE()
						,@AddedByID
					FROM customer c(NOLOCK)
					CROSS JOIN Devices d
					WHERE customer_id = @CustomerID
						AND d.DeviceID = @DeviceID
				END

				FETCH NEXT
				FROM ReplenishOrdersCursor
				INTO @ReplenishmentOrdersLogID
					,@DeviceID
					,@CarrierID
					,@CustomerID
					,@CustomerXCarrierAccountsID
					,@RefillQty
					,@MinimumQty
					,@ReplenishQty
			END

			CLOSE ReplenishOrdersCursor;

			DEALLOCATE ReplenishOrdersCursor;

			COMMIT TRANSACTION

			SELECT @Count = COUNT(*)
			FROM ReplenishmentOrdersLog(NOLOCK)
			WHERE IsActive = 1
				AND ISNULL(IsReplenished, 0) = 0
		END

		-- REMOVE LATER  
		SELECT *
		FROM @ReplishmentOrdersCreated
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

		DECLARE @ShowCreatedOrders VARCHAR(MAX) = ''

		SELECT ERROR_MESSAGE() AS 'ERROR MESSAGE'
			,ERROR_PROCEDURE() AS 'ERROR PROC'

		SELECT @ShowCreatedOrders = 'Created Orders: ' + @ShowCreatedOrders + ', ' + CAST(MobilityOrderID AS VARCHAR)
		FROM @ReplishmentOrdersCreated

		EXEC dbo.uspSendDBErrorEmail @Subject = 'CustomerCarrierAccounts_CreateReplenishmentOrders'
			,@ErrorMessage = @eMessage
			,@ErrorProcedure = @eProcedure
			,@ErrorLine = @eLine
			,@QueryParams = @ShowCreatedOrders
			,@UserID = 0
	END CATCH
END
