use mobility
go
ExistingShippingAddressID
103669

select top 10 * from ipath..accounts order by 1 desc


select * from customerAddress where customerID = 112275 and accountid = 148423 and address1 = '8529 Meadowbridge Rd'

select top 10 * from ipath..sdCase

declare @CustomerID INT = 112275
SELECT TOP 1  account_id
	, c.CustomerAddressID
	, a.address_1
	 ,a.city
	,sa.StateMasterID
	,a.zip
FROM ipath..account a (NOLOCK)
LEFT JOIN CustomerAddress c (NOLOCK) ON c.CustomerID = @CustomerID 
	AND c.AccountID = a.account_id
	AND c.IsActive = 1
	AND c.AddressType = 'S'
LEFT JOIN StateMaster sa (NOLOCK) ON sa.StateCode = a.state
	AND sa.IsActive = 1
WHERE a.status = 'A'
	AND a.customer_id = @CustomerID 
	and a.account_name = 'vCom - Pre-Purchased Hardware' 
order by 1 desc
				
select top 10 * from ipath..account where customer_id = 112275 and account_name = 'vCom - Pre-Purchased Hardware' order by 1 desc

 
 declare @CarrierID INT = 122

				-- GET Customer, CarrierAccount Info
				SELECT TOP 1 customer_id
					,cca.CarrierAccountID
					,cca.CustomerXCarrierAccountsID
				FROM customer c (NOLOCK)
				JOIN CustomerXCarrierAccounts cca (NOLOCK) ON cca.CustomerID = c.customer_id
					AND cca.CustomerID = c.customer_id
					AND cca.CarrierID = @CarrierID
					AND cca.IsActive = 1
				WHERE c.customer_name = 'vCom Solutions - Service Provider'


				sp_helptext CustomerCarrierAccounts_CreateReplenishmentOrders

SELECT ROW_NUMBER() OVER (
		PARTITION BY dxc.carrierID
		,dxc.DeviceID
		,dxc.DeviceConditionID ORDER BY [Margin] DESC
			,dxc.addeddatetime DESC
		) AS rownum
FROM DeviceXCarrier dxc(NOLOCK)
WHERE rownum = 1

	select * from CarrierAccounts where customerid = 112275
	select * from CustomerXCarrierAccounts where customerid = 112275
		and carrierid = 122
		and isactive = 1		

SELECT a.customer_id AS CustomerID
		,'S' AS AddressType
		,a.is_corp IsCorp
		,1 AS isViewable
		,1 isActive
		,99999 AddedByID
		,99999 ChangedByID
		,a.account_id AS AccountID
		,'a' AS RelType
	FROM ipath..account a(NOLOCK)
	LEFT JOIN CustomerAddress c(NOLOCK) ON c.AccountID = a.account_id
		AND a.customer_id = c.CustomerID
		AND AccountID IS NOT NULL
		AND RelType = 'a'
	WHERE Customer_Id = 112275
		AND CustomerAddressID IS NULL
		AND STATUS = 'A'


select top 10 * from ipath..account where address_1 like '%Meadowbridge%' or address_2 like '%Meadowbridge%' --or address_3 like '%Meadowbridge%' --where customer_id = 112275 and is_corp = 1
select * from CustomerAddress where (address1 like '%Meadowbridge%' or address2 like '%Meadowbridge%' or address3 like '%Meadowbridge%')
 and customerID = 112275




select * from CustomerXDeviceSpecialPrice where customerID = 112275 order by 1 desc

select TOP 1 * from CustomerXProductCatalog where CategoryPlanID = 4750 order by 1 desc
select top 10 * from Devices
SELECT TOP 1 1
					FROM CustomerXProductCatalog
					WHERE CustomerID = 112275
						AND CarrierID = 178
						AND CategoryPlanID = 6021
						AND ProductCatalogCategoryMasterID = 5		-- Device
						AND StatusID = 1


----------------------------------------------------------------------------------

SELECT DeviceID, ReplenishmentCCAID, count(*) AS RefillCount FROM MobilityOrderItems moi (NOLOCK)
JOIN MobilityOrderXDevices moxd (NOLOCK) ON moi.MobilityOrderItemID = moxd.MobilityOrderItemID 
WHERE ISNULL(ReplenishmentCCAID, 0) <> 0
	AND moi.IsActive = 1
	AND moi.LineStatusMasterID NOT IN (5001, 7001)
GROUP BY DeviceID, ReplenishmentCCAID


select * from Linestatusmaster
sp_helptext CustomerXProductCatalog_Insert