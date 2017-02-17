use master
go
set nocount on
Declare @servername varchar(40),
	@hostname varchar(40),
	@version varchar(10),
	@servicePak varchar(3),
	@cluster varchar(1),
	@fulltext varchar(1),
	@security varchar(5),
	@edition varchar(100),
	@collation varchar(40),
	@sort varchar(200),
	@port varchar(6),
	@pipe varchar(100),
	@path varchar(200),
	@errorlog varchar(200),
	@restartagent varchar(10),
	@restartsql varchar(10),
	@agentmail varchar(1),
	@rep varchar(1),
	@companyname varchar(20),
	@bootini int,
	@OSEdition varchar(100)
declare @3GB char(3)
declare @pae char(3)
declare @MaxMem int
declare @MinMem int
Declare @AWE char(3)
declare @bit varchar(7)
--Hostname
set @hostname = (select CAST(serverproperty('MachineName') as varchar(50)))
--SQLservername
set @servername = (select @@servername)
--SQL Version
set @version = (select CAST(serverproperty('ProductVersion') as varchar(50)))
--SQL Service Pak
set @servicePak = (select CAST(serverproperty('ProductLevel') as varchar(3)))
--IsClustered
set @cluster = (Select CAST(SERVERPROPERTY('IsClustered') as varchar(2)))
--FullText
set @fulltext = (Select CAST(SERVERPROPERTY('IsFullTextInstalled') as varchar(2)))
--Security Mode
set @security = (Select CAST(SERVERPROPERTY('IsIntegratedSecurityOnly') as varchar(2)))
if @security = 0
	set @security = 'Mixed'
else
	set @security = 'Win'
--SQL Edition
set @edition = (select CAST(serverproperty('Edition') as varchar(40)))
--Sort Order
set @collation = (SELECT CAST(SERVERPROPERTY('Collation') as varchar(50)))

/**********************/
/* Read Boot.ini File */
/**********************/
create table #fileexists ( 
	doesexist smallint,
	fileindir smallint,
	direxist smallint)

-- Check for boot.ini
	Insert into #fileexists exec master..xp_fileexist 'C:\boot.ini'
    set @bootini = (select doesexist from #fileexists FE)
    Drop table #fileexists
	if @bootini = 1
		Begin
		create table #txtTable (name varchar(500))
		bulk insert #txtTable from 'c:\boot.ini'
		set @3GB = (Select case when count(name) = 1 then 'Yes' else 'No' end from #txtTable where name like '%/3gb%')
		set @pae = (Select case when count(name) = 1 then 'Yes' else 'No' end from #txtTable where name like '%/pae%')
		set @OSEdition = (select replace(substring(substring(name,PATINDEX('%"%',name)+1,len(name)),1,PATINDEX('%"%',substring(name,PATINDEX('%"%',name)+1,len(name)))-1),',','') from #txtTable where name like '%"%"%' and name not like '%console%')
		--select * from #txtTable --debug
		drop table #txtTable
		End

/******************************************/
/* Determine O/S and SQL Bit Architecture */
/******************************************/
create table #CheckBit
	([index] int,
	[Name] varchar(50),
	[Internal_Value] nvarchar(100),
	[Character_Value] nvarchar(200))
insert into #CheckBit exec xp_msver

set @bit = (select case when Character_Value like '%64%' then '64 bit' else '32 bit' end from #CheckBit where Name ='FileDescription')
Set @OSEdition = @OSEdition + ', '+ (select case when Character_Value like '%X86%' then '32 bit' else '64 bit' end from #CheckBit where Name ='Platform')
drop table #CheckBit

/*********************/
/* Get Registry info */
/*********************/
DECLARE @test varchar(200), 
	@testint int,
	@key varchar(100),
	@TcpPortKey varchar(300),
	@ErrorLogKey varchar(100),
	@pipekey varchar(100),
	@defaultpathkey varchar(200),
	@keyrestartagent varchar(100),
	@keyrestartsql varchar(100),
	@keyagentmail varchar(100),
	@keyrep varchar(100),
	@keyhome varchar(400),
	@servicehome varchar(400),
	@version1 int,
	@agentlogon varchar(200),
	@srvlogon varchar(200)

set @version1 = (select cast(substring(@version, 0, patindex('%.%', @version)) as int))
Create table #ErrorLogLoc (Value varchar(10), data varchar(100))

if @version1 = 8
	begin
		set @edition = '2000 '+@edition+' '+@servicePak
		
		-- Get Memory Settings
		set @AWE = (Select case when value = 1 then 'Yes' else 'No' end from sysconfigures where comment ='AWE enabled in the server')
		set @MinMem = (select value from sysconfigures where comment ='Minimum size of server memory (MB)')
		set @MaxMem = (select value from sysconfigures where comment ='Maximum size of server memory (MB)')

		if charindex('\',@@servername,0) <>0
			begin
			set @TcpPortKey = 'SOFTWARE\MICROSOFT\Microsoft SQL Server\'+@@servicename+'\MSSQLServer\Supersocketnetlib\TCP'
			set @pipekey = 'SOFTWARE\MICROSOFT\Microsoft SQL Server\'+@@servicename+'\MSSQLServer\Supersocketnetlib\Np'
			set @ErrorLogKey = 'SOFTWARE\MICROSOFT\Microsoft SQL Server\'+@@servicename+'\MSSQLServer\Parameters'
			set @defaultpathkey = 'SOFTWARE\MICROSOFT\Microsoft SQL Server\'+@@servicename+'\Setup'
			set @keyrestartagent = 'SOFTWARE\MICROSOFT\Microsoft SQL Server\'+@@servicename+'\SQLServerAgent'
			set @keyrestartsql = 'SOFTWARE\MICROSOFT\Microsoft SQL Server\'+@@servicename+'\SQLServerAgent'
			set @keyagentmail = 'SOFTWARE\MICROSOFT\Microsoft SQL Server\'+@@servicename+'\SQLServerAgent'
			set @keyrep = 'SOFTWARE\MICROSOFT\Microsoft SQL Server\'+@@servicename+'\Replication'
			end
		else
			begin
			set @TcpPortKey = 'SOFTWARE\MICROSOFT\MSSQLServer\MSSQLServer\Supersocketnetlib\TCP'
			set @pipekey = 'SOFTWARE\MICROSOFT\MSSQLServer\MSSQLServer\Supersocketnetlib\Np'
			set @ErrorLogKey = 'SOFTWARE\MICROSOFT\MSSQLServer\MSSQLServer\Parameters'
			set @defaultpathkey = 'SOFTWARE\MICROSOFT\MSSQLServer\Setup'
			set @keyrestartagent = 'SOFTWARE\MICROSOFT\MSSQLServer\SQLServerAgent'
			set @keyrestartsql = 'SOFTWARE\MICROSOFT\MSSQLServer\SQLServerAgent'
			set @keyagentmail = 'SOFTWARE\MICROSOFT\MSSQLServer\SQLServerAgent'
			set @keyrep = 'SOFTWARE\MICROSOFT\MSSQLServer\Replication'
			end
		--Port #
		EXEC master..xp_regread @rootkey='HKEY_LOCAL_MACHINE',@key=@TcpPortKey,@value_name='Tcpport',@value=@test OUTPUT
		set @port = (SELECT convert(varchar(10),@test) as Port)
		--Default Pipe
		EXEC master..xp_regread @rootkey='HKEY_LOCAL_MACHINE',@key=@pipekey,@value_name='PipeName',@value=@test OUTPUT
		set @pipe = (SELECT convert(varchar(40),@test) as 'Default Pipe')
		--Default Path
		EXEC master..xp_regread @rootkey='HKEY_LOCAL_MACHINE',@key=@defaultpathkey,@value_name='SQLPath',@value=@test OUTPUT
		set @path = (SELECT convert(varchar(200),@test) as 'Default Path')
		--Errorlog Location
		insert into #ErrorLogLoc EXEC master..xp_regenumvalues @rootkey='HKEY_LOCAL_MACHINE',@key=@ErrorLogKey
		set @errorlog = (select substring(data,3,len(data)) from #ErrorLogLoc where left(data,2) ='-e')
		Drop table #ErrorLogLoc
		--Auto Start Agent
		EXEC master..xp_regread @rootkey='HKEY_LOCAL_MACHINE',@key=@keyrestartagent,@value_name='RestartServer',@value=@testint OUTPUT
		set @restartagent = (SELECT convert(varchar(2),@testint) as 'Restart Agent')
		--Auto Start Server
		EXEC master..xp_regread @rootkey='HKEY_LOCAL_MACHINE',@key=@keyrestartsql,@value_name='RestartSQLServer',@value=@testint OUTPUT
		set @restartsql = (SELECT convert(varchar(2),@testint) as 'Restart Server')
		--Agent Mail
		EXEC master..xp_regread @rootkey='HKEY_LOCAL_MACHINE',@key=@keyagentmail,@value_name='AlertEventSystem',@value=@testint OUTPUT
		set @agentmail = (SELECT convert(varchar(2),@testint) as 'Restart Server')
		--Replication
		EXEC master..xp_regread @rootkey='HKEY_LOCAL_MACHINE',@key=@keyrep,@value_name='IsInstalled',@value=@testint OUTPUT
		set @rep = (SELECT convert(varchar(2),@testint) as 'Restart Server')

		goto _Done
	end

if @version1 >= 9
	begin
		If @version1 = 9
			set @edition = '2005 '+@edition+' '+@servicePak
		If @version1 = 10
			set @edition = '2008 '+@edition+' '+@servicePak
		
		-- Get Memory Settings
		set @AWE = (Select case when value = 1 then 'Yes' else 'No' end from sysconfigures where comment ='AWE enabled in the server')
		set @MinMem = (select value from sysconfigures where comment ='Minimum size of server memory (MB)')
		set @MaxMem = (select value from sysconfigures where comment ='Maximum size of server memory (MB)')
		
		set @key = (select @@servicename)
		set @servicehome = 'SYSTEM\CurrentControlSet\Services'
		set @keyhome = 'SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL'
		
		EXEC master..xp_regread @rootkey='HKEY_LOCAL_MACHINE',@key=@keyhome,@value_name=@key,@value=@test OUTPUT
		set @keyhome = (SELECT convert(varchar(400),@test) as ServiceName)
		set @keyhome = 'SOFTWARE\Microsoft\Microsoft SQL Server\'+ @keyhome
		set @TcpPortKey = @keyhome + '\MSSQLServer\Supersocketnetlib\TCP\IPAll'
		set @pipekey = @keyhome + '\MSSQLServer\Supersocketnetlib\Np'
		set @ErrorLogKey = @keyhome + '\MSSQLServer\Parameters'
		set @defaultpathkey = @keyhome + '\Setup'
		set @keyagentmail = @keyhome + '\SQLServerAgent'
		set @keyrep = @keyhome + '\Replication'
		set @keyrestartagent = @servicehome + '\SQLServerAgent'
		set @keyrestartsql = @servicehome + '\MSSQLSERVER'
		If @key <> 'MSSQLSERVER'
			Begin
				set @keyrestartagent = @servicehome + '\SQLAgent$' + @key
				set @keyrestartsql = @servicehome + '\MSSQL$' + @key
			END
		
		--Port #
		EXEC master..xp_regread @rootkey='HKEY_LOCAL_MACHINE',@key=@TcpPortKey,@value_name='TcpPort',@value=@test OUTPUT
		set @port = (SELECT convert(varchar(10),@test) as Port)
		If @port is NULL
			EXEC master..xp_regread @rootkey='HKEY_LOCAL_MACHINE',@key=@TcpPortKey,@value_name='TcpDynamicPorts',@value=@test OUTPUT
		set @port = (SELECT convert(varchar(10),@test) as Port)
		--Default Pipe
		EXEC master..xp_regread @rootkey='HKEY_LOCAL_MACHINE',@key=@pipekey,@value_name='PipeName',@value=@test OUTPUT
		set @pipe = (SELECT convert(varchar(40),@test) as 'Default Pipe')
		--Default Path
		EXEC master..xp_regread @rootkey='HKEY_LOCAL_MACHINE',@key=@defaultpathkey,@value_name='SQLPath',@value=@test OUTPUT
		set @path = (SELECT convert(varchar(200),@test) as 'Default Path')
		--Errorlog Location
		insert into #ErrorLogLoc EXEC master..xp_regenumvalues @rootkey='HKEY_LOCAL_MACHINE',@key=@ErrorLogKey
		set @errorlog = (select substring(data,3,len(data)) from #ErrorLogLoc where left(data,2) ='-e')
		Drop table #ErrorLogLoc
		--Auto Start Agent
		EXEC master..xp_regread @rootkey='HKEY_LOCAL_MACHINE',@key=@keyrestartagent,@value_name='Start',@value=@testint OUTPUT
		set @restartagent = (SELECT convert(varchar(100),@testint) as 'Restart Agent')
		--Auto Start Server
		EXEC master..xp_regread @rootkey='HKEY_LOCAL_MACHINE',@key=@keyrestartsql,@value_name='Start',@value=@testint OUTPUT
		set @restartsql = (SELECT convert(varchar(100),@testint) as 'Restart Server')
		--Agent Mail
		EXEC master..xp_regread @rootkey='HKEY_LOCAL_MACHINE',@key=@keyagentmail,@value_name='AlertEventSystem',@value=@testint OUTPUT
		set @agentmail = (SELECT convert(varchar(2),@testint) as 'Restart Server')
		--Replication
		EXEC master..xp_regread @rootkey='HKEY_LOCAL_MACHINE',@key=@keyrep,@value_name='IsInstalled',@value=@testint OUTPUT
		set @rep = (SELECT convert(varchar(2),@testint) as 'Restart Server')
	
		-- Agent Log On
		EXEC master..xp_regread @rootkey='HKEY_LOCAL_MACHINE',@key=@keyrestartagent,@value_name='ObjectName',@value=@test OUTPUT
		set @agentlogon = (SELECT convert(varchar(100),@test) as 'Restart Agent')
		--Server Log On
		EXEC master..xp_regread @rootkey='HKEY_LOCAL_MACHINE',@key=@keyrestartsql,@value_name='ObjectName',@value=@test OUTPUT
		set @srvlogon = (SELECT convert(varchar(100),@test) as 'Restart Server')

		set @restartsql = (select (case @restartsql when '2' then 'Automatic' when '3' then 'Manual' when '4' then 'Disabled' end))
		set @restartagent = (select (case @restartagent when '2' then 'Automatic' when '3' then 'Manual' when '4' then 'Disabled' end))

		declare @test1 varchar(200)
		Declare @instanceName varchar(200)
		Declare @Owners varchar(300)
		declare @crkey varchar(300)
		declare @crkey1 varchar(300)
	
/****************************************/
/* Get Cluster Information for SQL 2005+*/
/****************************************/
	
	If 	@cluster = 1
		Begin	
			create table #t1 (col1 varchar(4000))
			insert into #t1 select NodeName+',' from sys.dm_os_cluster_nodes

			set @Owners = ''
			declare crkeycursor CURSOR for SELECT col1 FROM #t1
			Open crkeycursor

			Fetch next from crkeycursor
			into @crkey

			WHILE @@FETCH_STATUS = 0
				BEGIN 
					set @Owners = @Owners+' '+@crkey
			


			Fetch next from crkeycursor
			into @crkey
			end
			CLOSE crkeycursor
			DEALLOCATE crkeycursor	

		set @Owners = (select substring(@Owners,1,len(@Owners)-1))
		--select @Owners 
		drop table #t1
		End
  else
	set @Owners = (select CAST(serverproperty('ComputerNamePhysicalNetBIOS') as varchar(200)))
goto _Done
	end
_Done:

set @edition = @edition +', '+ @bit

--Report
select @hostname as Hostname, @servername as 'Server Name', @OSEdition as 'O/S Version',@edition as 'SQL Server Edition', @version as 'SQL Version', 
--@servicePak as 'Service Pack', @bit as 'Bit Architecture', 
@cluster as 'Clustered', @Owners as 'Instance Owners',
@fulltext as 'Full Text Installed', @security as 'Security Mode', @collation as Collation, @port as Port, @pipe as 'Default Pipe', @path as 'Default Path',
@errorlog as 'Errorlog Location', @restartsql as 'Auto Restart SQL', @srvlogon as 'SQL Server Startup Account',@restartagent as 'Auto Restart Agent', @agentlogon as 'SQL Agent Startup Account',@agentmail as 'SQL Agent Mail Setup', @rep as 'Replication Installed',
@3GB as 'Has /3GB Switch', @pae as 'Has /PAE Switch',@MinMem as 'Min Memory (MB)', @MaxMem as 'Max Memory (MB)', @AWE as 'AWE Enabled'
go