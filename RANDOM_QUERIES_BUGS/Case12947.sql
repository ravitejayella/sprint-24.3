use mobility
go


-- select * from sys.tables where name like '%addonproperty%'

-- select top 10 * from InventoryXAddonPropertyRel order by 1 desc

-- select top 10 * from MobilityOrderXAddonPropertyRel order by 1 desc


SELECT IMEI, IMEI2, ESN, ICCID, eSIM, * FROM MobilityOrderXDevices WHERE MobilityOrderID = 120945

SELECT ActivationDate, * from MobilityOrderitems where MobilityOrderID = 120945

select DeviceVendorID, IMEI, IMEI2, eSIM, ICCID from MobilityOrderXDevices where MobilityOrderID = 120945

SELECT * FROM CustomerXProductCatalog where ProductCatalogCategoryMasterID = 5 and  categoryplanid = 5464 and CustomerID in (select customer_id from customer where customer_name like '%wilbur%');


SELECT DeviceVendorID, IMEI, IMEI2, eSIM, ICCID from MobilityOrderXDevices where MobilityOrderID = 120945

select * from MobilityOrderCharges Where MobilityOrderID = 120945
and IsActive = 1
and USOC = 'MNEQUIP'

SELECT DeviceStatusID, * FROM DeviceXCarrier Where DeviceID = 5464 and carrierid = 178 and devicevendorid in (300)

SELECT StatusID, * FROM CustomerXProductCatalog where ProductCatalogCategoryMasterID = 5 and  categoryplanid = 5464 and CustomerID in (select customer_id from customer where customer_name like '%wilbur%')
and carrierid = 178


select * from DeviceVendor where DeviceVendorID = 300
select * from DeviceStatus where DeviceStatusID = 500

select * from MobilityOrderItemHistory where MobilityOrderItemID = 363323
and ChangeType like '%Vendor'
order by 1 desc


select * from Devices where DeviceID = 5464

------------------------------------
