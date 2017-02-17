set nocount on
DECLARE @dbname varchar(255)
DECLARE @backupdate1 datetime
DECLARE @backupdate2 datetime
DECLARE @backupdate3 datetime
DECLARE @backupdate4 datetime
DECLARE @backupdate5 datetime
DECLARE @backupdate6 datetime
DECLARE @backupdate7 datetime
DECLARE @logbackupdate1 datetime
DECLARE @logbackupdate2 datetime
DECLARE @logbackupdate3 datetime
DECLARE @logbackupdate4 datetime
DECLARE @logbackupdate5 datetime
DECLARE @logbackupdate6 datetime
DECLARE @logbackupdate7 datetime
DECLARE @diffbackupdate1 datetime
DECLARE @diffbackupdate2 datetime
DECLARE @diffbackupdate3 datetime
DECLARE @diffbackupdate4 datetime
DECLARE @diffbackupdate5 datetime
DECLARE @diffbackupdate6 datetime
DECLARE @diffbackupdate7 datetime
DECLARE @recmodel varchar(15)
DECLARE @FullBackupIntv varchar(10)
DECLARE @DiffBackupIntv varchar(10)
DECLARE @LogBackupIntv varchar(10)
create table #Backup (
	dbName varchar(255),
	LastFullBackupDate varchar(20) null,
	LastDiffBackupDate varchar(20)null,
	LastLogBackupDate varchar(20)null,
	RecoveryModel varchar(15),
	FullBackupIntv varchar(10) null,
	DiffBackupIntv varchar(10) null,
	LogBackupIntv varchar(10) null
	)
Create table #BackupIntv 
	(
	BackupIntv int null
	)
declare dbcursor CURSOR for SELECT name FROM master..sysdatabases
Open dbcursor

Fetch next from dbcursor
into @dbname

WHILE @@FETCH_STATUS = 0
	BEGIN 
		USE msdb
		-- Gather Recovery Model
		set @recmodel = (select CAST(DATABASEPROPERTYEX(@dbname, 'Recovery')as varchar(15)))

		-- Gather Full Backup History
		set @backupdate1 = (SELECT TOP 1 backup_start_date
		FROM backupset where database_name = @dbname
		and (type = 'D')
		ORDER BY  backup_start_date DESC)

		set @backupdate2 = (SELECT TOP 1 backup_start_date
		FROM backupset where database_name = @dbname and backup_start_date < @backupdate1
		and (type = 'D')
		ORDER BY  backup_start_date DESC)

		set @backupdate3 = (SELECT TOP 1 backup_start_date
		FROM backupset where database_name = @dbname and backup_start_date < @backupdate2
		and (type = 'D')
		ORDER BY  backup_start_date DESC)

		set @backupdate4 = (SELECT TOP 1 backup_start_date
		FROM backupset where database_name = @dbname and backup_start_date < @backupdate3
		and (type = 'D')
		ORDER BY  backup_start_date DESC)

		set @backupdate5 = (SELECT TOP 1 backup_start_date
		FROM backupset where database_name = @dbname and backup_start_date < @backupdate4
		and (type = 'D')
		ORDER BY  backup_start_date DESC)

		set @backupdate6 = (SELECT TOP 1 backup_start_date
		FROM backupset where database_name = @dbname and backup_start_date < @backupdate5
		and (type = 'D')
		ORDER BY  backup_start_date DESC)

		set @backupdate7 = (SELECT TOP 1 backup_start_date
		FROM backupset where database_name = @dbname and backup_start_date < @backupdate6
		and (type = 'D')
		ORDER BY  backup_start_date DESC)

		-- Gather Log Backup History
		set @logbackupdate1 = (SELECT TOP 1 backup_start_date
		FROM backupset where database_name = @dbname
		and (type = 'L')
		ORDER BY  backup_start_date DESC)

		set @logbackupdate2 = (SELECT TOP 1 backup_start_date
		FROM backupset where database_name = @dbname and backup_start_date < @logbackupdate1
		and (type = 'L')
		ORDER BY  backup_start_date DESC)

		set @logbackupdate3 = (SELECT TOP 1 backup_start_date
		FROM backupset where database_name = @dbname and backup_start_date < @logbackupdate2
		and (type = 'L')
		ORDER BY  backup_start_date DESC)

		set @logbackupdate4 = (SELECT TOP 1 backup_start_date
		FROM backupset where database_name = @dbname and backup_start_date < @logbackupdate3
		and (type = 'L')
		ORDER BY  backup_start_date DESC)

		set @logbackupdate5 = (SELECT TOP 1 backup_start_date
		FROM backupset where database_name = @dbname and backup_start_date < @logbackupdate4
		and (type = 'L')
		ORDER BY  backup_start_date DESC)

		set @logbackupdate6 = (SELECT TOP 1 backup_start_date
		FROM backupset where database_name = @dbname and backup_start_date < @logbackupdate5
		and (type = 'L')
		ORDER BY  backup_start_date DESC)

		set @logbackupdate7 = (SELECT TOP 1 backup_start_date
		FROM backupset where database_name = @dbname and backup_start_date < @logbackupdate6
		and (type = 'L')
		ORDER BY  backup_start_date DESC)

		-- Gather Differential Backup history
		set @diffbackupdate1 = (SELECT TOP 1 backup_start_date
		FROM backupset where database_name = @dbname
		and (type = 'I')
		ORDER BY  backup_start_date DESC)

		set @diffbackupdate2 = (SELECT TOP 1 backup_start_date
		FROM backupset where database_name = @dbname and backup_start_date < @diffbackupdate1
		and (type = 'I')
		ORDER BY  backup_start_date DESC)

		set @diffbackupdate3 = (SELECT TOP 1 backup_start_date
		FROM backupset where database_name = @dbname and backup_start_date < @diffbackupdate2
		and (type = 'I')
		ORDER BY  backup_start_date DESC)

		set @diffbackupdate4 = (SELECT TOP 1 backup_start_date
		FROM backupset where database_name = @dbname and backup_start_date < @diffbackupdate3
		and (type = 'I')
		ORDER BY  backup_start_date DESC)

		set @diffbackupdate5 = (SELECT TOP 1 backup_start_date
		FROM backupset where database_name = @dbname and backup_start_date < @diffbackupdate4
		and (type = 'I')
		ORDER BY  backup_start_date DESC)

		set @diffbackupdate6 = (SELECT TOP 1 backup_start_date
		FROM backupset where database_name = @dbname and backup_start_date < @diffbackupdate5
		and (type = 'I')
		ORDER BY  backup_start_date DESC)

		set @diffbackupdate7 = (SELECT TOP 1 backup_start_date
		FROM backupset where database_name = @dbname and backup_start_date < @diffbackupdate6
		and (type = 'I')
		ORDER BY  backup_start_date DESC)
		
		insert #BackupIntv
		select datediff(mi,@backupdate2,@backupdate1) 
		union all select datediff(mi,@backupdate3,@backupdate2)
		union all select datediff(mi,@backupdate4,@backupdate3)
		union all select datediff(mi,@backupdate5,@backupdate4)
		union all select datediff(mi,@backupdate6,@backupdate5)
		union all select datediff(mi,@backupdate7,@backupdate6)
				
		set @FullBackupIntv = (select case when avg(BackupIntv) > 1499 then cast(cast(round(CAST(avg(BackupIntv)as numeric(20,2))/1440,2) as numeric(20,2)) AS varchar)+' days' when avg(BackupIntv) > 59 then cast(cast(round(CAST(avg(BackupIntv)as numeric(20,2))/60,2) as numeric(20,2)) AS varchar)+' hrs'  else cast(avg(BackupIntv) AS varchar)+' min' end from #BackupIntv)
		Truncate table #BackupIntv

		insert #BackupIntv
		select datediff(mi,@logbackupdate2,@logbackupdate1) 
		union all select datediff(mi,@logbackupdate3,@logbackupdate2)
		union all select datediff(mi,@logbackupdate4,@logbackupdate3)
		union all select datediff(mi,@logbackupdate5,@logbackupdate4)
		union all select datediff(mi,@logbackupdate6,@logbackupdate5)
		union all select datediff(mi,@logbackupdate7,@logbackupdate6)

		set @LogBackupIntv = (select case when avg(BackupIntv) > 1499 then cast(cast(round(CAST(avg(BackupIntv)as numeric(20,2))/1440,2) as numeric(20,2)) AS varchar)+' days' when avg(BackupIntv) > 59 then cast(cast(round(CAST(avg(BackupIntv)as numeric(20,2))/60,2) as numeric(20,2)) AS varchar)+' hrs'  else cast(avg(BackupIntv) AS varchar)+' min' end from #BackupIntv)
		Truncate table #BackupIntv 

		insert #BackupIntv
		select datediff(mi,@diffbackupdate2,@diffbackupdate1) 
		union all select datediff(mi,@diffbackupdate3,@diffbackupdate2)
		union all select datediff(mi,@diffbackupdate4,@diffbackupdate3)
		union all select datediff(mi,@diffbackupdate5,@diffbackupdate4)
		union all select datediff(mi,@diffbackupdate6,@diffbackupdate5)
		union all select datediff(mi,@diffbackupdate7,@diffbackupdate6)
				
		set @DiffBackupIntv = (select case when avg(BackupIntv) > 1499 then cast(cast(round(CAST(avg(BackupIntv)as numeric(20,2))/1440,2) as numeric(20,2)) AS varchar)+' days' when avg(BackupIntv) > 59 then cast(cast(round(CAST(avg(BackupIntv)as numeric(20,2))/60,2) as numeric(20,2)) AS varchar)+' hrs'  else cast(avg(BackupIntv) AS varchar)+' min' end from #BackupIntv)
		Truncate table #BackupIntv

		insert #Backup
		VALUES (@dbname,cast(@backupdate1 as varchar), cast(@diffbackupdate1 as varchar), cast(@logbackupdate1 as varchar), @recmodel,cast(@FullBackupIntv as varchar), cast(@DiffBackupIntv as varchar),cast(@LogBackupIntv as varchar))

		Truncate table #BackupIntv
		
		Fetch next from dbcursor
		into @dbname
	END
update #Backup
set LastFullBackupDate = 'None' where LastFullBackupDate IS NULL
update #Backup
set LastDiffBackupDate = 'None' where LastDiffBackupDate IS NULL
update #Backup
set LastLogBackupDate = 'None' where LastLogBackupDate IS NULL
update #Backup
set FullBackupIntv = '' where FullBackupIntv IS NULL
update #Backup
set LogBackupIntv = '' where LogBackupIntv IS NULL
update #Backup
set DiffBackupIntv = '' where DiffBackupIntv IS NULL
select * from #Backup where databasepropertyex(dbName, 'status') = 'ONLINE' and dbName <> 'tempdb' order by dbName --where BackupDate = 'None' or LogBackupDate = 'None'

drop table #Backup
drop table #BackupIntv
CLOSE dbcursor
DEALLOCATE dbcursor