/************************** SPARE ORDER CREATE  -- (REPLENISH)

---- PARAMS
1.  @CustomerXCarrierAccountsID INT  Carrier Account :  Only 1 account exists for vCom service provider for any given carrier. So, use that...
		a. @CustomerID
		b. @CarrierID
		c. @CarrierAccountID
2. @AccountID INT  -- vCom - Pre-Purchased Hardware account (this will need to be created)


3. @DeviceXML
		DeviceXCarrierID  --- 
				gives DeviceID
				gives DeviceTypeID 
				gives DevicePricingMasterID
				gives DeviceConditionID
				gives DeviceVendorID
		,Qty
		,Cost = cost in the device catalog
		,Margin = -100??? as price is 0
		,Price = $0
		,IsInstallmentPlan
		,DownPayment
		,ROIOnCost
		,ROIOnPrice
		,Term
		,MonthlyPaymentOnCost
		,MonthlyPaymentOnPrice
		,CustomerXProductCatalogID
		,ChargeType
		,USOC
		,ChargeDescription

4. Shipping = Ground
	Shipping Charge = $0
	Shipping Price = $0
	Shipping Address = 8529 Meadowbridge Rd, Mechanicsville, VA 23116
	Fulfillment and SIM charges = $0.
	The Charge total for these orders should be $0

		******* GET ALL DETAILS OF THIS ADDRESS *******

	,@AttentionToName VARCHAR(200) = NULL
	,@Address1 VARCHAR(500) = NULL
	,@Address2 VARCHAR(500) = NULL
	,@Address3 VARCHAR(500) = NULL
	,@City VARCHAR(150) = NULL
	,@StateMasterID INT = NULL
	,@Zipcode VARCHAR(10) = NULL
	,@CountryMasterID INT = NULL
	,@ShippingTypeID INT = NULL


5. @ChargesXML
		[ChargeType] VARCHAR(50)    = "One Time"
		,[USOC] VARCHAR(50)			= "SHIP4"
		,[ChargeDescription] VARCHAR(250) = "Ground Shipping & Handling Charge"
		,[Quantity] INT		
		,[Cost] DECIMAL(18, 2)			= "32"
		,[Margin] DECIMAL(18, 2)		= 0	
		,[Price] DECIMAL(18, 2)			= "32"


		 ******* get shipping charges usoc description cost price margin etc.. from this query : ******* 
		(
				SELECT ShippingTypeMasterID
					,ShippingType
					,[ChargeType]
					,USOC
					,[ChargeDescription]
					,Cost
					,Margin
					,Price
				FROM (
					SELECT s.ShippingTypeMasterID
						,s.ShippingType
						,s.ShippingChargeType AS [ChargeType]
						,s.ShippingUSOC AS USOC
						,s.ShippingDescription AS [ChargeDescription]
						,CASE 
							WHEN ISNULL(smxc.ShippingCost, 0) = 0
								THEN s.ShippingCost
							ELSE smxc.ShippingCost
							END AS Cost
						,ISNULL(smxc.ShippingMargin, s.ShippingMargin) AS Margin
						,ISNULL(smxc.ShippingPrice, s.ShippingPrice) AS Price
						,ISNULL(smxc.IsActive, s.IsActive) AS IsActive
					FROM ShippingTypeMaster s
					LEFT JOIN ShippingTypeMasterXCustomer smxc(NOLOCK) ON smxc.ShippingTypeMasterID = s.ShippingTypeMasterID
						AND smxc.CustomerXCarrierAccountsID = @CustomerXCarrierAccountsID
					--AND smxc.IsActive = @IsActive  
					WHERE s.IsActive = 1
						AND s.ShippingTypeMasterID IN (
							1
							,3
							)
					) t
				WHERE IsActive = @IsActive
				ORDER BY ShippingTypeMasterID
		)


USE : @OrderDescription ?
	,@AddedByID INT
	,@RequestorID INT  =  'Inventory Management'
	
	,@TicketReferenceNumber VARCHAR(50) = NULL
	,@UserFirstName VARCHAR(250) = NULL
	,@UserLastName VARCHAR(250) = NULL
	,@UserTitle VARCHAR(50) = NULL
	,@UserEmail VARCHAR(250) = NULL
	,@CopyEndUser BIT = 0


---- TABLES NEEDED : 
TABLE : ReplenishmentOrdersLog
COLUMNS : 
	1. ReplenishmentOrdersLogID primary key identity
	2. DeviceID INT NOT NULL
	3. CarrierID INT NOT NULL
	4. CustomerID INT NOT NULL
	5. CustomerCarrierAccountID INT NOT NULL
	6. Quantity INT NOT NULL
	7. IsActive BIT DEFAULT 1 NOT NULL
	8. IsReplenished BIT NOT NULL
	9. DeviceXML VARCHAR(MAX)

************************** SPARE ORDER CREATE  -- (REPLENISH) END */

/************************************************************************************************************************************************/

/************************** SPARE ORDER COMPLETE -- (MOVE TO CUSTOMER SPARE)

---- PARAMS
1. 

------------- SHIPPING DETAILS
shipping type - ground
address - coorporate address
Attention to name - N/A
Tracking no - N/A
Ship date - Date of completion
Shipping Vendor - Other
First Name, LastName - not required.


---- TABLES

************************** SPARE ORDER COMPLETE END */

MobilityOrderID	MobilityOrderItemID
118840	354309