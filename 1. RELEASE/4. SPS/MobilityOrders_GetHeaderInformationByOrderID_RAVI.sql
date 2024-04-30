USE mobility 
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================                                  
-- Author:  SRIKANTH                                  
-- ALTER date: <ALTER Date,,>                                  
-- Description: <Description,,>                                  
-- =============================================          
-- Author:  NAGASAI MUDARA              
-- ALTER DATE: 2022-08-25        
-- Description: Order Requestor on Completed Order - Inactive Users      
-- CASE - 2513      
-- ==================================================        
-- Author:  Nagasai Mudara        
-- Modified date: 02.09.2023      
-- Description: Add Address 3 Field to Shipping Addresses      
-- SD CASE - 5743      
-- =================================================       
-- Author:  Nagasai                  
-- ALTER date: 02-20-2023             
-- Description: Remove "Provisioner" field from QMobile and       
-- utilize "Order Manager" Field to assign QS orders to QS MOM's      
-- SD Case - 4521      
-- =============================================        
-- Author:  AkhilM                  
-- ALTER date: 05-17-2023             
-- Description: Added NULL check near Requestor ID to avoid the error for older orders       
-- =============================================      
-- Author:  Ravi Teja Yella
-- ALTER date: 03/28/2024   
-- Description: Added Inventory Management Requestor
-- Case# 11432 - QS Managed Inventory - Phase 2
-- =============================================  
-- EXEC MobilityOrders_GetHeaderInformationByOrderID 101448                              
ALTER PROCEDURE [dbo].[MobilityOrders_GetHeaderInformationByOrderID] --15192                                 
	@MobilityOrderID INT
AS
BEGIN
	SELECT C.customer_name AS CustomerName
		,CASE 
			WHEN MCM.Channel = 'Retail'
				THEN Coalesce(LI.location_name, a.account_name)
			ELSE a.account_name
			END AS AssociatedAccount
		,car.CarrierUsageName AS CarrierName
		,CASE 
			WHEN isnull(CA.AccountName, '') = ''
				THEN CA.AccountFAN + ' - ' + CA.AccountBAN
			ELSE CA.AccountName
			END AS CarrierAccountName
		,CA.AccountNumber AS CarrierAccountNumber
		,CA.AccountFAN
		,CA.AccountBAN
		,MO.OrderReferenceNumber
		,MO.OrderDescription
		,OTypM.OrderTypeDesc
		,dbo.GetOrderSubType(@MobilityOrderID) OrderSubTypeDesc
		,MO.OrderOwnerID
		,ISNULL(u_OrderOwner.user_name, '') AS OrderOwner
		,
		--MO.ProvisionerID,   ISNULL(u_Provisioner.user_name,'') AS Provisioner,       
		--0 ProvisionerID,  ''  AS Provisioner,        
		MO.ProjectManagerID
		,ISNULL(u_projectManager.user_name, '') AS ProjectManager
		,MO.OrderOpenedDateTime
		,ISNULL(u_SR.user_name, '') AS 'SR'
		,ISNULL(u_MBDM.user_name, '') AS 'MBDM'
		,ISNULL(u_MAL.user_name, '') AS 'MAL'
		-- ,OSM.OrderStageDesc      
		,CASE 
			WHEN MAW.ID IS NOT NULL
				AND MAW.StatusID IN (
					0
					,1
					)
				THEN MAW.STATUS
			ELSE OSM.OrderStage
			END AS OrderStageDesc
		,OStM.OrderStatusDesc
		,(
			CASE 
				WHEN OSM.OrderStage = 'Complete'
					THEN 'Closed'
				WHEN OSM.OrderStage = 'Cancelled'
					THEN 'Cancelled'
				ELSE 'Open'
				END
			) AS VmanagerOrderStatus
		,(
			a.billing_address_1 + (
				CASE 
					WHEN a.billing_address_2 IS NOT NULL
						AND a.billing_address_2 <> ''
						THEN ', ' + a.billing_address_2
					ELSE ''
					END
				) + ', ' + (
				CASE 
					WHEN a.billing_address_3 IS NOT NULL
						AND a.billing_address_3 <> ''
						THEN ', ' + a.billing_address_3
					ELSE ''
					END
				) + ', ' + a.billing_city + ', ' + a.billing_state + ', ' + a.billing_zip + ', ' + a.billing_country
			) AS CustomerAddress
		,ISNULL(u_OpenedBy.user_name, '') AS OpenedBy
		,MO.OrderDueDateTime
		,MO.OrderClosedDateTime
		,MO.OrderCarrierSubmittionDateTime
		,MO.SLA
		,C.customer_id AS CustomerID
		,CustomerAddressID
		,AttentionToName
		,Address1 ShippingAddress1
		,Address2 ShippingAddress2
		,Address3 ShippingAddress3
		,SHIP.City ShippingCity
		,ZipCode ShippingZipCode
		,StateMasterID ShippingStateMasterID
		,CountryMasterID ShippingCountryMasterID
		,StateName ShippingStateName
		,CountryName ShippingCountryName
		,ShippingTypeID
		,TrackingNumber
		,ShippingType
		,TicketReferenceNumber
		,ShipDate
		,ShippingVendor
		,MO.AccountID
		,CASE 
			WHEN MCM.Channel = 'Retail'
				THEN 1
			ELSE 0
			END AS IsRetail
		,ISNULL(a.ccds_customer_number, 0) AS CCDSCustomerNumber
		,-- ADDED BY Srikanth on 08/12/19                      
		MCM.Channel
		,-- ADDED BY Srikanth on 08/12/19                              
		u_MBDM.user_email AS 'MBDMEmail'
		,ISNULL(u_MAL.user_email, '') AS 'MALEmail'
		,ISNULL(u_OrderOwner.user_email, '') AS 'OrderOwnerEmail'
		,MO.NextSteps
		,MO.RequestorID
		,CASE 
			WHEN MO.RequestorID > 0
				OR MO.RequestorID IS NULL --Modified by AkhilM on 05-17-2023 to avoid error for older orders      
				THEN ISNULL(u_Requestor.user_name, '')
			WHEN MO.RequestorID = - 1
				THEN 'Internal User'
			WHEN MO.RequestorID = - 2
				THEN 'Variance'
			WHEN MO.RequestorID = - 3
				THEN 'Pooling Management'
			WHEN MO.RequestorID = - 4
				THEN 'Optimization'
			WHEN MO.RequestorID = - 5
				THEN 'Inventory Management'
			END AS Requestor
		,u_Requestor.user_email AS RequestorEmail
		,MO.OrderOpenedByID
		,u_OpenedBy.user_email AS OpenedByEmail
		,u_OrderOwner.user_email AS OrderOwnerEmail
		,
		--u_Provisioner.user_email as ProvisionerEmail,                           
		u_projectManager.user_email AS ProjectManagerEmail
		,CA.CarrierAccountID
		,CA.CustomerXCarrierAccountsID
		,iPath.[dbo].[ApproversForOrder](MO.MobilityOrderID) AS Approvers
		,tax_id AS CustomerTaxID
		,AddressRelType
		,AddressAccountID
		,UserFirstName
		,UserLastName
		,UserTitle
		,UserEmail
		,CopyEndUser
		,OTypM.OrderCategory
		,MO.OrderStageID
		,CASE 
			WHEN MO.OrderStageID = 6001
				THEN MO.ChangedDateTime
			WHEN MO.OrderStageID = 7001
				THEN MO.OrderClosedDateTime
			ELSE NULL
			END AS OrderStageDate
		,CAST(1 AS BIT) ShowBulkUpdate
		,-- NS: TO HIDE/UNHIDE bulk line update 1 - true/show 0 -false/hide,      
		dbo.MobilityOrder_HasEquipmentShipped(MO.MobilityOrderID) AS HasEquipmentShipped
		,-- 1/0 -- NS: 1 atleast one item has ES      
		ISNULL(CC.CanCancel, 0) AS CanCancel
		,CA.ChannelMasterID
		,CM.ChannelDisplayName ChannelName
	FROM MobilityOrders MO(NOLOCK)
	INNER JOIN MobilityCarrierMaster MCM ON MCM.CarrierID = MO.CarrierID
	INNER JOIN customer C(NOLOCK) ON C.customer_id = MO.CustomerID
	INNER JOIN account a(NOLOCK) ON a.account_id = MO.AccountID
	INNER JOIN MobilityCarrierMaster car ON car.CarrierID = MO.CarrierID
	LEFT JOIN CustomerXCarrierAccounts CA(NOLOCK) ON CA.CarrierAccountID = MO.CarrierAccountID
		AND CA.CustomerID = MO.CustomerID
		AND CA.CustomerXCarrierAccountsID = MO.CustomerXCarrierAccountsID
	LEFT JOIN ChannelMaster CM(NOLOCK) ON CM.ChannelMasterID = CA.ChannelMasterID
	INNER JOIN OrderTypeMaster OTypM(NOLOCK) ON OTypM.OrderTypeMasterID = MO.OrderTypeID
	--LEFT JOIN OrderSubTypeMaster OSTypM ON OSTypM.OrderSubTypeMasterID = MO.OrderSubTypeMasterID                          
	LEFT JOIN [OrderStageMaster] OSM ON OSM.OrderStageMasterID = MO.OrderStageID
	LEFT JOIN [OrderStatusMaster] OStM ON OStM.OrderStatusMasterID = OSM.OrderStatusID
	LEFT JOIN users u_SR(NOLOCK) ON c.SR_user_id = u_SR.user_id
	LEFT JOIN users u_MAL(NOLOCK) ON c.MAL_user_id = u_MAL.user_id
	LEFT JOIN users u_MBDM(NOLOCK) ON c.MBDM_user_id = u_MBDM.user_id
	LEFT JOIN users u_OrderOwner(NOLOCK) ON MO.OrderOwnerID = u_OrderOwner.user_id
	LEFT JOIN users u_OpenedBy(NOLOCK) ON MO.OrderOpenedByID = u_OpenedBy.user_id
	--LEFT JOIN users u_Provisioner (nolock) ON MO.ProvisionerID = u_Provisioner.user_id                           
	LEFT JOIN users u_projectManager(NOLOCK) ON MO.ProjectManagerID = u_projectManager.user_id
	LEFT JOIN users u_Requestor(NOLOCK) ON MO.RequestorID = u_Requestor.user_id
	LEFT JOIN (
		SELECT DISTINCT MOI.TrackingNumber
			,MOI.MobilityOrderID
			,CUSTA.CustomerAddressID
			,Coalesce(MOI.AttentionToName, isnull(CUSTA.AttentionToName, '')) AttentionToName
			,CUSTA.Address1
			,CUSTA.Address2
			,CUSTA.City
			,CUSTA.ZipCode
			,CUSTA.StateMasterID
			,CUSTA.CountryMasterID
			,CUSTA.StateName
			,CUSTA.CountryName
			,CUSTA.AddressRelType
			,CUSTA.AddressAccountID
			,MOI.ShippingTypeID
			,STM.ShippingType
			,MOI.ShipDate
			,MOI.ShippingVendor
			,MOI.UserFirstName
			,MOI.UserLastName
			,MOI.UserTitle
			,MOI.UserEmail
			,MOI.CopyEndUser
		FROM MobilityOrderItems MOI(NOLOCK)
		JOIN MobilityOrders MO(NOLOCK) ON MO.MobilityOrderID = MOI.MobilityOrderID
			AND MO.OrderTypeID = 3
			AND MOI.MobilityOrderID = @MobilityOrderID -- (Spare) AND MOI.MobilityOrderID                              
		LEFT JOIN (
			-- account address                                  
			SELECT CUSTA.CustomerAddressID
				,Coalesce(CUSTA.AttentionToName, isnull(AC.account_name, '')) AS AttentionToName
				,Coalesce(CUSTA.Address1, AC.address_1) AS Address1
				,Coalesce(CUSTA.Address2, AC.address_2) AS Address2
				,Coalesce(CUSTA.Address3, AC.address3) AS Address3
				,Coalesce(CUSTA.City, AC.city) AS City
				,Coalesce(CUSTA.ZipCode, AC.zip) AS ZipCode
				,Coalesce(CUSTA.StateMasterID, ASM.StateMasterID) AS StateMasterID
				,Coalesce(CUSTA.CountryMasterID, ASM.CountryMasterID) AS CountryMasterID
				,Coalesce(SM.StateName, AC.STATE) AS StateName
				,Coalesce(CM.CountryName, AC.country) AS CountryName
				,ISNULL(CUSTA.RelType, '') AddressRelType
				,CUSTA.AccountID AddressAccountID
			FROM CustomerAddress CUSTA(NOLOCK)
			INNER JOIN StateMaster SM ON SM.StateMasterID = CUSTA.StateMasterID
			INNER JOIN CountryMaster CM ON CM.CountryMasterID = CUSTA.CountryMasterID
			INNER JOIN ipath..Account AC(NOLOCK) ON AC.account_Id = CUSTA.AccountID
				AND CUSTA.RelType = 'a'
			INNER JOIN StateMaster ASM ON SM.StateName = AC.STATE
			INNER JOIN CountryMaster ACM ON CM.CountryName = AC.country
			
			UNION -- location address            
			
			SELECT CUSTA.CustomerAddressID
				,Coalesce(CUSTA.AttentionToName, isnull(AC.location_name, '')) AS AttentionToName
				,Coalesce(CUSTA.Address1, AC.address_1) AS Address1
				,Coalesce(CUSTA.Address2, AC.address_2) AS Address2
				,Coalesce(CUSTA.Address3, AC.address3) AS Address3
				,Coalesce(CUSTA.City, AC.city) AS City
				,Coalesce(CUSTA.ZipCode, AC.zip) AS ZipCode
				,Coalesce(CUSTA.StateMasterID, ASM.StateMasterID) AS StateMasterID
				,Coalesce(CUSTA.CountryMasterID, ASM.CountryMasterID) AS CountryMasterID
				,Coalesce(SM.StateName, AC.STATE) AS StateName
				,Coalesce(CM.CountryName, 'US') AS CountryName
				,ISNULL(CUSTA.RelType, '') AddressRelType
				,CUSTA.AccountID AddressAccountID
			FROM CustomerAddress CUSTA(NOLOCK)
			INNER JOIN StateMaster SM ON SM.StateMasterID = CUSTA.StateMasterID
			INNER JOIN CountryMaster CM ON CM.CountryMasterID = CUSTA.CountryMasterID
			INNER JOIN ipath..location AC ON AC.location_id = CUSTA.AccountID
				AND CUSTA.RelType = 'l'
			INNER JOIN StateMaster ASM ON SM.StateName = AC.STATE
			INNER JOIN CountryMaster ACM ON CM.CountryName = 'US'
			
			UNION -- other address            
			
			SELECT CUSTA.CustomerAddressID
				,CUSTA.AttentionToName AS AttentionToName
				,CUSTA.Address1 AS Address1
				,CUSTA.Address2 AS Address2
				,CUSTA.Address3 AS Address3
				,CUSTA.City AS City
				,CUSTA.ZipCode AS ZipCode
				,CUSTA.StateMasterID AS StateMasterID
				,CUSTA.CountryMasterID AS CountryMasterID
				,SM.StateName AS StateName
				,Coalesce(CM.CountryName, 'US') AS CountryName
				,ISNULL(CUSTA.RelType, '') AddressRelType
				,ISNULL(CUSTA.AccountID, 0) AddressAccountID
			FROM CustomerAddress CUSTA(NOLOCK)
			LEFT JOIN StateMaster SM ON SM.StateMasterID = CUSTA.StateMasterID
			LEFT JOIN CountryMaster CM ON CM.CountryMasterID = CUSTA.CountryMasterID
			LEFT JOIN CountryMaster ACM ON CM.CountryName = 'US'
			) CUSTA ON CUSTA.CustomerAddressID = MOI.CustomerShippingAddressID
			AND ISNULL(MOI.AddressRelType, '') = ISNULL(CUSTA.AddressRelType, '')
		LEFT JOIN ShippingTypeMaster STM ON STM.ShippingTypeMasterID = MOI.ShippingTypeID
		WHERE MOI.MobilityOrderID = @MobilityOrderID
		) SHIP ON SHIP.MobilityOrderID = MO.MobilityOrderID
	LEFT JOIN (
		SELECT MOI.MobilityOrderID
			,l.location_id
			,l.location_name
			,l.location_name_other
		FROM MobilityOrderItems MOI(NOLOCK)
		INNER JOIN ipath..Location l(NOLOCK) ON l.location_id = MOI.InventoryRelTypeID
		WHERE MOI.MobilityOrderID = @MobilityOrderID
			AND RelType = 'l'
		
		UNION
		
		SELECT MOI.MobilityOrderID
			,a.account_id
			,a.account_name
			,a.account_name_other
		FROM MobilityOrderItems MOI(NOLOCK)
		INNER JOIN ipath..account a(NOLOCK) ON a.account_id = MOI.InventoryRelTypeID
		WHERE MOI.MobilityOrderID = @MobilityOrderID
			AND RelType = 'a'
		) AS LI ON LI.MobilityOrderID = MO.MobilityOrderID
	LEFT JOIN (
		SELECT CASE 
				WHEN count(*) > 0
					THEN 1
				ELSE 0
				END CanCancel
			,MobilityOrderID
		FROM MobilityORderItems(NOLOCK)
		WHERE isactive = 1
			AND LineSTatusMasterID NOT IN (
				7001
				,5001
				,5051
				)
		GROUP BY MobilityOrderID
		) CC ON CC.MobilityOrderID = MO.MobilityOrderID
	LEFT JOIN ipath..MobilityOrderXApproverWorkflow MAW ON MAW.StatusID = 1
		AND MAW.isActive = 1
		AND MAW.MobilityOrderiD = MO.MobilityOrderID
	WHERE MO.MobilityOrderID = @MobilityOrderID
END
GO
