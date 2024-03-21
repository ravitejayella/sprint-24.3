use mobility
go

select * from EquipmentInventory 
where CustomerXCarrierAccountsID is not null
order by 1 desc

DECLARE @rand int = 2
select top @rand * from ReplenishmentOrdersLog

SELECT * FROM SYS.TABLES WHERE NAME LIKE '%request%'


declare @Count  int
set @Count = 1
SELECT @Count = COUNT(*)
			FROM ReplenishmentOrdersLog(NOLOCK)
			WHERE IsActive = 1
				AND ISNULL(IsReplenished, 0) = 1
			

			select @Count



begin try
	declare @rand int = 20
	select 1/0
end try
begin catch
	select @rand
end catch