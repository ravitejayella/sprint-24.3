USE mobility
GO

SELECT *
FROM ReplenishmentOrdersLog
WHERE isactive = 1 AND isreplenished = 0

exec [dbo].[CustomerCarrierAccounts_UpdateReplenishmentLog]


EXEC [dbo].[CustomerCarrierAccounts_CreateReplenishmentOrders]


EXEC [dbo].[CustomerCarrierAccounts_SpareOrdersForUnusedDevices]


select top 10 * from EquipmentInventory Order by 1 desc

select top 100 * from bill.chargemaster order by 1 desc
710465
710460  -- actual charge 
-- NO INVENTORY CHARGE
-- ONLY COMPARE ORDER CHARGE

select * from MobilityOrderCharges where MobilityOrderId = 11

select top 100 * from MobilityOrderCharges 
where MobilityOrderChargeID = 4836868 
order by 1 desc 

select top 100 * from MobilityOrderCharges 
where MobilityOrderChargeID = 4836866
order by 1 desc

select top 100 * from InventoryCharges where InventoryChargeID = 1218872
order by 1 desc 

select InventoryServiceID from MobilityOrderItems where MobilityOrderItemID = 354620

select top 100 * from InventoryCharges 
-- where InventoryChargeID = 1218872
order by 1 desc 

