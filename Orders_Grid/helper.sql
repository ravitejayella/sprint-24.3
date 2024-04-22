use mobility
go

EXEC [MobilityOrders_GetAllByCustomer] @IncludeClosedOrders = 1
		,@ViewOnlyCancelled = 0
		,@ViewPendingCancel = 0
		,@LineNumber = '2797894500'
		,@ChannelType = 0
		,@UserID = 342
        ,@ClosedToDate = '04/19/2024'

exec [V23_MobilityOrders_GetAllByCustomer] @IncludeClosedOrders = 1
	,@ViewOnlyCancelled  = 0
	,@ViewPendingCancel  = 0
	,@LineNumber = '2797894500'
	,@ChannelType = 0
	,@UserID   = 342

select * from MobilityOrderItems where LineNumber = '2797894500'


