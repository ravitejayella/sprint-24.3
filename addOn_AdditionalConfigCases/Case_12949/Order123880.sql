USE mobility
GO

DECLARE @MobilityOrderID INT = 123880 
	,@AddedByID INT

SELECT @AddedByID = user_id
FROM users(NOLOCK)
WHERE user_name = 'Corey Stark'

INSERT INTO MobilityOrderXAddonPropertyRel (
	MobilityOrderID
	,MobilityOrderItemID
	,AddonID
	,AddonPropertyID
	,AddonPropertyValue
	,IsActive
	,AddedByID
	,ChangeByID
	)
SELECT MobilityOrderID
	,MobilityOrderItemID
	,ad.AddonID
	,ad.AddonPropertyID
	,CASE 
		WHEN ad.PropertyName = 'IP'
			THEN tmp.IPAddressValue
		WHEN ad.PropertyName = 'APN'
			THEN tmp.APNValue
		END
	,1
	,@AddedByID
	,@AddedByID
FROM MobilityOrderItems mo(NOLOCK)
INNER JOIN [dbo].[TempTableAddOnConfig123880] tmp ON tmp.OrderItemID = mo.MobilityOrderItemID
CROSS JOIN (
	SELECT ad.AddOnID
		,adp.AddonPropertyID
		,adp.PropertyName
	FROM AddOns ad(NOLOCK)
	JOIN AddonXPropertyRel adr(NOLOCK) ON ad.AddOnID = adr.AddOnID
	JOIN AddonProperties adp(NOLOCK) ON adp.AddonPropertyID = adr.AddonPropertyID
	WHERE ad.AddOnName = 'IP Address'
		AND (
			adp.PropertyName = 'APN'
			OR adp.PropertyName = 'IP'
			)
	) ad
WHERE MobilityOrderID = @MobilityOrderID
