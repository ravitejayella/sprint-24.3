use mobility
go

EXEC [MobilityOrders_GetAllByCustomer] @IncludeClosedOrders = 0
		,@ViewOnlyCancelled = 0
		,@ViewPendingCancel = 0
		,@UserID = 1404
		,@ChannelType = 0
        -- ,@OrderOwnerID = 1404
		-- ,@LineNumber = '2797894500'
        -- ,@ClosedToDate = '04/19/2024'

exec [V23_MobilityOrders_GetAllByCustomer] @IncludeClosedOrders = 1
	,@ViewOnlyCancelled  = 0
	,@ViewPendingCancel  = 0
	,@LineNumber = '2797894500'
	,@ChannelType = 0
	,@UserID   = 342

select * from MobilityOrderItems where MobilityOrderID = 124413
select * from MobilityOrderItems where MobilityOrderID = 124409

select * from MobilityOrders where MobilityOrderID = 124413
select * from MobilityOrders where MobilityOrderID = 124409

select * from  MobilityOrderXDevices where MobilityOrderID =124413

select * from CustomerXCarrierAccounts where CustomerXCarrierAccountsID = 3885
select * from CustomerXCarrierAccounts where CustomerXCarrierAccountsID = 4694

select * from CarrierAccounts where CarrierAccountID = 2641
select * from CarrierAccounts where CarrierAccountID = 3445

select * from OrderStageMaster -- 2001

select * from users where user_name like '%Darlene%'

