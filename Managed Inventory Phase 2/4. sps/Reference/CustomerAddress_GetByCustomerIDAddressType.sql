-- =============================================  
-- Author: <DeeptiSana>  
-- ALTER date: <22/10/2018>  
-- Description: <CustomerAddress_GetByCustomerID>  
-- Author: <kiranmai>  
-- ALTER date: <23/09/2022>  
-- Description: CaseID: 2817 - Update Logic for Shipping Address Dropdown  
-- =============================================  
-- Author: Nagasai  
-- Modified date: 2022-10-19  
-- Description: getting only active locations and accounts  
-- added status checks while getting address  
-- =============================================  
-- Author:  Nagasai Mudara    
-- Modified date: 02.09.2023  
-- Description: Add Address 3 Field to Shipping Addresses  
-- SD CASE - 5743  
-- =================================================   
-- EXEC [CustomerAddress_GetByCustomerIDAddressType] 119304, 'B'  
CREATE PROCEDURE [dbo].[CustomerAddress_GetByCustomerIDAddressType] @CustomerID INT
	,@AddressType VARCHAR(10)
	,@IsActive BIT = 1
AS
BEGIN
	INSERT INTO CustomerAddress (
		CustomerID
		,AddressType
		,IsCorp
		,IsVIewable
		,IsActive
		,AddedByID
		,ChangedByID
		,AccountID
		,RelType
		)
	SELECT a.customer_id AS CustomerID
		,'S' AS AddressType
		,a.is_corp IsCorp
		,1 AS isViewable
		,1 isActive
		,99999 AddedByID
		,99999 ChangedByID
		,a.account_id AS AccountID
		,'a' AS RelType
	FROM ipath..account a(NOLOCK)
	LEFT JOIN CustomerAddress c(NOLOCK) ON c.AccountID = a.account_id
		AND a.customer_id = c.CustomerID
		AND AccountID IS NOT NULL
		AND RelType = 'a'
	WHERE Customer_Id = @CustomerID
		AND CustomerAddressID IS NULL
		AND STATUS = 'A'

	INSERT INTO CustomerAddress (
		CustomerID
		,AddressType
		,IsCorp
		,IsVIewable
		,IsActive
		,AddedByID
		,ChangedByID
		,AccountID
		,RelType
		)
	SELECT l.customer_id AS CustomerID
		,'S' AS AddressType
		,0 IsCorp
		,1 AS isViewable
		,1 isActive
		,99999 AddedByID
		,99999 ChangedByID
		,l.location_id AS AccountID
		,'l' AS RelType
	FROM ipath.dbo.[location] l(NOLOCK)
	LEFT JOIN CustomerAddress c(NOLOCK) ON c.AccountID = l.location_id
		AND l.customer_id = c.CustomerID
		AND AccountID IS NOT NULL
		AND RelType = 'l'
	WHERE CustomerId = @CustomerID
		AND l.location_id IS NULL
		AND is_active = 1

	DECLARE @CustAddr TABLE (
		CustomerAddressID INT
		,AttentionToName VARCHAR(500)
		,CustomerAddress VARCHAR(500)
		,AliasName VARCHAR(500)
		,Address1 VARCHAR(500)
		,Address2 VARCHAR(500)
		,Address3 VARCHAR(500)
		,City VARCHAR(500)
		,StateMasterID INT
		,StateName VARCHAR(500)
		,Zipcode VARCHAR(500)
		,CountryMasterID INT
		,CountryName VARCHAR(500)
		,SortOrder INT
		,IsCorp INT
		,AccountID INT
		,RelType VARCHAR(10)
		)

	INSERT INTO @CustAddr
	/** GET ACCOUNT ADDRESS FROM ACCOUNT TABLE **/
	SELECT CustomerAddressID
		,'' AS AttentionToName
		,ISNULL(account_name_other, '') + (
			CASE 
				WHEN NULLIF(account_name_other, '') IS NULL
					THEN ''
				ELSE ' - '
				END
			) + ISNULL(a.address_1, '') + ',' + CASE 
			WHEN a.address_2 IS NOT NULL
				THEN ISNULL(a.address_2, '') + ' '
			ELSE ''
			END + ' ' + ISNULL(a.city, '') + ', ' + ISNULL(S.StateName, '') + ' ' + ISNULL(a.zip, '') + ', ' + ISNULL(Co.CountryName, '') AS CustomerAddress
		,ISNULL(account_name_other, '') AS AliasName
		,ISNULL(a.address_1, '') AS Address1
		,ISNULL(a.address_2, '') AS Address2
		,ISNULL(a.address3, '') AS Address3
		,ISNULL(a.city, '') AS City
		,ISNULL(S.StateMasterID, '') AS StateMasterID
		,ISNULL(S.StateName, '') AS StateName
		,ISNULL(a.zip, '') AS Zipcode
		,ISNULL(Co.CountryMasterID, 1) AS CountryMasterID
		,ISNULL(Co.CountryName, 'United States') AS CountryName
		,0 AS SortOrder
		,CAST(IsCorp AS INT) IsCorp
		,ISNULL(AccountID, '') AS AccountID
		,ISNULL(RelType, '')
	FROM CustomerAddress c(NOLOCK)
	INNER JOIN account a(NOLOCK) ON a.account_id = C.AccountID
		AND C.RelType = 'a'
	LEFT JOIN StateMaster S(NOLOCK) ON S.StateCode = a.[state]
	LEFT JOIN CountryMaster Co(NOLOCK) ON Co.CountryCode = a.country
	WHERE CustomerID = @CustomerID
		AND C.IsActive = @IsActive
		AND STATUS = 'A' --NS:2022-10-19 ADDED to void inactive accounts  
		AND ISNULL(@AddressType, AddressType) = @AddressType
	
	UNION
	
	/** GET LOCATION ADDRESS FROM LOCATION TABLE **/
	SELECT CustomerAddressID
		,'' AS AttentionToName
		,ISNULL(location_name_other, '') + (
			CASE 
				WHEN NULLIF(location_name_other, '') IS NULL
					THEN ''
				ELSE ' - '
				END
			) + ISNULL(l.address_1, '') + ',' + CASE 
			WHEN l.address_2 IS NOT NULL
				THEN ISNULL(l.address_2, '') + ' '
			ELSE ''
			END + ' ' + ISNULL(l.city, '') + ', ' + ISNULL(S.StateName, '') + ' ' + ISNULL(l.zip, '') + ', ' + ISNULL(Co.CountryName, '') AS CustomerAddress
		,ISNULL(location_name_other, '') AS AliasName
		,ISNULL(l.address_1, '') AS Address1
		,ISNULL(l.address_2, '') AS Address2
		,ISNULL(l.address3, '') AS Address3
		,ISNULL(l.city, '') AS City
		,ISNULL(S.StateMasterID, '') AS StateMasterID
		,ISNULL(S.StateName, '') AS StateName
		,ISNULL(l.zip, '') AS Zipcode
		,ISNULL(Co.CountryMasterID, 1) AS CountryMasterID
		,ISNULL(Co.CountryName, 'United States') AS CountryName
		,0 AS SortOrder
		,CAST(IsCorp AS INT) IsCorp
		,ISNULL(AccountID, '') AS AccountID
		,ISNULL(RelType, '')
	FROM CustomerAddress c(NOLOCK)
	INNER JOIN ipath.dbo.[location] l(NOLOCK) ON l.location_id = C.AccountID
		AND C.RelType = 'l'
	LEFT JOIN StateMaster S(NOLOCK) ON S.StateCode = l.[state]
	LEFT JOIN CountryMaster Co(NOLOCK) ON Co.CountryCode = 'US'
	WHERE CustomerID = @CustomerID
		AND C.IsActive = @IsActive
		AND is_active = 1 --NS:2022-10-19 ADDED to void inactive locations  
		AND ISNULL(@AddressType, AddressType) = @AddressType
	
	UNION
	
	/** GET ADDRESSES THAT ARE NOT ACCOUNTS AND LOCATIONS **/
	SELECT CustomerAddressID
		,'' AS AttentionToName
		,ISNULL(c.Address1, '') + ',' + CASE 
			WHEN c.Address2 IS NOT NULL
				THEN ISNULL(c.Address2, '') + ' '
			ELSE ''
			END + ' ' + ISNULL(C.city, '') + ', ' + ISNULL(S.StateName, '') + ' ' + ISNULL(c.Zipcode, '') + ', ' + ISNULL(Co.CountryName, '') AS CustomerAddress
		,'' AS AliasName
		,ISNULL(c.Address1, '') AS Address1
		,ISNULL(c.Address2, '') AS Address2
		,ISNULL(c.address3, '') AS Address3
		,ISNULL(C.City, '') AS City
		,ISNULL(S.StateMasterID, '') AS StateMasterID
		,ISNULL(S.StateName, '') AS StateName
		,ISNULL(c.Zipcode, '') AS Zipcode
		,ISNULL(Co.CountryMasterID, 1) AS CountryMasterID
		,ISNULL(Co.CountryName, 'United States') AS CountryName
		,0 AS SortOrder
		,CAST(IsCorp AS INT) IsCorp
		,ISNULL(c.AccountID, 0) AS AccountID
		,ISNULL(c.RelType, '')
	FROM CustomerAddress c(NOLOCK)
	INNER JOIN MobilityOrderItems MOI(NOLOCK) ON MOI.CustomerShippingAddressID = c.CustomerAddressID
		AND MOI.IsActive = 1
	LEFT JOIN StateMaster S(NOLOCK) ON S.StateMasterID = c.StateMasterID
	LEFT JOIN CountryMaster Co(NOLOCK) ON Co.CountryMasterID = c.CountryMasterID
	WHERE CustomerID = @CustomerID
		AND C.IsActive = @IsActive
		AND ISNULL(c.AccountID, 0) = 0
		AND ISNULL(@AddressType, AddressType) = @AddressType
		AND isnull(c.StateMasterID, 0) > 0
		AND MOI.LineStatusMAsterID NOT IN (
			5001
			,7001
			)
	
	UNION
	
	--- JOIN Address based on OldbIllingAddressID   
	SELECT CustomerAddressID
		,'' AS AttentionToName
		,ISNULL(c.Address1, '') + ',' + CASE 
			WHEN c.Address2 IS NOT NULL
				THEN ISNULL(c.Address2, '') + ' '
			ELSE ''
			END + ' ' + ISNULL(C.city, '') + ', ' + ISNULL(S.StateName, '') + ' ' + ISNULL(c.Zipcode, '') + ', ' + ISNULL(Co.CountryName, '') AS CustomerAddress
		,'' AS AliasName
		,ISNULL(c.Address1, '') AS Address1
		,ISNULL(c.Address2, '') AS Address2
		,ISNULL(c.address3, '') AS Address3
		,ISNULL(C.City, '') AS City
		,ISNULL(S.StateMasterID, '') AS StateMasterID
		,ISNULL(S.StateName, '') AS StateName
		,ISNULL(c.Zipcode, '') AS Zipcode
		,ISNULL(Co.CountryMasterID, 1) AS CountryMasterID
		,ISNULL(Co.CountryName, 'United States') AS CountryName
		,0 AS SortOrder
		,CAST(IsCorp AS INT) IsCorp
		,ISNULL(c.AccountID, 0) AS AccountID
		,ISNULL(c.RelType, '')
	FROM CustomerAddress c(NOLOCK)
	INNER JOIN MobilityOrderItems MOI(NOLOCK) ON MOI.OldBillingAddressID = c.CustomerAddressID
		AND MOI.IsActive = 1
	LEFT JOIN StateMaster S(NOLOCK) ON S.StateMasterID = c.StateMasterID
	LEFT JOIN CountryMaster Co(NOLOCK) ON Co.CountryMasterID = c.CountryMasterID
	WHERE CustomerID = @CustomerID
		AND C.IsActive = @IsActive
		AND ISNULL(c.AccountID, 0) = 0
		AND ISNULL(@AddressType, AddressType) = 'B'
		AND isnull(c.StateMasterID, 0) > 0
		AND MOI.LineStatusMAsterID NOT IN (
			5001
			,7001
			)
	
	UNION
	
	SELECT 0 AS CustomerAddressID
		,'' AS AttentionToName
		,'New' AS CustomerAddress
		,'' AS AliasName
		,''
		,''
		,''
		,''
		,''
		,''
		,''
		,''
		,''
		,1 AS SortOrder
		,2
		,0 AccountID
		,'' RelType

	SELECT *
		,AccountID AS RelTypeID
	FROM (
		SELECT *
		FROM @CustAddr
		) TT
	ORDER BY IsCorp DESC
		,AliasName
		,StateName
		,City
		,Address1
		--,AccountID DESC  
		--,CustomerAddress  
END
