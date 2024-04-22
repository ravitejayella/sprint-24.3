use mobility
go

-- DeviceID : 4311
-- =================================================

------===========================================================================================


SELECT CustomerID, CarrierID, CustomerXCarrierAccountsID, * from EquipmentInventory where DeviceID = 4311 and CustomerID = 119214
select CustomerID, CarrierID, * from SpareInventory where DeviceID = 4311 AND CustomerID = 119214

select CarrierID, MobilityOrderID, MobilityOrderItemID,  * from SpareInventory where CustomerID = 119214 and DeviceID = 6043
select  *from Devices where DeviceID = 6043

SELECT DeviceID
    ,CustomerID
    ,CarrierID
    ,NULL AS CustomerXCarrierAccountsID
    ,COUNT(*) AS InventoryCount
FROM SpareInventory(NOLOCK)
WHERE IsActive = 1
    AND MobilityOrderID IS NULL
    AND MobilityOrderItemID IS NULL
    and deviceid = 6043 
    and customerid = 119214
GROUP BY DeviceID
    ,CustomerID
    ,CarrierID


select * from EquipmentInventory where DeviceID = 6043 and CustomerID = 119214

select top 10 * from SpareInventory Order by 1 DESC
select top 10  * from MobilityOrders

-- -spare logic
SELECT s.DeviceID
    ,s.CustomerID
    ,s.CarrierID
    ,NULL AS CustomerXCarrierAccountsID
    ,COUNT(*) AS InventoryCount
FROM SpareInventory(NOLOCK) s
LEFT JOIN MobilityOrders mo (NOLOCK) ON mo.MobilityOrderID = s.MobilityOrderID 
    AND mo.CustomerID = s.CustomerID
WHERE s.IsActive = 1
    AND ((s.MobilityOrderID IS NULL
    AND s.MobilityOrderItemID IS NULL) OR (mo.OrderTypeID = 3 ))       -- Spare order for that customer
GROUP BY s.DeviceID
    ,s.CustomerID
    ,s.CarrierID

SELECT DeviceID
    ,CustomerID
    ,CarrierID
    ,NULL AS CustomerXCarrierAccountsID
    ,COUNT(*) AS InventoryCount
FROM SpareInventory(NOLOCK)
WHERE IsActive = 1
    AND MobilityOrderID IS NULL
    AND MobilityOrderItemID IS NULL
GROUP BY DeviceID
    ,CustomerID
    ,CarrierID


select top 10 * from bill.chargemaster order by 1 desc


SELECT TOP 1  DeviceVendorID
FROM DeviceXCarrier (NOLOCK)
WHERE DeviceID = 5999
    AND CarrierID = 178
ORDER BY Margin DESC


select 24 * 9

select  CarrierID, DeviceVendorID, DeviceConditionID , *from EquipmentInventory where EquipmentInventoryMasterID = 1771

select * from DeviceXCarrier where DeviceID = 5999 and carrierID = 178 
and DeviceConditionID = 100
and DeviceVendorID = 100 

select * from Devices where DeviceID = 5999


SELECT dEVICEVENDORid,  * FROM eQUIPMENTINVENTORY WHERE EquipmentInventoryMasterID = 1762


select * from MobilityOrderCharges where MobilityOrderID = 121930
select * from MobilityOrderXDevices where MobilityOrderID = 121930

select 1348.00 / 24 + 10
