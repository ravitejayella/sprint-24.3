USE mobility 
GO 

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Ravi Teja Yella
-- Create date: 03/21/2024
-- Description:	Check and record all managed inventory that needs replenishment
-- =============================================
CREATE PROCEDURE [dbo].[CustomerCarrierAccounts_UpdateReplenishmentLog]
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

		-- DECLARE existing inventoryCount table
		DECLARE @existingInventory TABLE (
			CustomerID INT
			,DeviceID INT
			,CarrierID INT NULL
			,CustomerXCarrierAccountsID INT NULL
			,InventoryCount INT
			)

		DELETE
		FROM @existingInventory

		-- ADD to existing inventory with basic grouping
		INSERT INTO @existingInventory
		SELECT CustomerID
			,DeviceID
			,CarrierID
			,MAX(CustomerXCarrierAccountsID) AS CustomerXCarrierAccountsID
			,SUM(InventoryCount) AS InventoryCount
		FROM (
			-- spare logic
            SELECT s.DeviceID
				,s.CustomerID
				,s.CarrierID
				,NULL AS CustomerXCarrierAccountsID
				,COUNT(*) AS InventoryCount
			FROM SpareInventory(NOLOCK) s
			LEFT JOIN MobilityOrders mo(NOLOCK) ON mo.MobilityOrderID = s.MobilityOrderID
				AND mo.CustomerID = s.CustomerID
			WHERE s.IsActive = 1
				AND (
					(
						s.MobilityOrderID IS NULL
						AND s.MobilityOrderItemID IS NULL
						)
					OR (mo.OrderTypeID = 3)
					) -- Allow if it's the Spare order for that customer
			GROUP BY s.DeviceID
				,s.CustomerID
				,s.CarrierID

			
			UNION ALL
			
            -- store logic
			SELECT DeviceID
				,CustomerID
				,CarrierID
				,CustomerXCarrierAccountsID
				,COUNT(*) AS InventoryCount
			FROM EquipmentInventory(NOLOCK)
			WHERE MobilityOrderID IS NULL
				AND MobilityOrderItemID IS NULL
			GROUP BY DeviceID
				,CustomerID
				,CarrierID
				,CustomerXCarrierAccountsID
			) AS CombinedInventory
		GROUP BY DeviceID
			,CustomerID
			,CarrierID
			,CustomerXCarrierAccountsID

		-- AGGREGATE NULL Carriers & Carrier Accounts
		UPDATE ei
		SET InventoryCount = ei.InventoryCount + NullCarrierInventory.InventoryCount
		FROM (
			SELECT CustomerID
				,DeviceID
				,SUM(InventoryCount) AS InventoryCount
			FROM @existingInventory
			WHERE CarrierID IS NULL
				AND CustomerXCarrierAccountsID IS NULL
			GROUP BY CustomerID
				,DeviceID
			) AS NullCarrierInventory
		INNER JOIN @existingInventory ei ON NullCarrierInventory.CustomerID = ei.CustomerID
			AND NullCarrierInventory.DeviceID = ei.DeviceID
		WHERE ei.CarrierID IS NOT NULL
			AND ei.CustomerXCarrierAccountsID IS NOT NULL;

		-- AGGREGATE NULL Carrier Accounts but with Carrier
		UPDATE ei
		SET InventoryCount = ei.InventoryCount + NullCarrierAccInv.InventoryCount
		FROM (
			SELECT CustomerID
				,DeviceID
				,CarrierID
				,SUM(InventoryCount) AS InventoryCount
			FROM @existingInventory
			WHERE CarrierID IS NOT NULL
				AND CustomerXCarrierAccountsID IS NULL
			GROUP BY CustomerID
				,DeviceID
				,CarrierID
			) AS NullCarrierAccInv
		INNER JOIN @existingInventory ei ON NullCarrierAccInv.CustomerID = ei.CustomerID
			AND NullCarrierAccInv.DeviceID = ei.DeviceID
			AND NullCarrierAccInv.CarrierID = ei.CarrierID
		WHERE ei.CustomerXCarrierAccountsID IS NOT NULL;

		-- REMOVE NULLS
		DELETE
		FROM @existingInventory
		WHERE CarrierID IS NULL
			OR CustomerXCarrierAccountsID IS NULL

		SELECT '@existingInventory'
			,*
		FROM @existingInventory -- where CustomerID = 119214  -- REMOVE

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
			,(mica.ReplenishQty - ISNULL(refil.RefillCount, 0)) AS RefillQty
			,0 AS IsReplenished
			,NULL AS DeviceXML
			,99999 AS AddedByID
			,GETDATE() AS AddedDateTime
		FROM ManagedInventoryXCarrierAccounts mica(NOLOCK)
		INNER JOIN CustomerXCarrierAccounts cca(NOLOCK) ON mica.CustomerXCarrierAccountsID = cca.CustomerXCarrierAccountsID
		LEFT JOIN (
			SELECT DeviceID
				,ReplenishmentCCAID
				,count(*) AS RefillCount
			FROM MobilityOrderItems moi(NOLOCK)
			INNER JOIN MobilityOrders mo(NOLOCK) ON mo.MobilityOrderID = moi.MobilityOrderID
				AND mo.OrderTypeID = 3 -- Spare
				AND mo.CustomerID = 112275 -- vCom Solutions - Service Provider
			JOIN MobilityOrderXDevices moxd(NOLOCK) ON moi.MobilityOrderItemID = moxd.MobilityOrderItemID
			WHERE ISNULL(ReplenishmentCCAID, 0) <> 0
				AND moi.IsActive = 1
				AND moi.LineStatusMasterID NOT IN (
					5001
					,7001
					)
			GROUP BY DeviceID
				,ReplenishmentCCAID
			) AS refil ON refil.DeviceID = mica.DeviceID
			AND refil.ReplenishmentCCAID = mica.CustomerXCarrierAccountsID
		LEFT JOIN @existingInventory si ON mica.DeviceID = si.DeviceID
			AND cca.CustomerID = si.CustomerID
			AND mica.CarrierID = si.CarrierID
			AND mica.CustomerXCarrierAccountsID = si.CustomerXCarrierAccountsID
		WHERE mica.IsActive = 1
			AND cca.IsActive = 1
			AND ISNULL(cca.IsManagedInventory, 0) <> 0
			AND ISNULL(mica.ReplenishQty, 0) <> 0 -- Must have replenish qty configured
			AND (ISNULL(si.InventoryCount, 0) + ISNULL(refil.RefillCount, 0)) <= ISNULL(mica.MinimumQty, 0) -- avoid items that are already ordered.
			-- AND (mica.ReplenishQty > (ISNULL(si.InventoryCount, 0) + ISNULL(refil.RefillCount, 0)))  -- avoid items that are already ordered.

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
GO
