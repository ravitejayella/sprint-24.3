USE [mobility]
GO

/****** Object:  StoredProcedure [dbo].[CustomerCarrierAccounts_UpdateReplenishmentLog]    Script Date: 3/21/2024 2:57:04 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Ravi Teja Yella
-- Create date: 03/21/2024
-- Description:	Check and record all managed inventory that needs replenishment
-- =============================================
ALTER PROCEDURE [dbo].[CustomerCarrierAccounts_UpdateReplenishmentLog]
AS
BEGIN
	BEGIN TRY
		-- GO THROUGH ALL MANAGED INVENTORIES
		BEGIN TRANSACTION

		-- InActive all existing replenishmentlog
		UPDATE ReplenishmentOrdersLog
		SET IsActive = 0
			,UpdatedByID = 99999
			,UpdatedDatetime = GETDATE()
		WHERE ISNULL(IsReplenished, 0) = 0
			AND IsActive = 1

		-- INSERT new records again
		INSERT INTO ReplenishmentOrdersLog (
			DeviceID
			,CarrierID
			,CustomerID
			,CustomerXCarrierAccountsID
			,MinimumQty
			,ReplenishQty
			,AvailableQty
			,RefillQty
			,IsReplenished
			,DeviceXML
			,AddedByID
			,AddedDateTime
			)
		SELECT mica.DeviceID
			,cca.CarrierID
			,cca.CustomerID
			,mica.CustomerXCarrierAccountsID
			,mica.MinimumQty
			,mica.ReplenishQty
			,ISNULL(si.InventoryCount, 0) AS AvailableQty
			,(mica.ReplenishQty - ISNULL(si.InventoryCount, 0)) AS RefillQty
			,0 AS IsReplenished
			,NULL AS DeviceXML
			,99999 AS AddedByID
			,GETDATE() AS AddedDateTime
		FROM ManagedInventoryXCarrierAccounts mica(NOLOCK)
		INNER JOIN CustomerXCarrierAccounts cca(NOLOCK) ON mica.CustomerXCarrierAccountsID = cca.CustomerXCarrierAccountsID
		LEFT JOIN (
			SELECT CustomerID
				,DeviceID
				,SUM(InventoryCount) AS InventoryCount
			FROM (
				SELECT DeviceID
					,CustomerID
					,COUNT(*) AS InventoryCount
				FROM SpareInventory(NOLOCK)
				WHERE IsActive = 1
					AND MobilityOrderID IS NULL
					AND MobilityOrderItemID IS NULL
				GROUP BY DeviceID
					,CustomerID
				
				UNION ALL
				
				SELECT DeviceID
					,CustomerID
					,COUNT(*) AS InventoryCount
				FROM EquipmentInventory(NOLOCK)
				WHERE MobilityOrderID IS NULL
					AND MobilityOrderItemID IS NULL
				GROUP BY DeviceID
					,CustomerID
				) AS CombinedInventory
			GROUP BY DeviceID
				,CustomerID
			) si ON mica.DeviceID = si.DeviceID
			AND cca.CustomerID = si.CustomerID
		WHERE mica.IsActive = 1
			AND cca.IsActive = 1
			AND ISNULL(cca.IsManagedInventory, 0) <> 0
			AND ISNULL(si.InventoryCount, 0) < ISNULL(mica.MinimumQty, 0)

		COMMIT TRANSACTION
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

		EXEC dbo.uspSendDBErrorEmail @Subject = 'CustomerCarrierAccounts_UpdateReplenishmentLog'
			,@ErrorMessage = @eMessage
			,@ErrorProcedure = @eProcedure
			,@ErrorLine = @eLine
			,@QueryParams = ''
			,@UserID = 0
	END CATCH

	SET NOCOUNT ON;
END
