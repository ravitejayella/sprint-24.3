DECLARE 
@ReferenceNumber VARCHAR(25)
	,@InventoryName VARCHAR(255)
	,@InventoryFirstName VARCHAR(250)
	,@InventoryLastName VARCHAR(250)
	,@InventoryEmail VARCHAR(250)
	,@CustomerID INT
	,@AccountID INT
	,@CarrierID INT
	,@CarrierAccountID INT
	,@CarrierDesc VARCHAR(250)
	,@Channel VARCHAR(250) = 'Wholesale Aggregator'
	,@ActivationDate DATETIME
	,@OrderTypeID INT
	,@add_usr VARCHAR(150)
	,@InventoryServiceID INT
	,@EquipmentInventoryID INT
	,@EquipmentStatusMasterID INT
	,@SpareInventoryID INT
	,@DeviceTypeMasterID INT
	,@IsPlanRequired BIT
	,@WebbingSDNo VARCHAR(75)
	,
	--Added on 12/6/2019                
	@AppleID VARCHAR(250)
	,@ContractStartDate DATETIME
	,@ContractEndDate DATETIME
	,@TermMasterID INT
	,@FamilyPlanID INT
	,@FamilyID INT
	,@CustomerXCarrierAccountsID INT
	,@IsBuddyUpgradable BIT
	,@IsUpgradeEligible BIT
	,@UpgradeEligibilityDate DATETIME
	,@TrueBuddyInventoryID INT
	,@BuddyIsUpgradeEligible BIT
	,@BuddyUpgradeEligibilityDate DATETIME
	,@BuddyContractEndDate DATETIME
	,@DeviceXCarrierID INT
	,@DeviceConditionID INT
	,@DeviceVendorID INT
	,@DeviceSerial VARCHAR(250)
DECLARE @InventoryID INT
	,@PrimaryServicePlanID INT
	,@PlanCustomerXProductCatalogID INT
	,@SubProduct VARCHAR(50)
	,@CostCenterID INT
	,@DepartmentID INT
	,@InventoryGroupID INT
	,@EmployeeID INT
	,@RelType CHAR(1)
	,@InventoryRelTypeID INT
	,@GLCodeID INT
	,@IsInventoryServiceRelSuccess BIT
DECLARE @NewInventoryServiceID INT
DECLARE @LineStatusMasterID INT
	,@IsEquipmentReady BIT
	,@IsEquipmentShipped BIT
	,@IsEquipmentDelivered BIT
	,@IsEquipmentCharged BIT
	,@DeviceChargeCapture BIT = 0
	,@APNValue VARCHAR(250) = NULL
	,@IsCustomAPN BIT = NULL
	,@DEPValue VARCHAR(250) = NULL
	,@IPAddressValue VARCHAR(250) = NULL
	,@CommunicationPlanValue VARCHAR(250) = NULL
	,@MSISDNValue VARCHAR(250) = NULL
	,@CarrierPriorityValue VARCHAR(250) = NULL
DECLARE @TerminationDate DATETIME
	,@ETFPrice DECIMAL(18, 2)

SELECT @add_usr = login_name
FROM users(NOLOCK)
WHERE user_id = @AddedByID

INSERT INTO orderBillingTransistionLog (
	mobilityOrderItemID
	,stateDescription
	,addedByID
	)
SELECT @MobilityOrderItemID
	,'Inventory Generation Started'
	,@AddedByID

------------------ SERVIVCE INFORMATION ------------------                
SELECT @ReferenceNumber = LineNumber
	,@InventoryName = (LTRIM(RTRIM(UserFirstName)) + ' ' + LTRIM(RTRIM(UserLastName)))
	,@InventoryFirstName = LTRIM(RTRIM(UserFirstName))
	,@InventoryLastName = LTRIM(RTRIM(UserLastName))
	,@ActivationDate = ISNULL(ActivationDate, GETDATE())
	,@InventoryServiceID = InventoryServiceID
	,@InventoryEmail = LTRIM(RTRIM(UserEmail))
	,@WebbingSDNo = WebbingSD
	,
	--Added on 12/6/2019                
	@AppleID = AppleID
	,@ContractStartDate = ContractStartDate
	,@ContractEndDate = ContractEndDate
	,@TermMasterID = TermMasterID
	,@IsBuddyUpgradable = IsBuddyUpgradable
	,@IsUpgradeEligible = IsUpgradeEligible
	,@UpgradeEligibilityDate = UpgradeEligibilityDate
	,@TrueBuddyInventoryID = TrueBuddyInventoryID
	,@CostCenterID = CostCenterID
	,@DepartmentID = DepartmentID
	,@InventoryGroupID = InventoryGroupID
	,@EmployeeID = EmployeeID
	,@RelType = RelType
	,@InventoryRelTypeID = InventoryRelTypeID
	,@TerminationDate = TerminationDate
	,@GLCodeID = GLCodeID
	,@LineStatusMasterID = LineStatusMasterID
FROM MobilityOrderItems(NOLOCK)
WHERE MobilityOrderID = @MobilityOrderID
	AND MobilityOrderItemID = @MobilityOrderItemID
	AND IsActive = 1

SELECT @IsEquipmentReady = (
		CASE 
			WHEN count(*) >= 1
				THEN 1
			ELSE 0
			END
		)
FROM MobilityOrderItemHistory MOIH(NOLOCK)
INNER JOIN MobilityOrderItems MOI(NOLOCK) ON MOI.MobilityOrderItemID = MOIH.MobilityOrderItemID
WHERE MOIH.MobilityOrderItemID = ISNULL(@MobilityOrderItemID, MOIH.MobilityOrderItemID)
	AND ChangeTo = 'Equipment Shipped'

SELECT @IsEquipmentShipped = (
		CASE 
			WHEN count(*) >= 1
				THEN 1
			ELSE 0
			END
		)
FROM [dbo].[EquipmentShipmentEmailLog] ESE(NOLOCK)
INNER JOIN MobilityOrderItems MOI(NOLOCK) ON MOI.MobilityOrderItemID = ESE.MobilityOrderItemID
WHERE ESE.isActive = 1
	AND ESE.IsAuthorized = 0
	AND MOI.LineStatusMasterID = 5051 -- Equipmentshipped status                            
	AND ESE.MobilityOrderID = @MobilityOrderID
	AND ESE.MobilityOrderItemID = ISNULL(@MobilityOrderItemID, ESE.MobilityOrderItemID)

SELECT @IsEquipmentDelivered = (
		CASE 
			WHEN count(*) >= 1
				THEN 1
			ELSE 0
			END
		)
FROM [dbo].[EquipmentShipmentEmailLog] ESE(NOLOCK)
INNER JOIN MobilityOrderItems MOI(NOLOCK) ON MOI.MobilityOrderItemID = ESE.MobilityOrderItemID
WHERE ESE.isActive = 1
	AND ESE.IsAuthorized = 1
	AND MOI.LineStatusMasterID = 5051 -- Equipmentshipped status                            
	AND ESE.MobilityOrderID = @MobilityOrderID
	AND ESE.MobilityOrderItemID = ISNULL(@MobilityOrderItemID, ESE.MobilityOrderItemID)

-- 1 / 0 -- 1 meaning already captured charges         
SELECT @IsEquipmentCharged = dbo.MobilityCharges_IsEquipmentReady(@MobilityOrderItemID);

-- Device Already Captured Flag, so no need to insert in this scenerio        
-- In case of ES, it will be Zero for the first time        
IF (
		@LineStatusMasterID = 5051
		AND @IsEquipmentReady = 1
		AND @IsEquipmentCharged = 0
		)
BEGIN
	SET @DeviceChargeCapture = 1
END

DECLARE @ChannelType BIT

------------------ CARRIER INFORMATION ------------------                
SELECT @OrderTypeID = OrderTypeID
	,@CustomerID = CustomerID
	,@AccountID = AccountID
	,@CarrierID = MO.CarrierID
	,@CarrierDesc = MCM.CarrierUsageName
	,@CarrierAccountID = CarrierAccountID
	,@Channel = Channel
	,@CustomerXCarrierAccountsID = ISNULL(CustomerXCarrierAccountsID, 0)
	,@ChannelType = CASE 
		WHEN BillingEntityID = - 1
			THEN 0
		ELSE 1
		END
FROM MobilityOrders MO(NOLOCK)
INNER JOIN iPath..carrier c(NOLOCK) ON c.carrier_id = MO.CarrierID
INNER JOIN MobilityCarrierMaster MCM(NOLOCK) ON MCM.carrierID = c.carrier_id
WHERE MobilityOrderID = @MobilityOrderID

IF @OrderTypeID = 3
	AND @LineStatusMasterID = 7001
BEGIN
	SET @DeviceChargeCapture = 1
END

-- NS: 5/11/2021        
-- updating iBiller date for Aggregator orders based on completion date        
IF (@ChannelType = 0)
BEGIN
	UPDATE MobilityOrderItems
	SET iBillerDate = (
			CASE 
				WHEN @Channel = 'Wholesale Aggregator'
					THEN dbo.GetBillCycleDate()
				ELSE NULL
				END
			)
	WHERE MobilityOrderID = @MobilityOrderID
		AND MobilityOrderItemID = @MobilityOrderItemID
		AND IsActive = 1
END

-- - NS: Hotfix - if value is 0        
IF (ISNULL(@CustomerXCarrierAccountsID, 0) = 0)
BEGIN
	SELECT @CustomerXCarrierAccountsID = CustomerXCarrierAccountsID
	FROM CustomerxCarrierAccounts(NOLOCK)
	WHERE CarrieraccountID = @CarrierAccountID
		AND CustomerID = @CustomerID
		AND CarrierID = @CarrierID

	-- FIX at Order level - DESK-13099 -20200622         
	UPDATE MobilityOrders
	SET CustomerXCarrierAccountsID = @CustomerXCarrierAccountsID
	WHERE MobilityOrderID = @MobilityOrderID
END

-- True Buddy upgrade info --  NS: 03/06/2020        
SELECT @BuddyUpgradeEligibilityDate = UpgradeEligibilityDate
	,@BuddyIsUpgradeEligible = IsUpgradeEligible
	,@BuddyContractEndDate = ContractEndDate
FROM InventoryServiceRel(NOLOCK)
WHERE InventoryServiceID = ISNULL(@TrueBuddyInventoryID, 0)

SET @SubProduct = CASE 
		WHEN @Channel = 'Wholesale Aggregator'
			THEN 'Complete'
		ELSE 'Select'
		END

------------------ DEVICE INFORMATION ------------------                
DECLARE @ServiceID INT
	,@ServiceType VARCHAR(250)

SELECT @ServiceID = ServiceID
	,@ServiceType = service_type
	,@EquipmentInventoryID = MOXD.EquipmentInventoryID
	,@SpareInventoryID = MOXD.SpareInventoryID
	,@DeviceTypeMasterID = DTM.DeviceTypeMasterID
	,@IsPlanRequired = IsPlanRequired
	,@DeviceXCarrierID = DeviceXCarrierID
	,@DeviceConditionID = DeviceConditionID
	,@DeviceVendorID = DeviceVendorID
	,@DeviceSerial = DeviceSerial
FROM MobilityOrderXDevices MOXD(NOLOCK)
INNER JOIN Devices D(NOLOCK) ON D.DeviceID = MOXD.DeviceID
INNER JOIN DeviceTypeMaster DTM(NOLOCK) ON DTM.DeviceTypeMasterID = D.DeviceTypesMasterID
INNER JOIN [service] s(NOLOCK) ON s.service_id = DTM.ServiceID
WHERE MobilityOrderID = @MobilityOrderID
	AND MobilityOrderItemID = @MobilityOrderItemID
	AND IsActive = 1

/*        
    Fix USOC ON DEVICES IF DOESN'T EXIST - 06.10.21        
   */
UPDATE MobilityOrderCharges
SET USOC = CASE 
		WHEN @DeviceTypeMasterID = 15
			THEN 'WWANHW'
		ELSE 'MNEQUIP'
		END
WHERE MobilityOrderItemID = @MobilityOrderItemID
	AND IsActive = 1
	AND ProductCatalogCategoryMasterID = 5
	AND ISNULL(USOC, '') = ''

UPDATE MobilityOrderCharges
SET USOC = CASE 
		WHEN @DeviceTypeMasterID = 15
			THEN 'WWANHW'
		ELSE 'MNEQUIP'
		END
WHERE MobilityOrderID = @MobilityOrderID
	AND IsActive = 1
	AND ProductCatalogCategoryMasterID = 5
	AND ISNULL(USOC, '') = ''




------------------- INSERT

INSERT INTO SpareInventory (
	CustomerID
	,DeviceID
	,EquipmentInventoryID
	,ESN
	,MEID
	,ICCID
	,PurchasedDate
	,DeviceProvider
	,DeviceSellerID
	,DeviceWarrantyTypeMasterID
	,DeviceWarrantyTermMasterID
	,InvoiceNumber
	,Cost
	,Margin
	,Price
	,MobilityOrderID
	,MobilityOrderItemID
	,AddedByID
	,ChangedByID
	,CarrierID
	)
SELECT @CustomerID
	,MOrD.DeviceID
	,MOrD.EquipmentInventoryID
	,MOrD.ESN
	,MOrD.IMEI
	,MOrD.ICCID
	,@ActivationDate
	,MOrD.DeviceProvider
	,MOrD.DeviceSellerID
	,MOrD.DeviceWarrantyTypeMasterID
	,MOrD.DeviceWarrantyTermMasterID
	,MOrD.InvoiceNumber
	,MOrD.PlanCost
	,MOrD.PlanMargin
	,MOrD.PlanPrice
	,MOrD.MobilityOrderID
	,MOrD.MobilityOrderItemID
	,@AddedByID
	,@AddedByID
	,DC.CarrierID
FROM MobilityOrderXDevices MOrD
/** Added BY CK - SD-9097 07/20/23 **/
INNER JOIN MobilityOrderItems MOI ON MOI.MobilityOrderItemID = MOrD.MobilityOrderItemID
	AND MOI.IsActive = 1
/** Added BY CK - SD-9097 07/20/23 **/
INNER JOIN DeviceXCarrier DC ON DC.DeviceID = MOrD.DeviceID
	/** FIXED BY SP - DESK-18472 09/15/21 **/
	AND ISNULL(DC.DeviceConditionID, '') = COALESCE(MOrD.DeviceConditionID, DC.DeviceConditionID, '')
	AND ISNULL(dc.DeviceVendorID, '') = COALESCE(MOrD.DeviceVendorID, dc.DeviceVendorID, '')
WHERE MOrD.MobilityOrderID = @MobilityOrderID
	AND MOrD.MobilityOrderItemID = @MobilityOrderItemID
	AND DC.CarrierID = @CarrierID
	AND MOI.LineStatusMasterID = 7001


------ UPDATE EQUIPMENT INVENTORY STATUS FOR VCOM STORE as sent to Customer  ----------                
IF ISNULL(@EquipmentInventoryID, 0) <> 0
BEGIN
	SELECT @EquipmentStatusMasterID = EquipmentStatusMasterID
	FROM EquipmentStatusMaster
	WHERE [StatusCode] = 'S'

	UPDATE EquipmentInventory
	SET EquipmentStatusMasterID = @EquipmentStatusMasterID
	WHERE EquipmentInventoryMasterID IN (
			SELECT EquipmentInventoryID
			FROM MobilityOrderXDevices
			WHERE MobilityOrderID = @MobilityOrderID
				AND MobilityOrderItemID = @MobilityOrderItemID
				AND EquipmentInventoryID <> 0
			)
END

--END        
/*********************************** BILLING PROPAGATION HAPPENING HERE IN CASE OF SPARE ORDERS *************************************************                
    *****************************************************************************/
EXEC Billing_Propagation @MobilityOrderItemID = @MobilityOrderItemID
	,@AddedByID = @AddedByID
	,@DeviceChargeCapture = @DeviceChargeCapture
