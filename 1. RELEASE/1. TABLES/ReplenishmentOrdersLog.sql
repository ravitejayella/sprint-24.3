USE [mobility]
GO

IF NOT EXISTS (
		SELECT 1
		FROM sys.tables
		WHERE NAME = 'ReplenishmentOrdersLog'
		)
BEGIN
	PRINT 'ReplenishmentOrdersLog'

	CREATE TABLE [dbo].[ReplenishmentOrdersLog] (
		ReplenishmentOrdersLogID INT PRIMARY KEY IDENTITY(3000, 1)
		,DeviceID INT NOT NULL
		,CarrierID INT NOT NULL
		,CustomerID INT NOT NULL
		,CustomerXCarrierAccountsID INT NOT NULL
		,MinimumQty INT NOT NULL
		,ReplenishQty INT NOT NULL
		,AvailableQty INT NOT NULL
		,RefillQty INT NOT NULL
		,IsActive BIT DEFAULT 1 NOT NULL
		,IsReplenished BIT NOT NULL
		,DeviceXML VARCHAR(MAX) DEFAULT NULL
		,AddedbyID INT NOT NULL
		,AddedDateTime DATETIME DEFAULT GETDATE()
		,UpdatedByID INT NULL
		,UpdatedDateTime DATETIME NULL
		);
END
