declare  @CustomerID INT = 119388
    ,@CarrierID INT = 178
    ,@Channel VARCHAR(100) = 'Wholesale Aggregator'
    ,@DeviceID int = 5780 
    ,@MobilityOrderItemID INT = 365357
    ,@DeviceConditionID int = null
    ,@DeviceVendorID int = NULL
    

    
-- select * from customer where customer_ID = 119214
SELECT *
FROM MobilityOrders
WHERE MobilityOrderID = 122156

SELECT *
FROM MobilityOrderXDevices
WHERE MobilityOrderID = 122156

SELECT MobilityOrderid
	,MobilityOrderItemID
	,EquipmentStatusMasterID
	,*
FROM EquipmentInventory
WHERE EquipmentInventoryMasterID = 1825

SELECT *
FROM DeviceXCarrier
WHERE DeviceXCarrierID = 14117

SELECT MobilityOrderid
	,MobilityOrderItemID
	,EquipmentStatusMasterID
	,*
FROM EquipmentInventory
WHERE EquipmentInventoryMasterID = 1719

SELECT *
FROM MobilityOrderXDevices
WHERE MobilityOrderID = 122715



SELECT *
FROM DeviceXCarrier
WHERE DeviceXCarrierID = 14117 

-- sp_helptext EquipmentInventory_GetByDeviceID

exec EquipmentInventory_GetByDeviceID 5780
	,374840


SELECT MEID, imei2 from EquipmentInventory where EquipmentInventoryMasterID = 1831

select * from MobilityOrderXDevices where IMEI = '351048873964958'  and IMEI2=  '351048874151232'

select top 2 * from MobilityOrderItems order by 1 desc
