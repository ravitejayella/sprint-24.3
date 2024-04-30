USE mobility
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- ============================================= 
-- Author:  AK      
-- Modified date: NA    
-- Description:  Create Spare Device
-- ============================================= 
-- Author:  Nagasai      
-- Modified date: 2021-04-05       
-- Description: update with vcom store changes
-- ============================================= 
-- Author:  Nagasai      
-- Modified date: 2021-04-10       
-- Description: device carrier changes
-- =============================================
-- Altered by : Ravi Teja Yella
-- Altered date : 11.16.2023
-- Description : Saving new added fields (ALSO NOT SAVING DEVICE DETAILS LIKE MAKE, MODEL ETC)
-- Case# 9993 - QMobile Store Look up Enhancements
-- =============================================
-- Altered by : Ravi Teja Yella
-- Altered Date : 01/19/2024
-- Case# 12114 : Issues with bulk store template
-- Description : Commenting out check for @IsEnrolled param as it is not needed and @IsEnrolled = '' gives true even when @IsEnrolled = 0
-- ============================================= 
-- Altered by : AkhilM
-- Altered date : 02.28.2024
-- Description : Changes to accept the QMobile Device Vendors
-- Case# 4686
-- =============================================
-- Altered by : Gopi Pagadala
-- Altered date : 03.07.2024
-- Description : Added VendorDesc column
-- Case# 4686
-- =============================================
-- Altered by : Ravi Teja Yella
-- Altered date : 04.22.2024
-- Description : Saving IsUnlocked flag
-- =============================================
ALTER PROCEDURE [dbo].[MobilityDevices_CreatevComStoreDevice] @InventoryType VARCHAR(1000) = NULL
	,@DeviceID VARCHAR(100)
	,@Shelf VARCHAR(250)
	,@ESN VARCHAR(250)
	,@MEID VARCHAR(250) = ''
	,@ICCID VARCHAR(250)
	,@IMEI VARCHAR(250)
	,@Cost VARCHAR(250)
	,@ShippingCost VARCHAR(250) = NULL
	,@ShippingPrice VARCHAR(250) = NULL
	,@Margin VARCHAR(250)
	,@Price VARCHAR(250)
	--@Seller varchar(250),                            
	,@WarrantyTerm VARCHAR(250)
	,@InvoiceNumber VARCHAR(250)
	,@RequiresPlan VARCHAR(250) = NULL
	,@CarrierName VARCHAR(250) = NULL
	,@ModelYear INT = 0
	,@ModelGeneration VARCHAR(150) = NULL
	,
	--@ChannelType varchar(250), 
	@DeviceCondition VARCHAR(150) = NULL
	,@DeviceVendor VARCHAR(150) = NULL
	,@IsUnlocked BIT = 0
	,@AddedByID INT
	,@CustomerName VARCHAR(300) = NULL
	,@AccountBAN VARCHAR(100) = NULL
	,@DEPValue VARCHAR(150) = NULL
	,@IsEnrolled BIT = NULL
	,@EquipmentOrderedDateString DATETIME = NULL
	,@EquipmentPurchasedDateString DATETIME = NULL
	,@WarrantyDateString DATETIME = NULL
	,@IseSimSelected BIT = NULL
	,@EID VARCHAR(100) = NULL
	,@IMEI2 VARCHAR(100) = NULL
AS
BEGIN
	SET @ShippingCost = CASE 
			WHEN @ShippingCost IS NULL
				OR @ShippingCost = ''
				THEN NULL
			ELSE @ShippingCost
			END
	SET @ShippingPrice = CASE 
			WHEN @ShippingPrice IS NULL
				OR @ShippingPrice = ''
				THEN NULL
			ELSE @ShippingPrice
			END

	DECLARE @Msg VARCHAR(MAX) = ''
	DECLARE @DeviceConditionID INT
		,@DeviceVendorID INT
		,@DeviceTypeMasterID INT
		,@DevicePricingCategoryMasterID INT
		--,@DeviceWarrantyTypeMasterID INT
		,@DeviceWarrantyTermMasterID INT
		,@DeviceSellerID INT
		,@CarrierID INT = NULL
		,@DeviceXCarrierID INT = NULL
		,@CustomerID INT
		,@CustomerXCarrierAccountsID INT
		,@EquipmentOrderedDate DATETIME = NULL
		,@WarrantyDate DATETIME = NULL
		,@EquipmentPurchasedDate DATETIME = NULL

	SELECT TOP 1 @CustomerID = customer_id
	FROM customer(NOLOCK)
	WHERE customer_name = @CustomerName

	SELECT TOP 1 @CustomerXCarrierAccountsID = CustomerXCarrierAccountsID
	FROM CustomerXCarrierAccounts(NOLOCK)
	WHERE AccountBAN = @AccountBAN
		AND IsActive = 1
		AND CustomerID = @CustomerID

	IF ISDATE(@EquipmentOrderedDateString) = 1
	BEGIN
		SET @EquipmentOrderedDate = CAST(@EquipmentOrderedDateString AS DATETIME)
	END
	ELSE
	BEGIN
		SET @Msg = 'Invalid Equipment Ordered Date, '
	END

	IF ISDATE(@EquipmentPurchasedDateString) = 1
	BEGIN
		SET @EquipmentPurchasedDate = CAST(@EquipmentPurchasedDateString AS DATETIME)
	END
	ELSE
	BEGIN
		SET @Msg = @Msg + 'Invalid Equipment Purchase Date, '
	END

	IF ISDATE(@WarrantyDateString) = 1
	BEGIN
		SET @WarrantyDate = CAST(@WarrantyDateString AS DATETIME)
	END
	ELSE
	BEGIN
		SET @Msg = @Msg + 'Invalid Warranty Date, '
	END

	IF (
			ISNULL(@WarrantyDate, '') = ''
			AND ISDATE(@EquipmentPurchasedDate) = 1
			)
	BEGIN
		SET @WarrantyDate = CASE 
				WHEN @WarrantyTerm = '30 day'
					THEN DATEADD(DAY, 30, @EquipmentPurchasedDate)
				WHEN @WarrantyTerm = '180 day'
					THEN DATEADD(DAY, 180, @EquipmentPurchasedDate)
				WHEN @WarrantyTerm = '1 Year'
					THEN DATEADD(YEAR, 1, @EquipmentPurchasedDate)
						--WHEN @WarrantyTerm = 'N/A' THEN NULL 
				ELSE NULL
				END
	END

	IF (
			@ESN = ''
			AND @MEID = ''
			AND @IMEI = ''
			)
	BEGIN
		SET @Msg = @Msg + 'ESN and MEID and IMEI cannot be empty, '
	END

	IF ISNULL(@CustomerName, '') <> ''
		AND ISNULL(@CustomerID, 0) = 0
	BEGIN
		SET @Msg = @Msg + 'Invalid Customer, '
	END

	IF (
			ISNULL(@AccountBAN, '') <> ''
			OR ISNULL(@CarrierName, '') <> ''
			)
		AND ISNULL(@CustomerXCarrierAccountsID, 0) = 0
	BEGIN
		SET @Msg = @Msg + 'Carrier Account BAN is mandatory, '
	END

	IF (
			@IseSimSelected = 1
			AND ISNULL(@EID, '') = ''
			)
	BEGIN
		SET @Msg = @Msg + 'EID cannot be empty when eSIM is selected, '
	END

	IF (
			@IseSimSelected = 1
			AND (
				LEN(@EID) < 19
				OR LEN(@EID) > 32
				)
			)
	BEGIN
		SET @Msg = @Msg + 'EID should be from 19 to 32 digits, '
	END

	--IF (@DeviceType <> '')
	--BEGIN
	--	SELECT @DeviceTypeMasterID = DeviceTypeMasterID
	--	FROM DeviceTypeMaster
	--	WHERE DeviceType = @DeviceType
	--	IF (@DeviceTypeMasterID IS NULL)
	--	BEGIN
	--		SET @Msg = @Msg + 'Invalid device type, '
	--	END
	--END
	IF (@DeviceCondition <> '')
	BEGIN
		SELECT @DeviceConditionID = DeviceConditionID
		FROM DeviceCondition
		WHERE ConditionName = @DeviceCondition

		IF (@DeviceConditionID IS NULL)
		BEGIN
			SET @Msg = @Msg + 'Invalid Device Condition, '
		END
	END

	IF (@DeviceVendor <> '')
	BEGIN
		-- START -- AddedBy AkhilM as per case 4686
		DECLARE @VendorName VARCHAR(100)

		IF @DeviceVendor = 'AT&T-Apex'
		BEGIN
			SET @VendorName = 'Carrier'
		END
		ELSE IF @DeviceVendor = 'Verizon-Telespire'
		BEGIN
			SET @VendorName = 'Carrier'
		END
		ELSE IF @DeviceVendor = 'Webbing'
		BEGIN
			SET @VendorName = 'Carrier'
		END
		ELSE
		BEGIN
			SET @VendorName = @DeviceVendor
		END

		-- END -- AddedBy AkhilM as per case 4686
		SELECT @DeviceVendorID = DeviceVendorID
		FROM DeviceVendor
		WHERE VendorName = @VendorName

		IF (@DeviceVendorID IS NULL)
		BEGIN
			SET @Msg = @Msg + 'Invalid Device Vendor, '
		END
	END

	IF (@CarrierName <> '')
	BEGIN
		SELECT @CarrierID = CarrierID
		FROM mobilitycarriermaster
		WHERE CarrierUsageName = ISNULL(@CarrierName, CarrierUsageName) --LIKE '%'+@CarrierName+'%' --AND Channel =  @ChannelType         

		IF (@CarrierID IS NULL)
		BEGIN
			SET @Msg = @Msg + 'Invalid Carrier, '
		END
	END

	--IF (@WarrantyType <> '')
	--BEGIN
	--	SELECT @DeviceWarrantyTypeMasterID = DeviceWarrantyTypeMasterID
	--	FROM DeviceWarrantyTypeMaster
	--	WHERE DeviceWarrantyType = @WarrantyType
	--	IF (@DeviceWarrantyTypeMasterID IS NULL)
	--	BEGIN
	--		SET @Msg = @Msg + 'Invalid warranty type, '
	--	END
	--END
	IF (@WarrantyTerm <> '')
	BEGIN
		SELECT @DeviceWarrantyTermMasterID = DeviceWarrantyTermMasterID
		FROM DeviceWarrantyTermMaster
		WHERE WarrantyTerm = @WarrantyTerm

		IF (@DeviceWarrantyTermMasterID IS NULL)
		BEGIN
			SET @Msg = @Msg + 'Invalid warranty term, '
		END
	END
	ELSE
	BEGIN
		SET @Msg = @Msg + 'Warranty Term is mandatory, '
	END

	--IF(@Seller<>'')                            
	--BEGIN                            
	-- SELECT @DeviceSellerID = DeviceSellerID FROM DeviceSellers             
	-- WHERE  SellerName=@Seller and isActive=1                            
	-- IF(@DeviceSellerID is null)                            
	-- BEGIN                            
	--  Insert into DeviceSellers (SellerName,isActive,AddedByID,ChangedByID)                            
	--  Values (@Seller,1,@AddedByID,@AddedByID)                            
	-- END                            
	--END                            
	IF (@Price <> '')
	BEGIN
		IF (cast(@Price AS DECIMAL(18, 2)) <= 500)
		BEGIN
			SET @DevicePricingCategoryMasterID = 3
		END
		ELSE IF (
				cast(@Price AS DECIMAL(18, 2)) > 500
				AND cast(@Price AS DECIMAL(18, 2)) < 1000
				)
		BEGIN
			SET @DevicePricingCategoryMasterID = 2
		END
		ELSE IF (cast(@Price AS DECIMAL(18, 2)) >= 1000)
		BEGIN
			SET @DevicePricingCategoryMasterID = 1
		END
	END

	DECLARE @hasESN BIT = 0
	DECLARE @IsPlanRequired BIT = 0

	IF (@ESN <> '')
		SET @hasESN = 1

	IF (@hasESN = 1)
	BEGIN
		IF EXISTS (
				SELECT TOP 1 *
				FROM EquipmentInventory ic(NOLOCK)
				LEFT JOIN MobilityOrderItems MOI(NOLOCK) ON MOI.MobilityOrderID = ic.MobilityOrderID
					AND MOI.MobilityOrderItemId = ic.MobilityOrderItemId
				WHERE ESN = @ESN
				) -- excluding completed orders
			--AND MOI.IsActive = 1
			--AND LineStatusMasterID NOT IN (
			--	5001
			--	,7001
			--	)
		BEGIN
			SET @Msg = @Msg + 'ESN Already Exists, '
		END
	END
	ELSE
	BEGIN
		IF (@MEID <> '')
		BEGIN
			IF EXISTS (
					SELECT TOP 1 *
					FROM EquipmentInventory ic(NOLOCK)
					LEFT JOIN MobilityOrderItems MOI(NOLOCK) ON MOI.MobilityOrderID = ic.MobilityOrderID
						AND MOI.MobilityOrderItemId = ic.MobilityOrderItemId
					WHERE MEID = @MEID
						AND MOI.IsActive = 1
						AND LineStatusMasterID NOT IN (
							5001
							,7001
							)
					) -- excluding completed orders                     
			BEGIN
				SET @Msg = @Msg + 'MEID Already Exists, '
			END
		END
		ELSE
		BEGIN
			IF EXISTS (
					SELECT TOP 1 *
					FROM EquipmentInventory ic(NOLOCK)
					LEFT JOIN MobilityOrderItems MOI(NOLOCK) ON MOI.MobilityOrderID = ic.MobilityOrderID
						AND MOI.MobilityOrderItemId = ic.MobilityOrderItemId
					WHERE MEID = @IMEI
					) -- excluding completed orders                    
				--AND MOI.IsActive = 1
				--AND LineStatusMasterID NOT IN (
				--	5001
				--	,7001
				--	)
			BEGIN
				SET @Msg = @Msg + 'IMEI Already Exists, '
			END
		END
	END

	IF NOT EXISTS (
			SELECT 1
			FROM Devices(NOLOCK)
			WHERE DeviceID = CAST(ISNULL(@DeviceID, 0) AS INT)
			)
	BEGIN
		SET @Msg = @Msg + 'Device does not exists, '
	END
	ELSE
	BEGIN
		IF ISNULL(@CustomerID, 0) <> 0
		BEGIN
			PRINT 'COMMENTING OUT CHECK FOR CUSTOMER CONFIGURATION'

			-- Check for Customer configured device
			IF NOT EXISTS (
					SELECT 1
					FROM CustomerXProductCatalog(NOLOCK)
					WHERE CategoryPlanID = ISNULL(@DeviceID, 0)
						AND CarrierID = CASE -- Not Checking for carrier because in a case of different carrier, we are new entry to DeviceXCarrier
							WHEN ISNULL(@CarrierID, 0) = 0
								THEN CarrierID
							ELSE @CarrierID
							END
						AND CustomerID = ISNULL(@CustomerID, 0)
						AND ProductCatalogCategoryMasterID = 5
						AND statusID = 1
					)
			BEGIN
				SET @Msg = @Msg + 'Device not configured, '
			END
		END
	END

	IF ISNULL(@DEPValue, '') <> ''
	BEGIN
		IF @DEPValue NOT IN (
				'ABM'
				,'KNOX'
				,'Google'
				,'None'
				)
		BEGIN
			SET @Msg = @Msg + 'Invalid DEPValue, '
		END
	END

	--IF(@IsEnrolled = '')                            
	--BEGIN                            
	--	SET @Msg = @Msg + 'Is Enrolled is mandatory, '
	--END    
	BEGIN TRANSACTION

	IF (@Msg = '')
	BEGIN
		IF (UPPER(@RequiresPlan) = UPPER('Yes'))
		BEGIN
			SET @IsPlanRequired = 1
		END

		IF (
				@MEID = ''
				OR @MEID IS NULL
				)
		BEGIN
			SET @MEID = @IMEI
		END

		IF (@CarrierID IS NULL)
		BEGIN
			DECLARE @LoopCarrier VARCHAR(100)

			DECLARE cursor_carrier CURSOR
			FOR
			SELECT CarrierID
			FROM MobilityCarrierMaster
			WHERE IsActive = 1

			OPEN cursor_carrier

			FETCH NEXT
			FROM cursor_carrier
			INTO @LoopCarrier

			WHILE @@fetch_status = 0
			BEGIN
				SET @DeviceXCarrierID = NULL

				SELECT @DeviceXCarrierID = DeviceXCarrierID
				FROM DeviceXCarrier(NOLOCK)
				WHERE DeviceID = @DeviceID
					AND CarrierID = @LoopCarrier

				IF (@DeviceXCarrierID IS NULL)
				BEGIN
					INSERT INTO DeviceXCarrier (
						CarrierID
						,DeviceID
						,Cost
						,Margin
						,Price
						,AddedDateTime
						,AddedByID
						,ChangedDateTime
						,ChangedByID
						,DeviceVendorID
						,DeviceConditionID
						,MSRP
						,DeviceStatusID
						)
					SELECT @LoopCarrier
						,@DeviceID
						,@Cost
						,@Margin
						,@Price
						,getdate()
						,@AddedByID
						,getdate()
						,@AddedByID
						,@DeviceVendorID
						,@DeviceConditionID
						,@Price
						,100

					SET @DeviceXCarrierID = @@IDENTITY
				END

				FETCH NEXT
				FROM cursor_carrier
				INTO @LoopCarrier
			END

			CLOSE cursor_carrier

			DEALLOCATE cursor_carrier

			INSERT INTO EquipmentInventory (
				InventoryType
				,DeviceID
				,DeviceTypeMasterID
				,EquipmentStatusMasterID
				,ModelName
				,Make
				,ModelNumber
				,Storage
				,Color
				,Size
				,Shelf
				,ESN
				,MEID
				,ICCID
				,Cost
				,ShippingCost
				,Margin
				,Price
				,ShippingPrice
				,DeviceSellerID
				,DeviceWarrantyTypeMasterID
				,DeviceWarrantyTermMasterID
				,InvoiceNumber
				,AddedByID
				,AddedDateTime
				,ChangedByID
				,ChangedDateTime
				,isActive
				,CarrierID
				,SIM
				,DeviceXCarrierID
				,DeviceConditionID
				,DeviceVendorID
				,CustomerID
				,CustomerXCarrierAccountsID
				,DEPValue
				,IsEnrolled
				,EquipmentOrderedDate
				,EquipmentPurchasedDate
				,WarrantyDate
				,IseSimSelected
				,EID
				,IMEI2
				,IsUnlocked
				)
			SELECT DISTINCT @InventoryType
				,DeviceID
				,0
				,1
				,'' -- ModelName defined as Non Nullable
				,NULL
				,NULL
				,NULL
				,NULL
				,NULL
				,@Shelf
				,@ESN
				,@MEID
				,@ICCID
				,@Cost
				,@ShippingCost
				,@Margin
				,@Price
				,@ShippingPrice
				,@DeviceSellerID
				,NULL
				,@DeviceWarrantyTermMasterID
				,@InvoiceNumber
				,@AddedByID
				,getdate()
				,@AddedByID
				,getdate()
				,1
				,@CarrierID
				,SimType
				,@DeviceXCarrierID
				,@DeviceConditionID
				,@DeviceVendorID
				,@CustomerID
				,@CustomerXCarrierAccountsID
				,@DEPValue
				,@IsEnrolled
				,@EquipmentOrderedDate
				,@EquipmentPurchasedDate
				,@WarrantyDate
				,@IseSimSelected
				,@EID
				,@IMEI2
				,CASE 
					WHEN ISNULL(@CarrierID, 0) <> 0
						THEN 0
					ELSE @IsUnlocked
					END -- added by ravi on 04/22/2024 
			FROM Devices(NOLOCK)
			WHERE DeviceID = @DeviceId
		END
		ELSE IF (
				@CarrierID IS NOT NULL
				AND @DeviceID IS NOT NULL
				)
		BEGIN
			SELECT @DeviceXCarrierID = DeviceXCarrierID
			FROM DeviceXCarrier(NOLOCK)
			WHERE DeviceID = @DeviceID
				AND CarrierID = @CarrierID

			IF (@DeviceXCarrierID IS NULL)
			BEGIN
				INSERT INTO DeviceXCarrier (
					CarrierID
					,DeviceID
					,Cost
					,Margin
					,Price
					,AddedDateTime
					,AddedByID
					,ChangedDateTime
					,ChangedByID
					,DeviceVendorID
					,DeviceConditionID
					,MSRP
					,DeviceStatusID
					)
				SELECT @CarrierID
					,@DeviceID
					,@Cost
					,@Margin
					,@Price
					,getdate()
					,@AddedByID
					,getdate()
					,@AddedByID
					,@DeviceVendorID
					,@DeviceConditionID
					,@Price
					,100

				SET @DeviceXCarrierID = @@IDENTITY
			END

			INSERT INTO EquipmentInventory (
				InventoryType
				,DeviceID
				,DeviceTypeMasterID
				,EquipmentStatusMasterID
				,ModelName
				,Make
				,ModelNumber
				,Storage
				,Color
				,Size
				,Shelf
				,ESN
				,MEID
				,ICCID
				,Cost
				,ShippingCost
				,Margin
				,Price
				,ShippingPrice
				,DeviceSellerID
				,DeviceWarrantyTypeMasterID
				,DeviceWarrantyTermMasterID
				,InvoiceNumber
				,AddedByID
				,AddedDateTime
				,ChangedByID
				,ChangedDateTime
				,isActive
				,CarrierID
				,SIM
				,DeviceXCarrierID
				,DeviceConditionID
				,DeviceVendorID
				,VendorDesc -- Case# 4686 - Gopi  
				,CustomerID
				,CustomerXCarrierAccountsID
				,DEPValue
				,IsEnrolled
				,EquipmentOrderedDate
				,EquipmentPurchasedDate
				,WarrantyDate
				,IseSimSelected
				,EID
				,IMEI2
				)
			SELECT DISTINCT @InventoryType
				,D.DeviceID
				,0
				,1
				,'' -- ModelName defined as Non Nullable
				,NULL
				,NULL
				,NULL
				,NULL
				,NULL
				,@Shelf
				,@ESN
				,@MEID
				,@ICCID
				,@Cost
				,@ShippingCost
				,@Margin
				,@Price
				,@ShippingPrice
				,@DeviceSellerID
				,NULL
				,@DeviceWarrantyTermMasterID
				,@InvoiceNumber
				,@AddedByID
				,getdate()
				,@AddedByID
				,getdate()
				,1
				,@CarrierID
				,SimType
				,@DeviceXCarrierID
				,@DeviceConditionID
				,@DeviceVendorID
				,@DeviceVendor -- Case# 4686 - Gopi
				,@CustomerID
				,@CustomerXCarrierAccountsID
				,@DEPValue
				,@IsEnrolled
				,@EquipmentOrderedDate
				,@EquipmentPurchasedDate
				,@WarrantyDate
				,@IseSimSelected
				,@EID
				,@IMEI2
			FROM Devices D(NOLOCK)
			INNER JOIN DeviceXCarrier DXC(NOLOCK) ON DXC.DeviceID = D.DeviceID
				AND DXC.CarrierID = @CarrierID
			WHERE D.DeviceID = @DeviceId
		END
	END

	SELECT @Msg AS ErrorMessage

	IF @@ERROR > 0
	BEGIN
		DECLARE @eMessage VARCHAR(800)
			,@eProcedure VARCHAR(800)
			,@eLine VARCHAR(800)

		SELECT @eMessage = ''
			,@eProcedure = ''
			,@eLine = ''

		SELECT @eMessage = ERROR_MESSAGE()
			,@eProcedure = ERROR_PROCEDURE()
			,@eLine = ERROR_LINE()

		EXEC dbo.uspSendDBErrorEmail @Subject = 'MobilityDevices_CreatevComStoreDevice'
			,@ErrorMessage = @eMessage
			,@ErrorProcedure = @eProcedure
			,@ErrorLine = @eLine
			,@QueryParams = ''
			,@UserID = @AddedByID

		ROLLBACK TRANSACTION
	END
	ELSE
	BEGIN
		COMMIT TRANSACTION
	END
END
GO
