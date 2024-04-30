use mobility
go

select IsUnlocked, EID, IseSimSelected, * from Equipmentinventory where EquipmentinventoryMasterID = 1842
select * from Devices where DeviceID = 5780
select * from Devices where ModelName like 'Apple iPhone 15 (Black 256GB)'
select * from DeviceVendor

select * from fulfillmentVendor
SELECT  * from MobilityCarrierMaster

select * from CarrierAccounts where accountBAN like '287329619320'
select * from CarrierAccounts where accountBAN like '05779987'


select * from sys.procedures where name like '%store%'
select * from sys.procedures where name like '%equipment%'

select * from users where user_name like '%brianna%'

select IMEI, IMEI2, esim, ICCID, * from MobilityOrderXDevices where MobilityOrderID = 122107

select EquipmentInventoryID, IMEI, IMEI2, esim, DeviceID, * from MobilityOrderXDevices where MobilityOrderID = 123031
select MobilityOrderID, MobilityOrderItemID, MEID, IMEI2, EID, CustomerID, CarrierID, * from EquipmentInventory where EquipmentInventoryMasterID = 1710 

select EquipmentInventoryID, IMEI, IMEI2, esim, DeviceID, * from MobilityOrderXDevices where IMEI IN(
    '351048874192366',
    '358892504201144',
    '358892504130590',
    '351048874146941',
    '351048874111655',
    '358892504043876',
    '351048874219904',
    '351335413996807',
    '351048874078904',
    '351048873968147',
    '351048874006293',
    '358892504231935',
    '351048874019981',
    '351048873914497',
    '358892504244334',
    '358892504248426',
    '351048873951093'
) 


select MobilityOrderID, MobilityOrderItemID, MEID, IMEI2, EID, CustomerID, CarrierID, * from EquipmentInventory where MEID IN (
    '351048874192366',
    '358892504201144',
    '358892504130590',
    '351048874146941',
    '351048874111655',
    '358892504043876',
    '351048874219904',
    '351335413996807',
    '351048874078904',
    '351048873968147',
    '351048874006293',
    '358892504231935',
    '351048874019981',
    '351048873914497',
    '358892504244334',
    '358892504248426',
    '351048873951093'
)


SELECT ei.EquipmentInventoryMasterID, mo.MobilityOrderID, mo.MobilityOrderItemID,  MEID, * FROM EquipmentInventory ei (NOLOCK)
JOIN MobilityOrderXDevices moxd (NOLOCK) ON ei.MEID = moxd.IMEI 
    AND ISNULL(ei.IMEI2, '') = ISNULL(moxd.IMEI2, '')
JOIN MobilityOrderItems mo (NOLOCK) ON mo.MobilityOrderItemID = moxd.MobilityOrderItemID
    and mo.IsActive = 1
JOIN MobilityOrders m (NOLOCK) ON m.MobilityOrderID = mo.MobilityOrderID
WHERE ei.MobilityOrderID IS NULL 
    AND moxd.EquipmentInventoryID IS NULL 
    AND ei.IsActive = 1 
    and ei.EquipmentStatusMasterID = 1
    AND ISNULL(ei.MEID, '') + ISNULL(ei.IMEI2, '') + ISNULL(ei.ICCID, '') + ISNULL(ei.EID, '') <> ''
    AND ei.CustomerID IS NOT NULL  
    AND m.OrderTypeID = 1
    -- AND mo.LineStatusMasterID >= 5051     -- filter by status?
order by ei.EquipmentInventoryMasterID


select * from EquipmentStatusMaster

select * from MobilityOrders where MobilityOrderID = 121831
select * from MobilityOrderItems where MobilityOrderID = 121831

select * from OrderStageMaster
select * from LineStatusMaster
