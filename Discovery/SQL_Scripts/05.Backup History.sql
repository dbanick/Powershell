use msdb
go
set nocount on
DECLARE @dbname varchar(255)
create table #t_Backup_History (
	DbName varchar(255),
	[Type] varchar(20), 
	backup_start_date datetime,
	backup_finish_date datetime,
	DurationMINs int, 
	size bigint, 
	physical_device_name varchar(4000)
	)
declare dbcursor CURSOR for SELECT name FROM master..sysdatabases
Open dbcursor

Fetch next from dbcursor
into @dbname

WHILE @@FETCH_STATUS = 0
	BEGIN 

		--Full
		insert into #t_Backup_History
		SELECT TOP 15 @dbname, 'Full',b.backup_start_date, b.backup_finish_date, datediff(mi,b.backup_start_date, b.backup_finish_date), b.backup_size, a.physical_device_name
		from backupmediafamily a, backupset b
	 	where a.media_set_id=b.media_set_id and b.database_name = @dbname
		and (b.type = 'D')
		ORDER BY  b.backup_start_date DESC
		
		--Diff
		insert into #t_Backup_History
		SELECT TOP 15 @dbname, 'Differential',b.backup_start_date, b.backup_finish_date, datediff(mi,b.backup_start_date, b.backup_finish_date), b.backup_size, a.physical_device_name
		from backupmediafamily a, backupset b
	 	where a.media_set_id=b.media_set_id and b.database_name = @dbname
		and (b.type = 'I')
		ORDER BY  b.backup_start_date DESC
		
		--Log
		insert into #t_Backup_History
		SELECT TOP 15 @dbname, 'Log',b.backup_start_date, b.backup_finish_date, datediff(mi,b.backup_start_date, b.backup_finish_date), b.backup_size, a.physical_device_name
		from backupmediafamily a, backupset b
	 	where a.media_set_id=b.media_set_id and b.database_name = @dbname
		and (b.type = 'L')
		ORDER BY  b.backup_start_date DESC
		
		Fetch next from dbcursor
		into @dbname
	END
CLOSE dbcursor
DEALLOCATE dbcursor




select * from #t_Backup_History order by DbName, Type,backup_start_date desc

go
drop table #t_Backup_History