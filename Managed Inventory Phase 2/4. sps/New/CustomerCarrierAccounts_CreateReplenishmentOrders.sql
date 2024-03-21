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

		WHILE ISNULL(@Count, 0) > 0
		BEGIN
			DECLARE @ReplenishmentOrdersLogID INT
				,@DeviceID INT
				,@CarrierID INT
				,@CustomerID INT
				,@CustomerXCarrierAccountsID INT
				,@Quantity INT

			BEGIN TRANSACTION

			DECLARE ReplenishOrdersCursor CURSOR
			FOR
			SELECT TOP 5 * -- limiting 5 as batch size
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
				,@Quantity

			WHILE @@FETCH_STATUS = 0
			BEGIN
				
				-- GET required data for Spare Order
				DECLARE @DevicesXML VARCHAR(MAX)
					,@ChargesXML VARCHAR(MAX)
					,@AccountID INT
					,@CarrierAccountID INT

				SELECT TOP 1 @CarrierAccountID = CarrierAccountID
				FROM CustomerXCarrierAccounts(NOLOCK)
				WHERE CustomerXCarrierAccountsID = @CustomerXCarrierAccountsID

				INSERT INTO @ReplishmentOrdersCreated
				EXEC [dbo].[MobilityOrder_SpareOrder] @CustomerID = @CustomerID
					,@AccountID = @AccountID
					,@CarrierID = @CarrierID
					,@CarrierAccountID = @CarrierAccountID
					,@CustomerXCarrierAccountsID = @CustomerXCarrierAccountsID
					,@OrderDescription = NULL
					,@DeviceXML = @DevicesXML
					--,@ExistingShippingAddressID INT
					--,@AttentionToName VARCHAR(200) = NULL
					--,@Address1 VARCHAR(500) = NULL
					--,@Address2 VARCHAR(500) = NULL
					--,@Address3 VARCHAR(500) = NULL
					--,@City VARCHAR(150) = NULL
					--,@StateMasterID INT = NULL
					--,@Zipcode VARCHAR(10) = NULL
					--,@CountryMasterID INT = NULL
					--,@ShippingTypeID INT = NULL
					--,@RequestorID = NULL
					,@AddedByID = 9999
					,@ChargesXML = @ChargesXML
					,@TicketReferenceNumber = NULL
					,@UserFirstName = NULL
					,@UserLastName = NULL
					,@UserTitle = NULL
					,@UserEmail = NULL
					,@CopyEndUser = 0

				-- UPDATE record as IsReplenished 
				UPDATE ReplenishmentOrdersLog
				SET IsReplenished = 1
					,UpdatedByID = 9999
					,UpdatedDateTime = GETDATE()
				WHERE ReplenishmentOrdersLogID = @ReplenishmentOrdersLogID

				-- GET order info
				DECLARE @MobilityOrderID INT
					,@MobilityOrderItemID INT
				
				SELECT TOP 1 @MobilityOrderID = MobilityOrderID
					,@MobilityOrderItemID = MobilityOrderItemID
				FROM @ReplishmentOrdersCreated 
				ORDER BY MobilityOrderID DESC

				-- notifications / notes etc


				FETCH NEXT
				FROM ReplenishOrdersCursor
				INTO @ReplenishmentOrdersLogID
					,@DeviceID
					,@CarrierID
					,@CustomerID
					,@CustomerXCarrierAccountsID
					,@Quantity
			END

			CLOSE ReplenishOrdersCursor;

			DEALLOCATE ReplenishOrdersCursor;

			COMMIT TRANSACTION

			SELECT @Count = COUNT(*)
			FROM ReplenishmentOrdersLog(NOLOCK)
			WHERE IsActive = 1
				AND ISNULL(IsReplenished, 0) = 0
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

		DECLARE @ShowCreatedOrders VARCHAR(MAX) = ''

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
