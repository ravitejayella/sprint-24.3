use MOBILITY
GO

select top 10 * from spareInventory
where customerid = 119214
and deviceid = 5537
and EquipmentInventoryID = 1731
 order by 1 DESC

select * from EquipmentInventory where EquipmentInventorymasterid = 1731
select * from EquipmentInventory where EquipmentInventorymasterid = 1732

select top 100 * from MobilityOrders where Ordertypeid = 3
and customerid = 119214
and MobilityOrderID = 121825
 order by 1 desc


 select * from MobilityOrderXDevices where MobilityOrderID = 121825
 select * from MobilityOrderCharges  where MobilityOrderID = 121825

 SELECT top 10 * FROM MobilityOrderCharges 
 where ChargeType = 'Monthly' and	USOC = 	'MINSTPLAN' and ChargeDescription = 'Samsung Galaxy S23 Ultra (Lavender 256GB) Installment Plan (12 Months)' 
	order by 1 desc


 select top 10 * from MobilityOrderXDevices 
 where DeviceID = 5537 and equipmentinventoryid = 1731
order by 1 desc

select * from MobilityCarrierMaster
 SELECT  *FROM EquipmentInventory where EquipmentInventoryMasterID = 1753

-- GET Default Vendor for a carrier
declare @DeviceID INT = 3793
    ,@EquipmentInventoryIDs VARCHAR(MAX) = '1753|1754'
    ,@CarrierID INT = 229
    ,@CustomerID int = 119214
DECLARE @DefaultDeviceVendorID INT  

SELECT TOP 1 @DefaultDeviceVendorID = CASE 
        WHEN EXISTS (
                SELECT 1
                FROM DeviceXCarrier (NOLOCK)
                WHERE DeviceID = @DeviceID
                    AND CarrierID IN (
                        122
                        ,229
                        )
                )
            THEN 100
        WHEN EXISTS (
                SELECT 1
                FROM DeviceXCarrier dc (NOLOCK)
                JOIN Devices d ON dc.DeviceID = d.DeviceID
                WHERE dc.DeviceID = @DeviceID
                    AND dc.CarrierID = 178
                    AND d.Make <> 'Apple'
                )
            THEN 100
        WHEN EXISTS (
                SELECT 1
                FROM DeviceXCarrier dc (NOLOCK)
                JOIN Devices d ON dc.DeviceID = d.DeviceID
                WHERE dc.DeviceID = @DeviceID
                    AND dc.CarrierID = 178
                    AND d.Make = 'Apple'
                )
            THEN 600
        ELSE (
                SELECT TOP 1 DeviceVendorID
                FROM DeviceXCarrier (NOLOCK)
                WHERE DeviceID = @DeviceID
                ORDER BY Margin DESC
                    ,AddedDateTime DESC
                )
        END

SELECT @DefaultDeviceVendorID AS '@DefaultDeviceVendorID'	-- REMOVE
    
SELECT NULL AS MobilityOrderXDeviceID
    ,@DeviceID
    ,ei.DeviceXCarrierID
    ,ei.DeviceConditionID
    ,@DefaultDeviceVendorID AS DeviceVendorID
    ,NULL AS InventoryDeviceRelID
    ,ei.EquipmentInventoryMasterID AS EquipmentInventoryID
    ,ei.MEID AS IMEI
    ,ei.ESN AS ESN
    ,ei.ICCID AS ICCID
    ,ISNULL(fv.FulfillmentVendor, 'vCom') AS DeviceProvider
    ,ei.DeviceSellerID AS DeviceSellerID
    ,ei.DeviceWarrantyTypeMasterID AS DeviceWarrantyTypeMasterID
    ,ei.DeviceWarrantyTermMasterID AS DeviceWarrantyTermMasterID
    ,ei.InvoiceNumber AS InvoiceNumber
    ,ei.IMEI2 AS IMEI2
    ,ei.EID AS eSIM
    ,ei.IseSimSelected AS IseSimSelected
    ,ei.DEPValue AS DEPValue
    
    --pricing
    ,dc.Cost
    ,dc.Margin
    ,CASE 
        WHEN (
                cdp.PriceExpiryDate IS NOT NULL
                AND GETDATE() <= cdp.PriceExpiryDate
                AND ISNULL(cdp.SpecialPrice, 0) <> 0
                )
            THEN cdp.SpecialPrice
        ELSE dc.Price
        END AS Price,

        CASE 
        WHEN (
                @DefaultDeviceVendorID = 100
                AND @CarrierID = 122
                )
            THEN 'AT&T-Apex'
        WHEN (
                @DefaultDeviceVendorID = 100
                AND @CarrierID = 178
                )
            THEN 'Verizon-Telespire'
        WHEN (
                @DefaultDeviceVendorID = 100
                AND @CarrierID NOT IN (
                    122
                    ,178
                    )
                )
            THEN 'Webbing' else 'ajfakfanskfajfkafakfa' end as 'afafasfa', fv.*, dc.*
FROM EquipmentInventory ei(NOLOCK)
LEFT JOIN DeviceXCarrier dc(NOLOCK) ON dc.DeviceID = ei.DeviceID
    AND dc.CarrierID = @CarrierID
    AND dc.DeviceVendorID = @DefaultDeviceVendorID
    AND dc.DeviceConditionID = ei.DeviceConditionID
LEFT JOIN CustomerXDeviceSpecialPrice cdp(NOLOCK) ON cdp.CustomerID = @CustomerID
    AND cdp.DeviceXCarrierID = dc.DeviceXCarrierID
    AND cdp.IsActive = 1
LEFT JOIN FulfillmentVendor fv(NOLOCK) ON fv.DeviceVendorID = dc.DeviceVendorID
    AND fv.IsQMobile = 1
    AND fv.FulfillmentVendor = CASE 
        WHEN (
                @DefaultDeviceVendorID = 100
                AND @CarrierID = 122
                )
            THEN 'AT&T-Apex'
        WHEN (
                @DefaultDeviceVendorID = 100
                AND @CarrierID = 178
                )
            THEN 'Verizon-Telespire'
        WHEN (
                @DefaultDeviceVendorID = 100
                AND @CarrierID NOT IN (
                    122
                    ,178
                    )
                )
            THEN 'Webbing'
        ELSE fv.FulfillmentVendor
        END
WHERE ei.DeviceID = @DeviceID
    AND ei.EquipmentInventoryMasterID IN (
        SELECT CAST(Value AS INT)
        FROM [dbo].SplitValue(@EquipmentInventoryIDs, '|')
        )

select DeviceVendorID from EquipmentInventory where EquipmentInventorymasterid = 1748

select * from customer where customer_id = 112275
---------------------------------------------------
select DeviceConditionID, * from DeviceXCarrier where DeviceID = 3793 and deviceVendorID = 100 and carrierid = 229
select DeviceConditionID from EquipmentInventory where EquipmentInventorymasterid = 1753

select * from FulfillmentVendor
select top 10   * from MobilityOrders order by 1 desc

select top 10 * from SPareInventory order by 1 desc

select top 100 * from bill.chargemaster
-- where customerid = 119214
order by 1 DESC

select * from customer where customer_name like '%vcom%'
