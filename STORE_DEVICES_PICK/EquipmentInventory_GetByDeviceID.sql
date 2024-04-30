USE mobility
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================        
-- Author:  Kiranmai        
-- ALTER date: <ALTER Date,,>        
-- Description: <Description,,>        
-- =============================================        
-- Author:  Nagasai        
-- ALTER date: 2021-01-26  
-- Description: fixed device 'HasPreOrder' and 'PreOrderEnddate'
-- =============================================  
-- Author:  Nagasai        
-- ALTER date: 2021-03-23  
-- Description: device vendor conditions and new carrier changes
-- =============================================  
-- Author:  AkhilM
-- Modified date: 2024-02-15
-- Description: Getting Vendor Name by Carrier and Vendor ID  SD -- 4686    
-- =============================================
-- Author:  Gopi Pagadala
-- Modified date: 2024-03-01
-- Description: Getting devices based on customer SD -- 12446    
-- =============================================
-- Author:  Gopi Pagadala
-- Modified date: 2024-03-26
-- Description: Getting IseSimSelected, EID, IMEI2 parameters  -- 12713 
-- =============================================
-- EXEC [EquipmentInventory_GetByDeviceID] 4750, @MobilityOrderItemID=353853, @CarrierID=122     
-- EXEC [EquipmentInventory_GetByDeviceID] 4207, @DeviceVendorID= 300
ALTER PROCEDURE [dbo].[EquipmentInventory_GetByDeviceID] --10        
	@DeviceID INT
	,@MobilityOrderItemID INT = NULL
	,@CarrierID INT = NULL
	,@DeviceVendorID INT = NULL
	,@DeviceConditionID INT = NULL
	,@CustomerID INT = NULL
AS
BEGIN
	DECLARE @ChannelType BIT

	IF (@CarrierID IS NULL)
	BEGIN
		SELECT @CarrierID = MO.CarrierID
			,@ChannelType = CASE 
				WHEN MCM.Channel = 'Retail'
					THEN 1
				ELSE 0
				END
			,@CustomerID = CASE 
				WHEN ISNULL(@MobilityOrderItemID, 0) = 0
					THEN @CustomerID
				ELSE MO.CustomerID
				END -- AddedBy Gopi as per case 12446
		FROM MobilityOrders MO
		INNER JOIN MobilityOrderItems MOI ON MOI.MobilityOrderID = MO.MobilityOrderID
		INNER JOIN MobilityCarrierMaster MCM ON MCM.CarrierID = ISNULL(MO.CarrierID, 0)
			AND MCM.BusinessUnit = 'vMobile'
		WHERE MOI.MobilityOrderItemID = @MobilityOrderItemID
	END

	DECLARE @Channel VARCHAR(50)

	IF (@ChannelType = 0)
	BEGIN
		SET @Channel = 'Wholesale Aggregator'
	END
	ELSE
	BEGIN
		SET @Channel = 'Retail'
	END

	SELECT EquipmentInventoryMasterID
		,InventoryType
		,InventoryTypeID
		,EI.DeviceID
		,D.DeviceTypesMasterID DeviceTypeMasterID
		,D.ModelName
		,D.Make
		,D.ModelNumber
		,D.Storage
		,D.Color
		,Shelf
		,ESN
		,MEID
		,ICCID
		,(
			SELECT STRING_AGG(DAV.AttributeValue, ',')
			FROM DevicesXSimOptions DSO(NOLOCK)
			JOIN [DeviceXAttributeValue] DAV(NOLOCK) ON DSO.SimOptionID = DAV.DeviceXAttributeValueID
			WHERE DSO.DeviceID = D.DeviceID
			) AS SIM
		,EI.Cost
		,EI.Margin
		,ShippingCost
		,EI.Price
		,ShippingPrice
		,MobilityOrderID
		,MobilityOrderItemID
		,EI.AddedByID
		,EI.AddedDateTime
		,EI.ChangedByID
		,EI.ChangedDateTime
		,(
			CASE 
				WHEN MobilityOrderItemID IS NOT NULL
					THEN CAST(1 AS BIT)
				ELSE CAST(0 AS BIT)
				END
			) IsSelected
		,EI.DeviceSellerID
		,DS.SellerName
		,EI.DeviceWarrantyTypeMasterID
		,DeviceWarrantyType
		,EI.DeviceWarrantyTermMasterID
		,WarrantyTerm
		,InvoiceNumber
		,MCM.CarrierID
		,MCM.CarrierUsageName
		,CASE 
			WHEN MCM.Channel = 'Retail'
				THEN 1
			ELSE 0
			END AS IsRetail
		,HasPreOrder = CASE 
			WHEN DC.DeviceStatusID = 300
				THEN 1
			ELSE 0
			END
		,DC.PreOrderEnddate
		,IsUnlocked
		,EI.DeviceXCarrierID
		,EI.DeviceVendorID
		,EI.DeviceConditionID
		,dbo.GetDeviceVendorByCarrier(EI.DeviceVendorID, DC.CarrierID) AS VendorName -- AddedBy AkhilM as per case 4686
		--,DV.VendorName -- CommentedBy AkhilM as per case 4686
		,DCC.ConditionName
		,D.ModelYear
		,D.ModelGeneration
		,ISNULL(MCM.channel, @Channel) channel
		,DTM.DeviceType
		,EI.VendorDesc
		,EI.IseSimSelected -- 12713
		,EI.EID
		,EI.IMEI2
	--  SELECT *
	FROM EquipmentInventory EI(NOLOCK)
	INNER JOIN Devices D(NOLOCK) ON EI.DeviceID = D.DeviceID
	-- INNER JOIN DevicexCarrier DC on D.DeviceID = DC.DeviceID AND EI.CarrierID = DC.CarrierID 
	LEFT JOIN DeviceXCarrier DC(NOLOCK) ON DC.DeviceID = EI.DeviceID
        AND dc.DeviceVendorID = ei.DeviceVendorID
        and dc.DeviceConditionID = ei.DeviceConditionID
        and dc.CarrierID = ei.CarrierID
	LEFT JOIN DeviceCondition DCC(NOLOCK) ON DCC.DeviceConditionID = EI.DeviceConditionID
	LEFT JOIN DeviceVendor DV(NOLOCK) ON DV.DeviceVendorID = EI.DeviceVendorID
		AND DV.IsActive = 1 -- AddedBy AkhilM as per case 4686
	LEFT JOIN MobilityCarrierMaster MCM(NOLOCK) ON MCM.CarrierID = ISNULL(EI.CarrierID, 0)
		AND MCM.BusinessUnit = 'vMobile'
	LEFT JOIN DeviceSellers DS(NOLOCK) ON DS.DeviceSellerID = EI.DeviceSellerID
	LEFT JOIN DeviceTypeMaster(NOLOCK) DTM ON DTM.DeviceTypeMasterID = D.DeviceTypesMasterID
	LEFT JOIN [DeviceWarrantyTermMaster] DWTM(NOLOCK) ON DWTM.DeviceWarrantyTermMasterID = EI.DeviceWarrantyTermMasterID
	LEFT JOIN [DeviceWarrantyTypeMaster] DWaTM(NOLOCK) ON DWaTM.DeviceWarrantyTypeMasterID = EI.DeviceWarrantyTypeMasterID
	WHERE EI.DeviceID = @DeviceID
		--AND (isnull(EI.CarrierID,0) = ISNULL(@CarrierID,isnull(EI.CarrierID,0)))-- OR CXD.CarrierID is null  )      
		AND (
			EI.CarrierID = ISNULL(@CarrierID, EI.CarrierID)
			OR (ISNULL(EI.CarrierID, 0) = 0)
			)
		AND (
			MobilityOrderItemID IS NULL
			OR MobilityOrderItemID = @MobilityOrderItemID
			)
		AND EI.isActive = 1
		AND EI.DeviceConditionID = ISNULL(@DeviceConditionID, EI.DeviceConditionID)
		AND EI.DeviceVendorID = ISNULL(@DeviceVendorID, EI.DeviceVendorID)
		AND (
			EI.CustomerID = ISNULL(@CustomerID, EI.CustomerID) -- AddedBy Gopi as per case 12446
			OR EI.CustomerID IS NULL
			)
	ORDER BY MCM.CarrierID DESC
END
GO
