USE mobility
GO


select * from ReplenishmentOrdersLog
where isactive = 1
and isreplenished = 0


SELECT @@TRANCOUNT

EXEC [dbo].[CustomerCarrierAccounts_UpdateReplenishmentLog]


EXEC [dbo].[CustomerCarrierAccounts_CreateReplenishmentOrders]


EXEC [dbo].[CustomerCarrierAccounts_SpareOrdersForUnusedDevices]


SELECT * FROM ManagedInventoryXCarrierAccounts where customerID = 119388
SELECT * From SpareInventory WHERE CustomerID = 20 AND DeviceID = 4750
SELECT * From EquipmentInventory WHERE MobilityOrderiD is null and CustomerID = 119388 and CustomerXCarrierAccountsID = 3318 AND DeviceID = 5257
SELECT * From EquipmentInventory WHERE MobilityOrderiD is null and CustomerID = 119388 and CustomerXCarrierAccountsID = 3318 AND DeviceID = 4908



select * from MobilityOrders 
where Mobilityorderid = 118937 
select * from MobilityOrderItems where Mobilityorderid in  (118937 ) 
SELECT * FROM MobilityOrderXDevices where MobilityOrderID = 118937
select * from Devices where DeviceID = 4750

SELECT * FROM MobilityOrderXDevices where MobilityOrderID = 118938
order by 1 desc

 


select * from customer where customer_name like '%wilbur%'
select top 10 * from DeviceXCarrier


select * from Devices where deviceid = 4908



select * from SpareInventory where CustomerID = 119388
and deviceID = 4908 and mobilityorderid is null

select distinct status from SPareInventory

select * from EquipmentInventory where CustomerID = 119388
and mobilityorderid is null
and deviceID = 4908

SELECT top 10 * FROM bill.inventorymaster where OrderID = 118935
SELECT top 10 * FROM bill.chargemaster where  OrderID = 118935 order by 1 desc  
SELECT top 10 * FROM bill.chargemaster where  OrderID = 118934 order by 1 desc  
SELECT top 10 * FROM bill.chargemaster where  OrderID = 118936 order by 1 desc  


SELECT * FROM MobilityOrderXDevices where MobilityOrderID = 118932

 