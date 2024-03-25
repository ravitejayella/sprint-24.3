USE [mobility]
GO

IF NOT EXISTS (
		SELECT TOP 1 *
		FROM INFORMATION_SCHEMA.COLUMNS
		WHERE TABLE_NAME = 'MobilityOrderItems'
			AND COLUMN_NAME = 'ReplenishmentCCAID'
		)
BEGIN
	PRINT 'ReplenishmentCCAID'

	ALTER TABLE MobilityOrderItems ADD ReplenishmentCCAID INT NULL;
END


