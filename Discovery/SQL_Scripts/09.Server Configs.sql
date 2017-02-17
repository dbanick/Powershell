use master
go

declare @version int
set @version = (select cast(substring(CAST(serverproperty('ProductVersion') as varchar(50)), 1,patindex('%.%',CAST(serverproperty('ProductVersion') as varchar(50)))-1 ) as int))


IF @version = 8
	select comment, value from syscurconfigs order by comment
If @version > 8
	select name, value_in_use from sys.configurations order by name


go