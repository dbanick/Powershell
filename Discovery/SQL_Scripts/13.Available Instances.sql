DECLARE @Debug int 
DECLARE @regSQLHomePath nvarchar(260)
DECLARE @regDatabseEngineInstances nvarchar(260)
DECLARE @regSSASInstances nvarchar(260)
DECLARE @regSSRSInstances nvarchar(260)
DECLARE @InstanceId int
DECLARE @MaxInstanceId int
DECLARE @SQLInstance nvarchar(50)
DECLARE @regSQLInstanceHomePath nvarchar(260)
DECLARE @SQLInstanceRegKey nvarchar(260)
DECLARE @SQLSSASInstanceRegKey nvarchar(260)
DECLARE @SQLSSRSInstanceRegKey nvarchar(260)
DECLARE @SQLInstanceVersionKey nvarchar(260)
DECLARE @SQLInstanceVersion nvarchar(25)
DECLARE @SQLInstanceEdition nvarchar(50)
DECLARE @SQLSSASInstanceVersion nvarchar(25)
DECLARE @SQLSSASInstanceEdition nvarchar(50)
DECLARE @SQLSSRSInstanceVersion nvarchar(25)
DECLARE @SQLSSRSInstanceEdition nvarchar(50)
DECLARE @HostName nvarchar(50)

SET @HostName = (SELECT CAST(SERVERPROPERTY('MachineName') as nvarchar(50)))
SET @regSQLHomePath = 'SOFTWARE\Microsoft\Microsoft SQL Server'

-- 2005+ Instances
SET @regDatabseEngineInstances = @regSQLHomePath + '\Instance Names\SQL'
SET @regSSASInstances = @regSQLHomePath + '\Instance Names\OLAP'
SET @regSSRSInstances = @regSQLHomePath + '\Instance Names\RS'

CREATE TABLE [#InstalledSQLEngines]
	(
	[SQLEngine] nvarchar(100),
	[SQLInstance] nvarchar(100),
	[SQLEdition] nvarchar(50),
	[SQLVersion] nvarchar(25)	
	)

CREATE TABLE [#InstalledInstances]
	(
	[InstanceId] int identity,
	[Value1] nvarchar(50),
	[SQLInstance] nvarchar(100),
	[RegData] nvarchar(260),
	[SQLVersion] nvarchar(25),
	[SQLEngineInstalled] nvarchar(50),
	[SQLEdition] nvarchar(50)
	)
INSERT INTO [#InstalledInstances] ([Value1],[SQLInstance],[RegData])
	EXEC master..xp_regread 'HKEY_LOCAL_MACHINE', @regSQLHomePath,'InstalledInstances'
	
IF @Debug = 1
	SELECT * FROM [#InstalledInstances]



SELECT @MaxInstanceId = MAX([InstanceId]), @InstanceId = 1 FROM [#InstalledInstances]

WHILE @InstanceId <= @MaxInstanceId
	BEGIN
		SET @SQLInstanceRegKey = NULL
		SET @regSQLInstanceHomePath = NULL
		SELECT @SQLInstance = [SQLInstance] FROM [#InstalledInstances] WHERE [InstanceId] = @InstanceId
		EXEC master..xp_regread @rootkey='HKEY_LOCAL_MACHINE',@key=@regDatabseEngineInstances,@value_name=@SQLInstance, @value=@SQLInstanceRegKey OUTPUT
		IF @SQLInstanceRegKey IS NULL
			SET @regSQLInstanceHomePath = @regSQLHomePath + '\' + @SQLInstance
		  ELSE
			SET @regSQLInstanceHomePath = @regSQLHomePath + '\' + @SQLInstanceRegKey
		
		If @Debug = 1
			PRINT '@regSQLInstanceHomePath: ' + @regSQLInstanceHomePath
		
		SET @SQLInstanceVersionKey = @regSQLInstanceHomePath + '\Setup'
		
		EXEC master..xp_regread @rootkey='HKEY_LOCAL_MACHINE',@key=@SQLInstanceVersionKey,@value_name='PatchLevel', @value=@SQLInstanceVersion OUTPUT
		EXEC master..xp_regread @rootkey='HKEY_LOCAL_MACHINE',@key=@SQLInstanceVersionKey,@value_name='Edition', @value=@SQLInstanceEdition OUTPUT
		
		INSERT INTO [#InstalledSQLEngines] SELECT 'Database Engine', @SQLInstance, @SQLInstanceEdition, @SQLInstanceVersion
		
		IF @SQLInstanceRegKey IS NOT NULL -- SSRS / SSAS
			BEGIN
				EXEC master..xp_regread @rootkey='HKEY_LOCAL_MACHINE',@key=@regSSASInstances,@value_name=@SQLInstance, @value=@SQLSSASInstanceRegKey OUTPUT
				
				IF @SQLSSASInstanceRegKey IS NOT NULL
					BEGIN
						SET @SQLSSASInstanceRegKey = @regSQLHomePath + '\' + @SQLSSASInstanceRegKey + '\Setup'
						EXEC master..xp_regread @rootkey='HKEY_LOCAL_MACHINE',@key=@SQLSSASInstanceRegKey,@value_name='PatchLevel', @value=@SQLSSASInstanceVersion OUTPUT
						EXEC master..xp_regread @rootkey='HKEY_LOCAL_MACHINE',@key=@SQLSSASInstanceRegKey,@value_name='Edition', @value=@SQLSSASInstanceEdition OUTPUT	
						INSERT INTO [#InstalledSQLEngines] SELECT 'Analysis Server', @SQLInstance, @SQLSSASInstanceEdition, @SQLSSASInstanceVersion			
					END
				
				EXEC master..xp_regread @rootkey='HKEY_LOCAL_MACHINE',@key=@regSSRSInstances,@value_name=@SQLInstance, @value=@SQLSSRSInstanceRegKey OUTPUT
				
				IF @SQLSSRSInstanceRegKey IS NOT NULL
					BEGIN
						SET @SQLSSRSInstanceRegKey = @regSQLHomePath + '\' + @SQLSSRSInstanceRegKey + '\Setup'
						EXEC master..xp_regread @rootkey='HKEY_LOCAL_MACHINE',@key=@SQLSSRSInstanceRegKey,@value_name='PatchLevel', @value=@SQLSSRSInstanceVersion OUTPUT
						EXEC master..xp_regread @rootkey='HKEY_LOCAL_MACHINE',@key=@SQLSSRSInstanceRegKey,@value_name='Edition', @value=@SQLSSRSInstanceEdition OUTPUT
						INSERT INTO [#InstalledSQLEngines] SELECT 'Reporting Services', @SQLInstance, @SQLSSRSInstanceEdition, @SQLSSRSInstanceVersion				
					END
			END
		
		SET @InstanceId = @InstanceId + 1
	END

--Fully Qualify Instance names
UPDATE [#InstalledSQLEngines] SET [SQLInstance] = CASE [SQLInstance] WHEN 'MSSQLSERVER' THEN @HostName ELSE @HostName + '\' + [SQLInstance] END

SELECT * FROM [#InstalledSQLEngines]
GO
DROP TABLE [#InstalledInstances]
DROP TABLE [#InstalledSQLEngines]
GO