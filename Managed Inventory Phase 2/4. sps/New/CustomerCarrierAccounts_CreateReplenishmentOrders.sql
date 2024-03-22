USE [mobility]
GO

/****** Object:  StoredProcedure [dbo].[CustomerCarrierAccounts_CreateReplenishmentOrders]    Script Date: 3/21/2024 4:17:14 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Ravi Teja Yella
-- Create date: 03/21/2024
-- Description:	Create Replenishment orders
-- =============================================
ALTER PROCEDURE [dbo].[CustomerCarrierAccounts_CreateReplenishmentOrders]
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

		SELECT @Count AS 'COUNT INIT'	-- REMOVE LATER

		/**************** SEPARATE *******************/
		DECLARE @OrderTypeID INT
			,@IsRetail BIT = 0		-- Only QS has managed Inventory
			,@LineStatusMasterID INT
			,@ShippingTypeID INT = 1	-- ground

		SELECT TOP 1 @OrderTypeID = OrderTypeMasterID
		FROM OrderTypeMaster (NOLOCK)
		WHERE OrderType = 'Spare'

		SELECT @LineStatusMasterID = LineStatusMasterID
		FROM LineStatusMaster
		WHERE StatusCode = 'MPR'
		/**************** SEPARATE *******************/
		
		WHILE ISNULL(@Count, 0) > 0
		BEGIN
			SELECT 'ENTER OUTER WHILE LOOP'		-- REMOVE

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
				SELECT @ReplenishmentOrdersLogID AS '@ReplenishmentOrdersLogID'			-- REMOVE 
					,@DeviceID AS '@DeviceID'
					,@CarrierID AS '@CarrierID'
					,@CustomerID AS '@CustomerID'
					,@CustomerXCarrierAccountsID AS '@CustomerXCarrierAccountsID'
					,@RefillQty AS '@RefillQty'
					,@MinimumQty AS '@MinimumQty'
					,@ReplenishQty AS '@ReplenishQty'

				DECLARE @MobilityOrderID INT
					,@MobilityOrderItemID INT

				/**************** SEPARATE *******************/
				EXEC [MobilityOrders_InsertNewOrder] @CustomerID = @CustomerID
					,@AccountID = @AccountID
					,@CarrierID = @CarrierID
					,@CarrierAccountID = @CarrierAccountID
					,@TicketReferenceNumber = @TicketReferenceNumber
					,@OrderTypeID = @OrderTypeID
					,@OrderDescription = @OrderDescription
					,@AddedByID = 99999
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
					,@AddedByID = 99999

				--EXEC [MobilityOrders_UpdateShipping] @MobilityOrderID			-- PENDING
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
					,HasPreOrder BIT
					)

				INSERT INTO @Devices
				SELECT 0
					,0
					,@DeviceID
					,dc.DeviceXCarrierID
					,100
					,100
					,@RefillQty
					,dc.Cost
					,-100
					,0
					,0
					,0
					,0
					,0
					,0
					,0
					,0
					,cpc.CustomerXProductCatalogID
					,cpc.ChargeType
					,cpc.USOC
					,cpc.Description
					,CASE 
						WHEN dc.DeviceStatusID = 300
							THEN 1
						ELSE 0
						END
				FROM Devices d(NOLOCK)
				JOIN DeviceXCarrier dc(NOLOCK) ON dc.DeviceID = d.DeviceID
				LEFT JOIN CustomerXProductCatalog cpc(NOLOCK) ON cpc.CategoryPlanID = d.DeviceID
					AND cpc.CarrierID = dc.CarrierID
					AND cpc.ProductCatalogCategoryMasterID = 5
					AND cpc.CustomerID = @CustomerID
					AND cpc.StatusID = 1 -- ask
				WHERE d.DeviceID = @DeviceID
					AND dc.CarrierID = @CarrierID

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
						,OrderSubTypeMasterID = 1
						,iBillerDate = (
							CASE 
								WHEN @IsRetail = 0
									THEN dbo.GetBillCycleDate()
								ELSE NULL
								END
							)
					WHERE MobilityOrderItemID = @MobilityOrderItemID

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
						,ChangedByID = 99999
					WHERE MobilityOrderItemID = @MobilityOrderItemID
				END	

				-- till here WHILE @cnt < @Qty
				/**************** SEPARATE *******************/
				
				
				-- GET required data for Spare Order
				DECLARE @DeviceXML VARCHAR(MAX)
					,@ChargesXML VARCHAR(MAX)
					,@AccountID INT
					,@CarrierAccountID INT

				-- GET @DeviceXML
				SELECT TOP 1 @DeviceXML = '<ROOT>
				<row 
					DeviceTypeID="0" 
					DevicePricingMasterID="0" 
					DeviceID="' + CAST(@DeviceID AS VARCHAR(20)) + '" 
					DeviceVendorID="100" 
					DeviceXCarrierID="' + CAST(dc.DeviceXCarrierID AS VARCHAR(20)) + '" 
					DeviceConditionID="100" 
					Qty="' + CAST(@RefillQty AS VARCHAR(20)) + '" 
					Cost="' + CAST(dc.Cost AS VARCHAR(20)) + '" 
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
				FROM Devices d(NOLOCK)
				JOIN DeviceXCarrier dc(NOLOCK) ON dc.DeviceID = d.DeviceID
				LEFT JOIN CustomerXProductCatalog cpc(NOLOCK) ON cpc.CategoryPlanID = d.DeviceID
					AND cpc.CarrierID = dc.CarrierID
					AND cpc.ProductCatalogCategoryMasterID = 5
					AND cpc.CustomerID = @CustomerID
					AND cpc.StatusID = 1 -- ask
				WHERE d.DeviceID = @DeviceID
					AND dc.CarrierID = @CarrierID

				-- GET @ChargesXML
				SET @ChargesXML = '<ROOT>
				<row 
					MobilityOrderChargeID="0" 
					CustomerXProductCatalogID="0" 
					CategoryPlanID="0" 
					ProductCatalogCategoryMasterID="0" 
					ChargeType="One Time" 
					USOC="SHIP4" 
					ChargeDescription="Ground Shipping & Handling Charge" 
					Quantity="1" 
					Cost="0" 
					Margin="0" 
					Price="0"
				/></ROOT>'

				SELECT @DeviceXML AS '@DeviceXML'		-- REMOVE
				SELECT @ChargesXML AS 'ChargesXML'		-- REMOVE

				-- GET @CarrierAccountID
				SELECT TOP 1 @CarrierAccountID = CarrierAccountID -- USUALLY ONLY 1 vCom Solutions Service Provider account per carrier
				FROM CustomerXCarrierAccounts(NOLOCK)
				WHERE CustomerXCarrierAccountsID = @CustomerXCarrierAccountsID

				-- GET ShippingAddress details
				EXEC [dbo].[MobilityOrder_SpareOrder] @CustomerID = @CustomerID
					,@AccountID = 119293			-- PENDING
					,@CarrierID = @CarrierID
					,@CarrierAccountID = @CarrierAccountID
					,@CustomerXCarrierAccountsID = @CustomerXCarrierAccountsID
					,@OrderDescription = NULL
					,@DeviceXML = @DeviceXML
					
					,@ExistingShippingAddressID = 0
					,@AttentionToName = 'vCom Solutions - Service Provider'
					,@Address1 = '8529 Meadowbridge Rd'
					,@Address2 = ''
					,@Address3 = ''
					,@City = 'Mechanicsville'
					,@StateMasterID = 38
					,@Zipcode = '23116'
					,@CountryMasterID = 1
					,@ShippingTypeID = 1
					
					,@RequestorID = - 5 -- Inventory Management (hardcoded in API)
					,@AddedByID = 99999
					,@ChargesXML = @ChargesXML
					,@TicketReferenceNumber = NULL
					,@UserFirstName = NULL
					,@UserLastName = NULL
					,@UserTitle = NULL
					,@UserEmail = NULL
					,@CopyEndUser = 0


				SELECT * FROM @ReplishmentOrdersCreated   -- REMOVE

				-- UPDATE record as IsReplenished 
				UPDATE ReplenishmentOrdersLog
				SET IsReplenished = 1
					,UpdatedByID = 99999
					,UpdatedDateTime = GETDATE()
				WHERE ReplenishmentOrdersLogID = @ReplenishmentOrdersLogID

				-- GET order info


				SELECT TOP 1 @MobilityOrderID = MobilityOrderID
					,@MobilityOrderItemID = MobilityOrderItemID
				FROM MobilityOrderItems (NOLOCK)
				ORDER BY MobilityOrderID DESC

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
						,99999
						,GETDATE()
						,99999
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

		SELECT ERROR_MESSAGE() AS 'ERROR MESSAGE', ERROR_PROCEDURE() AS 'ERROR PROC'

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
