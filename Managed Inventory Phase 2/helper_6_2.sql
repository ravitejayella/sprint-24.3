DECLARE @DeviceID INT = 4750
	,@EquipmentInventoryIDs varchar(max) = '1713|1711'
	,@CarrierID int = 122
	,@CustomerID int = 20

SELECT NULL AS MobilityOrderXDeviceID
	,@DeviceID
	,ei.DeviceXCarrierID
	,ei.DeviceConditionID
	,ei.DeviceVendorID
	,NULL AS InventoryDeviceRelID
	,ei.EquipmentInventoryMasterID AS EquipmentInventoryID
	,ei.MEID AS IMEI
	,ei.ESN AS ESN
	,'vCom' AS DeviceProvider -- ASK
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
	,cdp.PriceExpiryDate
	,cdp.SpecialPrice
	,CASE 
		WHEN (
				cdp.PriceExpiryDate IS NOT NULL
				AND GETDATE() <= cdp.PriceExpiryDate
				AND ISNULL(cdp.SpecialPrice, 0) <> 0
				)
			THEN cdp.SpecialPrice
		ELSE dc.Price
		END AS Price
FROM EquipmentInventory ei(NOLOCK)
LEFT JOIN DeviceXCarrier dc(NOLOCK) ON dc.DeviceID = ei.DeviceID
	AND dc.CarrierID = @CarrierID
	AND dc.DeviceVendorID = ei.DeviceVendorID
	AND dc.DeviceConditionID = ei.DeviceConditionID
LEFT JOIN CustomerXDeviceSpecialPrice cdp(NOLOCK) ON cdp.CustomerID = @CustomerID
	AND cdp.DeviceXCarrierID = dc.DeviceXCarrierID
	AND cdp.IsActive = 1
LEFT JOIN FulfillmentVendor fv (NOLOCK) ON fv.DeviceVendorID = ei.DeviceVendorID
WHERE ei.DeviceID = @DeviceID
	AND ei.EquipmentInventoryMasterID IN (
		SELECT CAST(Value AS INT)
		FROM [dbo].SplitValue(@EquipmentInventoryIDs, '|')
		)


select * from EquipmentInventory order by 1 desc

			IF 1 = 1 AND EXISTS (SELECT 1 from EquipmentInventory where 1 = 0 )
			begin
				print 'yea'
			end

			SELECT * FROM EquipmentStatusMaster