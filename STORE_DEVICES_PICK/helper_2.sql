SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =================================================    
-- Author:  AK / NS / SP  
-- ALTER date: <-NA-> /04-13-2020   
-- Description: <Description,,>    
-- =========================================================   
-- Author:  SP  
-- ALTER date: 10/12/21
-- Description: Do not validate the "Pending Activation" lines that are Active. 
-- =========================================================   
-- Author:  Nagasai Mudara  
-- ALTER date: 09/14/22
-- Description: Validating the Orders that are opened in vManager and in Draft stage. 
-- SD CASE - CASE- 2925
-- =========================================================  
-- =========================================================   
-- Author:  SP
-- ALTER date: 05/10/23
-- Description: e-SIM Project - Remove IMEI Validation / Added No Locks where ever required
-- SD Case 
-- =========================================================  
-- Altered by:  Ravi Teja Yella
-- Alter date: 08/09/2023
-- Description: Device sim limit validation related to multi sim changes 
-- SD Case : 8334 - Multi-sim
-- =========================================================  
-- Altered by:  Ravi Teja Yella
-- Alter date: 10/17/2023
-- Description: Allow same line number on two customers (allow resale)
-- SD Case : 9705 - Allow Same Mobile Inventory To Be Active with Two Customers 
-- =========================================================  
-- Altered by:  Gopi Pagadala
-- Alter date: 03/04/2024
-- Description: Checking whether the entered values are in the vCom Store
-- SD Case : 12446 - Device utilized for order 117379 still in Store Management 
-- ========================================================= 
-- Altered by:  Gopi Pagadala
-- Alter date: 03/27/2024
-- Description: Validating ESN/IMEI/IMEI2 fields using EquipmentInventoryMasterID in vCom store
-- SD Case : 12713 - Unable to pull device from vCom Store (Order 121612) 
-- ========================================================= 
--MobilityOrder_ValidateValueByType '','567456745674567','65745674567456745674','',21202, 804018
--EXEC MobilityOrder_ValidateValueByType '36475676745', NULL, NULL, '6523456778',20602,0  
-- EXEC MobilityOrder_ValidateValueByType NULL, '543245654324565', '54324532454324543245', '6564323456',292703,0,'543456434565432'
-- EXEC MobilityOrder_ValidateValueByType @ESN = NULL,@MEID='222222222222222',@ICCID=NULL,@MDN=NULL,@OrderItemID=NULL,@InventoryServiceID=1011506,@IMEI2='222222222222222',@DeviceID=5297
-- EXEC MobilityOrder_ValidateValueByType @ESN = 9738328882,@MEID='353992315845181',@ICCID=NULL, @MDN=9738328882, @OrderItemID=354411, @InventoryServiceID=0, @IMEI2='',@DeviceID=5779
-- =========================================================            
ALTER PROCEDURE [dbo].[MobilityOrder_ValidateValueByType] @ESN VARCHAR(MAX) = NULL
	,@MEID VARCHAR(MAX) = NULL
	,@ICCID VARCHAR(MAX) = NULL
	,@MDN VARCHAR(MAX) = NULL
	,@OrderItemID INT = NULL
	,@InventoryServiceID INT = NULL
	,@IMEI2 VARCHAR(100) = NULL
	,@DeviceID INT = NULL
	,@InventoryServicesPipe VARCHAR(255) = NULL
	,@EquipmentInventoryMasterID INT = NULL
AS
BEGIN
	-- Get Source CustomerID 
	DECLARE @SourceCustomerID INT
		,@TargetCustomerID INT

	IF ISNULL(@OrderItemID, 0) <> 0
		AND ISNULL(@OrderItemID, 0) <> - 1
	BEGIN
		SELECT TOP 1 @SourceCustomerID = CustomerID
		FROM MobilityOrderItems MOI(NOLOCK)
		INNER JOIN MobilityOrders MO(NOLOCK) ON MO.MobilityOrderID = MOI.MobilityOrderID
		WHERE MOI.MobilityOrderItemID = @OrderItemID
			AND MOI.IsActive = 1
	END
	ELSE
	BEGIN
		IF ISNULL(@InventoryServiceID, 0) <> 0
		BEGIN
			SELECT TOP 1 @SourceCustomerID = customer_id
			FROM InventoryServiceRel isr(NOLOCK)
			JOIN Inventory i(NOLOCK) ON i.inventory_id = isr.InventoryID
			WHERE i.is_active = 1
				AND isr.IsActive = 1
				AND isr.InventoryServiceID = @InventoryServiceID
		END
		ELSE
		BEGIN
			IF ISNULL(@InventoryServicesPipe, '') <> ''
			BEGIN
				SELECT TOP 1 @SourceCustomerID = customer_id
				FROM InventoryServiceRel isr(NOLOCK)
				JOIN Inventory i(NOLOCK) ON i.inventory_id = isr.InventoryID
				WHERE i.is_active = 1
					AND isr.IsActive = 1
					AND isr.InventoryServiceID IN (
						SELECT CAST(VALUE AS INT)
						FROM [dbo].[SplitValue](@InventoryServicesPipe, '|')
						WHERE VALUE <> ''
						)
			END
		END
	END

	/* 

MDN ** Assuming same customer **
1. Add 
	– sub product: Complete – should not allow.
	– Customer manged/expense – should allow
	– select – request for port or transfer
2. Port 
	– same carrier – should not allow (old carrier/new carrier)
	– different carrier - allow port
	– no checking for sub product- complete/expense/select
3. Transfer 
	– same carrier – should allow
	– same carrier and same carrier account-- shouldn't allow
	– same carrier and different carrier account-- should allow
	– different carrier - should allow

MDN ** Assuming different customer ** (CaseID: 9705 - Allow Same Mobile Inventory To Be Active with Two Customers)
1. Add, Port, Transfer
	- Allow if device is the same and MDN only exists on 1 other inventory of a different customer

Regarding ICCID, ESN and IMEI numbers.there are few lines which are migrated to mobility. 
As we are not checking these whether order is port, transfer or add. 
We are having issues. Now we need to ignore these in case of PORT or Transfer.

*/
	DECLARE @tblESN TABLE (ESN VARCHAR(100))
	DECLARE @tblMEID TABLE (MEID VARCHAR(100))
	DECLARE @tblICCID TABLE (ICCID VARCHAR(100))
	DECLARE @tblMDN TABLE (MDN VARCHAR(100))
	DECLARE @tblExisting TABLE (
		Value VARCHAR(100)
		,Type VARCHAR(10)
		,Message VARCHAR(250)
		)
	DECLARE @line VARCHAR(250) = ''
	DECLARE @Inputline VARCHAR(250) = '' -- check for Existing lines     

	INSERT INTO @tblESN
	SELECT value
	FROM dbo.[SplitValue](@Esn, ',')

	INSERT INTO @tblMEID
	SELECT value
	FROM dbo.[SplitValue](@Meid, ',')

	INSERT INTO @tblICCID
	SELECT value
	FROM dbo.[SplitValue](@ICCID, ',')

	INSERT INTO @tblMDN
	SELECT value
	FROM dbo.[SplitValue](@MDN, ',')

	-- IF 0, setting to NULL, When order doesnt exist
	--ex: Recordonly, create order etc.
	IF (@OrderItemID = 0)
	BEGIN
		SET @OrderItemID = NULL
	END

	DECLARE @CarrierIDOnOrder INT
		,@CarrierAccountIDOnOrder INT
		,@OrderSubTypeMasterID INT
		,@CarrierIDOnInventory INT
		,@CarrierAccountIDOnInventory INT
		,@OrderTypeID INT
		,@OrderID INT
		,@cusID INT

	SELECT @OrderSubTypeMasterID = MOI.OrderSubTypeMasterID
		,@CarrierIDOnOrder = MO.CarrierID
		,@CarrierAccountIDOnOrder = MO.CarrierAccountID
		,@OrderTypeID = OrderTypeID
		,@InventoryServiceID = ISNULL(@InventoryServiceID, MOI.inventoryServiceID)
	FROM MobilityOrders MO(NOLOCK)
	INNER JOIN MObilityOrderItems MOI(NOLOCK) ON MOI.MobilityOrderID = MO.MobilityOrderID
	LEFT JOIN OrderSubTypeMaster osm ON osm.OrderSubTypeMasterID = MOI.OrderSubTypeMasterID
	WHERE MOI.MobilityOrderItemID = ISNULL(@OrderItemID, MOI.MobilityOrderItemID)

	SELECT TOP 1 @CarrierIDOnInventory = isr.carrierID
		,@CarrierAccountIDOnInventory = isr.carrierAccountId
		,@line = isr.referenceNumber
	FROM inventory i(NOLOCK)
	JOIN inventoryServiceRel isr(NOLOCK) ON i.inventory_id = isr.inventoryID
		AND isr.InventoryStatusMasterID NOT IN (
			2000
			,3000
			) --DEVICE SHOULD NOT BE IN PENDING ACTIVATION TOO. ADDED BY SP 10/12/21
	JOIN inventory_service isv(NOLOCK) ON isv.inventory_service_id = isr.InventoryServiceID
		AND isv.is_vcom = 1
	--JOIN @tblMDN mdn  on mdn.MDN = isr.ReferenceNumber
	WHERE isr.isActive = 1
		AND i.customer_id = @SourceCustomerID -- Case# 9705
		AND InventoryServiceID <> CASE 
			WHEN @OrderItemID = - 1
				THEN @InventoryServiceID
			ELSE - 1
			END -- record only fix
		AND isr.referenceNumber IN (
			SELECT MDN
			FROM @tblMDN
			)
	ORDER BY 1 DESC

	IF @OrderItemID = - 1 -- Record Only Fix
	BEGIN
		SET @OrderTypeID = 5
		SET @OrderItemID = 0
	END

	DECLARE @ExsitsInOrder BIT = 0

	-- IF LINE IS NOT IN INVENTORY, USE THE ONE PROVIDED 
	IF (@Inputline = '')
	BEGIN
		SELECT TOP 1 @Inputline = MDN
		FROM @tblMDN
	END

	IF (@OrderTypeID <> 8)
		AND (@OrderTypeID <> 3)
		AND @Inputline <> ''
	BEGIN
		SELECT @ExsitsInOrder = CASE 
				WHEN ISNULL(MobilityOrderItemID, 0) = 0
					THEN 0
				ELSE 1
				END
			,@OrderID = moi.MobilityOrderID
		FROM MobilityOrderItems moi(NOLOCK)
		JOIN MobilityOrders mo(NOLOCK) ON moi.MobilityOrderID = mo.MobilityOrderID
		WHERE LineNumber = @Inputline
			AND mo.CustomerID = @SourceCustomerID -- Case# 9705
			AND isActive = 1
			AND LineStatusMasterID NOT IN (
				7001
				,5001
				,1
				)
			AND MobilityOrderItemID <> iSNULL(@OrderItemID, 0)
	END

	IF @OrderTypeID = 5
		OR @OrderTypeID = 12 -- Record only & Number change
	BEGIN
		SET @OrderSubTypeMasterID = 1
	END

	IF @ExsitsInOrder = 1
	BEGIN
		INSERT INTO @tblExisting
		SELECT @Inputline
			,'MDN'
			,'MDN exists in a different Order! Order# ' + CAST(@OrderID AS VARCHAR(150))
	END

	PRINT @ExsitsInOrder

	IF @ExsitsInOrder = 0
	BEGIN
		-- ADD/SPARE/SIM/RECORD ONLY 
		IF @OrderTypeID = 1
			OR @OrderTypeID = 5
			OR @OrderTypeID = 3
			OR @OrderTypeID = 8
			OR @OrderTypeID = 12
		BEGIN
			/* Removing the Validation to support multiple Services against the same IMEI - 05/10/23
			IF (CAST(@Esn AS VARCHAR) != '')
			BEGIN
				INSERT INTO @tblExisting
				SELECT DISTINCT t.ESN
					,'ESN'
					,'ESN already exists'
				FROM inventorydevicerel IDR
				JOIN @tblESN t ON t.ESN = IDR.ESN
				JOIN inventoryServiceRel isr ON isr.InventoryServiceID = idr.InventoryServiceID
					AND isr.IsActive = 1
					AND isr.InventoryStatusMasterID NOT IN (
						2000
						,3000
						)
				WHERE idr.isActive = 1
					AND InventoryDeviceRelID IS NOT NULL
			END

			IF (CAST(@Meid AS VARCHAR) != '')
			BEGIN
				INSERT INTO @tblExisting
				SELECT DISTINCT t.MEID
					,'MEID'
					,'MEID already exists'
				FROM inventorydevicerel IDR
				JOIN @tblMEID t ON t.MEID = IDR.MEID
				JOIN inventoryServiceRel isr ON isr.InventoryServiceID = idr.InventoryServiceID
					AND isr.IsActive = 1
					AND isr.InventoryStatusMasterID NOT IN (
						2000
						,3000
						)
				WHERE idr.isActive = 1
					AND InventoryDeviceRelID IS NOT NULL
			END
			*/
			IF (CAST(@ICCID AS VARCHAR) != '')
			BEGIN
				INSERT INTO @tblExisting
				SELECT DISTINCT t.ICCID
					,'ICCID'
					,'ICCID already exists'
				FROM inventorydevicerel IDR(NOLOCK)
				JOIN @tblICCID t ON t.ICCID = IDR.ICCID
				JOIN inventoryServiceRel isr(NOLOCK) ON isr.InventoryServiceID = idr.InventoryServiceID
					AND isr.IsActive = 1
					AND isr.InventoryStatusMasterID NOT IN (
						2000
						,3000
						)
				WHERE idr.isActive = 1
					AND ISNULL(idr.CustomerID, 0) = @SourceCustomerID -- Case# 9705
					AND InventoryDeviceRelID IS NOT NULL
			END

			IF @OrderTypeID = 1
				OR @OrderTypeID = 12
				OR @OrderTypeID = 5
			BEGIN
				IF @OrderSubTypeMasterID = 1
					OR @OrderSubTypeMasterID = 8
				BEGIN
					IF (@line <> '')
					BEGIN
						INSERT INTO @tblExisting
						SELECT @line
							,'MDN'
							,'MDN already exists, create port or transfer order!'
					END
				END
				ELSE IF @OrderSubTypeMasterID = 2
					AND @CarrierIDOnOrder = @CarrierIDOnInventory
				BEGIN
					IF (@line <> '')
					BEGIN
						INSERT INTO @tblExisting
						SELECT @line
							,'MDN'
							,'MDN already exists, cannot create port order!'
					END
				END
				ELSE IF @OrderSubTypeMasterID = 3
					AND @CarrierIDOnOrder = @CarrierIDOnInventory
					AND @CarrierAccountIDOnOrder = @CarrierAccountIDOnInventory
				BEGIN
					IF (@line <> '')
					BEGIN
						INSERT INTO @tblExisting
						SELECT @line
							,'MDN'
							,'MDN already exists, cannot create transfer order on same carrier/carrier account!'
					END
				END
			END
		END
		ELSE IF (
				@OrderTypeID = 2
				OR @OrderTypeID = 9
				) -- CHANGE/RECONNECT
		BEGIN
			/* Removing the Validation to support multiple Services against the same IMEI - 05/10/23
			IF (CAST(@Esn AS VARCHAR) != '')
			BEGIN
				INSERT INTO @tblExisting
				SELECT DISTINCT t.ESN
					,'ESN'
					,'ESN already exists'
				FROM inventorydevicerel IDR (NOLOCK)
				JOIN @tblESN t ON t.ESN = IDR.ESN
				JOIN inventoryServiceRel isr (NOLOCK) ON isr.InventoryServiceID = idr.InventoryServiceID
					AND isr.IsActive = 1
					AND isr.InventoryStatusMasterID <> 2000
				WHERE idr.isActive = 1
					AND InventoryDeviceRelID IS NOT NULL
					AND IDR.InventoryServiceID <> @InventoryServiceID
			END

			IF (CAST(@Meid AS VARCHAR) != '')
			BEGIN
				INSERT INTO @tblExisting
				SELECT DISTINCT t.MEID
					,'MEID'
					,'MEID already exists'
				FROM inventorydevicerel IDR (NOLOCK)
				JOIN @tblMEID t ON t.MEID = IDR.MEID
				JOIN inventoryServiceRel isr (NOLOCK) ON isr.InventoryServiceID = idr.InventoryServiceID
					AND isr.IsActive = 1
					AND isr.InventoryStatusMasterID <> 2000
				WHERE idr.isActive = 1
					AND InventoryDeviceRelID IS NOT NULL
					AND IDR.InventoryServiceID <> @InventoryServiceID
			END
			*/
			IF (CAST(@ICCID AS VARCHAR) != '')
			BEGIN
				INSERT INTO @tblExisting
				SELECT DISTINCT t.ICCID
					,'ICCID'
					,'ICCID already exists'
				FROM inventorydevicerel IDR(NOLOCK)
				JOIN @tblICCID t ON t.ICCID = IDR.ICCID
				JOIN inventoryServiceRel isr(NOLOCK) ON isr.InventoryServiceID = idr.InventoryServiceID
					AND isr.IsActive = 1
					AND isr.InventoryStatusMasterID <> 2000
				WHERE idr.isActive = 1
					AND ISNULL(idr.CustomerID, 0) = @SourceCustomerID -- Case# 9705
					AND InventoryDeviceRelID IS NOT NULL
					AND IDR.InventoryServiceID <> @InventoryServiceID
			END
		END
	END

	/* MDN validation across different customers 
		1. Get source device details
		2. Match against existing Orders / Inventory with the device for a different customer to source customer
		3. Allow MDN being shared between 2 customers (only 2 maximum lines of the same MDN with 2 different customers)
	*/
	/*	-- Commenting out logic to deal with existing lines with shared MDN
	IF ISNULL(@MDN, '') <> ''																-- Case# 9705
	BEGIN
		-- Get all source  & target details
		DECLARE @sourceDeviceID INT
			,@sourceDeviceOption INT
			,@targetDeviceOption INT

		IF ISNULL(@OrderItemID, 0) <> 0
		BEGIN
			SELECT TOP 1 @sourceDeviceID = ISNULL(@DeviceID, moxd.DeviceID)
			FROM MobilityOrderItems moi(NOLOCK)
			JOIN MobilityOrders mo(NOLOCK) ON mo.MobilityOrderID = moi.MobilityOrderID
			LEFT JOIN MobilityOrderXDevices moxd(NOLOCK) ON moxd.MobilityOrderItemID = moi.MobilityOrderItemID
			WHERE moi.IsActive = 1
				AND moi.MobilityOrderItemID = @OrderItemID
		END
		ELSE
		BEGIN
			IF ISNULL(@OrderItemID, 0) = 0
				AND ISNULL(@InventoryServiceID, 0) <> 0
			BEGIN
				SELECT TOP 1 @sourceDeviceID = idr.DeviceID
					,@sourceDeviceOption = CASE 
						WHEN (
								idr.IsBYOD = 1
								AND ISNULL(idr.SpareInventoryID, 0) = 0
								)
							THEN 2
						WHEN ISNULL(idr.SpareInventoryID, 0) <> 0
							THEN 3
						ELSE 1
						END
				FROM InventoryServiceRel isr(NOLOCK)
				INNER JOIN Inventory i(NOLOCK) ON isnull(isr.ReferenceNumber, '') = isnull(i.reference_number, '')
					AND i.inventory_id = isr.InventoryID -- Case# 9705
					AND i.is_active = 1
				JOIN InventoryDeviceRel idr(NOLOCK) ON idr.inventoryServiceID = isr.inventoryServiceID
				WHERE isr.InventoryServiceID = @InventoryServiceID
					AND isr.IsActive = 1
					AND idr.IsActive = 1
			END
		END

		DECLARE @targetInvTable TABLE (
			ReferenceNumber VARCHAR(50)
			,DeviceOption INT
			,ESN VARCHAR(100)
			,MEID VARCHAR(100)
			,IMEI2 VARCHAR(100)
			)

		INSERT INTO @targetInvTable
		SELECT isr.ReferenceNumber
			,CASE 
				WHEN (
						idr.IsBYOD = 1
						AND ISNULL(idr.SpareInventoryID, 0) = 0
						)
					THEN 2
				WHEN ISNULL(idr.SpareInventoryID, 0) <> 0
					THEN 3
				ELSE 1
				END AS DeviceOption
			,ISNULL(idr.ESN, '') AS ESN
			,ISNULL(idr.MEID, '') AS MEID
			,ISNULL(idr.IMEI2, '') AS IMEI2
		FROM InventoryServiceRel isr(NOLOCK)
		INNER JOIN ipath..inventory i(NOLOCK) ON i.inventory_id = isr.InventoryID
		JOIN InventoryDeviceRel idr(NOLOCK) ON idr.InventoryServiceID = isr.InventoryServiceID
		WHERE i.customer_id <> @sourceCustomerID
			AND isr.ReferenceNumber = @MDN
			AND isr.InventoryStatusMasterID <> 2000		-- exclude disconnected lines
			AND i.is_active = 1
			AND isr.IsActive = 1
			AND idr.IsActive = 1

		--SELECT @sourceCustomerID AS SOURCECUST
		--SELECT * FROM @targetInvTable		-- REMOVE
		-- Write validations based on source & target details
		IF EXISTS (
				SELECT TOP 1 *
				FROM @targetInvTable
				)
		BEGIN
			--INSERT INTO @tblExisting
			--SELECT 'Device'
			--	,'Device'
			--	,'Another inventory with same Reference Number: ' + ReferenceNumber + ' exists, but with a different device.'
			--FROM @targetInvTable
			--WHERE ESN <> ISNULL(CAST(@ESN AS VARCHAR), '')
			--	OR MEID <> ISNULL(CAST(@MEID AS VARCHAR), '')
			--	OR IMEI2 <> ISNULL(CAST(@IMEI2 AS VARCHAR), '')

			DECLARE @lineShareCount INT

			SELECT @lineShareCount = COUNT(*)
			FROM @targetInvTable

			--IF @lineShareCount > 1
			--BEGIN
			--	INSERT INTO @tblExisting
			--	SELECT @MDN
			--		,'MDN'
			--		,'Line has already been resold!'
			--END

			--IF @lineShareCount = 1
			--BEGIN
			--	SELECT @targetDeviceOption = DeviceOption
			--	FROM @targetInvTable

			--	IF @sourceDeviceOption <> @targetDeviceOption
			--	BEGIN
			--		INSERT INTO @tblExisting
			--		SELECT 'Device Option'
			--			,'Device'
			--			,'Device was set up as ''' + odo.DisplayName + ''' on Line: ' + tit.ReferenceNumber + ' for the other customer!'
			--		FROM @targetInvTable tit
			--		JOIN OrderDeviceOptionMaster odo ON odo.OrderDeviceOptionMasterID = tit.DeviceOption
			--	END
			--END
		END
	END

	*/
	/* ADD DEVICE VALIDATION at order level -- 8 lines limit for vCom, 4 lines limit for QS carriers*/
	DECLARE @deviceIsMultiSim BIT = 0
		,@CustomerID INT

	SELECT TOP 1 @deviceIsMultiSim = IsMultiSim
	FROM Devices(NOLOCK)
	WHERE DeviceID = ISNULL(@DeviceID, 0)

	IF (
			@deviceIsMultiSim = 1
			AND ISNULL(@OrderItemID, 0) <> 0
			AND CAST(ISNULL(@ESN, '') AS VARCHAR) + CAST(ISNULL(@MEID, '') AS VARCHAR) + CAST(ISNULL(@IMEI2, '') AS VARCHAR) <> ''
			)
	BEGIN
		DECLARE @ESN2 VARCHAR(MAX)
			,@IMEI VARCHAR(MAX)
			,@IMEI2_2 VARCHAR(MAX)
			,@DeviceID_2 INT
			,@InvServiceID INT
			,@Channel VARCHAR(100)
			,@CountRelatedInventories INT
			,@DeviceLimit INT
			,@CarrierChannel VARCHAR(100)
			,@IsSameChannel BIT = 1

		SELECT TOP 1 @CustomerID = mo.CustomerID
			,@ESN2 = @ESN
			,@IMEI = @MEID
			,@IMEI2_2 = @IMEI2
			,@DeviceID_2 = ISNULL(@DeviceID, moxd.DeviceID)
			,@InvServiceID = ISNULL(moi.InventoryServiceID, 0)
			,@DeviceLimit = CASE 
				WHEN mcm.Channel = 'Wholesale Aggregator'
					THEN 4
				ELSE 8
				END
			,@Channel = mcm.Channel
			,@CarrierChannel = CASE 
				WHEN mcm.Channel = 'Wholesale Aggregator'
					THEN 'QuantumShift'
				ELSE 'vCom'
				END
		FROM MobilityOrderItems moi(NOLOCK)
		JOIN MobilityOrders mo(NOLOCK) ON mo.MobilityOrderID = moi.MobilityOrderID
		JOIN MobilityCarrierMaster mcm(NOLOCK) ON mcm.CarrierID = mo.CarrierID
		LEFT JOIN MobilityOrderXDevices moxd(NOLOCK) ON moxd.MobilityOrderItemID = moi.MobilityOrderItemID
		WHERE moi.IsActive = 1
			AND moi.MobilityOrderItemID = @OrderItemID

		IF ISNULL(@ESN, '') = ''
		BEGIN
			SELECT @CountRelatedInventories = COUNT(*)
				,@IsSameChannel = CASE 
					WHEN COUNT(*) = SUM(CASE 
								WHEN mcm.Channel = @Channel
									THEN 1
								ELSE 0
								END)
						THEN 1
					ELSE 0
					END
			FROM inventoryServiceRel isr(NOLOCK)
			INNER JOIN Inventory i(NOLOCK) ON isnull(isr.ReferenceNumber, '') = isnull(i.reference_number, '')
				AND i.inventory_id = isr.InventoryID -- Case# 9705
				AND i.is_active = 1
			INNER JOIN InventoryDeviceRel idr(NOLOCK) ON idr.inventoryServiceID = isr.inventoryServiceID
			INNER JOIN MobilityCarrierMaster mcm(NOLOCK) ON mcm.CarrierID = isr.CarrierID
				AND idr.IsActive = 1
			WHERE isr.IsActive = 1
				AND i.customer_id = @CustomerID
				AND (
					idr.MEID = @IMEI
					OR idr.IMEI2 = @IMEI
					)
				-- AND ISNULL(idr.DeviceID, 0) = ISNULL(@DeviceID_2, 0)
				AND isr.inventoryStatusMasterID <> 2000
				AND isr.inventoryServiceID <> ISNULL(@InvServiceID, 0)
		END
		ELSE
		BEGIN
			SELECT @CountRelatedInventories = COUNT(*)
				,@IsSameChannel = CASE 
					WHEN COUNT(*) = SUM(CASE 
								WHEN mcm.Channel = @Channel
									THEN 1
								ELSE 0
								END)
						THEN 1
					ELSE 0
					END
			FROM inventoryServiceRel isr(NOLOCK)
			INNER JOIN Inventory i(NOLOCK) ON isnull(isr.ReferenceNumber, '') = isnull(i.reference_number, '')
				AND i.inventory_id = isr.InventoryID -- Case# 9705
				AND i.is_active = 1
			INNER JOIN InventoryDeviceRel idr(NOLOCK) ON idr.inventoryServiceID = isr.inventoryServiceID
			INNER JOIN MobilityCarrierMaster mcm(NOLOCK) ON mcm.CarrierID = isr.CarrierID
				AND idr.IsActive = 1
			WHERE isr.IsActive = 1
				AND i.customer_id = @CustomerID
				AND (idr.ESN = @ESN)
				-- AND ISNULL(idr.DeviceID, 0) = ISNULL(@DeviceID_2, 0)
				AND isr.inventoryStatusMasterID <> 2000
				AND isr.inventoryServiceID <> ISNULL(@InvServiceID, 0)
		END

		IF @IsSameChannel = 0
		BEGIN
			IF ISNULL(@ESN, '') = ''
			BEGIN
				/* Get existing inv info */
				INSERT INTO @tblExisting
				SELECT TOP 1 'Reference Number: ' + isr.ReferenceNumber
					,'Channel'
					,'Device already exists on ' + (
						CASE 
							WHEN mcm.Channel = 'Wholesale Aggregator'
								THEN 'QuantumShift'
							ELSE 'vCom'
							END
						) + ' carrier. This combination of active carriers is not allowed.'
				FROM inventoryServiceRel isr(NOLOCK)
				INNER JOIN Inventory i(NOLOCK) ON isnull(isr.ReferenceNumber, '') = isnull(i.reference_number, '')
					AND i.inventory_id = isr.InventoryID -- Case# 9705
					AND i.is_active = 1
				INNER JOIN InventoryDeviceRel idr(NOLOCK) ON idr.inventoryServiceID = isr.inventoryServiceID
				INNER JOIN MobilityCarrierMaster mcm(NOLOCK) ON mcm.CarrierID = isr.CarrierID
					AND idr.IsActive = 1
				WHERE isr.IsActive = 1
					AND i.customer_id = @CustomerID
					AND (
						idr.MEID = @IMEI
						OR idr.IMEI2 = @IMEI
						-- OR idr.IMEI2 = @IMEI
						-- OR idr.IMEI2 = @IMEI2_2
						)
					AND isr.inventoryStatusMasterID <> 2000
					AND isr.inventoryServiceID <> @InvServiceID
					AND mcm.Channel <> @Channel
			END
			ELSE
			BEGIN
				/* Get existing inv info */
				INSERT INTO @tblExisting
				SELECT TOP 1 'Reference Number: ' + isr.ReferenceNumber
					,'Channel'
					,'Device already exists on ' + (
						CASE 
							WHEN mcm.Channel = 'Wholesale Aggregator'
								THEN 'QuantumShift'
							ELSE 'vCom'
							END
						) + ' carrier. This combination of active carriers is not allowed.'
				FROM inventoryServiceRel isr(NOLOCK)
				INNER JOIN Inventory i(NOLOCK) ON isnull(isr.ReferenceNumber, '') = isnull(i.reference_number, '')
					AND i.inventory_id = isr.InventoryID -- Case# 9705
					AND i.is_active = 1
				INNER JOIN InventoryDeviceRel idr(NOLOCK) ON idr.inventoryServiceID = isr.inventoryServiceID
				INNER JOIN MobilityCarrierMaster mcm(NOLOCK) ON mcm.CarrierID = isr.CarrierID
					AND idr.IsActive = 1
				WHERE isr.IsActive = 1
					AND i.customer_id = @CustomerID
					AND (idr.ESN = @ESN)
					AND isr.inventoryStatusMasterID <> 2000
					AND isr.inventoryServiceID <> @InvServiceID
					AND mcm.Channel <> @Channel
			END
		END

		IF @IsSameChannel = 1
		BEGIN
			IF (
					ISNULL(@CountRelatedInventories, - 1) >= CASE 
						WHEN @deviceIsMultiSim = 1
							THEN @DeviceLimit
						ELSE 1
						END
					) -- MIN device limit is 4 (for QS carriers)
			BEGIN
				INSERT INTO @tblExisting
				SELECT 'ESN/IMEI: ' + ISNULL(@IMEI, '') + ', ' + 'IMEI2: ' + ISNULL(@IMEI2_2, '')
					,'Device'
					,'Device already exists on ' + CAST(ISNULL(@CountRelatedInventories, 0) AS VARCHAR(10)) + ' ' + @CarrierChannel + ' carrier(s).'
			END
		END
	END

	--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
	-- Checking whether the entered values are in the vCom Store
	-- SD Case : 12446
	DECLARE @equipmentInventoryID INT = NULL  --12713

	IF (
			ISNULL(@EquipmentInventoryMasterID, 0) = 0
			AND ISNULL(@OrderItemID, 0) <> 0
			AND CAST(ISNULL(@ESN, '') AS VARCHAR) + CAST(ISNULL(@MEID, '') AS VARCHAR) + CAST(ISNULL(@IMEI2, '') AS VARCHAR) <> ''
			)
	BEGIN
		IF (ISNULL(@ESN, '') <> '')
		BEGIN
			SELECT TOP 1 @equipmentInventoryID = ei.EquipmentInventoryMasterID
			FROM equipmentinventory ei(NOLOCK)
			WHERE ESN = @ESN

			--AND (
			--	CustomerID <> @SourceCustomerID
			--	OR IsActive = 0
			--	)
			IF (ISNULL(@equipmentInventoryID, 0) <> 0)
			BEGIN
				INSERT INTO @tblExisting
				SELECT 'ESN/IMEI: ' + ISNULL(@ESN, '')
					,'ESN'
					,'Device and ESN combination already exists on vCom Store'
			END
		END
		ELSE IF (ISNULL(@MEID, '') <> '')
		BEGIN
			SELECT TOP 1 @equipmentInventoryID = ei.EquipmentInventoryMasterID
			FROM equipmentinventory ei(NOLOCK)
			WHERE MEID = @MEID

			--AND (
			--	CustomerID <> @SourceCustomerID
			--	OR IsActive = 0
			--	)
			IF (ISNULL(@equipmentInventoryID, 0) <> 0)
			BEGIN
				INSERT INTO @tblExisting
				SELECT 'ESN/IMEI: ' + ISNULL(@MEID, '')
					,'MEID'
					,'Device and IMEI combination already exists on vCom Store'
			END
		END

		IF (ISNULL(@IMEI2, '') <> '')
		BEGIN
			SELECT TOP 1 @equipmentInventoryID = ei.EquipmentInventoryMasterID
			FROM equipmentinventory ei(NOLOCK)
			WHERE IMEI2 = @IMEI2

			--AND (
			--	CustomerID <> @SourceCustomerID
			--	OR IsActive = 0
			--	)
			IF (ISNULL(@equipmentInventoryID, 0) <> 0)
			BEGIN
				INSERT INTO @tblExisting
				SELECT 'IMEI2: ' + ISNULL(@IMEI2, '')
					,'IMEI2'
					,'Device and IMEI2 combination already exists on vCom Store'
			END
		END
	END
	ELSE IF (ISNULL(@EquipmentInventoryMasterID, 0) <> 0) -- 12713
	BEGIN
		IF (ISNULL(@ESN, '') <> '')
		BEGIN
			SELECT TOP 1 @equipmentInventoryID = ei.EquipmentInventoryMasterID
			FROM equipmentinventory ei(NOLOCK)
			WHERE EquipmentInventoryMasterID = @EquipmentInventoryMasterID
				AND ESN = @ESN

			IF (ISNULL(@equipmentInventoryID, 0) = 0)
			BEGIN
				INSERT INTO @tblExisting
				SELECT 'ESN/IMEI: ' + ISNULL(@ESN, '')
					,'ESN'
					,'ESN does not match with the information in vCom store'
			END
		END
		ELSE IF (ISNULL(@MEID, '') <> '')
		BEGIN
			SELECT TOP 1 @equipmentInventoryID = ei.EquipmentInventoryMasterID
			FROM equipmentinventory ei(NOLOCK)
			WHERE EquipmentInventoryMasterID = @EquipmentInventoryMasterID
				AND MEID = @MEID

			IF (ISNULL(@equipmentInventoryID, 0) = 0)
			BEGIN
				INSERT INTO @tblExisting
				SELECT 'ESN/IMEI: ' + ISNULL(@MEID, '')
					,'MEID'
					,'IMEI does not match with the information in vCom store'
			END
		END

		IF (ISNULL(@IMEI2, '') <> '')
		BEGIN
			SELECT TOP 1 @equipmentInventoryID = ei.EquipmentInventoryMasterID
			FROM equipmentinventory ei(NOLOCK)
			WHERE EquipmentInventoryMasterID = @EquipmentInventoryMasterID
				AND IMEI2 = @IMEI2

			IF (ISNULL(@equipmentInventoryID, 0) = 0)
			BEGIN
				INSERT INTO @tblExisting
				SELECT 'IMEI2: ' + ISNULL(@IMEI2, '')
					,'IMEI2'
					,'IMEI2 does not match with the information in vCom store'
			END
		END
	END

	/* Validation for Record only change order regarding multi-sim changes */
	-- get if inv is multisim
	SELECT TOP 1 @deviceIsMultiSim = d.IsMultiSim
	FROM InventoryDeviceRel idr(NOLOCK)
	JOIN Devices d(NOLOCK) ON idr.DeviceID = d.DeviceID
	WHERE d.DeviceID = CASE 
			WHEN ISNULL(@DeviceID, 0) = 0
				THEN d.DeviceID
			ELSE @DeviceID
			END
		AND idr.InventoryServiceID = CASE 
			WHEN ISNULL(@DeviceID, 0) = 0
				THEN @InventoryServiceID
			ELSE idr.InventoryServiceID
			END
		AND idr.IsActive = 1

	IF ISNULL(@OrderItemID, 0) = 0
		AND ISNULL(@InventoryServiceID, 0) <> 0
		AND @deviceIsMultiSim = 1
	BEGIN
		DECLARE @inventoriesTable TABLE (InventoryServiceID INT)

		SET @InventoryServicesPipe = CASE 
				WHEN ISNULL(@InventoryServicesPipe, '') = ''
					THEN NULL
				ELSE @InventoryServicesPipe
				END
		SET @InventoryServicesPipe = ISNULL(@InventoryServicesPipe, CAST(@InventoryServiceID AS VARCHAR))

		INSERT INTO @inventoriesTable
		SELECT CAST(VALUE AS INT)
		FROM [dbo].[SplitValue](@InventoryServicesPipe, '|')
		WHERE VALUE <> ''

		DECLARE @countExistingInv INT
			,@countInvFromPipe INT
			,@DeviceIDInv INT
			,@DeviceOptionID INT
			,@ChannelTypeInv VARCHAR(100)
			,@LineNumber VARCHAR(50)
			,@IsSameChannelInv BIT = 1
			,@ChannelInv VARCHAR(100)

		SELECT @countInvFromPipe = COUNT(*)
		FROM @inventoriesTable

		-- Get values
		SELECT TOP 1 @CustomerID = i.customer_id
			,@Channel = Channel
			,@DeviceOptionID = CASE 
				WHEN (
						idr.IsBYOD = 1
						AND ISNULL(idr.SpareInventoryID, 0) = 0
						)
					THEN 2
				WHEN ISNULL(idr.SpareInventoryID, 0) <> 0
					THEN 3
				ELSE 1
				END
			,@ChannelTypeInv = CASE 
				WHEN mcm.Channel = 'Wholesale Aggregator'
					THEN 'QuantumShift'
				ELSE 'vCom'
				END
			,@DeviceIDInv = idr.DeviceID
			,@LineNumber = isr.ReferenceNumber
			,@ChannelInv = mcm.Channel
		FROM InventoryServiceRel isr(NOLOCK)
		INNER JOIN Inventory i(NOLOCK) ON isnull(isr.ReferenceNumber, '') = isnull(i.reference_number, '')
			AND i.inventory_id = isr.InventoryID -- Case# 9705
			AND i.is_active = 1
		JOIN InventoryDeviceRel idr(NOLOCK) ON idr.inventoryServiceID = isr.inventoryServiceID
		JOIN MobilityCarrierMaster mcm(NOLOCK) ON mcm.CarrierID = isr.CarrierID
		WHERE isr.InventoryServiceID = @InventoryServiceID
			AND isr.IsActive = 1
			AND idr.IsActive = 1

		--PRINT '@CustomerID = ' + cast(@CustomerID as varchar)
		--PRINT '@@Channel = ' + cast(@Channel as varchar)
		--PRINT '@@ChannelTypeInv = ' + cast(@ChannelTypeInv as varchar)
		--PRINT '@DeviceIDInv = ' + cast(@CustomerID as varchar)
		--PRINT '@@LineNumber = ' + cast(@LineNumber as varchar)
		--PRINT '@@ChannelInv = ' + cast(@ChannelInv as varchar)
		--PRINT '@@ChannelInv = ' + cast(@ESN as varchar)
		--PRINT '@@ChannelInv = ' + cast(@MEID as varchar)
		--PRINT '@@ChannelInv = ' + cast(@IMEI2 as varchar)
		IF (ISNULL(CAST(@ESN AS VARCHAR), '') + ISNULL(CAST(@MEID AS VARCHAR), '') + ISNULL(CAST(@IMEI2 AS VARCHAR), '') != '')
		BEGIN
			-- Get count for validation
			SELECT @countExistingInv = COUNT(*)
				,@IsSameChannelInv = CASE 
					WHEN COUNT(*) = SUM(CASE 
								WHEN mcm.Channel = @ChannelInv
									THEN 1
								ELSE 0
								END)
						THEN 1
					ELSE 0
					END
			FROM inventoryServiceRel isr(NOLOCK)
			INNER JOIN Inventory i(NOLOCK) ON isnull(isr.ReferenceNumber, '') = isnull(i.reference_number, '')
				AND i.inventory_id = isr.InventoryID -- Case# 9705
				AND i.is_active = 1
			INNER JOIN InventoryDeviceRel idr(NOLOCK) ON idr.inventoryServiceID = isr.inventoryServiceID
			INNER JOIN MobilityCarrierMaster mcm(NOLOCK) ON mcm.CarrierID = isr.CarrierID
				AND idr.IsActive = 1
			WHERE isr.IsActive = 1
				AND i.customer_id = @CustomerID
				AND ISNULL(idr.ESN, '') = ISNULL(CAST(@ESN AS VARCHAR), '')
				AND ISNULL(idr.MEID, '') = ISNULL(CAST(@MEID AS VARCHAR), '')
				AND ISNULL(idr.IMEI2, '') = ISNULL(CAST(@IMEI2 AS VARCHAR), '')
				--AND ISNULL(idr.DeviceID, 0) = ISNULL(@DeviceIDInv, 0)
				AND isr.inventoryStatusMasterID <> 2000

			--AND isr.InventoryServiceID NOT IN (SELECT InventoryServiceID FROM @inventoriesTable)
			--PRINT '@countExistingInv = ' + cast(@countExistingInv as varchar)
			--PRINT '@IsSameChannelInv = ' + cast(@IsSameChannelInv as varchar)
			IF @IsSameChannelInv = 0
			BEGIN
				/* Get existing inv info */
				INSERT INTO @tblExisting
				SELECT TOP 1 'Reference Number: ' + isr.ReferenceNumber
					,'Channel'
					,'Device already exists on ' + (
						CASE 
							WHEN mcm.Channel = 'Wholesale Aggregator'
								THEN 'QuantumShift'
							ELSE 'vCom'
							END
						) + ' carrier. This combination of active carriers is not allowed.'
				FROM inventoryServiceRel isr(NOLOCK)
				INNER JOIN Inventory i(NOLOCK) ON isnull(isr.ReferenceNumber, '') = isnull(i.reference_number, '')
					AND i.inventory_id = isr.InventoryID -- Case# 9705
					AND i.is_active = 1
				INNER JOIN InventoryDeviceRel idr(NOLOCK) ON idr.inventoryServiceID = isr.inventoryServiceID
				INNER JOIN MobilityCarrierMaster mcm(NOLOCK) ON mcm.CarrierID = isr.CarrierID
					AND idr.IsActive = 1
				WHERE isr.IsActive = 1
					AND i.customer_id = @CustomerID
					AND ISNULL(idr.ESN, '') = CAST(ISNULL(@ESN, '') AS VARCHAR)
					AND ISNULL(idr.MEID, '') = CAST(ISNULL(@MEID, '') AS VARCHAR)
					AND ISNULL(idr.IMEI2, '') = CAST(ISNULL(@IMEI2, '') AS VARCHAR)
					--AND ISNULL(idr.DeviceID, 0) = ISNULL(@DeviceIDInv, 0)
					AND isr.inventoryStatusMasterID <> 2000
					AND isr.inventoryServiceID <> @InventoryServiceID
					AND mcm.Channel <> @ChannelInv
			END

			IF @IsSameChannelInv = 1
			BEGIN
				-- Validate in case of all except Spare
				IF (@DeviceOptionID <> 3)
				BEGIN
					IF (
							@countExistingInv + @countInvFromPipe > CASE 
								WHEN @Channel = 'Wholesale Aggregator'
									THEN CASE 
											WHEN @deviceIsMultiSim = 1
												THEN 4
											ELSE 1
											END
								ELSE CASE 
										WHEN @deviceIsMultiSim = 1
											THEN 8
										ELSE 1
										END
								END
							)
					BEGIN
						INSERT INTO @tblExisting
						SELECT 'ESN: ' + ISNULL(CAST(@ESN AS VARCHAR), '') + ', ' + 'IMEI: ' + ISNULL(CAST(@MEID AS VARCHAR), '') + ', ' + 'IMEI2: ' + ISNULL(CAST(@IMEI2 AS VARCHAR), '')
							,'Device'
							,'Device already exists on ' + CAST(ISNULL(@countExistingInv, 0) AS VARCHAR(10)) + ' ' + @ChannelTypeInv + ' carrier(s).'
					END
				END
			END
		END
	END

	SELECT *
	FROM @tblExisting
END
GO
