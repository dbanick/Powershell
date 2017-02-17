USE [master]
go
SET nocount on
DECLARE @servername varchar(40),
	@version varchar(10),
	@servicePak varchar(3),
	@security varchar(25),
	@edition varchar(100),
	@bitversion varchar(6),
	@collation varchar(40),
	@sort varchar(200),
	@port varchar(6),
	@pipe varchar(100),
	@path varchar(200),
	@errorlog varchar(200),
	@logshipping varchar(5),
	@IsPublished int,
	@IsMergePublished int,
	@IsSubscribed int,
	@rep varchar(5),
	@cmd nvarchar(300),
	@IsFullText int,
	@fulltext varchar(5),
	@dbname varchar(255),
	@version1 int,
	@tcpEnabled int,
	@npEnabled int,
	@ConnectProtocol varchar(20)

--Server Instance Name
SET @servername = (SELECT @@SERVERNAME)
--Version
SET @version = (SELECT CAST(SERVERPROPERTY('ProductVersion') as varchar(50)))
SET @version1 = (SELECT CAST(SUBSTRING(@version, 0, patindex('%.%', @version)) as int))
--Service Pak
SET @servicePak = (SELECT CAST(SERVERPROPERTY('ProductLevel') as varchar(3)))
--Authentication
SET @security = (SELECT CAST(SERVERPROPERTY('IsIntegratedSecurityOnly') as varchar(25)))
IF @security = 0
	SET @security = 'Windows/SQL Server'
ELSE
	SET @security = 'Windows'
--Edition
SET @edition = (SELECT CAST(SERVERPROPERTY('Edition') as varchar(100)))
IF @version like '8.0%'
	SET @edition = 'SQL 2000 ' + @edition + ''
ELSE IF @version like '9.0%'
	SET @edition = 'SQL 2005 ' + @edition + ''
ELSE IF @version like '10.0%'
	SET @edition = 'SQL 2008 ' + @edition + ''
ELSE IF @version like '10.5%'
	SET @edition = 'SQL 2008 R2 ' + @edition + ''
ELSE IF @version like '11.0%'
	SET @edition = 'SQL 2012 ' + @edition + ''
--Bit Architecture
IF @edition like '%64-bit%'
	BEGIN
	SET @bitversion = '64 bit'
	SET @edition = SUBSTRING( @edition, 0, charindex('(', @edition))
	END
ELSE
	SET @bitversion = '32 bit'
--Sort Order
SET @collation = (SELECT CAST(SERVERPROPERTY('Collation') as varchar(50)))
--Relication & Full Text Indexing
CREATE TABLE #dbProperty 
	([IsPublished] int,
	[IsMergePublished] int,
	[IsSubscribed] int,
	[IsFullText] int)

DECLARE dbcursor CURSOR for SELECT name FROM master..sysdatabases where (512 & status) <> 512 and (32 & status) <> 32 and cmptlevel > 70
Open dbcursor

Fetch next from dbcursor
into @dbname

WHILE @@FETCH_STATUS = 0
	BEGIN

		SET @IsPublished = (SELECT CAST(databasepropertyex(@dbname, 'IsPublished') as int))
		SET @IsMergePublished =(SELECT CAST(databasepropertyex(@dbname, 'IsMergePublished') as int))
		SET @IsSubscribed =(SELECT CAST(databasepropertyex(@dbname, 'IsSubscribed') as int))

		IF @version1 = 8
			SET @cmd = 'SELECT @IsFullText=count(*) from ['+@dbname+'].[dbo].[sysfulltextcatalogs]'
		 ELSE
			SET @cmd = 'SELECT @IsFullText=count(*) from ['+@dbname+'].[sys].[fulltext_indexes]'
		exec sp_executesql @cmd, N'@dbname varchar(255), @IsFullText int output', @dbname=@dbname, @IsFullText=@IsFullText output

		insert #dbProperty
		values(@IsPublished, @IsMergePublished, @IsSubscribed, @IsFullText)
		Fetch next from dbcursor
		into @dbname
	END

IF ((SELECT sum(IsPublished) + sum(IsMergePublished) + sum(IsSubscribed) from #dbProperty) > 0)
	SET @rep = 'True'
ELSE
	SET @rep = 'False'

IF ((SELECT sum(IsFullText) from #dbProperty) > 0)
	SET @fulltext = 'True'
ELSE
	SET @fulltext = 'False'

CLOSE dbcursor
DEALLOCATE dbcursor
DROP TABLE #dbProperty

DECLARE @test varchar(200), 
	@testint int,
	@key varchar(100),
	@TcpPortKey varchar(300),
	@ErrorLogKey varchar(100),
	@pipekey varchar(100),
	@defaultpathkey varchar(200),
	@keyhome varchar(400),
	@servicehome varchar(400),
	@TcpEnabledKey varchar(100)
	
CREATE TABLE #ErrorLogLoc (Value varchar(10), data varchar(100))

IF @version1 = 8
	BEGIN
		IF charindex('\',@@SERVERNAME,0) <>0
			BEGIN
			SET @TcpPortKey = 'SOFTWARE\MICROSOFT\Microsoft SQL Server\'+@@servicename+'\MSSQLServer\Supersocketnetlib\TCP'
			SET @pipekey = 'SOFTWARE\MICROSOFT\Microsoft SQL Server\'+@@servicename+'\MSSQLServer\Supersocketnetlib\Np'
			SET @ErrorLogKey = 'SOFTWARE\MICROSOFT\Microsoft SQL Server\'+@@servicename+'\MSSQLServer\Parameters'
			SET @defaultpathkey = 'SOFTWARE\MICROSOFT\Microsoft SQL Server\'+@@servicename+'\Setup'
			END
		ELSE
			BEGIN
			SET @TcpPortKey = 'SOFTWARE\MICROSOFT\MSSQLServer\MSSQLServer\Supersocketnetlib\TCP'
			SET @pipekey = 'SOFTWARE\MICROSOFT\MSSQLServer\MSSQLServer\Supersocketnetlib\Np'
			SET @ErrorLogKey = 'SOFTWARE\MICROSOFT\MSSQLServer\MSSQLServer\Parameters'
			SET @defaultpathkey = 'SOFTWARE\MICROSOFT\MSSQLServer\Setup'
			END
		-- TCP Enabled
		EXEC master..xp_regread @rootkey='HKEY_LOCAL_MACHINE',@key=@TcpPortKey,@value_name='Enabled',@value=@tcpEnabled OUTPUT
		-- Name Pipe Enabled
		EXEC master..xp_regread @rootkey='HKEY_LOCAL_MACHINE',@key=@pipekey,@value_name='Enabled',@value=@npEnabled OUTPUT
		--Port #
		EXEC master..xp_regread @rootkey='HKEY_LOCAL_MACHINE',@key=@TcpPortKey,@value_name='Tcpport',@value=@test OUTPUT
		SET @port = (SELECT convert(varchar(10),@test) as Port)
		--Name Pipe
		EXEC master..xp_regread @rootkey='HKEY_LOCAL_MACHINE',@key=@pipekey,@value_name='PipeName',@value=@test OUTPUT
		SET @pipe = (SELECT convert(varchar(40),@test) as 'Default Pipe')
		--Instance Home
		EXEC master..xp_regread @rootkey='HKEY_LOCAL_MACHINE',@key=@defaultpathkey,@value_name='SQLPath',@value=@test OUTPUT
		SET @path = (SELECT convert(varchar(200),@test) as 'Default Path')
		--Error Log Location
		INSERT INTO #ErrorLogLoc EXEC master..xp_regenumvalues @rootkey='HKEY_LOCAL_MACHINE',@key=@ErrorLogKey
		SET @errorlog = (SELECT SUBSTRING(data,3,len(data)) from #ErrorLogLoc where left(data,2) ='-e')
		DROP TABLE #ErrorLogLoc
		--Log Shipping
		IF (((SELECT count(*) from msdb..log_shipping_primaries) > 0) or ((SELECT count(*) from msdb..log_shipping_secondaries) > 0))
			SET @logshipping = 'True'
				ELSE
			SET @logshipping = 'False'

		goto _Done
	END

IF @version1 >= 9
	BEGIN
		SET @key = (SELECT @@servicename)
		SET @servicehome = 'SYSTEM\CurrentControlSet\Services'
		SET @keyhome = 'SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL'
		
		EXEC master..xp_regread @rootkey='HKEY_LOCAL_MACHINE',@key=@keyhome,@value_name=@key,@value=@test OUTPUT
		SET @keyhome = (SELECT convert(varchar(400),@test) as ServiceName)
		SET @keyhome = 'SOFTWARE\Microsoft\Microsoft SQL Server\'+ @keyhome
		SET @TcpEnabledKey = @keyhome + '\MSSQLServer\Supersocketnetlib\TCP'
		SET @TcpPortKey = @TcpEnabledKey + '\IPAll'
		SET @pipekey = @keyhome + '\MSSQLServer\Supersocketnetlib\Np'
		SET @ErrorLogKey = @keyhome + '\MSSQLServer\Parameters'
		SET @defaultpathkey = @keyhome + '\Setup'
		
		--Port #
		EXEC master..xp_regread @rootkey='HKEY_LOCAL_MACHINE',@key=@TcpPortKey,@value_name='TcpPort',@value=@test OUTPUT
		SET @port = (SELECT convert(varchar(10),@test) as Port)
		IF @port is NULL
			EXEC master..xp_regread @rootkey='HKEY_LOCAL_MACHINE',@key=@TcpPortKey,@value_name='TcpDynamicPorts',@value=@test OUTPUT
		SET @port = (SELECT convert(varchar(10),@test) as Port)
		-- TCP Enabled
		EXEC master..xp_regread @rootkey='HKEY_LOCAL_MACHINE',@key=@TcpEnabledKey,@value_name='Enabled',@value=@tcpEnabled OUTPUT
		-- Name Pipe Enabled
		EXEC master..xp_regread @rootkey='HKEY_LOCAL_MACHINE',@key=@pipekey,@value_name='Enabled',@value=@npEnabled OUTPUT
		--Name Pipe
		EXEC master..xp_regread @rootkey='HKEY_LOCAL_MACHINE',@key=@pipekey,@value_name='PipeName',@value=@test OUTPUT
		SET @pipe = (SELECT convert(varchar(100),@test) as 'Default Pipe')
		--Instance Home
		EXEC master..xp_regread @rootkey='HKEY_LOCAL_MACHINE',@key=@defaultpathkey,@value_name='SQLPath',@value=@test OUTPUT
		SET @path = (SELECT convert(varchar(200),@test) as 'Default Path')
		--Error Log Location
		INSERT INTO #ErrorLogLoc EXEC master..xp_regenumvalues @rootkey='HKEY_LOCAL_MACHINE',@key=@ErrorLogKey
		SET @errorlog = (SELECT SUBSTRING(data,3,len(data)) from #ErrorLogLoc where left(data,2) ='-e')
		DROP TABLE #ErrorLogLoc
		--Log Shipping
		IF (((SELECT count(*) from msdb..log_shipping_primary_databases) > 0) or ((SELECT count(*) from msdb..log_shipping_secondary_databases) > 0))
			SET @logshipping = 'True'
		ELSE
			SET @logshipping = 'False'
		
		goto _Done
	END
_Done:

SELECT @ConnectProtocol = (Case when @tcpEnabled = 1 and @npEnabled = 0 then 'TCP/IP' when @tcpEnabled = 0 and @npEnabled = 1 then 'Named Pipes' when @tcpEnabled = 1 and @npEnabled = 1 then 'TCP/IP & Named Pipes' END)



SELECT @servername as 'Server Instance Name', @edition as 'SQL Server Edition', @bitversion as 'Bit Architecture', '' + @version + ' ' + @servicePak + '' as 'SQL Server Version', 
@security as 'Authentication', @collation as 'Sort Order', @port as Port, @pipe as 'Name Pipe', @path as 'Instance Home', @errorlog as 'Error Log Location',
@logshipping as 'Log Shipping', @rep as 'Replication', @fulltext as 'Full Text Indexing', @ConnectProtocol as 'Connectivity Protocol'
go