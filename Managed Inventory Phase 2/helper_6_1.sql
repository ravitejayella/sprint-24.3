use mobility
go

select DEPValue, * from EquipmentInventory where customerID = 20
and EquipmentInventoryMasterID in (1711,1713,1714)
order by 2 desc

SELECT top 5 * FROM DeviceXCarrier
SELECT top 5 * FROM CustomerXProductCatalog

select top 5 * from CustomerXDeviceSpecialPrice
where CustomerID = 20


select * from EquipmentInventory where EquipmentInventoryMasterID = 1712
SELECT * FROM DeviceXCarrier 
WHERE DeviceID = 4785
and carrierid = 178

SELECT * FROM sys.tables where name like '%shipping%'

 
SELECT TOP 1 
	s.ShippingChargeType AS [ChargeType]
	,s.ShippingUSOC AS USOC
	,s.ShippingDescription AS [ChargeDescription]
	,CASE 
		WHEN ISNULL(smxc.ShippingCost, 0) = 0
			THEN s.ShippingCost
		ELSE smxc.ShippingCost
		END AS Cost
	,ISNULL(smxc.ShippingMargin, s.ShippingMargin) AS Margin
	,ISNULL(smxc.ShippingPrice, s.ShippingPrice) AS Price
FROM ShippingTypeMaster s (NOLOCK)
LEFT JOIN ShippingTypeMasterXCustomer smxc(NOLOCK) ON smxc.ShippingTypeMasterID = s.ShippingTypeMasterID
	AND smxc.CustomerXCarrierAccountsID = 2124
WHERE s.IsActive = 1
	AND smxc.IsActive = 1
	AND s.ShippingType = 'Ground'

UNION 

SELECT 'One Time'
	,'MNDEP'
	,'Device Enrollment Program'
	,

	SELECT TOP 10 * FROM MobilityOrderXDevices where MobilityOrderID = 118921 order by 1 desc
	select * from MobilityOrderitems  where MobilityOrderID = 118921 order by 1 desc

	select top 10 * from EquipmentInventory order by 1 desc


select * from MobilityOrderCharges where mobilityorderid = 118459
order by 1 desc

select * from sys.tables where name like '%charge%'


SELECT ISNULL(CC.CustomerChargeID, 0) CustomerChargeID
			,C.ChargeID
			,ISNULL(CC.CustomerID, 0) CustomerID
			,ISNULL(CC.CategoryPlanID, C.CategoryPlanID) AS CategoryPlanID
			,ISNULL(ISNULL(CC.AttributeID, C.AttributeID), 0) AttributeID
			,ISNULL(CC.ProductCatalogCategoryMasterID, C.ProductCatalogCategoryMasterID) ProductCatalogCategoryMasterID
			,ISNULL(CC.Cost, C.Cost) AS Cost
			,ISNULL(CC.Margin, C.Margin) AS Margin
			,ISNULL(CC.Price, C.Price) AS Price
			,CASE 
				WHEN CC.IsActive IS NULL
					THEN CAST(0 AS BIT)
				ELSE CC.IsActive
				END AS IsActive
			,u.usoc AS USOC
			,billDescription AS BillDescription
			,CASE 
				WHEN timesToBill = '1'
					THEN 'One Time'
				ELSE 'Monthly'
				END AS chargeType
		FROM Charges C
		LEFT JOIN CustomerCharges CC ON C.CategoryPlanID = CC.CategoryPlanID
			AND C.ProductCatalogCategoryMasterID = CC.ProductCatalogCategoryMasterID --AND C.IsActive = 1            
			AND CC.ChargeID = C.ChargeID
			AND CC.CustomerID = @CustomerID
		LEFT JOIN BillingDb..usoc_master U ON U.usoc = C.usoc
		WHERE C.ProductCatalogCategoryMasterID = 8
			AND c.CategoryPlanID = @CarrierAccountID




SELECT TOP 1 LineStatusMasterID
FROM LineStatusMaster (NOLOCK)
WHERE LineStatus = 'Complete' and isactive = 1


SELECT TOP 1  OrderTypeMasterID
		FROM OrderTypeMaster(NOLOCK)
		WHERE OrderType = 'Spare'

select top 10 * from SpareInventory
select top 100 linesubstatusmasterid, * from MobilityOrderItems where linestatusmasterid = 7001
order by MobilityOrderItemID desc


select * from LineSubStatusMaster
where linestatusmasterid = 7001

SELECT TOP 1  lsm.LineStatusMasterID, lsm.*
				FROM LineStatusMaster lm (NOLOCK)
				LEFT JOIN LineSubStatusMaster lsm (NOLOCK) ON lsm.LineStatusMasterID = lm.LineStatusMasterID
				WHERE LineStatus = 'Complete'
					AND lsm.LineSubStatus = 'Automated'
					AND lm.IsActive = 1
					AND lsm.IsActive = 1


SELECT TOP 10 * FROM MobilityOrders
OrderOwnerID
320


sp_helptext uspSendDeviceAvailabilityNotification

use mobility
go
select * from sys.procedures where name like '%v23%'





SELECT top 10 * FROM MobilityOrders Order by 1 desc

SELECT top 10  * FROM MobilityOrderItems Order by 1 desc

select * from FulfillmentVendor
where IsQMobile = 1

--update MobilityOrderXDevices
--set DeviceProvider = 'AT&T-Apex'
--WHERE MobilityOrderID = 118912 or MobilityOrderID = 118913


select top 10 * from SpareInventory
order by 1 desc


MobilityOrders_Getservicedetailsforspareordersbyid 118913

select distinct DEPValue from CarrierAccounts 
where DEPValue is not null and DEPValue <> 'none' Order by 1 desc