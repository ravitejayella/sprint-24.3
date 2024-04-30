USE mobility
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author: Srikanth/ Nagasai
-- ALTER date: <ALTER Date,,>
-- Description: <Description,,>
-- Modified by : Sridhar on 2020-Jan-19
-- Modified date : 2019-02-05
-- Modified by : Srikanth on 2020-Jan-20
-- Modified date : 2020-01-10
-- Modified by : Nagasai
-- Modified date : 2020-04-14
-- Modified by : Nagasai
-- Reason: Added line number to search filters
-- Modified date : 2020-08-09
-- =============================================
-- Author: Nagasai
-- Reason: ORDER STAGE AGE FIX
-- Modified date : 2021-03-31
-- =============================================
-- Author: Nagasai
-- Reason: RESTRICT VMANAGER ORDERS WHICH ARE IN DRAFT
-- Modified date : 2021-09-20
-- =============================================
-- Author: Kiranmai
-- Reason: Added IsActive =1 condition to the final select queries where we are joining Mobilityorderitems in case of linenumber is not null
--- DESK-19473: MDN 2172789951 stranded on order 48137
-- Modified date : 08-DEC-2021
-- =============================================
-- Author: SP
-- Reason: Enhancement to report the Order as Lost/Stolen if there is atleast one Lost/Stolen Device in the ORder SD CASE# 1262
-- Modified date : 07/06/22
-- =============================================
-- Author: NAGASAI MUDARA
-- ALTER DATE: 2022-08-25
-- Description: Order Requestor on Completed Order - Inactive Users
-- CASE - 2513
-- ==================================================
-- Author: Nagasai
-- ALTER date: 2022-11-17
-- Description: Update OrderSubType against Order
-- Add missing "Actions" for Add & Change order types
-- SD CASE - 2504
-- =============================================
-- Author: Nagasai
-- ALTER date: 02-20-2023
-- Description: Remove "Provisioner" field from QMobile and
-- utilize "Order Manager" Field to assign QS orders to QS MOM's
-- SD Case - 4521
-- =============================================
-- =============================================
-- Modified By: Geethika Yedla
-- Modified Date: 02-20-2023
-- Description: Order Grid View Sort Issues (Qmobile and vMobile)
-- SD CaseID#8726
-- =============================================
-- Modified By: AkhilM
-- Modified Date: 08-03-2023
-- Description: Made changes for the output data for the case 1077
-- =============================================
-- Modified By: AkhilM
-- Modified Date: 10-09-2023
-- Description: Made changes as per case 1017
-- =============================================
-- Modified By: AkhilM
-- Modified Date: 12-04-2023
-- Description: Made changes as per case 11540
-- =============================================
-- Modified By: Ravi Teja Yella
-- Modified Date: 03/07/2024
-- Description: Added filtering based on @MobilityOrderIDs before adding items to temporary tables on View Pending Cancellation, Include Completed & View Cancelled options
-- Case# 12552 : 3-5 minutes to return a search for a specific completed order. 
-- =============================================
-- Modified By: Ravi Teja Yella
-- Modified Date: 04/19/2024
-- Description: 1. Added filtering based on @LineNumber  before adding items to temporary tables on View Pending Cancellation, Include Completed & View Cancelled options
-- Description: 2. Adjusted logic to show open orders too when not specifying ClosedDates
-- Case# 13004: 1. QMobile Closed order search by Ref# not working  
-- Case# 13004: 2. When clicking on include completed, it is showing only completed orders
-- =============================================
-- EXEC [MobilityOrders_GetAllByCustomer] @MobilityOrderIDs = '15088', @CustomerID=0,@IncludeClosedOrders=1,@ViewOnlyCancelled=0 , @ChannelType=1
-- EXEC [MobilityOrders_GetAllByCustomer] @MobilityOrderIDs = '13157,12678,12426', @CustomerID=20,@IncludeClosedOrders=0,@ChannelType=1 @ViewOnlyCancelled=0 ,@ProvisionerID=231 , @OrderOwnerID=320, @ChannelType=1 ,@LineNumber='3175495443'
-- EXEC [MobilityOrders_GetAllByCustomer] @ViewPendingCancel = 1, @IncludeClosedOrders=0,@ChannelType=0, @ViewOnlyCancelled=0 ,@ProvisionerID=231 , @OrderOwnerID=320, @ChannelType=1 ,@LineNumber='3175495443'
-- EXEC [MobilityOrders_GetAllByCustomer] @UserID=1375, @CustomerID=20,@IncludeClosedOrders=0,@ChannelType=0, @ViewOnlyCancelled=0 ,@ProvisionerID=231 , @OrderOwnerID=320, @ChannelType=1 ,@LineNumber='3175495443'
-- EXEC [MobilityOrders_GetAllByCustomer] @UserID=273, @ViewPendingCancel = 0, @IncludeClosedOrders=0,@ChannelType=0, @ViewOnlyCancelled=1 ,@ProvisionerID=231 , @OrderOwnerID=320, @ChannelType=1 ,@LineNumber='6757668769'
-- EXEC [MobilityOrders_GetAllByCustomer] @MobilityOrderIDs=11575, @UserID=273,@LineNumber='5619908998', @ViewPendingCancel = 0, @IncludeClosedOrders=0,@ChannelType=0, @ViewOnlyCancelled=1 ,@ProvisionerID=231 , @OrderOwnerID=320, @ChannelType=1 ,
-- EXEC [MobilityOrders_GetAllByCustomer] @UserID=273,@LineNumber='6613310122', @ViewPendingCancel = 0, @IncludeClosedOrders=0,@ChannelType=0, @ViewOnlyCancelled=1 ,@ProvisionerID=231 , @OrderOwnerID=320, @ChannelType=1
-- EXEC [MobilityOrders_GetAllByCustomer] @CustomerID = 119188, @ChannelType = 1
ALTER PROCEDURE [dbo].[MobilityOrders_GetAllByCustomer] @CustomerID INT = NULL
	,@IncludeClosedOrders BIT = 0
	,@ViewOnlyCancelled BIT = 0
	,@ViewPendingCancel BIT = 0
	,@AccountFAN VARCHAR(150) = NULL
	,@AccountBAN VARCHAR(150) = NULL
	,@AccountID INT = NULL
	,@CarrierID INT = NULL
	,@OrderOwnerID INT = NULL
	--,@ProvisionerID INT = NULL
	,@LineNumber VARCHAR(50) = NULL
	,@TicketReferenceNumber VARCHAR(50) = NULL
	,@ChannelType BIT = 0
	,@MobilityOrderIDs VARCHAR(max) = NULL
	,@UserID INT = NULL
	,@ClosedFromDate DATETIME = NULL
	,@ClosedToDate DATETIME = NULL
	,@OpenFromDate DATETIME = NULL
	,@OpenToDate DATETIME = NULL
AS
BEGIN
	SET @CustomerID = CASE 
			WHEN @CustomerID = 0
				THEN NULL
			ELSE @CustomerID
			END

	/* DECLARE A TABLE VARIABLE to PUSH ALL THE ORDERS IN */
	DECLARE @OrdersTable TABLE (
		[OrderReferenceNumber] [nvarchar](50)
		,[MobilityOrderID] [int]
		,[OrderType] [varchar](100) NOT NULL
		,[OrderSubType] [varchar](100) NULL
		,[OrderAge] [varchar](100) NULL
		,[OrderStage] [varchar](100) NULL
		,
		-- [LineStatus] [varchar](100) NULL,
		[OrderOwner] [varchar](250)
		,[OrderOpenedDateTime] [datetime]
		,[OrderClosedDateTime] [datetime]
		,[OrderOpenedBy] [varchar](100)
		,[OrderDueDateTime] [datetime]
		,[LineNumber] [varchar](25)
		,[CarrierUsageName] [varchar](250)
		,[AccountName] [varchar](255)
		,[CustomerName] [varchar](255) NOT NULL
		,[OrderDescription] [varchar](500)
		,[AccountFAN] [varchar](150)
		,[AccountBAN] [varchar](150)
		,[CustomerID] [int]
		,[CarrierID] [int]
		,[CarrierAccountID] [int]
		,[AccountID] [int]
		,[OrderOpenedByID] [int]
		,[OrderStageID] [int]
		,[OrderOwnerID] [int]
		,[IsMigrated] [bit]
		,[IsRetail] [int]
		,[Qty] INT
		,NextSteps VARCHAR(max)
		--,ProvisionerID INT
		--,[Provisioner] [Varchar](250)
		,ProjectManagerID INT
		,[ProjectManager] [varchar](250)
		,[StageAge] [varchar](100) NULL
		,TicketReferenceNumber VARCHAR(250)
		,OrderTypeID INT
		,CurrentOwnerID INT
		,HasRead BIT
		,OrderCategory VARCHAR(150)
		,RequestorID INT
		,RequestedBy [Varchar](250)
		,PlatFormTool VARCHAR(150)
		,ChannelMasterID INT
		,ChannelName VARCHAR(250)
		)
	--, MRC decimal(19,2),
	-- NRC decimal(19,2)
	/*START -- Added by AkhilM as per case 11540*/
	DECLARE @OpenedDatesTbl TABLE (OpenedDate DATETIME)
	DECLARE @ClosedOrdersOnlyFromDateFlag BIT
		,@ClosedOrdersOnlyToDateFlag BIT

	IF @IncludeClosedOrders = 1
	BEGIN
		INSERT INTO @OpenedDatesTbl
		SELECT DISTINCT OrderOpenedDateTime AS OpenedDate
		FROM MobilityOrders(NOLOCK)
		WHERE ISNULL(OrderOpenedDateTime, '') <> ''
		
		UNION
		
		SELECT DISTINCT open_dt AS OpenedDate
		FROM LegacyMobileOrders(NOLOCK)
		WHERE ISNULL(open_dt, '') <> ''
	END
	ELSE
	BEGIN
		INSERT INTO @OpenedDatesTbl
		SELECT DISTINCT OrderOpenedDateTime AS OpenedDate
		FROM MobilityOrders(NOLOCK)
		WHERE ISNULL(OrderOpenedDateTime, '') <> ''
	END

	IF ISNULL(@OpenFromDate, '') = ''
	BEGIN
		SELECT TOP 1 @OpenFromDate = OpenedDate
		FROM @OpenedDatesTbl
		ORDER BY OpenedDate ASC
	END

	IF ISNULL(@OpenToDate, '') = ''
	BEGIN
		SELECT TOP 1 @OpenToDate = OpenedDate
		FROM @OpenedDatesTbl
		ORDER BY OpenedDate DESC
	END

	/*END -- Added by AkhilM as per case 11540*/
	IF @IncludeClosedOrders = 1
	BEGIN
		/*START -- Added by AkhilM as per case 11540*/
		DECLARE @ClosedDatesTbl TABLE (ClosedDate DATETIME)

		INSERT INTO @ClosedDatesTbl
		SELECT DISTINCT OrderClosedDateTime AS ClosedDate
		FROM MobilityOrders(NOLOCK)
		WHERE ISNULL(OrderClosedDateTime, '') <> ''
		
		UNION
		
		SELECT DISTINCT close_dt AS ClosedDate
		FROM LegacyMobileOrders(NOLOCK)
		WHERE ISNULL(close_dt, '') <> ''

		IF ISNULL(@ClosedFromDate, '') = ''
		BEGIN
			SET @ClosedOrdersOnlyFromDateFlag = 0

			SELECT TOP 1 @ClosedFromDate = ClosedDate
			FROM @ClosedDatesTbl
			ORDER BY ClosedDate ASC
		END
		ELSE
		BEGIN
			SET @ClosedOrdersOnlyFromDateFlag = 1
		END

		IF ISNULL(@ClosedToDate, '') = ''
		BEGIN
			SET @ClosedOrdersOnlyToDateFlag = 0

			SELECT TOP 1 @ClosedToDate = ClosedDate
			FROM @ClosedDatesTbl
			ORDER BY ClosedDate DESC
		END
		ELSE
		BEGIN
			SET @ClosedOrdersOnlyToDateFlag = 1
		END

		/*END -- Added by AkhilM as per case 11540*/
		/** INCLUDE ALL THE CLOSED ORDERS **/
		SELECT *
		INTO #tempClosedOrders
		FROM (
			SELECT DISTINCT MO.OrderReferenceNumber
				,MO.MobilityOrderID
				,
				-- OTM.OrderType, MODIFIED BY SP ON 07/06/22 CASE# 1262
				CASE 
					WHEN mo.OrderTypeID = 6
						THEN CASE 
								WHEN MIN(MOI.OrderSubTypeMasterID) OVER (PARTITION BY MOI.MobilityOrderItemID) = 9
									THEN OTM.OrderType + ' - ' + OSTM.OrderSubType
								ELSE OTM.OrderType
								END
					ELSE OTM.OrderType
					END AS OrderType
				,MO.OrderSubType
				,CASE 
					WHEN [dbo].[GetMobileBusinessDays](OrderOpenedDateTime, GETDATE()) <= 1 -- ModifiedBy AkhilM on 10/09/2023 as per case 1017
						THEN CAST([dbo].[GetMobileBusinessHours](OrderOpenedDateTime, GETDATE()) AS VARCHAR(50)) + ' hours' -- ModifiedBy AkhilM on 10/09/2023 as per case 1017
					ELSE CASE 
							WHEN MO.OrderClosedDateTime IS NULL
								AND MO.OrderStageID <> 6001
								THEN CAST([dbo].[GetMobileBusinessHours](OrderOpenedDateTime, GETDATE()) / 10 AS VARCHAR(50)) + ' days' -- ModifiedBy AkhilM on 10/09/2023 as per case 1017
							WHEN (
									MO.OrderStageID = 6001
									OR MO.OrderStageID = 7001
									)
								THEN CAST([dbo].[GetMobileBusinessHours](OrderOpenedDateTime, MOH.MOHAddedDateTime) / 10 AS VARCHAR(50)) + ' days' -- ModifiedBy AkhilM on 10/09/2023 as per case 1017
							ELSE CAST([dbo].[GetMobileBusinessHours](OrderOpenedDateTime, GETDATE()) / 10 AS VARCHAR(50)) + ' days' -- MOH.MOHAddedDateTime -- ModifiedBy AkhilM on 10/09/2023 as per case 1017
							END
					END AS OrderAge
				,OSM.OrderStage
				,U.user_name OrderOwner
				,MO.OrderOpenedDateTime
				,MO.OrderClosedDateTime
				,UO.user_name AS OrderOpenedBy
				,MO.OrderDueDateTime
				,'' AS LineNumber
				,MCM.CarrierUsageName
				,a.account_name AS AccountName
				,c.customer_name AS CustomerName
				,MO.OrderDescription
				,CA.AccountFAN
				,CA.AccountBAN
				,MO.CustomerID
				,MO.CarrierID
				,MO.CarrierAccountID
				,MO.AccountID
				,MO.OrderOpenedByID
				,MO.OrderStageID
				,MO.OrderOwnerID
				,cast(0 AS BIT) AS IsMigrated
				,
				--, MOI.LineNumber
				CASE 
					WHEN MCM.Channel = 'Retail'
						THEN 1
					ELSE 0
					END AS IsRetail
				,DT.Qty
				,MO.NextSteps
				--,MO.ProvisionerID
				--,ISNULL(u_Provisioner.user_name, '') AS Provisioner
				,MO.ProjectManagerID
				,ISNULL(u_projectManager.user_name, '') AS ProjectManager
				,CASE 
					WHEN [dbo].[GetMobileBusinessDays](MOH.MOHAddedDateTime, GETDATE()) <= 1 -- ModifiedBy AkhilM on 10/09/2023 as per case 1017
						THEN CAST([dbo].[GetMobileBusinessHours](MOH.MOHAddedDateTime, GETDATE()) AS VARCHAR(50)) + ' hours' -- ModifiedBy AkhilM on 10/09/2023 as per case 1017
					ELSE CASE 
							WHEN (
									MOH.MOHAddedDateTime IS NULL
									AND (
										MO.OrderStageID = 6001
										OR MO.OrderStageID = 7001
										)
									)
								THEN CAST([dbo].[GetMobileBusinessHours](OrderOpenedDateTime, MOH.MOHAddedDateTime) / 10 AS VARCHAR(50)) + ' days' -- ModifiedBy AkhilM on 10/09/2023 as per case 1017
							WHEN (
									MOH.MOHAddedDateTime IS NULL
									AND (
										MO.OrderStageID <> 6001
										OR MO.OrderStageID <> 7001
										)
									)
								THEN CAST([dbo].[GetMobileBusinessHours](MOH.MOHAddedDateTime, GETDATE()) / 10 AS VARCHAR(50)) + ' days' -- MOH.MOHAddedDateTime -- ModifiedBy AkhilM on 10/09/2023 as per case 1017
							ELSE CAST([dbo].[GetMobileBusinessHours](MOH.MOHAddedDateTime, GETDATE()) / 10 AS VARCHAR(50)) + ' days' -- MOH.MOHAddedDateTime -- ModifiedBy AkhilM on 10/09/2023 as per case 1017
							END
					END AS StageAge
				,MO.TicketReferenceNumber
				,MO.OrderTypeID
				,OUI.OwnerId
				,CASE 
					WHEN OUI.OwnerId IS NOT NULL
						THEN CAST(0 AS BIT)
					ELSE CAST(1 AS BIT)
					END AS HasRead
				,OTM.OrderCategory
				,
				-- ADDED BY SP ON 3/3/21
				MO.RequestorID
				,CASE 
					WHEN MO.RequestorID > 0
						THEN ISNULL(u_RequestedBy.user_name, '')
					WHEN MO.RequestorID = - 1
						THEN 'Internal User'
					WHEN MO.RequestorID = - 2
						THEN 'Variance'
					WHEN MO.RequestorID = - 3
						THEN 'Pooling Management'
					WHEN MO.RequestorID = - 4
						THEN 'Optimization'
					END AS RequestedBy
				,MO.PlatFormTool
				,CA.ChannelMasterID
				,CM.ChannelDisplayName ChannelName
			FROM MobilityOrders MO(NOLOCK)
			INNER JOIN MobilityOrderItems MOI(NOLOCK) ON MOI.MobilityOrderID = MO.MobilityOrderID
			INNER JOIN LineStatusMaster LSM ON LSM.LineStatusMasterID = MOI.LineStatusMasterID
			INNER JOIN MobilityCarrierMaster MCM ON MCM.CarrierID = MO.CarrierID
			INNER JOIN account a(NOLOCK) ON a.account_id = MO.accountID
			INNER JOIN customer c(NOLOCK) ON c.customer_id = MO.CustomerID
			LEFT JOIN CustomerXCarrierAccounts CA(NOLOCK) ON CA.CarrierAccountID = MO.CarrierAccountID
				AND CA.CustomerID = MO.CustomerID
				AND CA.CustomerXCarrierAccountsID = ISNULL(MO.CustomerXCarrierAccountsID, CA.CustomerXCarrierAccountsID)
			LEFT JOIN ChannelMaster CM(NOLOCK) ON CM.ChannelMasterID = CA.ChannelMasterID
			INNER JOIN OrderTypeMaster OTM ON OTM.OrderTypeMasterID = MO.OrderTypeID
			LEFT JOIN OrderSubTypeMaster OSTM ON OSTM.OrderSubTypeMasterID = MOI.OrderSubTypeMasterID
			INNER JOIN OrderStageMaster OSM ON OSM.OrderStageMasterID = MO.OrderStageID
			LEFT JOIN users U(NOLOCK) ON U.user_id = MO.OrderOwnerID
			INNER JOIN users UO(NOLOCK) ON UO.user_id = MO.OrderOpenedByID
			--LEFT JOIN users u_Provisioner(NOLOCK) ON MO.ProvisionerID = u_Provisioner.user_id
			LEFT JOIN users u_projectManager(NOLOCK) ON MO.ProjectManagerID = u_projectManager.user_id
			LEFT JOIN users u_RequestedBy(NOLOCK) ON MO.RequestorID = u_RequestedBy.user_id
			LEFT JOIN OrderUnreadItems OUI(NOLOCK) ON OUI.MobilityOrderID = MO.MobilityOrderID
				AND OUI.OwnerId = @UserID
			INNER JOIN (
				SELECT MOI.MobilityOrderID
					,COUNT(MOI.MobilityOrderItemID) AS Qty
				FROM MobilityOrders MO(NOLOCK)
				INNER JOIN MobilityOrderItems MOI(NOLOCK) ON MOI.MobilityOrderID = MO.MobilityOrderID
					AND MOI.IsActive = 1
				GROUP BY MOI.MobilityOrderID
				) DT ON DT.MobilityOrderID = MO.MobilityOrderID
			LEFT JOIN (
				SELECT MOH.MobilityOrderID
					,MAX(MOH.AddedDateTime) AS MOHAddedDateTime
				FROM MobilityOrderHistory MOH(NOLOCK)
				INNER JOIN MobilityOrders MO(NOLOCK) ON MO.MobilityOrderID = MOH.MobilityOrderID
					AND MO.OrderStageID = MOH.ChangeToID
				GROUP BY MOH.MobilityOrderID
				) MOH ON MOH.MobilityOrderID = MO.MobilityOrderID
			WHERE MOI.IsActive = 1
				AND MO.CustomerID = ISNULL(@CustomerID, MO.CustomerID)
				AND OrderStageID <> 6001
				AND CASE 
					WHEN @ClosedOrdersOnlyFromDateFlag = 1 -- ravi on 04/19/2024
						THEN CASE 
								WHEN MO.OrderClosedDateTime >= @ClosedFromDate
									AND MO.OrderClosedDateTime IS NOT NULL
									THEN 1
								ELSE 0
								END
					ELSE 1
					END = 1
				AND CASE 
					WHEN @ClosedOrdersOnlyToDateFlag = 1 -- ravi on 04/19/2024
						THEN CASE 
								WHEN MO.OrderClosedDateTime <= @ClosedToDate
									AND MO.OrderClosedDateTime IS NOT NULL
									THEN 1
								ELSE 0
								END
					ELSE 1
					END = 1
				AND MO.OrderOpenedDateTime >= @OpenFromDate
				AND MO.OrderOpenedDateTime <= @OpenToDate -- Added by AkhilM as per case 11540
				AND (
					ISNULL(@MobilityOrderIDs, '') = ''
					OR MO.MobilityOrderID IN (
						SELECT value
						FROM dbo.[SplitValue](@MobilityOrderIDs, ',')
						)
					) -- added by ravi on 03/07/2024
				AND ISNULL(MOI.LineNumber, '') = CASE 
					WHEN ISNULL(@LineNumber, '') = ''
						THEN ISNULL(MOI.LineNumber, '')
					ELSE @LineNumber
					END -- added by ravi on 04/19/2024
				--UNION
				--/*********************************** JOIN IPATH ORDERS IN THIS CASE ****************************/
				--SELECT DISTINCT OrderRefernceNumber
				--	,order_id
				--	,order_type_desc
				--	,order_sub_type
				--	,sage
				--	,order_stage_desc
				--	,OrderOwner
				--	,o.open_dt
				--	,o.close_dt
				--	,o.opened_by
				--	,o.order_due
				--	,'' lineNumber
				--	,carrier_usage_name
				--	,o.account_name
				--	,c.customer_name AS CustomerName
				--	,order_desc
				--	,accountFAN
				--	,accountBAN
				--	,o.customer_id
				--	,o.carrier_id
				--	,carrier_account_id
				--	,o.account_id
				--	,opened_by_id
				--	,order_stage_id
				--	,owner_user_id
				--	,IsMigrated
				--	,CAST(0 AS BIT) AS IsRetail
				--	,1 AS Qty
				--	,'' NextSteps
				--	--,0 ProvisionerID
				--	--,'' Provisioner
				--	,0 ProjectManagerID
				--	,'' ProjectManager
				--	,'' StageAge --, 0 MRC, 0 NRC
				--	,NULL TicketReferenceNumber
				--	,0
				--	,0
				--	,CAST(1 AS BIT) AS HasRead
				--	,o.order_type_desc OrderCategory -- ADDED BY SP ON 3/3/21
				--	,0
				--	,'' RequestedBy
				--	,'Legacy' PlatFormTool
				--	,0 ChannelMasterID
				--	,'' ChannelName
				--FROM LegacyMobileOrders o(NOLOCK)
				--LEFT JOIN account a(NOLOCK) ON o.account_id = a.account_id
				--LEFT JOIN customer c(NOLOCK) ON c.customer_id = a.customer_id
				--LEFT JOIN ipath..tot_summary tot(NOLOCK) ON tot.target_id = o.order_id
				--	AND tot.target_type = 'Order'
				--WHERE o.customer_id = ISNULL(@CustomerID, o.customer_id)
				--	AND isnull(o.lineNumber, '') LIKE '%' + isnull(@LineNumber, isnull(o.lineNumber, '')) + '%'
				--	AND o.close_dt >= @ClosedFromDate
				--	AND o.close_dt <= @ClosedToDate -- Added by AkhilM as per case 11540
				--	AND o.open_dt >= @OpenFromDate
				--	AND o.open_dt <= @OpenToDate -- Added by AkhilM as per case 11540
				--	AND (
				--		ISNULL(@MobilityOrderIDs, '') = ''
				--		OR order_id IN (
				--			SELECT value
				--			FROM dbo.[SplitValue](@MobilityOrderIDs, ',')
				--			)
				--		) -- added by ravi on 03/07/2024
				-- AND MOI.LineNumber = CASE WHEN ISNULL(@LineNumber, '') = '' THEN MOI.LineNumber ELSE @LineNumber END    -- added by ravi on 04/19/2024
			) AS TT
		ORDER BY 2 DESC

		INSERT INTO @OrdersTable
		SELECT *
		FROM #tempClosedOrders
		WHERE isnull(AccountFAN, '') = ISNULL(@AccountFAN, isnull(AccountFAN, ''))
			AND isnull(AccountBAN, '') = ISNULL(@AccountBAN, isnull(AccountBAN, ''))
			AND AccountID = ISNULL(@AccountID, AccountID)
			AND CarrierID = ISNULL(@CarrierID, CarrierID)
			AND ISNULL(OrderOwnerID, 0) = ISNULL(@OrderOwnerID, ISNULL(OrderOwnerID, 0))
			--AND ISNULL(ProvisionerID, 0) = ISNULL(@ProvisionerID, ISNULL(ProvisionerID, 0))
			AND isnull(TicketReferenceNumber, '') LIKE '%' + isnull(@TicketReferenceNumber, isnull(TicketReferenceNumber, '')) + '%'
		ORDER BY 2 DESC

		DROP TABLE #tempClosedOrders
	END
			/** VIEW ONLY CANCEllED ORDERS **/
	ELSE IF @ViewOnlyCancelled = 1
	BEGIN
		SELECT DISTINCT MO.OrderReferenceNumber
			,MO.MobilityOrderID
			,
			-- OTM.OrderType, MODIFIED BY SP ON 07/06/22 CASE# 1262
			CASE 
				WHEN mo.OrderTypeID = 6
					THEN CASE 
							WHEN MIN(MOI.OrderSubTypeMasterID) OVER (PARTITION BY MOI.MobilityOrderItemID) = 9
								THEN OTM.OrderType + ' - ' + OSTM.OrderSubType
							ELSE OTM.OrderType
							END
				ELSE OTM.OrderType
				END AS OrderType
			,MO.OrderSubType
			,CASE 
				WHEN [dbo].[GetMobileBusinessDays](OrderOpenedDateTime, GETDATE()) <= 1 -- ModifiedBy AkhilM on 10/09/2023 as per case 1017
					THEN CAST([dbo].[GetMobileBusinessHours](OrderOpenedDateTime, GETDATE()) AS VARCHAR(50)) + ' hours' -- ModifiedBy AkhilM on 10/09/2023 as per case 1017
				ELSE CASE 
						WHEN MO.OrderClosedDateTime IS NULL
							AND MO.OrderStageID <> 6001
							THEN CAST([dbo].[GetMobileBusinessHours](OrderOpenedDateTime, GETDATE()) / 10 AS VARCHAR(50)) + ' days' -- ModifiedBy AkhilM on 10/09/2023 as per case 1017
						WHEN (
								MO.OrderStageID = 6001
								OR MO.OrderStageID = 7001
								)
							THEN CAST([dbo].[GetMobileBusinessHours](OrderOpenedDateTime, MOH.MOHAddedDateTime) / 10 AS VARCHAR(50)) + ' days' -- ModifiedBy AkhilM on 10/09/2023 as per case 1017
						ELSE CAST([dbo].[GetMobileBusinessHours](OrderOpenedDateTime, GETDATE()) / 10 AS VARCHAR(50)) + ' days' -- MOH.MOHAddedDateTime -- ModifiedBy AkhilM on 10/09/2023 as per case 1017
						END
				END AS OrderAge
			,OSM.OrderStage
			,
			--LSM.LineStatus,
			U.user_name OrderOwner
			,MO.OrderOpenedDateTime
			,MO.OrderClosedDateTime
			,UO.user_name AS OrderOpenedBy
			,MO.OrderDueDateTime
			,'' AS LineNumber
			,MCM.CarrierUsageName
			,a.account_name AS AccountName
			,c.customer_name AS CustomerName
			,MO.OrderDescription
			,CA.AccountFAN
			,CA.AccountBAN
			,MO.CustomerID
			,MO.CarrierID
			,MO.CarrierAccountID
			,MO.AccountID
			,MO.OrderOpenedByID
			,MO.OrderStageID
			,MO.OrderOwnerID
			,cast(0 AS BIT) AS IsMigrated
			,CASE 
				WHEN MCM.Channel = 'Retail'
					THEN 1
				ELSE 0
				END AS IsRetail
			,DT.Qty
			,MO.NextSteps
			--,MO.ProvisionerID
			--,ISNULL(u_Provisioner.user_name, '') AS Provisioner
			,MO.ProjectManagerID
			,ISNULL(u_projectManager.user_name, '') AS ProjectManager
			,CASE 
				WHEN [dbo].[GetMobileBusinessDays](MOH.MOHAddedDateTime, GETDATE()) <= 1 -- ModifiedBy AkhilM on 10/09/2023 as per case 1017
					THEN CAST([dbo].[GetMobileBusinessHours](MOH.MOHAddedDateTime, GETDATE()) AS VARCHAR(50)) + ' hours' -- ModifiedBy AkhilM on 10/09/2023 as per case 1017
				ELSE CASE 
						WHEN (
								MOH.MOHAddedDateTime IS NULL
								AND (
									MO.OrderStageID = 6001
									OR MO.OrderStageID = 7001
									)
								)
							THEN CAST([dbo].[GetMobileBusinessHours](OrderOpenedDateTime, MOH.MOHAddedDateTime) / 10 AS VARCHAR(50)) + ' days' -- ModifiedBy AkhilM on 10/09/2023 as per case 1017
						WHEN (
								MOH.MOHAddedDateTime IS NULL
								AND (
									MO.OrderStageID <> 6001
									OR MO.OrderStageID <> 7001
									)
								)
							THEN CAST([dbo].[GetMobileBusinessHours](MOH.MOHAddedDateTime, GETDATE()) / 10 AS VARCHAR(50)) + ' days' -- MOH.MOHAddedDateTime -- ModifiedBy AkhilM on 10/09/2023 as per case 1017
						ELSE CAST([dbo].[GetMobileBusinessHours](MOH.MOHAddedDateTime, GETDATE()) / 10 AS VARCHAR(50)) + ' days' -- MOH.MOHAddedDateTime -- ModifiedBy AkhilM on 10/09/2023 as per case 1017
						END
				END AS StageAge
			,MO.TicketReferenceNumber
			,MO.OrderTypeID
			,OUI.OwnerId
			,CASE 
				WHEN OUI.OwnerId IS NOT NULL
					THEN CAST(0 AS BIT)
				ELSE CAST(1 AS BIT)
				END AS HasRead
			,OTM.OrderCategory
			,
			-- ADDED BY SP ON 3/3/21
			MO.RequestorID
			,CASE 
				WHEN MO.RequestorID > 0
					THEN ISNULL(u_RequestedBy.user_name, '')
				WHEN MO.RequestorID = - 1
					THEN 'Internal User'
				WHEN MO.RequestorID = - 2
					THEN 'Variance'
				WHEN MO.RequestorID = - 3
					THEN 'Pooling Management'
				WHEN MO.RequestorID = - 4
					THEN 'Optimization'
				END AS RequestedBy
			,MO.PlatFormTool
			,CA.ChannelMasterID
			,CM.ChannelDisplayName ChannelName
		INTO #tempCancelledOrders
		FROM MobilityOrders MO(NOLOCK)
		INNER JOIN MobilityOrderItems MOI(NOLOCK) ON MOI.MobilityOrderID = MO.MobilityOrderID
		INNER JOIN LineStatusMaster LSM ON LSM.LineStatusMasterID = MOI.LineStatusMasterID
		INNER JOIN MobilityCarrierMaster MCM ON MCM.CarrierID = MO.CarrierID
		INNER JOIN account a(NOLOCK) ON a.account_id = MO.accountID
		INNER JOIN customer c(NOLOCK) ON c.customer_id = MO.CustomerID
		LEFT JOIN CustomerXCarrierAccounts CA(NOLOCK) ON CA.CarrierAccountID = MO.CarrierAccountID
			AND CA.CustomerID = MO.CustomerID
			AND CA.CustomerXCarrierAccountsID = ISNULL(MO.CustomerXCarrierAccountsID, CA.CustomerXCarrierAccountsID)
		LEFT JOIN ChannelMaster CM(NOLOCK) ON CM.ChannelMasterID = CA.ChannelMasterID
		INNER JOIN OrderTypeMaster OTM ON OTM.OrderTypeMasterID = MO.OrderTypeID
		INNER JOIN OrderStageMaster OSM ON OSM.OrderStageMasterID = MO.OrderStageID
		LEFT JOIN OrderSubTypeMaster OSTM ON OSTM.OrderSubTypeMasterID = MOI.OrderSubTypeMasterID
		-- INNER JOIN OrderStageMaster OSM ON OSM.OrderStageMasterID = MO.OrderStageID
		LEFT JOIN users U(NOLOCK) ON U.user_id = MO.OrderOwnerID
		INNER JOIN users UO(NOLOCK) ON UO.user_id = MO.OrderOpenedByID
		--LEFT JOIN users u_Provisioner(NOLOCK) ON MO.ProvisionerID = u_Provisioner.user_id
		LEFT JOIN users u_projectManager(NOLOCK) ON MO.ProjectManagerID = u_projectManager.user_id
		LEFT JOIN users u_RequestedBy(NOLOCK) ON MO.RequestorID = u_RequestedBy.user_id
		LEFT JOIN OrderUnreadItems OUI(NOLOCK) ON OUI.MobilityOrderID = MO.MobilityOrderID
			AND OUI.OwnerId = @UserID
		INNER JOIN (
			SELECT MOI.MobilityOrderID
				,COUNT(MOI.MobilityOrderItemID) AS Qty
			FROM MobilityOrders MO(NOLOCK)
			INNER JOIN MobilityOrderItems MOI(NOLOCK) ON MOI.MobilityOrderID = MO.MobilityOrderID
				AND MOI.IsActive = 1
			GROUP BY MOI.MobilityOrderID
			) DT ON DT.MobilityOrderID = MO.MobilityOrderID
		LEFT JOIN (
			SELECT MOH.MobilityOrderID
				,MAX(MOH.AddedDateTime) AS MOHAddedDateTime
			FROM MobilityOrderHistory MOH(NOLOCK)
			INNER JOIN MobilityOrders MO(NOLOCK) ON MO.MobilityOrderID = MOH.MobilityOrderID
				AND MO.OrderStageID = MOH.ChangeToID
			GROUP BY MOH.MobilityOrderID
			) MOH ON MOH.MobilityOrderID = MO.MobilityOrderID
		WHERE MOI.IsActive = 1
			AND MO.CustomerID = ISNULL(@CustomerID, MO.CustomerID)
			AND MOI.LineStatusMasterID = 5001
			AND MO.OrderOpenedDateTime >= @OpenFromDate
			AND MO.OrderOpenedDateTime <= @OpenToDate
			AND (
				ISNULL(@MobilityOrderIDs, '') = ''
				OR MO.MobilityOrderID IN (
					SELECT value
					FROM dbo.[SplitValue](@MobilityOrderIDs, ',')
					)
				) -- added by ravi on 03/07/2024
			AND ISNULL(MOI.LineNumber, '') = CASE 
				WHEN ISNULL(@LineNumber, '') = ''
					THEN ISNULL(MOI.LineNumber, '')
				ELSE @LineNumber
				END -- added by ravi on 04/19/2024
		ORDER BY 2 DESC

		INSERT INTO @OrdersTable
		SELECT *
		FROM #tempCancelledOrders
		WHERE isnull(AccountFAN, '') = ISNULL(@AccountFAN, isnull(AccountFAN, ''))
			AND isnull(AccountBAN, '') = ISNULL(@AccountBAN, isnull(AccountBAN, ''))
			AND AccountID = ISNULL(@AccountID, AccountID)
			AND CarrierID = ISNULL(@CarrierID, CarrierID)
			--AND MO.MobilityOrderID = ISNULL(@MobilityOrderID, MO.MobilityOrderID)
			AND OrderOwnerID = ISNULL(@OrderOwnerID, OrderOwnerID)
			--AND ISNULL(ProvisionerID, 0) = ISNULL(@ProvisionerID, ISNULL(ProvisionerID, 0))
			--AND OrderStageID = 6001
			-- AND isnull(LineNumber,'') like '%' + isnull(@LineNumber,isnull(LineNumber,'')) + '%'
			AND isnull(TicketReferenceNumber, '') LIKE '%' + isnull(@TicketReferenceNumber, isnull(TicketReferenceNumber, '')) + '%'
		--AND MOI.LineNumber like '%' + isnull(@LineNumber,'') + '%'
		ORDER BY 2 DESC

		DROP TABLE #tempCancelledOrders
	END
			/** VIEW PENDING CANCEL ORDERS **/
	ELSE IF @ViewPendingCancel = 1
	BEGIN
		SELECT DISTINCT MO.OrderReferenceNumber
			,MO.MobilityOrderID
			,
			-- OTM.OrderType, MODIFIED BY SP ON 07/06/22 CASE# 1262
			CASE 
				WHEN mo.OrderTypeID = 6
					THEN CASE 
							WHEN MIN(MOI.OrderSubTypeMasterID) OVER (PARTITION BY MOI.MobilityOrderItemID) = 9
								THEN OTM.OrderType + ' - ' + OSTM.OrderSubType
							ELSE OTM.OrderType
							END
				ELSE OTM.OrderType
				END AS OrderType
			,MO.OrderSubType
			,CASE 
				WHEN [dbo].[GetMobileBusinessDays](OrderOpenedDateTime, GETDATE()) <= 1
					THEN CAST([dbo].[GetMobileBusinessHours](OrderOpenedDateTime, GETDATE()) AS VARCHAR(50)) + ' hours' -- ModifiedBy AkhilM on 10/09/2023 as per case 1017
				ELSE CASE 
						WHEN MO.OrderClosedDateTime IS NULL
							AND MO.OrderStageID <> 6001
							THEN CAST([dbo].[GetMobileBusinessHours](OrderOpenedDateTime, GETDATE()) / 10 AS VARCHAR(50)) + ' days' -- ModifiedBy AkhilM on 10/09/2023 as per case 1017
						WHEN (
								MO.OrderStageID = 6001
								OR MO.OrderStageID = 7001
								)
							THEN CAST([dbo].[GetMobileBusinessHours](OrderOpenedDateTime, MOH.MOHAddedDateTime) / 10 AS VARCHAR(50)) + ' days' -- ModifiedBy AkhilM on 10/09/2023 as per case 1017
						ELSE CAST([dbo].[GetMobileBusinessHours](OrderOpenedDateTime, GETDATE()) / 10 AS VARCHAR(50)) + ' days' -- MOH.MOHAddedDateTime -- ModifiedBy AkhilM on 10/09/2023 as per case 1017
						END
				END AS OrderAge
			,OSM.OrderStage
			,
			--LSM.LineStatus,
			U.user_name OrderOwner
			,MO.OrderOpenedDateTime
			,MO.OrderClosedDateTime
			,UO.user_name AS OrderOpenedBy
			,MO.OrderDueDateTime
			,'' AS LineNumber
			,MCM.CarrierUsageName
			,a.account_name AS AccountName
			,c.customer_name AS CustomerName
			,MO.OrderDescription
			,CA.AccountFAN
			,CA.AccountBAN
			,MO.CustomerID
			,MO.CarrierID
			,MO.CarrierAccountID
			,MO.AccountID
			,MO.OrderOpenedByID
			,MO.OrderStageID
			,MO.OrderOwnerID
			,cast(0 AS BIT) AS IsMigrated
			,CASE 
				WHEN MCM.Channel = 'Retail'
					THEN 1
				ELSE 0
				END AS IsRetail
			,DT.Qty
			,MO.NextSteps
			--,MO.ProvisionerID
			--,ISNULL(u_Provisioner.user_name, '') AS Provisioner
			,MO.ProjectManagerID
			,ISNULL(u_projectManager.user_name, '') AS ProjectManager
			,CASE 
				WHEN [dbo].[GetMobileBusinessDays](MOH.MOHAddedDateTime, GETDATE()) <= 1 -- ModifiedBy AkhilM on 10/09/2023 as per case 1017
					THEN CAST([dbo].[GetMobileBusinessHours](MOH.MOHAddedDateTime, GETDATE()) AS VARCHAR(50)) + ' hours' -- ModifiedBy AkhilM on 10/09/2023 as per case 1017
				ELSE CASE 
						WHEN (
								MOH.MOHAddedDateTime IS NULL
								AND (
									MO.OrderStageID = 6001
									OR MO.OrderStageID = 7001
									)
								)
							THEN CAST([dbo].[GetMobileBusinessHours](OrderOpenedDateTime, MOH.MOHAddedDateTime) / 10 AS VARCHAR(50)) + ' days' -- ModifiedBy AkhilM on 10/09/2023 as per case 1017
						WHEN (
								MOH.MOHAddedDateTime IS NULL
								AND (
									MO.OrderStageID <> 6001
									OR MO.OrderStageID <> 7001
									)
								)
							THEN CAST([dbo].[GetMobileBusinessHours](MOH.MOHAddedDateTime, GETDATE()) / 10 AS VARCHAR(50)) + ' days' -- MOH.MOHAddedDateTime -- ModifiedBy AkhilM on 10/09/2023 as per case 1017
						ELSE CAST([dbo].[GetMobileBusinessHours](MOH.MOHAddedDateTime, GETDATE()) / 10 AS VARCHAR(50)) + ' days' -- MOH.MOHAddedDateTime -- ModifiedBy AkhilM on 10/09/2023 as per case 1017
						END
				END AS StageAge
			,MO.TicketReferenceNumber
			,MO.OrderTypeID
			,OUI.OwnerId
			,CASE 
				WHEN OUI.OwnerId IS NOT NULL
					THEN CAST(0 AS BIT)
				ELSE CAST(1 AS BIT)
				END AS HasRead
			,OTM.OrderCategory
			,
			-- ADDED BY SP ON 3/3/21
			MO.RequestorID
			,CASE 
				WHEN MO.RequestorID > 0
					THEN ISNULL(u_RequestedBy.user_name, '')
				WHEN MO.RequestorID = - 1
					THEN 'Internal User'
				WHEN MO.RequestorID = - 2
					THEN 'Variance'
				WHEN MO.RequestorID = - 3
					THEN 'Pooling Management'
				WHEN MO.RequestorID = - 4
					THEN 'Optimization'
				END AS RequestedBy
			,MO.PlatFormTool
			,CA.ChannelMasterID
			,CM.ChannelDisplayName ChannelName
		INTO #tempPendingCancel
		FROM MobilityOrders MO(NOLOCK)
		INNER JOIN MobilityOrderItems MOI(NOLOCK) ON MOI.MobilityOrderID = MO.MobilityOrderID
		INNER JOIN LineStatusMaster LSM ON LSM.LineStatusMasterID = MOI.LineStatusMasterID
		INNER JOIN MobilityCarrierMaster MCM ON MCM.CarrierID = MO.CarrierID
		INNER JOIN account a(NOLOCK) ON a.account_id = MO.accountID
		INNER JOIN customer c(NOLOCK) ON c.customer_id = MO.CustomerID
		LEFT JOIN CustomerXCarrierAccounts CA(NOLOCK) ON CA.CarrierAccountID = MO.CarrierAccountID
			AND CA.CustomerID = MO.CustomerID
			AND CA.CustomerXCarrierAccountsID = ISNULL(MO.CustomerXCarrierAccountsID, CA.CustomerXCarrierAccountsID)
		LEFT JOIN ChannelMaster CM(NOLOCK) ON CM.ChannelMasterID = CA.ChannelMasterID
		INNER JOIN OrderTypeMaster OTM ON OTM.OrderTypeMasterID = MO.OrderTypeID
		INNER JOIN OrderStageMaster OSM ON OSM.OrderStageMasterID = MO.OrderStageID
		LEFT JOIN OrderSubTypeMaster OSTM ON OSTM.OrderSubTypeMasterID = MOI.OrderSubTypeMasterID
		-- INNER JOIN OrderStageMaster OSM ON OSM.OrderStageMasterID = MO.OrderStageID
		LEFT JOIN users U(NOLOCK) ON U.user_id = MO.OrderOwnerID
		INNER JOIN users UO(NOLOCK) ON UO.user_id = MO.OrderOpenedByID
		--LEFT JOIN users u_Provisioner(NOLOCK) ON MO.ProvisionerID = u_Provisioner.user_id
		LEFT JOIN users u_projectManager(NOLOCK) ON MO.ProjectManagerID = u_projectManager.user_id
		LEFT JOIN users u_RequestedBy(NOLOCK) ON MO.RequestorID = u_RequestedBy.user_id
		LEFT JOIN OrderUnreadItems OUI(NOLOCK) ON OUI.MobilityOrderID = MO.MobilityOrderID
			AND OUI.OwnerId = @UserID
		INNER JOIN (
			SELECT MOI.MobilityOrderID
				,COUNT(MOI.MobilityOrderItemID) AS Qty
			FROM MobilityOrders MO(NOLOCK)
			INNER JOIN MobilityOrderItems MOI(NOLOCK) ON MOI.MobilityOrderID = MO.MobilityOrderID
				AND MOI.IsActive = 1
			GROUP BY MOI.MobilityOrderID
			) DT ON DT.MobilityOrderID = MO.MobilityOrderID
		LEFT JOIN (
			SELECT MOH.MobilityOrderID
				,MAX(MOH.AddedDateTime) AS MOHAddedDateTime
			FROM MobilityOrderHistory MOH(NOLOCK)
			INNER JOIN MobilityOrders MO(NOLOCK) ON MO.MobilityOrderID = MOH.MobilityOrderID
				AND MO.OrderStageID = MOH.ChangeToID
			GROUP BY MOH.MobilityOrderID
			) MOH ON MOH.MobilityOrderID = MO.MobilityOrderID
		WHERE MOI.IsActive = 1
			AND MO.CustomerID = ISNULL(@CustomerID, MO.CustomerID)
			AND MOI.LineStatusMasterID = 4551
			AND MO.OrderOpenedDateTime >= @OpenFromDate
			AND MO.OrderOpenedDateTime <= @OpenToDate
			AND (
				ISNULL(@MobilityOrderIDs, '') = ''
				OR MO.MobilityOrderID IN (
					SELECT value
					FROM dbo.[SplitValue](@MobilityOrderIDs, ',')
					)
				) -- added by ravi on 03/07/2024
			AND ISNULL(MOI.LineNumber, '') = CASE 
				WHEN ISNULL(@LineNumber, '') = ''
					THEN ISNULL(MOI.LineNumber, '')
				ELSE @LineNumber
				END -- added by ravi on 04/19/2024

		INSERT INTO @OrdersTable
		SELECT *
		FROM #tempPendingCancel
		WHERE isnull(AccountFAN, '') = ISNULL(@AccountFAN, isnull(AccountFAN, ''))
			AND isnull(AccountBAN, '') = ISNULL(@AccountBAN, isnull(AccountBAN, ''))
			AND AccountID = ISNULL(@AccountID, AccountID)
			AND CarrierID = ISNULL(@CarrierID, CarrierID)
			--AND MO.MobilityOrderID = ISNULL(@MobilityOrderID, MO.MobilityOrderID)
			AND OrderOwnerID = ISNULL(@OrderOwnerID, OrderOwnerID)
			--AND ISNULL(ProvisionerID, 0) = ISNULL(@ProvisionerID, ISNULL(ProvisionerID, 0))
			--AND OrderStageID = 6001
			-- AND isnull(LineNumber,'') like '%' + isnull(@LineNumber,isnull(LineNumber,'')) + '%'
			AND isnull(TicketReferenceNumber, '') LIKE '%' + isnull(@TicketReferenceNumber, isnull(TicketReferenceNumber, '')) + '%'
		--AND MOI.LineNumber like '%' + isnull(@LineNumber,'') + '%'
		ORDER BY 2 DESC

		DROP TABLE #tempPendingCancel
	END
	ELSE
	BEGIN
		--INSERT INTO @OrdersTable
		SELECT DISTINCT MO.OrderReferenceNumber
			,MO.MobilityOrderID
			,
			-- OTM.OrderType, MODIFIED BY SP ON 07/06/22 CASE# 1262
			CASE 
				WHEN mo.OrderTypeID = 6
					THEN CASE 
							WHEN MIN(MOI.OrderSubTypeMasterID) OVER (PARTITION BY MOI.MobilityOrderItemID) = 9
								THEN OTM.OrderType + ' - ' + OSTM.OrderSubType
							ELSE OTM.OrderType
							END
				ELSE OTM.OrderType
				END AS OrderType
			,MO.OrderSubType
			,CASE 
				WHEN [dbo].[GetMobileBusinessDays](OrderOpenedDateTime, GETDATE()) <= 1 -- ModifiedBy AkhilM on 10/09/2023 as per case 1017
					THEN CAST([dbo].[GetMobileBusinessHours](OrderOpenedDateTime, GETDATE()) AS VARCHAR(50)) + ' hours' -- ModifiedBy AkhilM on 10/09/2023 as per case 1017
				ELSE CASE 
						WHEN MO.OrderClosedDateTime IS NULL
							AND MO.OrderStageID <> 6001
							THEN CAST([dbo].[GetMobileBusinessHours](OrderOpenedDateTime, GETDATE()) / 10 AS VARCHAR(50)) + ' days' -- ModifiedBy AkhilM on 10/09/2023 as per case 1017
						WHEN (
								MO.OrderStageID = 6001
								OR MO.OrderStageID = 7001
								)
							THEN CAST([dbo].[GetMobileBusinessHours](OrderOpenedDateTime, MOH.MOHAddedDateTime) / 10 AS VARCHAR(50)) + ' days' -- ModifiedBy AkhilM on 10/09/2023 as per case 1017
						ELSE CAST([dbo].[GetMobileBusinessHours](OrderOpenedDateTime, GETDATE()) / 10 AS VARCHAR(50)) + ' days' -- MOH.MOHAddedDateTime -- ModifiedBy AkhilM on 10/09/2023 as per case 1017
						END
				END AS OrderAge
			,OSM.OrderStage
			,
			-- LSM.LineStatus,
			U.user_name OrderOwner
			,MO.OrderOpenedDateTime
			,MO.OrderClosedDateTime
			,UO.user_name AS OrderOpenedBy
			,MO.OrderDueDateTime
			,'' AS LineNumber
			,MCM.CarrierUsageName
			,a.account_name AS AccountName
			,c.customer_name AS CustomerName
			,MO.OrderDescription
			,CA.AccountFAN
			,CA.AccountBAN
			,MO.CustomerID
			,MO.CarrierID
			,MO.CarrierAccountID
			,MO.AccountID
			,MO.OrderOpenedByID
			,MO.OrderStageID
			,MO.OrderOwnerID
			,cast(0 AS BIT) AS IsMigrated
			,CASE 
				WHEN MCM.Channel = 'Retail'
					THEN 1
				ELSE 0
				END AS IsRetail
			,DT.Qty
			,MO.NextSteps
			--,MO.ProvisionerID
			--,ISNULL(u_Provisioner.user_name, '') AS Provisioner
			,MO.ProjectManagerID
			,ISNULL(u_projectManager.user_name, '') AS ProjectManager
			,CASE 
				WHEN [dbo].[GetMobileBusinessDays](MOH.MOHAddedDateTime, GETDATE()) <= 1 -- ModifiedBy AkhilM on 10/09/2023 as per case 1017
					THEN CAST([dbo].[GetMobileBusinessHours](MOH.MOHAddedDateTime, GETDATE()) AS VARCHAR(50)) + ' hours' -- ModifiedBy AkhilM on 10/09/2023 as per case 1017
				ELSE CASE 
						WHEN (
								MOH.MOHAddedDateTime IS NULL
								AND (
									MO.OrderStageID = 6001
									OR MO.OrderStageID = 7001
									)
								)
							THEN CAST([dbo].[GetMobileBusinessHours](OrderOpenedDateTime, MOH.MOHAddedDateTime) / 10 AS VARCHAR(50)) + ' days' -- ModifiedBy AkhilM on 10/09/2023 as per case 1017
						WHEN (
								MOH.MOHAddedDateTime IS NULL
								AND (
									MO.OrderStageID <> 6001
									OR MO.OrderStageID <> 7001
									)
								)
							THEN CAST([dbo].[GetMobileBusinessHours](MOH.MOHAddedDateTime, GETDATE()) / 10 AS VARCHAR(50)) + ' days' -- MOH.MOHAddedDateTime -- ModifiedBy AkhilM on 10/09/2023 as per case 1017
						ELSE CAST([dbo].[GetMobileBusinessHours](MOH.MOHAddedDateTime, GETDATE()) / 10 AS VARCHAR(50)) + ' days' -- MOH.MOHAddedDateTime -- ModifiedBy AkhilM on 10/09/2023 as per case 1017
						END
				END AS StageAge
			,
			--,dbo.GetOrderChargeTotalByType(MO.MobilityOrderID, 'Monthly') AS MRC, dbo.GetOrderChargeTotalByType(MO.MobilityOrderID, 'One Time') AS NRC
			MO.TicketReferenceNumber
			,MO.OrderTypeID
			,OUI.OwnerId
			,CASE 
				WHEN OUI.OwnerId IS NOT NULL
					THEN CAST(0 AS BIT)
				ELSE CAST(1 AS BIT)
				END AS HasRead
			,OTM.OrderCategory
			,
			-- ADDED BY SP ON 3/3/21
			MO.RequestorID
			,CASE 
				WHEN MO.RequestorID > 0
					THEN ISNULL(u_RequestedBy.user_name, '')
				WHEN MO.RequestorID = - 1
					THEN 'Internal User'
				WHEN MO.RequestorID = - 2
					THEN 'Variance'
				WHEN MO.RequestorID = - 3
					THEN 'Pooling Management'
				WHEN MO.RequestorID = - 4
					THEN 'Optimization'
				END AS RequestedBy
			,MO.PlatFormTool
			,CA.ChannelMasterID
			,CM.ChannelDisplayName ChannelName
		INTO #tempOpenOrders
		FROM MobilityOrders MO(NOLOCK)
		INNER JOIN MobilityOrderItems MOI(NOLOCK) ON MOI.MobilityOrderID = MO.MobilityOrderID
		INNER JOIN LineStatusMaster LSM ON LSM.LineStatusMasterID = MOI.LineStatusMasterID
		INNER JOIN MobilityCarrierMaster MCM ON MCM.CarrierID = MO.CarrierID
		INNER JOIN account a(NOLOCK) ON a.account_id = MO.accountID
		INNER JOIN customer c(NOLOCK) ON c.customer_id = MO.CustomerID
		LEFT JOIN CustomerXCarrierAccounts CA(NOLOCK) ON CA.CarrierAccountID = MO.CarrierAccountID
			AND CA.CustomerID = MO.CustomerID
			AND CA.CustomerXCarrierAccountsID = ISNULL(MO.CustomerXCarrierAccountsID, CA.CustomerXCarrierAccountsID)
		LEFT JOIN ChannelMaster CM(NOLOCK) ON CM.ChannelMasterID = CA.ChannelMasterID
		INNER JOIN OrderTypeMaster OTM ON OTM.OrderTypeMasterID = MO.OrderTypeID
		LEFT JOIN OrderSubTypeMaster OSTM ON OSTM.OrderSubTypeMasterID = MOI.OrderSubTypeMasterID
		INNER JOIN OrderStageMaster OSM ON OSM.OrderStageMasterID = MO.OrderStageID
		LEFT JOIN users U(NOLOCK) ON U.user_id = MO.OrderOwnerID
		INNER JOIN users UO(NOLOCK) ON UO.user_id = MO.OrderOpenedByID
		--LEFT JOIN users u_Provisioner(NOLOCK) ON MO.ProvisionerID = u_Provisioner.user_id
		LEFT JOIN users u_projectManager(NOLOCK) ON MO.ProjectManagerID = u_projectManager.user_id
		LEFT JOIN users u_RequestedBy(NOLOCK) ON MO.RequestorID = u_RequestedBy.user_id
		LEFT JOIN OrderUnreadItems OUI(NOLOCK) ON OUI.MobilityOrderID = MO.MobilityOrderID
			AND OUI.OwnerId = @UserID
		INNER JOIN (
			SELECT MOI.MobilityOrderID
				,COUNT(MOI.MobilityOrderItemID) AS Qty
			FROM MobilityOrders MO(NOLOCK)
			INNER JOIN MobilityOrderItems MOI(NOLOCK) ON MOI.MobilityOrderID = MO.MobilityOrderID
				AND MOI.IsActive = 1
			GROUP BY MOI.MobilityOrderID
			) DT ON DT.MobilityOrderID = MO.MobilityOrderID
		LEFT JOIN (
			SELECT MOH.MobilityOrderID
				,MAX(MOH.AddedDateTime) AS MOHAddedDateTime
			FROM MobilityOrderHistory MOH(NOLOCK)
			INNER JOIN MobilityOrders MO(NOLOCK) ON MO.MobilityOrderID = MOH.MobilityOrderID
				AND MO.OrderStageID = MOH.ChangeToID
			GROUP BY MOH.MobilityOrderID
			) MOH ON MOH.MobilityOrderID = MO.MobilityOrderID
		WHERE MOI.IsActive = 1
			AND MO.CustomerID = ISNULL(@CustomerID, MO.CustomerID)
			AND OrderStageID NOT IN (
				6001
				,7001
				)
			AND MO.OrderOpenedDateTime >= @OpenFromDate
			AND MO.OrderOpenedDateTime <= @OpenToDate
			AND (
				ISNULL(@MobilityOrderIDs, '') = ''
				OR MO.MobilityOrderID IN (
					SELECT value
					FROM dbo.[SplitValue](@MobilityOrderIDs, ',')
					)
				) -- added by ravi on 03/07/2024
			AND ISNULL(MOI.LineNumber, '') = CASE 
				WHEN ISNULL(@LineNumber, '') = ''
					THEN ISNULL(MOI.LineNumber, '')
				ELSE @LineNumber
				END -- added by ravi on 04/19/2024
		ORDER BY 2 DESC -- AddedBy: GY Case#8726

		INSERT INTO @OrdersTable
		SELECT *
		FROM #tempOpenOrders
		WHERE (
				AccountFAN IS NULL
				OR isnull(AccountFAN, '') = ISNULL(@AccountFAN, isnull(AccountFAN, ''))
				)
			AND (
				AccountBAN IS NULL
				OR isnull(AccountBAN, '') = ISNULL(@AccountBAN, isnull(AccountBAN, ''))
				)
			AND AccountID = ISNULL(@AccountID, AccountID)
			AND CarrierID = ISNULL(@CarrierID, CarrierID)
			--AND MO.MobilityOrderID = ISNULL(@MobilityOrderID, MO.MobilityOrderID)
			AND OrderOwnerID = ISNULL(@OrderOwnerID, OrderOwnerID)
			--AND ISNULL(ProvisionerID, 0) = ISNULL(@ProvisionerID, ISNULL(ProvisionerID, 0))
			--AND OrderStageID < 6000
			--AND isnull(LineNumber,'') like '%' + isnull(@LineNumber,isnull(LineNumber,'')) + '%'
			AND isnull(TicketReferenceNumber, '') LIKE '%' + isnull(@TicketReferenceNumber, isnull(TicketReferenceNumber, '')) + '%'
		ORDER BY 2 DESC -- AddedBy: GY Case#8726

		--AND MOI.LineNumber like '%' + isnull(@LineNumber,'') + '%'
		DROP TABLE #tempOpenOrders
	END

	DECLARE @Channel VARCHAR(50) -- ADDED BY NS on 07/23/19

	-- NS - 2021-09-20- v14Release
	-- Delete orders created from vManager which are in Draft stage
	DELETE
	FROM @OrdersTable
	WHERE (
			OrderStage = 'Draft'
			AND PlatFormTool LIKE 'vManager%'
			)

	IF (@ChannelType = 0) -- ADDED BY NS on 07/23/19
	BEGIN
		SET @Channel = 'Wholesale Aggregator'

		IF (@MobilityOrderIDs <> '')
		BEGIN
			IF (@LineNumber IS NOT NULL)
			BEGIN
				SELECT OT.*
					,CASE 
						WHEN IsMigrated = 1
							THEN 0.00
						ELSE dbo.GetOrderChargeTotalByOrderType(OT.MobilityOrderID, 'Monthly', OT.OrderTypeID)
						END AS MRC
					,CASE 
						WHEN IsMigrated = 1
							THEN 0.00
						ELSE dbo.GetOrderChargeTotalByOrderType(OT.MobilityOrderID, 'One Time', OT.OrderTypeID)
						END AS NRC
				FROM @OrdersTable OT
				INNER JOIN MobilityCarrierMaster MCM ON MCM.CarrierID = OT.CarrierID
				INNER JOIN MobilityOrderItems MOI(NOLOCK) ON MOI.MobilityOrderID = OT.MobilityOrderID
				WHERE MCM.channel = @Channel -- ADDED BY NS on 07/23/19
					AND isnull(MOI.LineNumber, '') LIKE '%' + isnull(@LineNumber, isnull(MOI.LineNumber, '')) + '%'
					AND MOI.IsActive = 1 --AddedBy Kiranmai on 12/08/2021
					AND OT.MobilityOrderID IN (
						SELECT value
						FROM dbo.[SplitValue](@MobilityOrderIDs, ',')
						)
				ORDER BY 2 DESC -- AddedBy: GY Case#8726
			END
			ELSE
			BEGIN
				SELECT OT.*
					,CASE 
						WHEN IsMigrated = 1
							THEN 0.00
						ELSE dbo.GetOrderChargeTotalByOrderType(OT.MobilityOrderID, 'Monthly', OT.OrderTypeID)
						END AS MRC
					,CASE 
						WHEN IsMigrated = 1
							THEN 0.00
						ELSE dbo.GetOrderChargeTotalByOrderType(OT.MobilityOrderID, 'One Time', OT.OrderTypeID)
						END AS NRC
				FROM @OrdersTable OT
				INNER JOIN MobilityCarrierMaster MCM ON MCM.CarrierID = OT.CarrierID
				WHERE MCM.channel = @Channel -- ADDED BY NS on 07/23/19
					AND MobilityOrderID IN (
						SELECT value
						FROM dbo.[SplitValue](@MobilityOrderIDs, ',')
						)
				ORDER BY 2 DESC -- AddedBy: GY Case#8726
			END
		END
		ELSE
		BEGIN
			IF (@LineNumber IS NOT NULL)
			BEGIN
				SELECT OT.*
					,CASE 
						WHEN IsMigrated = 1
							THEN 0.00
						ELSE dbo.GetOrderChargeTotalByOrderType(OT.MobilityOrderID, 'Monthly', OT.OrderTypeID)
						END AS MRC
					,CASE 
						WHEN IsMigrated = 1
							THEN 0.00
						ELSE dbo.GetOrderChargeTotalByOrderType(OT.MobilityOrderID, 'One Time', OT.OrderTypeID)
						END AS NRC
				FROM @OrdersTable OT
				INNER JOIN MobilityCarrierMaster MCM ON MCM.CarrierID = OT.CarrierID
				INNER JOIN MobilityOrderItems MOI(NOLOCK) ON MOI.MobilityOrderID = OT.MobilityOrderID
				WHERE MCM.channel = @Channel -- ADDED BY NS on 07/23/19
					AND isnull(MOI.LineNumber, '') LIKE '%' + isnull(@LineNumber, isnull(MOI.LineNumber, '')) + '%'
					AND MOI.IsActive = 1 --AddedBy Kiranmai on 12/08/2021
				ORDER BY 2 DESC -- AddedBy: GY Case#8726
			END
			ELSE
			BEGIN
				SELECT OT.*
					,CASE 
						WHEN IsMigrated = 1
							THEN 0.00
						ELSE dbo.GetOrderChargeTotalByOrderType(OT.MobilityOrderID, 'Monthly', OT.OrderTypeID)
						END AS MRC
					,CASE 
						WHEN IsMigrated = 1
							THEN 0.00
						ELSE dbo.GetOrderChargeTotalByOrderType(OT.MobilityOrderID, 'One Time', OT.OrderTypeID)
						END AS NRC
				FROM @OrdersTable OT
				INNER JOIN MobilityCarrierMaster MCM ON MCM.CarrierID = OT.CarrierID
				WHERE MCM.channel = @Channel -- ADDED BY NS on 07/23/19
				ORDER BY 2 DESC -- AddedBy: GY Case#8726
			END
		END
	END
	ELSE
	BEGIN
		SET @Channel = 'Retail'

		IF (@MobilityOrderIDs <> '')
		BEGIN
			IF (@LineNumber IS NOT NULL)
			BEGIN
				SELECT OT.*
					,-- Modified by AkhilM on 08-03-2023 as per case 1077
					CASE 
						WHEN IsMigrated = 1
							THEN 0.00
						ELSE dbo.GetOrderChargeTotalByOrderType(OT.MobilityOrderID, 'Monthly', OT.OrderTypeID)
						END AS MRC
					,CASE 
						WHEN IsMigrated = 1
							THEN 0.00
						ELSE dbo.GetOrderChargeTotalByOrderType(OT.MobilityOrderID, 'One Time', OT.OrderTypeID)
						END AS NRC
				FROM @OrdersTable OT
				INNER JOIN MobilityOrderItems MOI(NOLOCK) ON MOI.MobilityOrderID = OT.MobilityOrderID
				WHERE OT.MobilityOrderID IN (
						SELECT value
						FROM dbo.[SplitValue](@MobilityOrderIDs, ',')
						)
					AND isnull(MOI.LineNumber, '') LIKE '%' + isnull(@LineNumber, isnull(MOI.LineNumber, '')) + '%'
					AND MOI.IsActive = 1 --AddedBy Kiranmai on 12/08/2021
				ORDER BY 2 DESC -- AddedBy: GY Case#8726
			END
			ELSE
			BEGIN
				SELECT OT.*
					,-- Modified by AkhilM on 08-03-2023 as per case 1077
					CASE 
						WHEN IsMigrated = 1
							THEN 0.00
						ELSE dbo.GetOrderChargeTotalByOrderType(MobilityOrderID, 'Monthly', OT.OrderTypeID)
						END AS MRC
					,CASE 
						WHEN IsMigrated = 1
							THEN 0.00
						ELSE dbo.GetOrderChargeTotalByOrderType(MobilityOrderID, 'One Time', OT.OrderTypeID)
						END AS NRC
				FROM @OrdersTable OT
				WHERE MobilityOrderID IN (
						SELECT value
						FROM dbo.[SplitValue](@MobilityOrderIDs, ',')
						)
				ORDER BY 2 DESC -- AddedBy: GY Case#8726
			END
		END
		ELSE
		BEGIN
			IF (@LineNumber IS NOT NULL)
			BEGIN
				SELECT OT.*
					,-- Modified by AkhilM on 08-03-2023 as per case 1077
					CASE 
						WHEN IsMigrated = 1
							THEN 0.00
						ELSE dbo.GetOrderChargeTotalByOrderType(OT.MobilityOrderID, 'Monthly', OT.OrderTypeID)
						END AS MRC
					,CASE 
						WHEN IsMigrated = 1
							THEN 0.00
						ELSE dbo.GetOrderChargeTotalByOrderType(OT.MobilityOrderID, 'One Time', OT.OrderTypeID)
						END AS NRC
				FROM @OrdersTable OT
				INNER JOIN MobilityOrderItems MOI(NOLOCK) ON MOI.MobilityOrderID = OT.MobilityOrderID
					AND isnull(MOI.LineNumber, '') LIKE '%' + isnull(@LineNumber, isnull(MOI.LineNumber, '')) + '%'
					AND MOI.IsActive = 1 --AddedBy Kiranmai on 12/08/2021
				ORDER BY 2 DESC -- AddedBy: GY Case#8726
			END
			ELSE
			BEGIN
				SELECT OT.*
					,-- Modified by AkhilM on 08-03-2023 as per case 1077
					CASE 
						WHEN IsMigrated = 1
							THEN 0.00
						ELSE dbo.GetOrderChargeTotalByOrderType(MobilityOrderID, 'Monthly', OT.OrderTypeID)
						END AS MRC
					,CASE 
						WHEN IsMigrated = 1
							THEN 0.00
						ELSE dbo.GetOrderChargeTotalByOrderType(MobilityOrderID, 'One Time', OT.OrderTypeID)
						END AS NRC
				FROM @OrdersTable OT
				ORDER BY 2 DESC -- AddedBy: GY Case#8726
			END
		END
	END
END
GO
