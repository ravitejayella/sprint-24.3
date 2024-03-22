USE mobility
GO

--select * from ReplenishmentOrdersLog

SELECT @@TRANCOUNT

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

 
 An INSERT EXEC statement cannot be nested.
 Charges_GetOtherOrderCharges

