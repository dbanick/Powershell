set nocount on
declare @dbname varchar(255)
declare @IsAutoClose int
declare @IsAutoShrink int
declare @Recovery varchar(100)
declare @Status varchar(100)
declare @IsPublished int
declare @IsMergePublished int
declare @IsSubscribed int
Declare @IsAutoCreateStatistics int
Declare @IsAutoUpdateStatistics int
Declare @IsTornPageDetectionEnabled int
Declare @Updateability varchar(100)
Declare @UserAccess varchar(100)
Declare @DBOwner varchar(100)
Declare @LogShippedPri int
Declare @LogShippedSec int
Declare @PageVerify int
Declare @MirrorRole nvarchar(20)
Declare @MirrorPartner nvarchar(50)
Declare @MirrorType int

Declare @cmd nvarchar(300)
Declare @Fulltext int
Declare @version1 int
set @version1 = (select cast(substring(CAST(serverproperty('ProductVersion') as varchar(50)), 0, patindex('%.%', CAST(serverproperty('ProductVersion') as varchar(50)))) as int))

create table #db_property 
	(dbname varchar(255),
	DatabaseOwner varchar(100) null,
	IsAutoClose int,
	IsAutoShrink int,
	[Recovery] varchar(100),
	[Status] varchar(100),
	[IsAutoCreateStatistics] int,
	[IsAutoUpdateStatistics] int,
	[PageVerify] int,
	[Updateability] varchar(100),
	[UserAccess] varchar(200),
	[IsPublished] int,
	[IsMergePublished] int,
	[IsSubscribed] int,
	[Fulltext] int,
	[LogShipPri] int,
	[LogShipSec] int,
	[MirrorRole] nvarchar(20),
	[MirrorPartner] nvarchar(50),
	[MirrorType] int)
declare dbcursor CURSOR for SELECT name FROM master..sysdatabases
Open dbcursor

Fetch next from dbcursor
into @dbname

WHILE @@FETCH_STATUS = 0
	BEGIN 
	  
	  set @DBOwner = (select rtrim(SUSER_SNAME(sid)) from master.dbo.sysdatabases where name=@dbname)
	  set @Status = (select cast(databasepropertyex(@dbname, 'status') as varchar(100)))
	  If @version1 = 8
				Begin
					set @cmd = 'select @LogShippedPri=count(*) from msdb..log_shipping_primaries where primary_database_name ='''+@dbname+''''
					exec sp_executesql @cmd, N'@dbname varchar(255), @LogShippedPri int output', @dbname=@dbname, @LogShippedPri=@LogShippedPri output
					set @cmd = 'select @LogShippedSec=count(*) from msdb..log_shipping_secondaries where secondary_database_name ='''+@dbname+''''
					exec sp_executesql @cmd, N'@dbname varchar(255), @LogShippedSec int output', @dbname=@dbname, @LogShippedSec=@LogShippedSec output
					set @cmd =''
				End
			 Else
				Begin
					set @cmd = 'select @LogShippedPri=count(*) from msdb..log_shipping_primary_databases where primary_database ='''+@dbname+''''
					exec sp_executesql @cmd, N'@dbname varchar(255), @LogShippedPri int output', @dbname=@dbname, @LogShippedPri=@LogShippedPri output
					set @cmd = 'select @LogShippedSec=count(*) from msdb..log_shipping_secondary_databases where secondary_database ='''+@dbname+''''
					exec sp_executesql @cmd, N'@dbname varchar(255), @LogShippedSec int output', @dbname=@dbname, @LogShippedSec=@LogShippedSec output
					set @cmd =''
				End
	
	-- Mirroring
	If @version1 > 8
		Begin
			set @cmd = 'SELECT @MirrorRole=CAST(mirroring_role_desc as nvarchar(20)), @MirrorPartner=CAST(mirroring_partner_instance as nvarchar(50)), @MirrorType=mirroring_safety_level from sys.database_mirroring where DB_NAME(database_id) ='''+@dbname+''''
			exec sp_executesql @cmd, N'@dbname varchar(255), @MirrorRole nvarchar(20) output, @MirrorPartner nvarchar(50) output, @MirrorType int output', @dbname=@dbname, @MirrorRole=@MirrorRole output, @MirrorPartner=@MirrorPartner output, @MirrorType=@MirrorType output
		End
		
	If @Status = 'ONLINE'
		Begin
			  set @IsAutoClose = (select cast(databasepropertyex(@dbname, 'IsAutoClose') as int))
			  set @IsAutoShrink =(select cast(databasepropertyex(@dbname, 'IsAutoShrink') as int))
			  set @Recovery = (select cast(databasepropertyex(@dbname, 'Recovery') as varchar(100)))
			  set @IsPublished = (select cast(databasepropertyex(@dbname, 'IsPublished') as int))
			  set @IsMergePublished =(select cast(databasepropertyex(@dbname, 'IsMergePublished') as int))
			  set @IsSubscribed =(select cast(databasepropertyex(@dbname, 'IsSubscribed') as int))
			  set @IsAutoCreateStatistics = (select cast(databasepropertyex(@dbname, 'IsAutoCreateStatistics') as int))
			  set @IsAutoUpdateStatistics = (select cast(databasepropertyex(@dbname, 'IsAutoUpdateStatistics') as int))
			  --set @IsTornPageDetectionEnabled = (select cast(databasepropertyex(@dbname, 'IsTornPageDetectionEnabled') as int))
			  set @Updateability = (select cast(databasepropertyex(@dbname, 'Updateability') as varchar(100)))
			  set @UserAccess = (select cast(databasepropertyex(@dbname, 'UserAccess') as varchar(100)))

			If @version1 = 8
				set @PageVerify = (select cast(databasepropertyex(@dbname, 'IsTornPageDetectionEnabled') as int))
			  Else
				Begin
					set @cmd = 'select @PageVerify=page_verify_option from master.sys.databases where name ='''+@dbname+''''
					exec sp_executesql @cmd, N'@dbname varchar(255), @PageVerify int output', @dbname=@dbname, @PageVerify=@PageVerify output
					PRINT @PageVerify
					set @cmd =''
				End
			
			
			  -- Fulltext
			  
			  If @version1 = 8
					set @cmd = 'select @Fulltext=count(*) from ['+@dbname+'].[dbo].[sysfulltextcatalogs]'
				 Else
					set @cmd = 'select @Fulltext=count(*) from ['+@dbname+'].[sys].[fulltext_indexes]'
				exec sp_executesql @cmd, N'@dbname varchar(255), @Fulltext int output', @dbname=@dbname, @Fulltext=@Fulltext output
				
				set @cmd = ''
				
			If @version1 = 8
				Begin
					set @cmd = 'select @LogShippedPri=count(*) from msdb..log_shipping_primaries where primary_database_name ='''+@dbname+''''
					exec sp_executesql @cmd, N'@dbname varchar(255), @LogShippedPri int output', @dbname=@dbname, @LogShippedPri=@LogShippedPri output
					set @cmd = 'select @LogShippedSec=count(*) from msdb..log_shipping_secondaries where secondary_database_name ='''+@dbname+''''
					exec sp_executesql @cmd, N'@dbname varchar(255), @LogShippedSec int output', @dbname=@dbname, @LogShippedSec=@LogShippedSec output
					set @cmd =''
				End
			 Else
				Begin
					set @cmd = 'select @LogShippedPri=count(*) from msdb..log_shipping_primary_databases where primary_database ='''+@dbname+''''
					exec sp_executesql @cmd, N'@dbname varchar(255), @LogShippedPri int output', @dbname=@dbname, @LogShippedPri=@LogShippedPri output
					set @cmd = 'select @LogShippedSec=count(*) from msdb..log_shipping_secondary_databases where secondary_database ='''+@dbname+''''
					exec sp_executesql @cmd, N'@dbname varchar(255), @LogShippedSec int output', @dbname=@dbname, @LogShippedSec=@LogShippedSec output
					set @cmd =''
				End
			
			
		END
		
	insert #db_property
	values(@dbname, @DBOwner,@IsAutoClose,@IsAutoShrink,@Recovery,@Status,@IsAutoCreateStatistics,@IsAutoUpdateStatistics,@PageVerify,@Updateability,@UserAccess,@IsPublished,@IsMergePublished, @IsSubscribed, @Fulltext,@LogShippedPri,@LogShippedSec,@MirrorRole,@MirrorPartner,@MirrorType)
	
	--Cleanup
	Set @DBOwner=null
	Set @IsAutoClose=null
	Set @IsAutoShrink=null
	Set @Recovery=null
	Set @Status=null
	Set @IsAutoCreateStatistics=null
	Set @IsAutoUpdateStatistics=null
	Set @IsTornPageDetectionEnabled=null
	Set @Updateability=null
	Set @UserAccess=null
	Set @IsPublished=null
	Set @IsMergePublished=null
	Set @IsSubscribed=null
	Set @Fulltext=null
	Set @LogShippedPri=null
	Set @LogShippedSec=null
	Set @MirrorRole=null
	Set @MirrorPartner=null
	Set @MirrorType=null

Fetch next from dbcursor
	into @dbname
	END
--select * from #db_property

select dbname,
DatabaseOwner, 
case when IsAutoClose = 1 then 'Yes' when IsAutoClose is null then 'N/A' else 'No' end as 'IsAutoClose', 
case when IsAutoShrink = 1 then 'Yes' when IsAutoShrink is null then 'N/A' else 'No' end as 'IsAutoShrink', 
case when [Recovery] is null then 'N/A' else [Recovery] end as 'Recovery', 
case when Status is null then 'N/A' else Status end as 'Status',
case when IsAutoCreateStatistics = 1 then 'Yes' when IsAutoCreateStatistics is null then 'N/A' else 'No' end as 'IsAutoCreateStatistics',
case when IsAutoUpdateStatistics = 1 then 'Yes' when IsAutoUpdateStatistics is null then 'N/A' else 'No' end as 'IsAutoUpdateStatistics',
case when PageVerify = 1 then 'TORN_PAGE_DETECTION' when PageVerify = 2 then 'CHECKSUM' when PageVerify is null then 'N/A' else 'None' end as 'PageVerify',
case when Updateability is null then 'N/A' else Updateability end as 'Updateability',
case when UserAccess is null then 'N/A' else UserAccess end as 'UserAccess',
case when IsPublished = 1 then 'Yes' when IsPublished is null then 'N/A' else 'No' end as 'IsPublished', 
case when IsMergePublished = 1 then 'Yes' when IsMergePublished is null then 'N/A' else 'No' end as 'IsMergePublished', 
case when IsSubscribed = 1 then 'Yes' when IsSubscribed is null then 'N/A' else 'No' end as 'IsSubscribed',
case when [Fulltext] > 0 then 'Yes' when [Fulltext] is null then 'N/A' else 'No' end as FullTextIndexes,
case when [LogShipPri]= 1 then 'Yes' when [LogShipPri] is null then 'N/A' else 'No' end as 'Is Log Shipping Primary',
case when [LogShipSec]= 1 then 'Yes' when [LogShipSec] is null then 'N/A' else 'No' end as 'Is Log Shipping Secondary',
case when [MirrorRole] is null then 'N/A' else [MirrorRole] end as 'MirrorRole',
case when [MirrorType] = 0 then 'Unknown' when [MirrorType] = 1 then 'Asynchronous' when [MirrorType] = 2 then 'Synchronous' else 'N/A' end as 'MirrorType',
case when [MirrorPartner] is null then 'N/A' else [MirrorPartner] end as 'MirrorPartner'
from #db_property order by dbname

CLOSE dbcursor
DEALLOCATE dbcursor
go
drop table #db_property
go
