USE mobility
GO

------------------------- SELECT  QUERY
SELECT m.CustomerID
	,moxd.EquipmentInventoryID
	,ei.MobilityOrderID
	,ei.MobilityOrderItemID
	,ei.EquipmentInventoryMasterID AS 'Effected StoreID'
	,mo.MobilityOrderID AS 'Effected OrderID'
	,mo.MobilityOrderItemID AS 'Effected OrderItemID'
	,MEID
	,*
FROM EquipmentInventory ei(NOLOCK)
JOIN MobilityOrderXDevices moxd(NOLOCK) ON ei.MEID = moxd.IMEI
	AND ISNULL(ei.IMEI2, '') = ISNULL(moxd.IMEI2, '')
	AND ISNULL(ei.ESN, '') = ISNULL(moxd.ESN, '')
JOIN MobilityOrderItems mo(NOLOCK) ON mo.MobilityOrderItemID = moxd.MobilityOrderItemID
	AND mo.IsActive = 1
JOIN MobilityOrders m(NOLOCK) ON m.MobilityOrderID = mo.MobilityOrderID
WHERE ei.MobilityOrderID IS NULL
	AND moxd.EquipmentInventoryID IS NULL
	AND ei.IsActive = 1
	AND ei.EquipmentStatusMasterID = 1
	AND ISNULL(ei.MEID, '') + ISNULL(ei.IMEI2, '') + ISNULL(ei.ICCID, '') + ISNULL(ei.EID, '') <> ''
	AND ei.CustomerID IS NOT NULL
	AND m.OrderTypeID = 1
-- AND mo.LineStatusMasterID >= 5051     -- filter by status?
ORDER BY ei.EquipmentInventoryMasterID

-------------------------- UPDATE QUERY
-- BEGIN TRANSACTION
-- -- Update MobilityOrderXDevices table
-- UPDATE moxd
-- SET moxd.EquipmentInventoryID = ei.EquipmentInventoryMasterID
-- FROM MobilityOrderXDevices moxd
-- JOIN EquipmentInventory ei(NOLOCK) ON ISNULL(ei.MEID, '') = ISNULL(moxd.IMEI, '')
-- 	AND ISNULL(ei.IMEI2, '') = ISNULL(moxd.IMEI2, '')
-- 	AND ISNULL(ei.ESN, '') = ISNULL(moxd.ESN, '')
-- JOIN MobilityOrderItems mo(NOLOCK) ON mo.MobilityOrderItemID = moxd.MobilityOrderItemID
-- 	AND mo.IsActive = 1
-- JOIN MobilityOrders m(NOLOCK) ON m.MobilityOrderID = mo.MobilityOrderID
-- WHERE ei.MobilityOrderID IS NULL
-- 	AND moxd.EquipmentInventoryID IS NULL
-- 	AND ei.IsActive = 1
-- 	AND ei.EquipmentStatusMasterID = 1
-- 	AND ISNULL(ei.MEID, '') + ISNULL(ei.IMEI2, '') + ISNULL(ei.ICCID, '') + ISNULL(ei.EID, '') <> ''
-- 	AND ei.CustomerID IS NOT NULL
-- 	AND m.OrderTypeID = 1;

-- -- Update EquipmentInventory table
-- UPDATE ei
-- SET ei.MobilityOrderID = mo.MobilityOrderID
-- 	,ei.MobilityOrderItemID = mo.MobilityOrderItemID
-- 	,ei.EquipmentStatusMasterID = CASE 
-- 		WHEN mo.LineStatusMasterID >= 5051 -- IF >= 5051 
-- 			THEN 3
-- 		ELSE 1
-- 		END
-- FROM EquipmentInventory ei
-- JOIN MobilityOrderXDevices moxd(NOLOCK) ON ei.MEID = moxd.IMEI
-- 	AND ISNULL(ei.IMEI2, '') = ISNULL(moxd.IMEI2, '')
-- 	AND ISNULL(ei.ESN, '') = ISNULL(moxd.ESN, '')
-- JOIN MobilityOrderItems mo(NOLOCK) ON mo.MobilityOrderItemID = moxd.MobilityOrderItemID
-- 	AND mo.IsActive = 1
-- JOIN MobilityOrders m(NOLOCK) ON m.MobilityOrderID = mo.MobilityOrderID
-- WHERE ei.MobilityOrderID IS NULL
-- 	AND ei.IsActive = 1
-- 	AND ei.EquipmentStatusMasterID = 1
-- 	AND ISNULL(ei.MEID, '') + ISNULL(ei.IMEI2, '') + ISNULL(ei.ICCID, '') + ISNULL(ei.EID, '') <> ''
-- 	AND ei.CustomerID IS NOT NULL
-- 	AND m.OrderTypeID = 1;

-- -- ROLLBACK OR COMMIT
-- IF ERROR_NUMBER() > 0
-- BEGIN
-- 	SELECT ERROR_MESSAGE() AS 'ERROR_MESSAGE'
-- 	IF @@TRANCOUNT > 0
-- 	BEGIN
-- 		ROLLBACK TRANSACTION
-- 	END
-- END
-- ELSE
-- BEGIN
-- 	COMMIT TRANSACTION
-- 	SELECT 'UPDATED'
-- END


