USE mobility
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================  
-- Author:  SP  
-- ALTER date: <ALTER Date,,>  
-- Description: <Description,,>  
-- =============================================  
-- Author:  Nagasai      
-- Modified date: 2021-01-26       
-- Description: device pricing category changes       
-- ============================================= 
-- Author:  Nagasai     
-- ALTER date: 02-12-2021     
-- Description: device catalog changes v21     
-- ============================================= 
-- Author:  NAGASAI                
-- ALTER date: 05-05-2021                 
-- Description: Added additional order fields             
-- ============================================= 
-- Author:  NAGASAI                
-- ALTER date: 08-12-2021                 
-- Description: Added Es FLAG FOR CHARGED          
-- ============================================= 
-- Author:  AkhilM
-- Modified date: 2024-02-15
-- Description: Getting Vendor Name by Carrier and Vendor ID  SD -- 4686    
-- =============================================
-- Author : Ravi Teja Yella
-- Altered date : 03/27/2024
-- Description : Returning DEPValue 
-- Case# 11432 - QS Managed Inventory - Phase 2	
-- =============================================
-- EXEC [MobilityOrders_GetServiceDetailsForSpareOrdersByID] 118937  
ALTER PROCEDURE [dbo].[MobilityOrders_GetServiceDetailsForSpareOrdersByID] @MobilityOrderID INT
AS
BEGIN
	--- GET ALL DEVICE AND STATUS RELATED INFORMATION for SPARE ORDER TO BE DISPLAYED IN THE SERVICE DETAILS GRID IN THE ORDER MANGEMENT PAGE -------  
	SELECT MOXD.MobilityOrderID
		,MOXD.MobilityOrderItemID
		,DeviceType
		,ModelName
		,PriceCategory
		,COUNT(*) AS Quantity
		,SUM(PlanCost) AS Cost
		,PlanMargin AS Margin
		,SUM(PlanPrice) Price
		,IsInstallmentPlan
		,PlanMonths AS Tenure
		,DownPayment
		,ROIOnCost
		,ROIOnPrice
		,
		--dbo.uspGetPricingCategoryID(MOXD.PlanPrice) DevicePricingCategoryMasterID, 
		(
			CASE 
				WHEN (ISNULL(sp.SpecialPrice, 0) > 0)
					AND sp.PriceExpiryDate > GETDATE()
					AND BillingEntityID = - 1
					THEN dbo.uspGetPricingCategoryID(ISNULL(NULLIF(sp.SpecialPrice, 0), DxC.Price))
				WHEN (ISNULL(sp.SpecialPrice, 0) > 0)
					AND BillingEntityID > 1
					THEN dbo.uspGetPricingCategoryID(ISNULL(NULLIF(sp.SpecialPrice, 0), DxC.Price))
				ELSE dbo.uspGetPricingCategoryID(DxC.Price)
				END
			) AS DevicePricingCategoryMasterID
		,D.DeviceID
		,DTM.DeviceTypeMasterID
		,MOI.LineStatusMasterID
		,MOI.LineSubStatusMasterID
		,LineStatus
		,LineSubStatus
		,MO.CustomerID
		,MO.CarrierID
		,MOI.CustomerShippingAddressID
		,MOI.ShippingTypeID
		,D.HasESN
		,(
			SELECT SUM(Price * Quantity)
			FROM MobilityOrderCharges
			WHERE IsActive = 1
				AND ChargeType = 'Monthly'
				AND MobilityOrderID = @MobilityOrderID
				AND MobilityOrderItemID = MOXD.MobilityOrderItemID
			) MRC
		,(
			SELECT SUM(Price * Quantity)
			FROM MobilityOrderCharges
			WHERE IsActive = 1
				AND ChargeType = 'One Time'
				AND MobilityOrderID = @MobilityOrderID
				AND MobilityOrderItemID = MOXD.MobilityOrderItemID
			) NRC
		,HasPreOrder = CASE 
			WHEN DXC.DeviceStatusID = 400
				OR DXC.DeviceStatusID = 300
				THEN CAST(1 AS BIT)
			ELSE CAST(0 AS BIT)
			END
		,DXC.PreOrderEnddate
		,CASE 
			WHEN MCM.Channel = 'Retail'
				THEN 1
			ELSE 0
			END AS IsRetail
		,vManagerStatus
		,D.Make
		,MOXD.DeviceXCarrierID
		,MOXD.DeviceConditionID
		,MOXD.DeviceVendorID
		,MOXD.SpecialPrice
		,MOXD.HasSpecialPrice
		,dbo.GetDeviceVendorByCarrier(MOXD.DeviceVendorID,MO.CarrierID) AS VendorName -- AddedBy AkhilM as per case 4686
		--,DV.VendorName -- CommentedBy AkhilM as per case 4686
		,DCC.ConditionName
		,OTM.OrderCategory
		,UserFirstName AS InventoryFristName
		,UserLastName AS InventoryLastName
		,EmployeeID
		,e.first_name AS EmployeeFirstName
		,e.last_name AS EmployeeLastName
		,iBillerDate
		,CopyEndUser
		,UserEmail
		,CASE 
			WHEN MOI.LineStatusMasterID = 5001
				THEN MOI.ItemCancelledDateTime
			WHEN MOI.LineStatusMasterID = 7001
				THEN MOI.ItemClosedDateTime
			ELSE NULL
			END AS LineStageDate
		,CASE 
			WHEN dbo.MobilityCharges_IsEquipmentReady(ISNULL(MOI.MobilityOrderItemID, 0)) = 1
				THEN 1
			ELSE 0
			END AS IsEquipmentCharged
		,MOI.DEPValue AS DEPValue
	FROM MobilityOrderXDevices MOXD(NOLOCK)
	INNER JOIN MobilityOrders MO(NOLOCK) ON MO.MobilityOrderID = MOXD.MobilityOrderID
	INNER JOIN OrderTypeMaster OTM(NOLOCK) ON OTM.OrderTypeMasterID = MO.OrderTypeID
	INNER JOIN MobilityCarrierMaster MCM(NOLOCK) ON MCM.CarrierID = MO.CarrierID
	INNER JOIN MobilityOrderItems MOI(NOLOCK) ON MOI.MobilityOrderItemID = MOXD.MobilityOrderItemID
	INNER JOIN LineStatusMaster LSM(NOLOCK) ON LSM.LineStatusMasterID = MOI.LineStatusMasterID
	LEFT JOIN LineSubStatusMaster LSSM(NOLOCK) ON LSSM.LineSubStatusMasterID = MOI.LineSubStatusMasterID
	INNER JOIN Devices D(NOLOCK) ON D.DeviceID = MOXD.DeviceID
	LEFT JOIN employee e(NOLOCK) ON e.employee_id = MOI.EmployeeID
	--INNER JOIN DeviceXCarrier DXC on DXC.CarrierID = MO.CarrierID AND DXC.DeviceID = MOXD.DeviceID
	LEFT JOIN DeviceXCarrier DxC(NOLOCK) ON DxC.DeviceID = MOXD.DeviceID
		AND DXC.CarrierID = MO.CarrierID
		AND DXC.DeviceVendorID = ISNULL(NULLIF(MOXD.DeviceVendorID, 0), 100)
		AND DXC.DeviceConditionID = ISNULL(NULLIF(MOXD.DeviceConditionID, 0), 100)
	LEFT JOIN CustomerXDeviceSpecialPrice sp(NOLOCK) ON sp.DeviceXCarrierID = DxC.DeviceXCarrierID
		AND sp.CustomerID = MO.CustomerID
		AND sp.IsActive = 1
	LEFT JOIN DeviceCondition DCC(NOLOCK) ON DCC.DeviceConditionID = MOXD.DeviceConditionID
	LEFT JOIN DeviceVendor DV(NOLOCK) ON DV.DeviceVendorID = MOXD.DeviceVendorID
		AND DV.IsActive = 1 -- AddedBy AkhilM as per case 4686
	INNER JOIN DeviceTypeMaster DTM(NOLOCK) ON DTM.DeviceTypeMasterID = D.DeviceTypesMasterID
	INNER JOIN DevicePricingCategoryMaster DPCM(NOLOCK) ON DPCM.DevicePricingCategoryMasterID = (
			CASE 
				WHEN (ISNULL(sp.SpecialPrice, 0) > 0)
					AND sp.PriceExpiryDate > GETDATE()
					AND BillingEntityID = - 1
					THEN dbo.uspGetPricingCategoryID(ISNULL(NULLIF(sp.SpecialPrice, 0), DxC.Price))
				WHEN (ISNULL(sp.SpecialPrice, 0) > 0)
					AND BillingEntityID > 1
					THEN dbo.uspGetPricingCategoryID(ISNULL(NULLIF(sp.SpecialPrice, 0), DxC.Price))
				ELSE dbo.uspGetPricingCategoryID(DxC.Price)
				END
			)
	--dbo.uspGetPricingCategoryID(MOXD.PlanPrice)--D.DevicePricingCategoryMasterID   
	WHERE MOXD.MobilityOrderID = @MobilityOrderID
	GROUP BY MOXD.MobilityOrderID
		,MOXD.MobilityOrderItemID
		,DeviceType
		,ModelName
		,PriceCategory
		,IsInstallmentPlan
		,PlanMonths
		,PlanMargin
		,DownPayment
		,ROIOnCost
		,ROIOnPrice
		,
		-- dbo.uspGetPricingCategoryID(MOXD.PlanPrice), 
		(
			CASE 
				WHEN (ISNULL(sp.SpecialPrice, 0) > 0)
					AND sp.PriceExpiryDate > GETDATE()
					AND BillingEntityID = - 1
					THEN dbo.uspGetPricingCategoryID(ISNULL(NULLIF(sp.SpecialPrice, 0), DxC.Price))
				WHEN (ISNULL(sp.SpecialPrice, 0) > 0)
					AND BillingEntityID > 1
					THEN dbo.uspGetPricingCategoryID(ISNULL(NULLIF(sp.SpecialPrice, 0), DxC.Price))
				ELSE dbo.uspGetPricingCategoryID(DxC.Price)
				END
			)
		,D.DeviceID
		,DTM.DeviceTypeMasterID
		,MOI.LineStatusMasterID
		,MOI.LineSubStatusMasterID
		,LineStatus
		,LineSubStatus
		,MO.CustomerID
		,MO.CarrierID
		,MOI.CustomerShippingAddressID
		,MOI.ShippingTypeID
		,D.HasESN
		,CASE 
			WHEN DXC.DeviceStatusID = 400
				OR DXC.DeviceStatusID = 300
				THEN CAST(1 AS BIT)
			ELSE CAST(0 AS BIT)
			END
		,DXC.PreOrderEnddate
		,MCM.Channel
		,vManagerStatus
		,D.Make
		,MOXD.DeviceXCarrierID
		,MOXD.DeviceConditionID
		,MOXD.DeviceVendorID
		,MOXD.SpecialPrice
		,MOXD.HasSpecialPrice
		,VendorName
		,DCC.ConditionName
		,OTM.OrderCategory
		,UserFirstName
		,UserLastName
		,EmployeeID
		,e.first_name
		,e.last_name
		,iBillerDate
		,CopyEndUser
		,userEmail
		,CASE 
			WHEN MOI.LineStatusMasterID = 5001
				THEN MOI.ItemCancelledDateTime
			WHEN MOI.LineStatusMasterID = 7001
				THEN MOI.ItemClosedDateTime
			ELSE NULL
			END
		,CASE 
			WHEN dbo.MobilityCharges_IsEquipmentReady(ISNULL(MOI.MobilityOrderItemID, 0)) = 1
				THEN 1
			ELSE 0
			END
		,MOI.DEPValue
END
GO
