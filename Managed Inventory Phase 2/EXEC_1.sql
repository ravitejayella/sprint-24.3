USE mobility
GO

select * from ReplenishmentOrdersLog
where isactive = 1
and isreplenished = 0

SELECT @@TRANCOUNT

EXEC [dbo].[CustomerCarrierAccounts_UpdateReplenishmentLog]


EXEC [dbo].[CustomerCarrierAccounts_CreateReplenishmentOrders]

SELECT TOP 5 ReplenishmentOrdersLogID -- limiting 5 as batch size
				,DeviceID
				,CarrierID
				,CustomerID
				,CustomerXCarrierAccountsID
				,RefillQty
				,MinimumQty
				,ReplenishQty
			FROM ReplenishmentOrdersLog(NOLOCK)
			WHERE IsActive = 1
				AND ISNULL(IsReplenished, 0) = 0

 
--Cannot insert the value NULL into column 'AccountID', table 'mobility.dbo.MobilityOrders'; column does not allow nulls. INSERT fails.

--An INSERT EXEC statement cannot be nested.	Charges_GetOtherOrderCharges

select * from MobilityOrders where Mobilityorderid = 118875
select * from MobilityOrderItems where Mobilityorderid in  (118870,
118889,
118890,
118891,
118892,
118893,
118894)

select * from MobilityOrderXDevices where Mobilityorderid = 118870

select * from MobilityOrderXDevices where Mobilityorderid = 118877

--update MobilityOrderCharges 
--set MobilityOrderItemID = null
--where Mobilityorderid = 118871

select * from MobilityOrderCharges where Mobilityorderid = 118871
select * from MobilityOrderCharges where Mobilityorderid = 118872

select top 10  * from CustomerXDevices

select * from sys.tables where name like '%customer%%device%'

select * from CustomerXDeviceSpecialPrice where customerID = 112275 order by 1 desc

SELECT customerid, carrierid, customerXCarrierAccountsID, * FROM EquipmentInventory where EquipmentInventoryMasterID = 1711

SELECT top 10 customerid, carrierid, CarrierAccountID, * FROM SpareInventory -- where EquipmentInventoryMasterID = 1711

