use mobility
GO

select top 100 * from bill.chargemaster order by 1 desc
-- 710465
-- 710460  -- actual charge 
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

-- one time
select top 100 * from MobilityOrderCharges 
where MobilityOrderChargeID = 4836866
select * from MobilityOrderCharges where MobilityOrderChargeID in (4836866, 4836883)

-- monthly
select top 100 * from MobilityOrderCharges 
where MobilityOrderChargeID = 4836868 

select * from MobilityOrderCharges where MobilityOrderChargeID = 4836883
select InventoryServiceID from MobilityOrderItems where MobilityOrderItemID = 354624 
select top 10 * from bill.chargemaster order by 1 desc


select * from MobilityOrderItems where ReplenishmentCCAID = 4667