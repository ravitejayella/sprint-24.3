use mobility
go

CREATE TABLE dbo.TempTableAddOnConfig123880 (
    OrderItemID INT,
    APNValue VARCHAR(150),
    IPAddressValue VARCHAR(150)
);

CREATE TABLE dbo.TempTableAddOnConfig123755 (
    OrderItemID INT,
    APNValue VARCHAR(150),
    IPAddressValue VARCHAR(150)
);
 

select * from  [dbo].[TempTableAddOnConfig123880]
select * from  [dbo].[TempTableAddOnConfig123755]


--DROP TABLE [dbo].[TempTableAddOnConfig123880]
--DROP TABLE [dbo].[TempTableAddOnConfig123755]
