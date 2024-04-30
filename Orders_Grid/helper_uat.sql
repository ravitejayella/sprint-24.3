use mobility
go

EXEC [MobilityOrders_GetAllByCustomer] @IncludeClosedOrders = 0
		,@ViewOnlyCancelled = 0
		,@ViewPendingCancel = 0
		,@UserID = 1404
		,@OrderOwnerID = 1404
		,@ChannelType = 0
		-- ,@LineNumber = '2797894500'
        -- ,@ClosedToDate = '04/19/2024'

exec [V23_MobilityOrders_GetAllByCustomer] @IncludeClosedOrders = 1
	,@ViewOnlyCancelled  = 0
	,@ViewPendingCancel  = 0
	,@LineNumber = '2797894500'
	,@ChannelType = 0
	,@UserID   = 342

select * from MobilityOrderItems where LineNumber = '2797894500'

