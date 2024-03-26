use mobility
go


select  * from EquipmentInventory
select * from ManagedInventoryXCarrierAccounts


 SELECT mica.CustomerID, cca.CustomerXCarrierAccountsID, mica.DeviceID, COUNT(*) AS DeviceCount
		FROM ManagedInventoryXCarrierAccounts mica(NOLOCK)
		INNER JOIN CustomerXCarrierAccounts cca(NOLOCK) ON mica.CustomerXCarrierAccountsID = cca.CustomerXCarrierAccountsID
		INNER JOIN EquipmentInventory ei (NOLOCK) ON ei.DeviceID = mica.DeviceID
			AND ISNULL(ei.CustomerID, 0) = mica.CustomerID
			AND ISNULL(mica.CustomerXCarrierAccountsID, 0) = CASE WHEN ISNULL(ei.CustomerXCarrierAccountsID, 0) = 0 THEN ISNULL(mica.CustomerXCarrierAccountsID, 0) ELSE ei.CustomerXCarrierAccountsID END
			AND ISNULL(ei.MobilityOrderID, 0) = 0
			AND ISNULL(ei.MobilityOrderItemID, 0) = 0
		WHERE mica.IsActive = 1
			AND cca.IsActive = 1
			AND ISNULL(cca.IsManagedInventory, 0) <> 0
			AND EquipmentPurchasedDate IS NOT NULL 
			AND GETDATE() > DATEADD(day, CAST(RTRIM(LTRIM(substring('30 days', 1, 3))) AS INT), CAST(EquipmentPurchasedDate AS DATE)) 
		GROUP BY mica.CustomerID, mica.DeviceID, cca.CustomerXCarrierAccountsID
		

	sp_help CustomerXCarrierAccounts
	
	select * from sys.procedures where name like '%term%'

	sp_helptext GetDateOrTermPeriodOptions

select distinct InventoryPeriod 
from CustomerXCarrierAccounts
where InventoryPeriod is not null

select CAST(RTRIM(LTRIM(substring('30 days', 1, 3))) AS INT)

select cast('30 days' as date)
