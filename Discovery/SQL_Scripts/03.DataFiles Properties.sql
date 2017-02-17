		  Use master
		  go

		  IF  EXISTS (SELECT * FROM tempdb..sysobjects with (nolock) WHERE name like '%##drives%' AND type in (N'U'))
		  DROP TABLE ##drives
		  IF  EXISTS (SELECT * FROM tempdb..sysobjects with (nolock) WHERE name like '%##database%' AND type in (N'U'))
		  DROP TABLE ##database
		  IF  EXISTS (SELECT * FROM tempdb..sysobjects with (nolock) WHERE name like '%##db_space_info%' AND type in (N'U'))
		  DROP TABLE ##db_space_info

		  DECLARE @hr int
		  declare @exec varchar(500)
		  DECLARE @fso int
		  DECLARE @drive nchar(1)
		  DECLARE @odrive int
		  DECLARE @TotalSize nvarchar(20)
		  DECLARE @MB numeric(20,2) ; SET @MB = 1048576.00

		  CREATE TABLE ##drives (
		  drive nchar(1) collate database_default PRIMARY KEY,
		  FreeSpace numeric(20,2) NULL,
		  TotalSize numeric(20,2) NULL
		  )

		  INSERT ##drives(drive,FreeSpace)
		  EXEC master.dbo.xp_fixeddrives

		  CREATE TABLE ##database (dbname nvarchar(128) collate database_default)

		  INSERT ##database(dbname)
		  SELECT name FROM sysdatabases --with (nolock)
		  where (512 & status) <> 512
		  and (32 & status) <> 32
		  and cmptlevel > 70

		  DECLARE @dbname nvarchar(128)
		  DECLARE @sql nvarchar(4000)
		  CREATE TABLE ##db_space_info(
		  dbname nvarchar(128) collate database_default,
		  fgname nvarchar(50) collate database_default null,
		  lname nvarchar(400) collate database_default,
		  phname nvarchar(500) collate database_default,
		  used_mb numeric(20,2),
		  percent_used nvarchar(10) collate database_default,
		  autogrow bit,growth_check bit
		  )

		  DECLARE dbinfocur CURSOR LOCAL FAST_FORWARD FOR SELECT dbname from ##database ORDER by dbname

		  OPEN dbinfocur

		  FETCH NEXT FROM dbinfocur
		  INTO @dbname

		  WHILE @@FETCH_STATUS=0
		  BEGIN
		  set @sql = 'use [' + @dbname +']'
		  set @sql = @sql + ' insert into ##db_space_info
		  select @dbname, sfg.groupname as fgname,lname=rtrim([name]), phname=rtrim(filename),
		  used_mb=convert(numeric(20,2),convert(numeric(20,2),FILEPROPERTY([name],''SpaceUsed''))/128),
		  case when convert(numeric(20,2),convert(numeric(20,2),FILEPROPERTY([name],''SpaceUsed''))/128) != 0
		  then convert(nvarchar(10),convert(numeric(20,2),convert(numeric(20,2),convert(numeric(20,2),FILEPROPERTY([name],''SpaceUsed''))/128) / convert(numeric(20,2),convert(numeric(20,2),[size])/128) * 100))
		  else ''0'' end percent_used,
		  case when growth = 0 then 0 else 1 end IsAutogrow,
		  CASE WHEN (sf.status&0x100000) > 0 and [maxsize] > 0 and convert(numeric (20,2),convert(numeric(20,2),convert(numeric(20,2),[size])/128) * (str(growth))/100) + convert(numeric(20,2),convert(numeric(20,2),[size])/128) < [maxsize]/128.0 and convert(numeric (20,2),convert(numeric(20,2),convert(numeric(20,2),[size])/128) * (str(growth))/100) < FreeSpace
		  THEN 1
		  WHEN (sf.status&0x100000) > 0 and [maxsize] = -1 and convert(numeric (20,2),convert(numeric(20,2),convert(numeric(20,2),[size])/128) * (str(growth))/100) < FreeSpace
		  THEN 1
		  WHEN (sf.status&0x100000) < 1 and [maxsize] > 0 and convert(numeric(20,2),growth/128.0) + convert(numeric(20,2),convert(numeric(20,2),[size])/128) < [maxsize]/128.0 and convert(numeric(20,2),growth/128.0) < FreeSpace
		  THEN 1
		  WHEN (sf.status&0x100000) < 1 and [maxsize] = -1 and convert(numeric(20,2),growth/128.0) < FreeSpace
		  THEN 1
		  ELSE 0 end growth_check
		  from sysfiles sf with (nolock)
		  left outer join sysfilegroups sfg with (nolock) on sf.groupid=sfg.groupid,##drives
		  where (drive  = upper(left(filename,1)) COLLATE DATABASE_DEFAULT
		  or drive  = lower(left(filename,1)) COLLATE DATABASE_DEFAULT) order by 1'

		  exec sp_executesql @sql,N'@dbname nvarchar(128) output', @dbname output

		  FETCH NEXT FROM dbinfocur
		  INTO @dbname
		  END

		  CLOSE dbinfocur
		  DEALLOCATE dbinfocur
		  
		  create table #db_Files1
			(name varchar(400),
			fileid int,
			filename nvarchar(4000),
			Filegroup nvarchar(255),
			Size nvarchar(300),
			MaxSize nvarchar(100),
			Growth nvarchar(100),
			usage nvarchar(100))
		create table #db_Files2
			(Database_Name nvarchar(255),
			Filegroup nvarchar(255),
			Logical_Name nvarchar(400),
			filename nvarchar(4000),
			Size nvarchar(300),
			MaxSize nvarchar(100),
			Growth nvarchar(100))

		DECLARE dbcursor CURSOR LOCAL FAST_FORWARD FOR SELECT dbname from ##database ORDER by dbname
		Open dbcursor

		Fetch next from dbcursor
		into @dbname

		WHILE @@FETCH_STATUS = 0
			BEGIN 
			 set @exec = 'Use ['+@dbname+'] exec sp_helpfile'
		insert into #db_Files1 exec (@exec)

		insert into #db_Files2 select rtrim(@dbname), Filegroup, rtrim(name), filename,Size, MaxSize, Growth from #db_Files1
		truncate table #db_Files1
		Fetch next from dbcursor
				into @dbname
			END

		CLOSE dbcursor
		DEALLOCATE dbcursor
		  
		  update #db_Files2 set Filegroup = 'Log' where Filegroup is null
		  update ##db_space_info set fgname ='Log' where fgname is null
		  
		  select b.Database_Name,b.Filegroup,b.Logical_Name,b.Size,b.MaxSize,a.used_mb,a.percent_used,b.Growth,a.autogrow,a.growth_check,b.filename from ##db_space_info a, #db_Files2 b 
		  where b.Database_Name = a.dbname and b.Filegroup = a.fgname and b.Logical_Name = a.lname
		  order by 1,2,3
		  
		  --select * from ##db_space_info with (nolock) order by dbname, fgname,lname
		  drop table ##drives drop table ##database drop table ##db_space_info
		  drop table #db_Files2
		  drop table #db_Files1
go