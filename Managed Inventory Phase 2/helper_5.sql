use mobility
go

select * from sys.tables where name like '%special%'

select top 100 * from CustomerXDeviceSpecialPrice
where CustomerID = 20

select top 10 * from CustomerXCarrierAccounts order by 1 desc

SELECT * FROM LineStatusMaster

select top 10 * from DeviceXCarrier

select * from EquipmentInventory
where CarrierID is not null

select * from OrderDeviceOptionsMaster

declare @EquipmentInventoryIDs varchar(100) = '593|595|596|597'
DECLARE @DeviceID INT = 2675, @CarrierID INT = 122
SELECT NULL AS MobilityOrderXDeviceID
	,@DeviceID
	,ei.DeviceXCarrierID
	,ei.DeviceConditionID
	,ei.DeviceVendorID
	,NULL AS InventoryDeviceRelID
	,ei.EquipmentInventoryMasterID AS EquipmentInventoryID
	,ei.MEID AS IMEI
	,ei.ESN AS ESN
	,'vCom' AS DeviceProvider			-- ASK
	,ei.DeviceSellerID as DeviceSellerID
	,ei.DeviceWarrantyTypeMasterID as DeviceWarrantyTypeMasterID
	,ei.DeviceWarrantyTermMasterID as DeviceWarrantyTermMasterID
	,ei.InvoiceNumber as InvoiceNumber
	,ei.IMEI2 as IMEI2
	,ei.EID AS eSIM
	,ei.IseSimSelected as IseSimSelected
FROM  EquipmentInventory ei  
WHERE ei.DeviceID = @DeviceID
	AND ei.EquipmentInventoryMasterID IN (
		SELECT CAST(Value AS INT)
		FROM [dbo].SplitValue(@EquipmentInventoryIDs, '|')
	)

 
    SELECT distinct column_name  
    FROM INFORMATION_SCHEMA.COLUMNS 
    WHERE TABLE_NAME = 'CustomerXCarrierAccounts' 
	order by 1 desc

    AND COLUMN_NAME like '%PlanMonths%' or 
	COLUMN_NAME like '%DownPayment%' or
	COLUMN_NAME like '%PlanMonths%' 

AllowInstallments
DownPayment
PlanMonths

select * from CustomerXCarrierAccounts where AllowInstallments = 1 and customerid = 20 and accountname = 'vCom Solutions Corp - AT&T'


select * from MobilityorderXDevices where MobilityorderID = 118900


select substring('12 months', 1, 3)
select  * from ManagedInventoryXCarrierAccounts

	SELECT 
    o.name AS FunctionName,
    m.definition AS FunctionDefinition
FROM 
    sys.objects o
INNER JOIN 
    sys.sql_modules m ON o.object_id = m.object_id
WHERE 
    o.type IN ('FN', 'IF', 'TF')  -- Functions: Scalar, Inline Table-Valued, Table-Valued
    AND o.is_ms_shipped = 0       -- Exclude system functions
    AND o.name LIKE '%pricing%'     -- Filter by function name containing 'price'
ORDER BY 
    o.name;

	DECLARE @price decimal(19, 2) = CAST(1 AS DECIMAL(19,2))

	select dbo.uspGetPricingCategoryID(@price) 


select top 10 Depvalue, * from MobilityOrderitems

 ---------------------------------------------------- ship
SELECT TOP 1  account_id
					, c.CustomerAddressID
					, a.address_1
					, a.city
					, sa.StateMasterID
					, a.zip
					,CM.COUNTRYMASTERID
					,a.*
				FROM customer cus(NOLOCK)
				LEFT JOIN ipath..account a(NOLOCK) ON cus.customer_id = a.customer_id
				LEFT JOIN CustomerAddress c(NOLOCK) ON c.CustomerID = cus.customer_id
					AND c.AccountID = a.account_id
					AND c.IsActive = 1
					AND c.AddressType = 'S'
				LEFT JOIN StateMaster sa(NOLOCK) ON sa.StateCode = a.STATE
					AND sa.IsActive = 1
				LEFT JOIN CountryMaster cm (NOLOCK) ON cm.CountryCode = a.country
					AND cm.IsActive = 1
				WHERE a.STATUS = 'A'
					AND cus.customer_id = 20
					AND a.is_corp = 1




SELECT mica.CustomerID AS CustomerID
	,cca.CustomerXCarrierAccountsID AS CustomerXCarrierAccountsID
	,mica.DeviceID AS DeviceID
	--,COUNT(*) AS UnUsedDeviceCount
	--,STRING_AGG(CAST(ei.EquipmentInventoryMasterID AS VARCHAR(100)), '|') AS EquipmentInventoryIDs
FROM ManagedInventoryXCarrierAccounts mica(NOLOCK)
INNER JOIN CustomerXCarrierAccounts cca(NOLOCK) ON mica.CustomerXCarrierAccountsID = cca.CustomerXCarrierAccountsID
INNER JOIN EquipmentInventory ei(NOLOCK) ON ei.DeviceID = mica.DeviceID
	AND ISNULL(ei.CustomerID, 0) = mica.CustomerID
	AND ISNULL(mica.CustomerXCarrierAccountsID, 0) = ISNULL(ei.CustomerXCarrierAccountsID, 0)
	AND ISNULL(ei.MobilityOrderID, 0) = 0
	AND ISNULL(ei.MobilityOrderItemID, 0) = 0
WHERE mica.IsActive = 1
	AND cca.IsActive = 1
	AND ISNULL(cca.IsManagedInventory, 0) <> 0
	AND ei.EquipmentPurchasedDate IS NOT NULL
	AND GETDATE() > DATEADD(day, CAST(RTRIM(LTRIM(substring(cca.InventoryPeriod, 1, 3))) AS INT), CAST(ei.EquipmentPurchasedDate AS DATE))
GROUP BY mica.CustomerID
	,mica.DeviceID
	,cca.CustomerXCarrierAccountsID


select * from Equipmentinventory
where EquipmentinventorymasterID = 1711

 
SELECT * FROM EquipmentInventory 
where EquipmentinventorymasterID = 1711


SELECT * FROM DeviceXCarrier 
where carrierID = 178
and deviceid = 4785

select * from DeviceStatus