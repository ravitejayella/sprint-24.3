/*

1. new Requested By - 'Inventory Management'

2. Add a new field to MobilityOrders and populate it (and show it) in case of Spare Order created which is a Replenishment Order 
	a. Replenishment Order should be a Spare Order from vCom Solutions Service Provider.
	b. Check if existing functionality has vCom SP customer Spare orders add devices to Store.
		i. If so, Update the customer once the devices get added to store 
		ii. If not, complete the vCom SP spare order, add devices to store with said Customer
	c. in UI, show Customer for which Replenishment Order was created for


	Order Type = Spare
	Customer = vCom Solutions - Service Provider
	Requested By = Inventory Management
	Account = vCom - Pre-Purchased Hardware account (this will need to be created)
	Carrier = Carrier from the carrier account that triggered the replenishment
	Carrier Account = there's only 1 account per carrier
	Cost = cost in the device catalog
	Price = $0
	Shipping = Ground
	Shipping Charge = $0
	Shipping Price = $0
	Shipping Address = 8529 Meadowbridge Rd, Mechanicsville, VA 23116
	Fulfillment and SIM charges = $0.
	The Charge total for these orders should be $0
	Add the following note to the order:
		Reupping Managed Inventory for <Customer>. Configured Minimum Qty for <Device> is <Minimum Qty> and Replenishment Qty is <Replenishment Qty>

		Example: 

		AT&T BC Carrier account has Managed Inventory and the Apple iPhone 15 (Black 512GB) is one of the configured devices. Minimum qty = 5 and Replenish Qty = 20. 

		There are 2 in Spare Inventory (1 with no carrier, 1 with carrier = AT&T BC) and 6 in the store (2 carrier = AT&T BC, 2 carrier = Null, 2 carrier = Verizon BC). So 6 eligible for AT&T and 5 eligible for Verizon. 

		An AT&T BC order is created for 1 Apple iPhone 15 (Black 512GB), that leaves  5 available (1 in Spare, 4 in the store). An order would be created for 15 devices to bring the available inventory back up to 20

------------------------------------------------------------------------------------------------------------

3. Automatically create a spare order for a device that has been in the store for the number of configured inventory days +1. 

4. Automatically charge the customer and complete spare orders created by the inventory management process. 
	a. Device Price = current catalog price 
	b. Whether the device(s) should be charged in a lump sum or as installments is based on what's configured for that device on the Inventory Management section of the carrier account 






*/