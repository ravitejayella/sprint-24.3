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
				,@IsActive BIT
				,@IsReplenished BIT
				,@DeviceXML VARCHAR(MAX)

			BEGIN TRANSACTION

			DECLARE ReplenishOrdersCursor CURSOR
			FOR
			SELECT TOP 5 *				-- limiting 5 as batch size
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
				,@IsActive
				,@IsReplenished
				,@DeviceXML

			WHILE @@FETCH_STATUS = 0
			BEGIN
				SELECT 1

				FETCH NEXT
				FROM ReplenishOrdersCursor
				INTO @ReplenishmentOrdersLogID
					,@DeviceID
					,@CarrierID
					,@CustomerID
					,@CustomerXCarrierAccountsID
					,@Quantity
					,@IsActive
					,@IsReplenished
					,@DeviceXML
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

		EXEC dbo.uspSendDBErrorEmail @Subject = 'CustomerCarrierAccounts_CreateReplenishmentOrders'
			,@ErrorMessage = @eMessage
			,@ErrorProcedure = @eProcedure
			,@ErrorLine = @eLine
			,@QueryParams = ''
			,@UserID = 0
	END CATCH
END
