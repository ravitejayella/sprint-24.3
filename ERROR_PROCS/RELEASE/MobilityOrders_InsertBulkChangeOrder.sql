USE [mobility]
GO
/****** Object:  StoredProcedure [dbo].[MobilityOrders_InsertBulkChangeOrder]    Script Date: 3/28/2024 4:34:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================  
-- Author:		NS 
-- MODIFIED DATE: 2022-10-29
-- Description:	DESK-18996 -- issues with add on 
-- Termination dates
-- =============================================  
-- Author:		NS 
-- MODIFIED DATE: 2021-04-22
-- Description:	Added Bulk Plan DataReset
-- =============================================
-- Author:		NS 
-- MODIFIED DATE: 2021-04-23
-- Description:	adding customer subsidized features
-- =============================================
-- Author:  Nagasai                            
-- ALTER date: 05-06-2021                           
-- Description:  added ibiller date
-- ============================================= 
-- Author: NAGASAI MUDAREA
-- MODIFIED Date: 01.03.2022
-- Description:DESK-19663- 49294 - MNS Add On/Feature Charges 
-- =============================================
-- Author:		Nagasai Mudara
-- Create date: 2022-06-10
-- Description:	CASE-1304 - Update WWAN Provisioner logic
-- =============================================
-- Author: NAGASAI MUDAREA
-- MODIFIED Date: 06.06.2022
-- Description:CASE-1721- Removed addons which are not in inventory charges 
-- =========================================================================
-- Author:  Nagasai Mudara  
-- Modified date: 09.05.2022
-- Description: Overhaul Mobile Order Notifications
-- SD CASE - 1689
-- =================================================
-- Author:  Nagasai Mudara  
-- Modified date: 11.15.2022
-- Description: Mobile Draft Orders for Optimizations
-- SD CASE - 3308
-- ================================================= 
-- =================================================
-- Author:  SP  
-- Modified date: 05/16/23
-- Description: Back Dating Mobile Plans
--Upgrade – will only allow backdating IF change happens before the bill close
--Downgrade – no backdating allowed
-- SD CASE - 6741
-- ================================================= 
-- Altered by:  Ravi Teja Yella  
-- ALTER date: 01-30-2024
-- Description: Inserting Service Attributes as per case 10226
-- ==================================================
-- Altered by: Ravi Teja Yella
-- Altered date : 03/12/2024
-- Description : Added ERROR handling, ADDED TRANSACTIONS AND ADDED NOLOCKs
-- ============================================= 
-- Altered by: Ravi Teja Yella
-- Altered date : 03/28/2024
-- Description : Added params to error email
-- =============================================
ALTER PROCEDURE [dbo].[MobilityOrders_InsertBulkChangeOrder] @InventoryServiceIDs TEXT
	,@OrderPlans TEXT
	,@OrderAttributes TEXT
	,@ChargesXML TEXT
	,@AddedByID INT
	,@OrderDescription VARCHAR(MAX)
	,@RequestorID INT = NULL
AS
BEGIN
	BEGIN TRY
		DECLARE @MobilityOrderID INT
		DECLARE @MobilityOrderItemID INT
		DECLARE @LineStatusMasterID INT = 0
			,@LineStatusID INT
			,@IsRetail BIT = 0
		DECLARE @OrderTypeID INT = 2
			,@MobilityOrderXDeviceID INT
			,@IsNew BIT = 1
		DECLARE @FirstName VARCHAR(250)
			,@LastName VARCHAR(250)
			,@Email VARCHAR(250)
		DECLARE @XMLHandle INT
			,@XMLData VARCHAR(MAX)
		DECLARE @tblnventoryService TABLE (
			InventoryServiceID INT
			,CustomerID INT
			,CarrierID INT
			,ServiceID INT
			,AccountID INT
			,LineStatusMasterID INT
			)
		DECLARE @InventoryServiceID INT
			,@CustomerID INT
			,@CarrierID INT
			,@ServiceID INT
			,@AccountID INT
			,@FamilyPlanID INT
			,@FamilyID INT
		DECLARE @MainCharges TABLE (
			[MobilityOrderChargeChangeID] INT
			,[MobilityOrderChargeID] INT
			,[CustomerXProductCatalogID] INT
			,[CategoryPlanID] INT
			,[ProductCatalogCategoryMasterID] INT
			,[ChargeType] VARCHAR(50)
			,[USOC] VARCHAR(50)
			,[ChargeDescription] VARCHAR(250)
			,[Quantity] INT
			,[Cost] DECIMAL(18, 2)
			,[Margin] DECIMAL(18, 2)
			,[Price] DECIMAL(18, 2)
			,[ChangeType] VARCHAR(5)
			)
		DECLARE @Charges TABLE (
			[MobilityOrderChargeChangeID] INT
			,[MobilityOrderChargeID] INT
			,[CustomerXProductCatalogID] INT
			,[CategoryPlanID] INT
			,[ProductCatalogCategoryMasterID] INT
			,[ChargeType] VARCHAR(50)
			,[USOC] VARCHAR(50)
			,[ChargeDescription] VARCHAR(250)
			,[Quantity] INT
			,[Cost] DECIMAL(18, 2)
			,[Margin] DECIMAL(18, 2)
			,[Price] DECIMAL(18, 2)
			,[ChangeType] VARCHAR(5)
			)
		DECLARE @Charges1 TABLE (
			[MobilityOrderChargeChangeID] INT
			,[MobilityOrderChargeID] INT
			,[CustomerXProductCatalogID] INT
			,[CategoryPlanID] INT
			,[ProductCatalogCategoryMasterID] INT
			,[ChargeType] VARCHAR(50)
			,[USOC] VARCHAR(50)
			,[ChargeDescription] VARCHAR(250)
			,[Quantity] INT
			,[Cost] DECIMAL(18, 2)
			,[Margin] DECIMAL(18, 2)
			,[Price] DECIMAL(18, 2)
			,[ChangeType] VARCHAR(5)
			)

		--SELECT @LineStatusID = LineStatusMasterID                                           
		--FROM LineStatusMaster WHERE StatusCode = 'MPR'  
		SET @XMLData = @InventoryServiceIDs

		IF (@XMLData <> '')
		BEGIN
			EXEC sp_xml_preparedocument @XMLHandle OUTPUT
				,@XMLData

			INSERT INTO @tblnventoryService (
				InventoryServiceID
				,CustomerID
				,CarrierID
				,ServiceID
				,AccountID
				,LineStatusMasterID
				)
			SELECT InventoryServiceID
				,CustomerID
				,CarrierID
				,ServiceID
				,AccountID
				,LineStatusMasterID
			FROM OPENXML(@XMLHandle, '/ROOT/row', 2) WITH (
					InventoryServiceID INT '@InventoryServiceID'
					,CustomerID INT '@CustomerID'
					,CarrierID INT '@CarrierID'
					,ServiceID INT '@ServiceID'
					,AccountID INT '@AccountID'
					,LineStatusMasterID INT '@LineStatusMasterID'
					)

			EXEC sp_xml_removedocument @XMLHandle
		END

		DECLARE @TBLADDONS TABLE (
			MobilityOrderID INT
			,MobilityOrderItemID INT
			,AddOnID INT
			,AddOnAttributeID INT
			,EffectiveDate DATETIME
			,Terminationdate DATETIME
			,AddedByID INT
			,ChangedByID INT
			,CustomerXProductCatalogID INT
			,USOC VARCHAR(50)
			,CountryIDs VARCHAR(50)
			,CallForwardNumber VARCHAR(150)
			)

		--Order Creation Cursor Start      
		BEGIN TRANSACTION

		DECLARE curOrderItemCreation CURSOR
		FOR
		SELECT InventoryServiceID
			,CustomerID
			,CarrierID
			,ServiceID
			,AccountID
			,LineStatusMasterID
		FROM @tblnventoryService

		OPEN curOrderItemCreation

		FETCH NEXT
		FROM curOrderItemCreation
		INTO @InventoryServiceID
			,@CustomerID
			,@CarrierID
			,@ServiceID
			,@AccountID
			,@LineStatusMasterID

		WHILE @@FETCH_STATUS = 0
		BEGIN
			DECLARE @desc VARCHAR(100)
				,@CarrierAccountID VARCHAR(250)
				,@ExistingMobilityOrderID INT
				,@ExistingMobilityOrderItemID INT
				,@CustomerXCarrierAccountsID INT
			DECLARE @ChannelMasterID INT = 0
				,@existingActivationDate DATETIME
				,@ActivationDate DATETIME

			SELECT @CarrierAccountID = CarrierAccountID
				,@FirstName = FirstName
				,@LastName = LastName
				,@Email = Email
				,@ExistingMobilityOrderID = MobilityOrderID
				,@ExistingMobilityOrderItemID = MobilityOrderItemID
				,@CustomerXCarrierAccountsID = CustomerXCarrierAccountsID
				,@existingActivationDate = EffectiveDate
			FROM InventoryServiceRel(NOLOCK)
			WHERE InventoryServiceID = @InventoryServiceID
				AND IsActive = 1

			DECLARE @LineNumber VARCHAR(50)

			--SELECT @LineNumber = reference_number                                          
			--FROM iPath..inventory inv                                          
			--JOIN iPath..inventory_service invs on invs.inventory_id = inv.inventory_id                                           
			--WHERE invs.inventory_service_id = @InventoryServiceID   
			SELECT @LineNumber = ReferenceNumber -- ADDED READING THE LINE NUMBER FROM INVENTORYSERVICEREL NS 07/21/22
			FROM InventoryServiceRel(NOLOCK)
			WHERE InventoryServiceID = @InventoryServiceID
				AND IsActive = 1

			SELECT @IsRetail = CASE 
					WHEN Channel = 'Retail'
						THEN 1
					ELSE 0
					END
			FROM MobilityCarrierMaster (NOLOCK)
			WHERE CarrierID = @CarrierID

			/* GET Draft LINE STAGE*/
			IF (ISNULL(@LineStatusMasterID, 0) = 0)
			BEGIN
				SELECT @LineStatusMasterID = LineStatusMasterID
				FROM LineStatusMaster (NOLOCK)
				WHERE StatusCode = 'MPR'
			END

			IF (
					@MobilityOrderID IS NULL
					AND @MobilityOrderItemID IS NULL
					)
			BEGIN
				DECLARE @HasAssignments BIT = 1

				SET @HasAssignments = CASE 
						WHEN ISNULL(@LineStatusMasterID, 0) <> 1
							THEN 1
						ELSE 0
						END

				--- INSERT MAIN ORDER ---          
				EXEC [MobilityOrders_InsertNewOrder] @CustomerID = @CustomerID
					,@AccountID = @AccountID
					,@CarrierID = @CarrierID
					,@CarrierAccountID = @CarrierAccountID
					,@OrderTypeID = @OrderTypeID
					,@OrderDescription = @OrderDescription
					,@AddedByID = @AddedByID
					,@RequestorID = @RequestorID
					,@CustomerXCarrierAccountsID = @CustomerXCarrierAccountsID
					,@MobilityOrderID = @MobilityOrderID OUTPUT
					,@MobilityOrderItemID = @MobilityOrderItemID OUTPUT
					,@HasAssignments = @HasAssignments
			END
			ELSE
			BEGIN
				--- INSERT ORDER ITEM---            
				INSERT INTO MobilityOrderItems (
					MobilityOrderID
					,OrderSubTypeMasterID
					,LineStatusMasterID
					,AddedByID
					,ChangedByID
					)
				VALUES (
					@MobilityOrderID
					,4
					,@LineStatusMasterID
					,@AddedByID
					,@AddedByID
					)

				SELECT @MobilityOrderItemID = SCOPE_IDENTITY() --@@IDENTITY  
			END

			/***** Get service attributes from line to order - Case# 10226 *****/
			IF @IsRetail = 0
			BEGIN
				INSERT INTO ServiceAttributesRel (
					ServiceAttributeID
					,ServiceAttributeLevelID
					,ServiceAttributeLevelValue
					,AttributeValue
					,AttributeDatatype
					,IsCustomerEditable
					,IsCustomerViewable
					,IsActive
					,AddedByID
					,AddedDateTime
					,UpdatedByID
					,UpdatedDateTime
					)
				SELECT ServiceAttributeID
					,2
					,@MobilityOrderItemID
					,AttributeValue
					,AttributeDatatype
					,0
					,IsCustomerViewable
					,IsActive
					,@AddedByID
					,GETDATE()
					,@AddedByID
					,GETDATE()
				FROM ServiceAttributesRel (NOLOCK)
				WHERE ServiceAttributeLevelID = 3
					AND ServiceAttributeLevelValue = @InventoryServiceID
					AND IsActive = 1
			END

			/*** End of service attributes from line to order ***/
			-- NEW Change order insert history
			EXEC MobilityOrderItemHistory_Insert @LineStatusMasterID = @LineStatusMasterID
				,@LineSubStatusMasterID = NULL
				,@MobilityOrderItemID = @MobilityOrderItemID
				,@AddedByID = @AddedByID

			---- UPDATE SERVICE INFORMATION ---- (LINE NUMBER/INVENTORY NAME/LINE STATUS TO NEW -----                                          
			UPDATE MobilityOrderItems
			SET InventoryServiceID = @InventoryServiceID
				,OrderSubTypeMasterID = 4
				,LineNumber = @LineNumber
				,UserFirstName = @FirstName
				,UserLastName = @LastName
				,LineStatusMasterID = @LineStatusMasterID
				,UserEmail = @Email
				,iBillerDate = (
					CASE 
						WHEN @IsRetail = 0
							THEN dbo.GetBillCycleDate()
						ELSE NULL
						END
					)
			WHERE MobilityOrderItemID = @MobilityOrderItemID

			---- UPDATE Inventory SERVICE status in iPath to PC meaning Pending Change -----       
			UPDATE iPath..inventory_service
			SET [status] = 'PC'
			WHERE inventory_service_id = @InventoryServiceID

			UPDATE InventoryServiceRel
			SET InventoryStatusMasterID = dbo.GetInventoryStatusMasterByCode('PC')
			WHERE InventoryServiceID = @InventoryServiceID
				AND IsActive = 1

			--Start Plans And Addons Insertion                                  
			SET @XMLData = ''
			SET @XMLData = @OrderPlans

			IF (@XMLData <> '')
			BEGIN
				EXEC sp_xml_preparedocument @XMLHandle OUTPUT
					,@XMLData

				INSERT INTO MobilityOrderXCategoryPlanChanges (
					MobilityOrderID
					,MobilityOrderItemID
					,ProductCatalogCategoryMasterID
					,CategoryPlanID
					,AddedByID
					,ChangedByID
					,ChangeType
					,CustomerXProductCatalogID
					,FamilyPlanID
					,FamilyID
					)
				SELECT @MobilityOrderID
					,@MobilityOrderItemID
					,ProductCatalogCategoryMasterID
					,CategoryPlanID
					,@AddedByID
					,@AddedByID
					,'N'
					,CustomerXProductCatalogID
					,FamilyPlanID
					,FamilyID
				FROM OPENXML(@XMLHandle, '/ROOT/row', 2) WITH (
						ProductCatalogCategoryMasterID INT '@ProductCatalogCategoryMasterID'
						,CategoryPlanID INT '@CategoryPlanID'
						,CustomerXProductCatalogID INT '@CustomerXProductCatalogID'
						,FamilyPlanID INT '@FamilyPlanID'
						,FamilyID INT '@FamilyID'
						)

				EXEC sp_xml_removedocument @XMLHandle

				INSERT INTO MobilityOrderXCategoryPlanChanges (
					MobilityOrderID
					,MobilityOrderItemID
					,ProductCatalogCategoryMasterID
					,CategoryPlanID
					,AddedByID
					,ChangedByID
					,ChangeType
					,CustomerXProductCatalogID
					,FamilyPlanID
					,FamilyID
					)
				SELECT @MobilityOrderID
					,@MobilityOrderItemID
					,1
					,PrimaryServicePlanID
					,@AddedByID
					,@AddedByID
					,'R'
					,CustomerXProductCatalogID
					,FamilyPlanID
					,FamilyID
				FROM InventoryServiceRel (NOLOCK)
				WHERE InventoryServiceID = @InventoryServiceID
					AND IsActive = 1
			END
			ELSE
			BEGIN
				INSERT INTO MobilityOrderXCategoryPlans (
					MobilityOrderID
					,MobilityOrderItemID
					,ProductCatalogCategoryMasterID
					,CategoryPlanID
					,AddedByID
					,ChangedByID
					,ChangeType
					,CustomerXProductCatalogID
					,FamilyPlanID
					,FamilyID
					)
				SELECT @MobilityOrderID
					,@MobilityOrderItemID
					,1
					,PrimaryServicePlanID
					,@AddedByID
					,@AddedByID
					,'E'
					,CustomerXProductCatalogID
					,FamilyPlanID
					,FamilyID
				FROM InventoryServiceRel (NOLOCK)
				WHERE InventoryServiceID = @InventoryServiceID
					AND IsActive = 1
			END

			--Insert existing Addons                         
			SET @XMLData = @OrderAttributes

			DELETE
			FROM @TBLADDONS

			IF (@XMLData <> '')
			BEGIN
				EXEC sp_xml_preparedocument @XMLHandle OUTPUT
					,@XMLData

				INSERT INTO @TBLADDONS (
					MobilityOrderID
					,MobilityOrderItemID
					,AddOnID
					,AddOnAttributeID
					,EffectiveDate
					,Terminationdate
					,AddedByID
					,ChangedByID
					,CustomerXProductCatalogID
					,USOC
					,CountryIDs
					,CallForwardNumber
					)
				SELECT @MobilityOrderID
					,@MobilityOrderItemID
					,AddOnID
					,AddOnAttributeID
					,EffectiveDate
					,TerminationDate
					,@AddedByID
					,@AddedByID
					,CustomerXProductCatalogID
					,USOC
					,CountryIDs
					,CallForwardNumber
				FROM OPENXML(@XMLHandle, '/ROOT/row', 2) WITH (
						AddOnID INT '@AddOnID'
						,AddOnAttributeID INT '@AddOnAttributeID'
						,EffectiveDate DATETIME '@EffectiveDate'
						,TerminationDate DATETIME '@TerminationDate'
						,CustomerXProductCatalogID INT '@CustomerXProductCatalogID'
						,USOC VARCHAR(50) '@USOC'
						,CountryIDs VARCHAR(max) '@CountryIDs'
						,CallForwardNumber VARCHAR(50) '@CallForwardNumber'
						)

				EXEC sp_xml_removedocument @XMLHandle
			END

			---------------------Addons Logic---              
			DECLARE @AddonInsertTable TABLE (
				CategoryPlanID INT
				,AttributeID INT
				,EffectiveDate DATETIME
				,Terminationdate DATETIME
				,ChangeType VARCHAR(100)
				,CustomerXProductCatalogID INT
				,USOC VARCHAR(50)
				,CountryIDs VARCHAR(50)
				,CallForwardNumber VARCHAR(150)
				)

			DELETE
			FROM @AddonInsertTable

			INSERT INTO @AddonInsertTable (
				CategoryPlanID
				,AttributeID
				,EffectiveDate
				,Terminationdate
				,ChangeType
				,CustomerXProductCatalogID
				,USOC
				,CountryIDs
				,CallForwardNumber
				)
			SELECT t.AddOnID
				,t.AddOnAttributeID
				,m.EffectiveDate
				,m.Terminationdate
				,'E'
				,m.CustomerXProductCatalogID
				,t.USOC
				,t.CountryIDs
				,t.CallForwardNumber
			FROM @TBLADDONS t
			LEFT JOIN inventoryAddonRel m (NOLOCK) ON t.AddonID = m.AddonID
				AND isActive = 1
				AND m.inventoryserviceID = @InventoryServiceID
			WHERE t.addonID = m.AddOnID
				AND t.Terminationdate IS NULL
				AND t.AddOnAttributeID = 0
			
			UNION
			
			SELECT m.AddOnID
				,m.AddOnAttributeID
				,m.EffectiveDate
				,m.Terminationdate
				,'E'
				,m.CustomerXProductCatalogID
				,t.USOC
				,t.CountryIDs
				,t.CallForwardNumber
			FROM @TBLADDONS t
			LEFT JOIN inventoryAddonRel m (NOLOCK) ON t.AddonID = m.AddonID
				AND isActive = 1
				AND m.inventoryserviceID = @InventoryServiceID
			WHERE t.addonID = m.AddOnID
				AND t.Terminationdate IS NULL
				AND t.AddOnAttributeID IS NOT NULL
				AND t.AddOnAttributeID = m.AddOnAttributeID
			
			UNION
			
			SELECT m.AddOnID
				,m.AddOnAttributeID
				,m.EffectiveDate
				,m.Terminationdate
				,'E'
				,m.CustomerXProductCatalogID
				,t.USOC
				,t.CountryIDs
				,t.CallForwardNumber
			FROM inventoryAddonRel m (NOLOCK)
			LEFT JOIN @TBLADDONS t ON t.AddonID = m.AddonID
			WHERE isActive = 1
				AND m.inventoryserviceID = @InventoryServiceID
				AND t.AddOnID IS NULL
				-- NS: Added to avoid termination dates DESK-18996  
				AND (
					m.TerminationDate IS NULL
					OR m.TerminationDate >= GETDATE()
					)
			
			UNION
			
			SELECT t.AddOnID
				,m.AddOnAttributeID
				,m.EffectiveDate
				,t.Terminationdate
				,'R'
				,m.CustomerXProductCatalogID
				,t.USOC
				,t.CountryIDs
				,t.CallForwardNumber
			FROM @TBLADDONS t
			LEFT JOIN inventoryAddonRel m (NOLOCK) ON t.AddonID = m.AddonID
				AND isActive = 1
				AND m.inventoryserviceID = @InventoryServiceID
			WHERE t.addonID = m.AddOnID
				AND t.Terminationdate IS NULL
				AND t.AddOnAttributeID IS NOT NULL
				AND t.AddOnAttributeID <> m.AddOnAttributeID
			
			UNION
			
			SELECT t.AddOnID
				,t.AddOnAttributeID
				,t.EffectiveDate
				,t.Terminationdate
				,'N'
				,t.CustomerXProductCatalogID
				,t.USOC
				,t.CountryIDs
				,t.CallForwardNumber
			FROM @TBLADDONS t
			LEFT JOIN inventoryAddonRel m (NOLOCK) ON t.AddonID = m.AddonID
				AND isActive = 1
				AND m.inventoryserviceID = @InventoryServiceID
			WHERE t.addonID = m.AddOnID
				AND t.AddOnAttributeID IS NOT NULL
				AND t.AddOnAttributeID <> m.AddOnAttributeID
			
			UNION
			
			SELECT t.AddOnID
				,t.AddOnAttributeID
				,t.EffectiveDate
				,t.Terminationdate
				,'N'
				,t.CustomerXProductCatalogID
				,t.USOC
				,t.CountryIDs
				,t.CallForwardNumber
			FROM @TBLADDONS t
			LEFT JOIN inventoryAddonRel m (NOLOCK) ON t.AddonID = m.AddonID
				AND isActive = 1
				AND m.inventoryserviceID = @InventoryServiceID
			WHERE m.AddOnID IS NULL
			
			UNION
			
			SELECT t.AddOnID
				,m.AddOnAttributeID
				,m.EffectiveDate
				,t.Terminationdate
				,'R'
				,m.CustomerXProductCatalogID
				,t.USOC
				,t.CountryIDs
				,t.CallForwardNumber
			FROM @TBLADDONS t
			LEFT JOIN inventoryAddonRel m (NOLOCK) ON t.AddonID = m.AddonID
				AND isActive = 1
				AND m.inventoryserviceID = @InventoryServiceID
			WHERE t.addonID = m.AddOnID
				AND t.Terminationdate IS NOT NULL
				AND t.AddOnAttributeID = 0
			
			UNION
			
			SELECT t.AddOnID
				,m.AddOnAttributeID
				,m.EffectiveDate
				,t.Terminationdate
				,'R'
				,m.CustomerXProductCatalogID
				,t.USOC
				,t.CountryIDs
				,t.CallForwardNumber
			FROM @TBLADDONS t
			LEFT JOIN inventoryAddonRel m (NOLOCK) ON t.AddonID = m.AddonID
				AND isActive = 1
				AND m.inventoryserviceID = @InventoryServiceID
			WHERE t.addonID = m.AddOnID
				AND t.Terminationdate IS NOT NULL
				AND t.AddOnAttributeID = 0
				AND t.AddOnAttributeID = m.AddOnAttributeID

			--NS 2022-06-06 --- delete addons that are not in invnetory charges table
			DELETE
			FROM @AddonInsertTable
			WHERE ChangeType = 'E'
				AND categoryplanid NOT IN (
					SELECT categoryplanid
					FROM inventorycharges ic(NOLOCK)
					WHERE inventoryserviceID = @InventoryServiceID
						AND ProductCatalogCategoryMasterID = 7
						AND STATUS = 'A'
						AND (
							ic.TerminationDate IS NULL
							OR ic.TerminationDate >= GETDATE()
							)
					)

			INSERT INTO MobilityOrderXCategoryPlans (
				MobilityOrderID
				,MobilityOrderItemID
				,ProductCatalogCategoryMasterID
				,CategoryPlanID
				,AttributeID
				,EffectiveDate
				,Terminationdate
				,ChangeType
				,AddedByID
				,ChangedByID
				,CustomerXProductCatalogID
				,CountryIDs
				,CallForwardNumber
				)
			SELECT @MobilityOrderID
				,@MobilityOrderItemID
				,7
				,CategoryPlanID
				,AttributeID
				,tmp.EffectiveDate
				,tmp.Terminationdate
				,ChangeType
				,@AddedByID
				,@AddedByID
				,CustomerXProductCatalogID
				,CASE 
					WHEN (
							AO.AddOnType = 'PASS'
							OR ISNULL(AO.IsInternational, 0) = 1
							)
						THEN ISNULL(CountryIDs, '1')
					ELSE CountryIDs
					END
				,CallForwardNumber
			FROM @AddonInsertTable tmp
			LEFT JOIN Addons AO(NOLOCK) ON tmp.CategoryPlanID = AO.AddonID
			WHERE ChangeType = 'E'

			--AND ISNULL(USOC,'') NOT IN ( 'MNSWWAN') -- NS: Removing MNS USOC FROM EXISTING PLAN
			INSERT INTO MobilityOrderXCategoryPlanChanges (
				MobilityOrderID
				,MobilityOrderItemID
				,ProductCatalogCategoryMasterID
				,CategoryPlanID
				,AttributeID
				,EffectiveDate
				,Terminationdate
				,ChangeType
				,AddedByID
				,ChangedByID
				,CustomerXProductCatalogID
				,CountryIDs
				,CallForwardNumber
				)
			SELECT @MobilityOrderID
				,@MobilityOrderItemID
				,7
				,CategoryPlanID
				,AttributeID
				,tmp.EffectiveDate
				,tmp.Terminationdate
				,ChangeType
				,@AddedByID
				,@AddedByID
				,CustomerXProductCatalogID
				,CASE 
					WHEN AO.AddOnType = 'PASS'
						OR ISNULL(AO.IsInternational, 0) = 1
						THEN ISNULL(CountryIDs, '1')
					ELSE CountryIDs
					END
				,CallForwardNumber
			FROM @AddonInsertTable tmp
			LEFT JOIN Addons AO(NOLOCK) ON tmp.CategoryPlanID = AO.AddonID
			WHERE ChangeType <> 'E'

			---------------------End----------------   
			--END Addons                    
			-- NS: 2022-11-14 -- Linestatus check 
			IF (ISNULL(@LineStatusMasterID, 0) <> 1)
			BEGIN
				---- UPDATE MobilityOrders with Stage/CarrierAccount/Requestor Information ------      
				UPDATE MobilityOrders
				SET OrderStageID = CASE 
						WHEN ipath.dbo.[GetHasApprovalWorkflow](@RequestorID, @OrderTypeID) = 1
							THEN 8001
						ELSE 2001
						END --- (NEW)                             
				WHERE MobilityOrderID = @MobilityOrderID
			END

			IF (
					ISNULL(@ServiceID, 0) = 64
					AND @IsRetail = 0
					) -- for WWAN Orders 
			BEGIN
				EXEC [MobilityOrderWWANUserUpdate] @MobilityOrderID = @MobilityOrderID
					,@AddedByID = @AddedByID
			END

			IF (ipath.dbo.[GetHasApprovalWorkflow](@RequestorID, @OrderTypeID) = 1)
			BEGIN
				--Add to email notification LOG --ANIL
				EXEC MobilityOrderItemsXUpdateNotificationtype @MobilityOrderID
					,NULL
					,10 --To set approval notification type     
			END
			ELSE
			BEGIN
				-- EXEC MobilityOrderItemsXUpdateNotificationtype @MobilityOrderID,@MobilityOrderItemID,@LineStatusMasterID
				EXEC MobileNotificationCriteria_InsertLog @MobilityOrderID = @MobilityOrderID
					,@MobilityOrderItemID = @MobilityOrderItemID
					,@AddedByID = @AddedByID
			END

			SET @XMLData = ''
			SET @XMLData = @ChargesXML

			IF (@XMLData <> '')
			BEGIN
				UPDATE MobilityOrderCharges
				SET IsActive = 0
				WHERE MobilityOrderItemID = @MobilityOrderItemID
					AND ProductCatalogCategoryMasterID <> 5

				UPDATE MobilityOrderChargeChanges
				SET IsActive = 0
				WHERE MobilityOrderItemID = @MobilityOrderItemID
					AND ProductCatalogCategoryMasterID <> 5

				DELETE
				FROM @MainCharges

				DELETE
				FROM @Charges

				DELETE
				FROM @Charges1

				EXEC sp_xml_preparedocument @XMLHandle OUTPUT
					,@XMLData

				INSERT INTO @Charges
				SELECT 0
					,0
					,CustomerXProductCatalogID
					,CategoryPlanID
					,ProductCatalogCategoryMasterID
					,ChargeType
					,USOC
					,ChargeDescription
					,1
					,Cost
					,Margin
					,Price
					,'N' --,StartDate  ,EndDate                                       
				FROM OPENXML(@XMLHandle, '/ROOT/row', 2) WITH (
						CustomerXProductCatalogID INT '@CustomerXProductCatalogID'
						,CategoryPlanID INT '@CategoryPlanID'
						,ProductCatalogCategoryMasterID INT '@ProductCatalogCategoryMasterID'
						,ChargeType VARCHAR(50) '@ChargeType'
						,USOC VARCHAR(50) '@USOC'
						,ChargeDescription VARCHAR(250) '@ChargeDescription'
						,Cost DECIMAL(18, 2) '@Cost'
						,Margin DECIMAL(18, 2) '@Margin'
						,Price DECIMAL(18, 2) '@Price'
						)

				EXEC sp_xml_removedocument @XMLHandle

				INSERT INTO @Charges1
				SELECT 0
					,0
					,CustomerXProductCatalogID
					,CategoryPlanID
					,ProductCatalogCategoryMasterID
					,ChargeType
					,USOC
					,ChargeDescription
					,Quantity
					,Cost
					,Margin
					,Price
					,'E' AS ChangeType
				FROM InventoryCharges IC (NOLOCK)
				WHERE InventoryServiceID = @InventoryServiceID
					AND ProductCatalogCategoryMasterID IN (
						1
						,7
						)
					AND ChargeType IN (
						'Monthly'
						,'One Time'
						)
					AND [Status] = 'A'
					AND (
						TerminationDate IS NULL
						OR TerminationDate >= GETDATE()
						)

				--Update ChangeType For Primary Plan       
				IF (cast(@OrderPlans AS VARCHAR) <> '')
				BEGIN
					UPDATE cc
					SET cc.ChangeType = CASE 
							WHEN tt.CategoryPlanId IS NULL
								THEN 'N'
							ELSE 'E'
							END
					FROM @Charges cc
					LEFT JOIN (
						SELECT *
						FROM @Charges1
						WHERE ProductCatalogCategoryMasterID = 1
						) tt ON tt.CategoryPlanId = cc.CategoryPlanId
					WHERE cc.ProductCatalogCategoryMasterID = 1

					UPDATE cc
					SET cc.ChangeType = CASE 
							WHEN tt.CategoryPlanId IS NULL
								THEN 'R'
							ELSE 'E'
							END
					FROM @Charges1 cc
					LEFT JOIN (
						SELECT *
						FROM @Charges
						WHERE ProductCatalogCategoryMasterID = 1
						) tt ON tt.CategoryPlanId = cc.CategoryPlanId
					WHERE cc.ProductCatalogCategoryMasterID = 1

					-- NS: IM-1007 
					-- added Remove plan if the existing plan is same plan 
					UPDATE cc
					SET cc.ChangeType = 'R'
					FROM @Charges cc
					LEFT JOIN (
						SELECT *
						FROM @Charges1
						WHERE ProductCatalogCategoryMasterID = 1
						) tt ON tt.CategoryPlanId = cc.CategoryPlanId
					WHERE cc.ProductCatalogCategoryMasterID = 1
						AND tt.CategoryPlanId = cc.CategoryPlanId

					--SELECT * FROM @Charges where ProductCatalogCategoryMasterID =1                                  
					-- UNION                                  
					-- SELECT * FROM @Charges1  where ProductCatalogCategoryMasterID =1      
					DELETE
					FROM @Charges
					WHERE ChangeType = 'E'
						AND ProductCatalogCategoryMasterID = 1

					INSERT INTO @MainCharges
					SELECT *
					FROM @Charges
					WHERE ProductCatalogCategoryMasterID = 1
					
					UNION
					
					SELECT *
					FROM @Charges1
					WHERE ProductCatalogCategoryMasterID = 1

					-- SELECT * FROM @MainCharges
					------ INSERT EXISTING CHARGES ---------------                                      
					INSERT INTO MobilityOrderCharges (
						MobilityOrderID
						,MobilityOrderItemID
						,CustomerXProductCatalogID
						,CategoryPlanID
						,ProductCatalogCategoryMasterID
						,ChargeType
						,USOC
						,ChargeDescription
						,Quantity
						,Cost
						,Margin
						,Price
						,TimesToBill
						,IsActive
						,AddedByID
						,ChangedByID
						)
					SELECT @MobilityOrderID
						,@MobilityOrderItemID
						,CustomerXProductCatalogID
						,CategoryPlanID
						,ProductCatalogCategoryMasterID
						,ChargeType
						,USOC
						,ChargeDescription
						,Quantity
						,Cost
						,Margin
						,Price
						,999
						,1
						,@AddedByID
						,@AddedByID
					FROM @MainCharges
					WHERE ChangeType = 'E'
						AND ProductCatalogCategoryMasterID = 1

					-----------INSERT NEW AND REMOVED CHARGESS -------------------------                                      
					INSERT INTO MobilityOrderChargeChanges (
						MobilityOrderChargeID
						,MobilityOrderID
						,MobilityOrderItemID
						,CustomerXProductCatalogID
						,CategoryPlanID
						,ProductCatalogCategoryMasterID
						,ChargeType
						,USOC
						,ChargeDescription
						,Quantity
						,Cost
						,Margin
						,Price
						,ChangeType
						,TimesToBill
						,IsActive
						,AddedByID
						,ChangedByID
						)
					SELECT MobilityOrderChargeID
						,@MobilityOrderID
						,@MobilityOrderItemID
						,m.CustomerXProductCatalogID
						,CategoryPlanID
						,ProductCatalogCategoryMasterID
						,ChargeType
						,m.USOC
						,ChargeDescription
						,Quantity
						,Cost
						,Margin
						,Price
						,ChangeType
						,(
							CASE 
								WHEN ChargeType = 'Monthly'
									THEN 999
								ELSE 1
								END
							)
						,1
						,@AddedByID
						,@AddedByID
					FROM @MainCharges m
					LEFT JOIN @TBLADDONS t ON t.AddonID = m.CategoryPlanID
					WHERE ChangeType IN (
							'N'
							,'R'
							)
						AND ProductCatalogCategoryMasterID = 1
				END

				INSERT INTO MobilityOrderCharges (
					MobilityOrderID
					,MobilityOrderItemID
					,CustomerXProductCatalogID
					,CategoryPlanID
					,ProductCatalogCategoryMasterID
					,ChargeType
					,USOC
					,ChargeDescription
					,Quantity
					,Cost
					,Margin
					,Price
					,TimesToBill
					,IsActive
					,AddedByID
					,ChangedByID
					)
				SELECT @MobilityOrderID
					,@MobilityOrderItemID
					,ic.CustomerXProductCatalogID
					,a.CategoryPlanID
					,7
					,ic.ChargeType
					,ic.USOC
					,ic.ChargeDescription
					,ic.Quantity
					,ic.Cost
					,ic.Margin
					,ic.Price
					,(
						CASE 
							WHEN ic.ChargeType = 'Monthly'
								THEN 999
							ELSE 1
							END
						)
					,1
					,@AddedByID
					,@AddedByID
				FROM @AddonInsertTable a
				LEFT JOIN @Charges c ON a.CategoryPlanID = c.CategoryPlanID
					AND c.ProductCatalogCategoryMasterID = 7
				LEFT JOIN inventorycharges ic (NOLOCK) ON a.CategoryPlanID = ic.CategoryPlanID
					AND inventoryserviceID = @InventoryServiceID
					AND ic.ProductCatalogCategoryMasterID IN (7)
					AND STATUS = 'A'
				WHERE a.changetype = 'E'
					AND (
						ic.TerminationDate IS NULL
						OR ic.TerminationDate >= GETDATE()
						)

				-- AND ISNULL(A.USOC,'') NOT IN ( 'MNSWWAN') -- NS: Removing MNS USOC FROM EXISTING CHARGE
				INSERT INTO MobilityOrderChargeChanges (
					MobilityOrderChargeID
					,MobilityOrderID
					,MobilityOrderItemID
					,CustomerXProductCatalogID
					,CategoryPlanID
					,ProductCatalogCategoryMasterID
					,ChargeType
					,USOC
					,ChargeDescription
					,Quantity
					,Cost
					,Margin
					,Price
					,ChangeType
					,TimesToBill
					,IsActive
					,AddedByID
					,ChangedByID
					)
				SELECT 0
					,@MobilityOrderID
					,@MobilityOrderItemID
					,c.CustomerXProductCatalogID
					,a.CategoryPlanID
					,7
					,c.ChargeType
					,c.USOC
					,CASE 
						WHEN a.changetype = 'R'
							THEN ic.ChargeDescription
						ELSE c.ChargeDescription
						END
					,c.Quantity
					,c.Cost
					,c.Margin
					,c.Price
					,a.changetype
					,(
						CASE 
							WHEN ic.ChargeType = 'Monthly'
								THEN 999
							ELSE 1
							END
						)
					,1
					,@AddedByID
					,@AddedByID
				FROM @AddonInsertTable a
				LEFT JOIN @Charges c ON a.CategoryPlanID = c.CategoryPlanID
					AND c.ProductCatalogCategoryMasterID = 7
				LEFT JOIN inventorycharges ic (NOLOCK) ON a.CategoryPlanID = ic.CategoryPlanID
					AND inventoryserviceID = @InventoryServiceID
					AND ic.ProductCatalogCategoryMasterID IN (7)
					AND STATUS = 'A'
				WHERE a.changetype IN (
						'R'
						,'N'
						)
					AND (
						ic.TerminationDate IS NULL
						OR ic.TerminationDate >= GETDATE()
						)
			END

			/** IF THE CHANNEL IS QS THEN GET THE ACTIVATION DATE FROM THE FUNCTION **/
			SELECT @ChannelMasterID = ChannelMasterID
			FROM CustomerXCarrierAccounts(NOLOCK)
			WHERE CustomerXCarrierAccountsID = @CustomerXCarrierAccountsID

			/** THE BELOW CODE FOR CHANGE IN ACTIVATION DATE IS IMPLEMENTED FOR CHANGE PLAN ORDERS AS PER SD CASE 6741 **/
			IF @ChannelMasterID = 1
				AND @OrderTypeID = 2
			BEGIN
				DECLARE @oldPlanQuota INT
					,@newPlanQuote INT

				SELECT @newPlanQuote = (
						CASE 
							WHEN psp.IsDataUnlimited = 1
								THEN 100000
							ELSE psp.NoOfIncludedMBs
							END
						)
				FROM MobilityOrderXCategoryPlanChanges cp(NOLOCK)
				JOIN PrimaryServicePlans psp(NOLOCK) ON psp.PrimaryServicePlanID = cp.CategoryPlanID
				WHERE MobilityOrderItemID = @MobilityOrderItemID
					AND cp.ProductCatalogCategoryMasterID = 1
					AND cp.ChangeType = 'N'

				/** Only if the plan exists update the activation date */
				IF @newPlanQuote IS NOT NULL
				BEGIN
					SELECT @oldPlanQuota = (
							CASE 
								WHEN psp.IsDataUnlimited = 1
									THEN 100000
								ELSE psp.NoOfIncludedMBs
								END
							)
					FROM MobilityOrderXCategoryPlanChanges cp(NOLOCK)
					JOIN PrimaryServicePlans psp(NOLOCK) ON psp.PrimaryServicePlanID = cp.CategoryPlanID
					WHERE MobilityOrderItemID = @MobilityOrderItemID
						AND cp.ProductCatalogCategoryMasterID = 1
						AND cp.ChangeType = 'R'

					SELECT @ActivationDate = StartDate
					FROM dbo.uspGetActivationTerminationDatesByDataQuotaOrPlan(@oldPlanQuota, @newPlanQuote, 'quota')

					IF @ActivationDate < @existingActivationDate
					BEGIN
						SET @ActivationDate = @existingActivationDate
					END

					UPDATE MobilityOrderItems
					SET ActivationDate = @ActivationDate
					WHERE MobilityOrderItemID = @MobilityOrderItemID
				END
			END

			--END Plans AND Addons Insertion   
			/* -- Commented out -- DESK-19663- 49294 - MNS Add On/Feature Charges 
    --NS: 20210423 - Add additional Customer based addons
    IF NOT EXISTS (SELECT TOP 1 * FROM  @AddonInsertTable                                          
		WHERE ChangeType = 'R'  AND USOC = 'MNSWWAN')
		BEGIN
		--print 'rr'
		-- NS: MNS CHARGES TO ADD CHANGE CHARGE WHEN WE HAVE THIS 'MNSWWAN' EXISTING RECORD.
			IF NOT EXISTS (SELECT TOP 1 * FROM  @AddonInsertTable                                          
			WHERE ChangeType = 'E'  AND USOC = 'MNSWWAN')
			BEGIN
				IF(ISNULL(@ServiceID,0) = 64) -- for WWAN Orders  
				BEGIN  
				--	print 'ee'
					EXEC MobilityOrder_ChangeOrderItemMNSExhibit  @CustomerID=@CustomerID,@MobilityOrderID = @MobilityOrderID, 
										@MobilityOrderItemID = @MobilityOrderItemID , @AddedByID=@AddedByID  		   
				END  
			END				 
		END
		*/
			-- Capture booking information : Sridhar: Dt: 03/03/2020      
			EXEC uspManageBookingAgainstOrderItem @MobilityOrderItemID
				,@LineStatusMasterID

			-- Dynamic order description update        
			IF ISNULL(@MobilityOrderID, 0) > 0
			BEGIN
				EXEC OrderDescriptionInsertorUpdate @MobilityOrderID
			END

			FETCH NEXT
			FROM curOrderItemCreation
			INTO @InventoryServiceID
				,@CustomerID
				,@CarrierID
				,@ServiceID
				,@AccountID
				,@LineStatusMasterID
		END

		CLOSE curOrderItemCreation

		DEALLOCATE curOrderItemCreation

		--End Order Creation Cursor         
		-- NS: ADDED TO RESET ALL PLAN INFORMATION FOR THE BULK ORDER
		EXEC MobilityOrder_BulkPlanDataReset @MobilityOrderID

		COMMIT TRANSACTION
	END TRY

	BEGIN CATCH
		IF @@TRANCOUNT > 0
		BEGIN
			ROLLBACK TRANSACTION

			SET @MobilityOrderID = 0
		END

		DECLARE @eMessage VARCHAR(800)
			,@eProcedure VARCHAR(800)
			,@eLine VARCHAR(800)

		SELECT @eMessage = ''
			,@eProcedure = ''
			,@eLine = ''

		SELECT @eMessage = ERROR_MESSAGE()
			,@eProcedure = ERROR_PROCEDURE()
			,@eLine = ERROR_LINE()

		DECLARE @params VARCHAR(MAX) = 'OrderPlans : ' + CAST(@OrderPlans AS VARCHAR) + ' , OrderAttributes : ' + CAST(@OrderAttributes AS VARCHAR)  + ' , ChargesXML: ' + CAST(@ChargesXML AS VARCHAR) + ' , InventoryServiceIDs : ' + CAST(@InventoryServiceIDs AS VARCHAR)
		EXEC dbo.uspSendDBErrorEmail @Subject = 'MobilityOrders_InsertBulkChangeOrder'
			,@ErrorMessage = @eMessage
			,@ErrorProcedure = @eProcedure
			,@ErrorLine = @eLine
			,@QueryParams = @params
			,@UserID = 0
	END CATCH

	SELECT @MobilityOrderID AS MobilityOrderID
END
