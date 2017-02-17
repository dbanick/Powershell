Use master
go
Set Nocount on

-- Create Tables
CREATE TABLE #MaintPlansReport (
	MaintPlanName varchar(277), 
	SubPlanName varchar(277),
	InstanceName varchar(100),
	--[UserID] varchar(200) NULL,	 
	TaskName varchar(277), 
	TaskType varchar(200), 
	TaskEnabled char(3), 
	DatabaseSelectionType varchar(2000), 
	IgnoreOfflineDatabases char(3),
	TaskOptions varchar(2000)
)

CREATE TABLE #MaintPlanConnections1 (
	[id] [int] IDENTITY(1,1) NOT NULL,
	[PlanText] [varchar](max) NULL
)

CREATE TABLE #MaintPlanConnections2 (
	[id] [int] IDENTITY(0,1) NOT NULL,
	[ConnectionID] varchar(100) NULL,
	[ConnectionName] [varchar](100) NULL,
	[InstanceName] [varchar](100) NULL,
	[ConnectionUserID] [varchar] (200) NULL
)

CREATE TABLE [dbo].[#MaintPlans](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[MaintPlanName] [varchar](277) NULL,
	[packagedata] [image] NULL
)

CREATE TABLE [dbo].[#MaintTask1](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[SubPlanID] [int] NOT NULL,
	[PlanText] [varchar](max) NULL,
	[TaskName] [varchar](100) NULL,
	[TaskType] [varchar](200) NULL,
	[Server] varchar(100) NULL,
	[TaskEnabled] [char](3) DEFAULT ('Yes') NULL,
	[DatabaseSelectionType] [varchar](2000) NULL,
	[IgnoreDatabaseState] [char](3) DEFAULT ('No') NULL,
	[TaskOptions] [varchar](2000) DEFAULT ('') NULL
)

CREATE TABLE [dbo].[#SUBPLANS1](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[PlanText] [varchar](max) NULL
)

CREATE TABLE [dbo].[#SUBPLANS2](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[SubPlanName] [varchar](277) NULL,
	[PlanText] [varchar](max) NULL
)
Declare @version int, @exec varchar(200)
set @version = (select cast(substring(CAST(serverproperty('ProductVersion') as varchar(50)), 1,patindex('%.%',CAST(serverproperty('ProductVersion') as varchar(50)))-1 ) as int))

If @version = 9 
	BEGIN 
		set @exec = 'insert into #MaintPlans (MaintPlanName, packagedata) Select name, packagedata from msdb..sysdtspackages90 where packagetype = 6'
		Exec(@exec)
	END
  Else if @version > 9
	BEGIN
		set @exec = 'insert into #MaintPlans (MaintPlanName, packagedata) Select name, packagedata from msdb..sysssispackages where packagetype = 6'
		Exec(@exec)
	END

Declare @MaintID int, @MaintPlanName varchar(277)
Set @MaintID = 1

WHILE @MaintID <= (Select MAX(id) from #MaintPlans)
	BEGIN
		-- Table Cleanup
		truncate table #SUBPLANS1
		truncate table #SUBPLANS2
		truncate table #MaintTask1
		truncate table #MaintPlanConnections1
		truncate table #MaintPlanConnections2
		
		-- Grab Connection Info Part 1
		Declare @ConnectPlan1 varchar(max), @ConnectPlan1String varchar(max)
		Select @ConnectPlan1=cast(cast([packagedata] as varbinary(max)) as varchar(max)), @MaintPlanName=MaintPlanName FROM #MaintPlans where id = @MaintID


		IF @ConnectPlan1 IS NOT NULL
		BEGIN
		IF CHARINDEX('<DTS:ConnectionManager>'+char(13)+char(10)+'<DTS:Property DTS:Name="DelayValidation">0</DTS:Property>',@ConnectPlan1) <> 0 -- For multiple databases in the parameter
				BEGIN
				SET @ConnectPlan1String = @ConnectPlan1;

				WHILE CHARINDEX('<DTS:ConnectionManager>'+char(13)+char(10)+'<DTS:Property DTS:Name="DelayValidation">0</DTS:Property>',@ConnectPlan1String) <> 0
					BEGIN
					INSERT INTO #MaintPlanConnections1 (PlanText) 
					VALUES(Left(@ConnectPlan1String,CHARINDEX('<DTS:ConnectionManager>'+char(13)+char(10)+'<DTS:Property DTS:Name="DelayValidation">0</DTS:Property>',@ConnectPlan1String)-1));
					SET @ConnectPlan1String = Right(@ConnectPlan1String, Len(@ConnectPlan1String)-CHARINDEX('<DTS:ConnectionManager>'+char(13)+char(10)+'<DTS:Property DTS:Name="DelayValidation">0</DTS:Property>',@ConnectPlan1String));
					END
					INSERT INTO #MaintPlanConnections1 (PlanText) 
					VALUES(@ConnectPlan1String);
				END
		END

		Delete from #MaintPlanConnections1 where id = 1
		
		IF (Select count(*) from #MaintPlanConnections1) = 0  -- 2005 Connection Strings
			BEGIN
				--Declare @ConnectPlan1 varchar(max), @ConnectPlan1String varchar(max)
				Select @ConnectPlan1=cast(cast([packagedata] as varbinary(max)) as varchar(max)), @MaintPlanName=MaintPlanName FROM #MaintPlans where id = @MaintID


				IF @ConnectPlan1 IS NOT NULL
				BEGIN
				IF CHARINDEX('<DTS:ConnectionManager><DTS:Property DTS:Name="DelayValidation">0</DTS:Property>',@ConnectPlan1) <> 0 -- For multiple databases in the parameter
						BEGIN
						SET @ConnectPlan1String = @ConnectPlan1;

						WHILE CHARINDEX('<DTS:ConnectionManager><DTS:Property DTS:Name="DelayValidation">0</DTS:Property>',@ConnectPlan1String) <> 0
							BEGIN
							INSERT INTO #MaintPlanConnections1 (PlanText) 
							VALUES(Left(@ConnectPlan1String,CHARINDEX('<DTS:ConnectionManager><DTS:Property DTS:Name="DelayValidation">0</DTS:Property>',@ConnectPlan1String)-1));
							SET @ConnectPlan1String = Right(@ConnectPlan1String, Len(@ConnectPlan1String)-CHARINDEX('<DTS:ConnectionManager><DTS:Property DTS:Name="DelayValidation">0</DTS:Property>',@ConnectPlan1String));
							END
							INSERT INTO #MaintPlanConnections1 (PlanText) 
							VALUES(@ConnectPlan1String);
						END
				END

				Delete from #MaintPlanConnections1 where id = 1
			END
		
		
		-- Grab Connection Info Part 2
		DECLARE @ConnectPlan2 varchar(max), @MaintConnectID int, @ConnectionName varchar(200), @ConnectionServer varchar(200), @ConnectionID varchar(100), @ConnectionUserID varchar(200)
		select @MaintConnectID=MIN(id) from #MaintPlanConnections1  

		While @MaintConnectID <= (Select MAX(id) from #MaintPlanConnections1)
			BEGIN
				Select @ConnectPlan2=[PlanText] FROM #MaintPlanConnections1 where id =@MaintConnectID

				-- ConnectionID
				select @ConnectionID=SUBSTRING(@ConnectPlan2,CHARINDEX('<DTS:Property DTS:Name="DTSID">{',@ConnectPlan2)+LEN('<DTS:Property DTS:Name="DTSID">{'),CHARINDEX('}</DTS:Property>',@ConnectPlan2,CHARINDEX('<DTS:Property DTS:Name="DTSID">{',@ConnectPlan2))-(CHARINDEX('<DTS:Property DTS:Name="DTSID">{',@ConnectPlan2)+LEN('<DTS:Property DTS:Name="DTSID">{'))) 
				-- ConnectionName
				select @ConnectionName=SUBSTRING(@ConnectPlan2,CHARINDEX('<DTS:Property DTS:Name="ObjectName">',@ConnectPlan2)+LEN('<DTS:Property DTS:Name="ObjectName">'),CHARINDEX('</DTS:Property>',@ConnectPlan2,CHARINDEX('<DTS:Property DTS:Name="ObjectName">',@ConnectPlan2))-(CHARINDEX('<DTS:Property DTS:Name="ObjectName">',@ConnectPlan2)+LEN('<DTS:Property DTS:Name="ObjectName">'))) 
				Select @ConnectionName=SUBSTRING(@ConnectionName, CHARINDEX('=',@ConnectionName)+1, LEN(@ConnectionName))
				-- Server
				select @ConnectionServer=SUBSTRING(@ConnectPlan2,CHARINDEX('<DTS:Property DTS:Name="ConnectionString">',@ConnectPlan2)+LEN('<DTS:Property DTS:Name="ConnectionString">'),CHARINDEX(';',@ConnectPlan2,CHARINDEX('<DTS:Property DTS:Name="ConnectionString">',@ConnectPlan2))-(CHARINDEX('<DTS:Property DTS:Name="ConnectionString">',@ConnectPlan2)+LEN('<DTS:Property DTS:Name="ConnectionString">'))) 
				Select @ConnectionServer=Replace(SUBSTRING(@ConnectionServer, CHARINDEX('=',@ConnectionServer)+1, LEN(@ConnectionServer)),'''','')				
				
--				IF CHARINDEX('uid=', @ConnectPlan2) > 0
--					BEGIN
--						Select @ConnectionUserID=Replace(SUBSTRING(@ConnectPlan2, CHARINDEX('uid=',@ConnectPlan2)+4, LEN(@ConnectPlan2)),'''','')
--						Select @ConnectionUserID=SUBSTRING(@ConnectionUserID, 1,CHARINDEX(';',@ConnectionUserID)-1)
--					END
--				  ELSE 
--					SET @ConnectionUserID = 'Trusted_Connection=true'
				insert into #MaintPlanConnections2 ([ConnectionID],[ConnectionName],[InstanceName]) values(@ConnectionID,@ConnectionName, @ConnectionServer)

				Set @MaintConnectID = @MaintConnectID + 1
			END
				
		-- Part 1 Delimit
		Declare @SubPlan1 varchar(max), @SubPlanString1 varchar(max)

		Select @SubPlan1=cast(cast([packagedata] as varbinary(max)) as varchar(max)), @MaintPlanName=MaintPlanName FROM #MaintPlans where id = @MaintID

		IF @SubPlan1 IS NOT NULL
		BEGIN
		IF CHARINDEX('<DTS:Property DTS:Name="CreationName">STOCK:SEQUENCE</DTS:Property>',@SubPlan1) <> 0 -- For multiple databases in the parameter
				BEGIN
				SET @SubPlanString1 = @SubPlan1;

				WHILE CHARINDEX('<DTS:Property DTS:Name="CreationName">STOCK:SEQUENCE</DTS:Property>',@SubPlanString1) <> 0
					BEGIN
					INSERT INTO #SUBPLANS1 (PlanText) 
					VALUES(Left(@SubPlanString1,CHARINDEX('<DTS:Property DTS:Name="CreationName">STOCK:SEQUENCE</DTS:Property>',@SubPlanString1)-1));
					SET @SubPlanString1 = Right(@SubPlanString1, Len(@SubPlanString1)-CHARINDEX('<DTS:Property DTS:Name="CreationName">STOCK:SEQUENCE</DTS:Property>',@SubPlanString1));
					END
					INSERT INTO #SUBPLANS1 (PlanText) 
					VALUES(@SubPlanString1);
				END
		END

		Delete from #SUBPLANS1 where id = (select MAX(id) from #SUBPLANS1)

		-- Part 2 Delimit
		Declare @SubPlan2 varchar(max), @SubPlanString2 varchar(max), @ID2 int
		Set @ID2 = 1

		While @ID2 <= (Select MAX(ID) from #SUBPLANS1)
		BEGIN
			Select @SubPlan2=[PlanText] FROM #SUBPLANS1 where id =@ID2
			Set @ID2 = @ID2 + 1

			IF @SubPlan2 IS NOT NULL
			BEGIN
			IF CHARINDEX('<DTS:Executable DTS:ExecutableType="STOCK:SEQUENCE">',@SubPlan2) <> 0 -- For multiple databases in the parameter
					BEGIN
					SET @SubPlanString2 = @SubPlan2;
					SET @SubPlanString2 = Right(@SubPlanString2, Len(@SubPlanString2)-CHARINDEX('<DTS:Executable DTS:ExecutableType="STOCK:SEQUENCE">',@SubPlanString2));
					INSERT INTO #SUBPLANS2 (PlanText) 
					VALUES(@SubPlanString2);
					END
			END
		END

		-- Grab SubPlan Name
		Update [#SUBPLANS2]
		Set SubPlanName = Substring(Reverse(substring(Reverse([PlanText]), 1, CHARINDEX('>"emaNtcejbO"=emaN:STD ytreporP:STD<',Reverse([PlanText]))-1)), 1, CHARINDEX('</DTS:Property>',Reverse(substring(Reverse([PlanText]), 1, CHARINDEX('>"emaNtcejbO"=emaN:STD ytreporP:STD<',Reverse([PlanText]))-1)))-1)
		 
		-- Part 3 Delimit
		Declare @SubPlan3 varchar(max), @SubPlanString3 varchar(max), @ID3 int
		Set @ID3 = 1

		While @ID3 <= (Select MAX(ID) from #SUBPLANS2)
		BEGIN
				Select @SubPlan3=[PlanText] FROM #SUBPLANS2 where id =@ID3
				
			IF @SubPlan3 IS NOT NULL
			BEGIN
			IF CHARINDEX('<DTS:Executable DTS:ExecutableType=',@SubPlan3) <> 0 -- For multiple databases in the parameter
					BEGIN
					SET @SubPlanString3 = @SubPlan3;

					WHILE CHARINDEX('<DTS:Executable DTS:ExecutableType=',@SubPlanString3) <> 0
						BEGIN
						INSERT INTO #MaintTask1 (SubPlanID, PlanText) 
						VALUES(@ID3, Left(@SubPlanString3,CHARINDEX('<DTS:Executable DTS:ExecutableType=',@SubPlanString3)-1));
						SET @SubPlanString3 = Right(@SubPlanString3, Len(@SubPlanString3)-CHARINDEX('<DTS:Executable DTS:ExecutableType=',@SubPlanString3));
						END
						INSERT INTO #MaintTask1 (SubPlanID, PlanText) 
						VALUES(@ID3, @SubPlanString3);
					END
			END
			Delete from #MaintTask1 where id = (select MIN(id) from #MaintTask1 where SubPlanID = @ID3)
			Set @ID3 = @ID3 + 1
		END

		--Grab TaskType
		update #MaintTask1
		Set TaskType = replace(SUBSTRING(PlanText, 1, charindex(',', PlanText)-1),'DTS:Executable DTS:ExecutableType="Microsoft.SqlServer.Management.DatabaseMaintenance.','')
		
		-- Grab TaskDisabled
		update #MaintTask1
		Set TaskEnabled = 'No'
		where SUBSTRING(PlanText, CHARINDEX('<DTS:Property DTS:Name="Disabled">', PlanText)+LEN('<DTS:Property DTS:Name="Disabled">'), 1) = 1
		
		-- Grab Ignore Database State (2008 only)
		update #MaintTask1
		Set IgnoreDatabaseState = 'Yes'
		where SUBSTRING(PlanText, CHARINDEX('SQLTask:IgnoreDatabasesInNotOnlineState="', PlanText)+LEN('SQLTask:IgnoreDatabasesInNotOnlineState="'), 1) = 'T'
		
		-- Grab TaskName
		Update #MaintTask1
		Set TaskName = SUBSTRING(SUBSTRING(PlanText, CHARINDEX('SQLTask:TaskName="', PlanText)+LEN('SQLTask:TaskName="'), LEN(PlanText)), 1, CHARINDEX('"',(SUBSTRING(PlanText, CHARINDEX('SQLTask:TaskName="', PlanText)+LEN('SQLTask:TaskName="'), LEN(PlanText))))-1)
		
		-- Grab Database SelectionType
		update #MaintTask1
		set DatabaseSelectionType = substring(PlanText, charindex('SQLTask:DatabaseSelectionType="', PlanText)+len('SQLTask:DatabaseSelectionType="'), 1)
		Where charindex('SQLTask:DatabaseSelectionType="', PlanText) > 0

		update #MaintTask1
		set DatabaseSelectionType = 'N/A', IgnoreDatabaseState = 'N/A'
		Where DatabaseSelectionType is null

		Update #MaintTask1
		Set [DatabaseSelectionType] = 'These Databases: '+REPLACE(REPLACE(SUBSTRING(PlanText, CHARINDEX('<SQLTask:SelectedDatabases SQLTask:DatabaseName="', PlanText), CHARINDEX('<SQLTask:BackupDestinationList', PlanText)-CHARINDEX('<SQLTask:SelectedDatabases SQLTask:DatabaseName="', PlanText)), '"/>', '],'), '<SQLTask:SelectedDatabases SQLTask:DatabaseName="', '[')
		where [DatabaseSelectionType] = '4' and CHARINDEX('<SQLTask:BackupDestinationList', PlanText) > 0		
		
		Update #MaintTask1
		Set [DatabaseSelectionType] = 'These Databases: '+REPLACE(REPLACE(SUBSTRING(PlanText, CHARINDEX('<SQLTask:SelectedDatabases SQLTask:DatabaseName="', PlanText), CHARINDEX('</SQLTask:SqlTaskData></DTS:ObjectData>', PlanText)-CHARINDEX('<SQLTask:SelectedDatabases SQLTask:DatabaseName="', PlanText)), '"/>', '],'), '<SQLTask:SelectedDatabases SQLTask:DatabaseName="', '[')
		where [DatabaseSelectionType] = '4'
		      
		Update #MaintTask1
		Set [DatabaseSelectionType] = LEFT([DatabaseSelectionType], LEN([DatabaseSelectionType])-1)
		where LEFT([DatabaseSelectionType], LEN('These Databases:')) = 'These Databases:'

		update #MaintTask1
		set DatabaseSelectionType = case When DatabaseSelectionType = 1 Then 'All Databases' When DatabaseSelectionType = 2 Then 'All System Databases' When DatabaseSelectionType = 3	Then 'All User Databases' END
		Where DatabaseSelectionType in('1','2','3')
		
		-- Grab SQL Agent Task Option Info
		update #MaintTask1
		Set TaskOptions = 'Start job: '''+RTRIM(REPLACE(SUBSTRING(PlanText,CHARINDEX('SQLTask:AgentJobID="',PlanText)+LEN('SQLTask:AgentJobID="'),CHARINDEX('xmlns:SQLTask="',PlanText,CHARINDEX('SQLTask:AgentJobID="',PlanText))-(CHARINDEX('SQLTask:AgentJobID="',PlanText)+LEN('SQLTask:AgentJobID="'))+6), '" xmlns:', ''))+''''
		Where TaskType = 'DbMaintenanceExecuteAgentJobTask'


		Update #MaintTask1
		Set TaskOptions = LEFT(TaskOptions, LEN(TaskOptions)-1)
		where LEFT(TaskOptions, LEN('Starts job(s): ')) = 'Starts job(s): '
		
		-- Grab SQL for Execute SQL task
		update #MaintTask1
		Set TaskOptions = 'Execute SQL: '+REPLACE((RTRIM(REPLACE(SUBSTRING(PlanText,CHARINDEX('SQLTask:SqlStatementSource="',PlanText)+LEN('SQLTask:SqlStatementSource="'),CHARINDEX('" SQLTask:CodePage',PlanText,CHARINDEX('SQLTask:SqlStatementSource="',PlanText))-(CHARINDEX('SQLTask:SqlStatementSource="',PlanText)+LEN('SQLTask:SqlStatementSource="'))+18), '" SQLTask:CodePage', ';'))),'&#xA;', char(10)+char(10)) 
		Where TaskType = 'DbMaintenanceTSQLExecuteTask' and not CHARINDEX('" SQLTask:CodePage',PlanText,CHARINDEX('SQLTask:SqlStatementSource="',PlanText)) = 0
		
		update #MaintTask1
		Set TaskOptions = 'Execute SQL: '+REPLACE((RTRIM(REPLACE(SUBSTRING(PlanText,CHARINDEX('SQLTask:SqlStatementSource="',PlanText)+LEN('SQLTask:SqlStatementSource="'),CHARINDEX('" SQLTask:ResultType="',PlanText,CHARINDEX('SQLTask:SqlStatementSource="',PlanText))-(CHARINDEX('SQLTask:SqlStatementSource="',PlanText)+LEN('SQLTask:SqlStatementSource="'))+18), '" SQLTask:CodePage', ';'))),'&#xA;', char(10)+char(10)) 
		Where TaskType = 'DbMaintenanceTSQLExecuteTask' and not CHARINDEX('" SQLTask:ResultType="',PlanText,CHARINDEX('SQLTask:SqlStatementSource="',PlanText)) = 0
		
		-- Grab ReOrg Task Info
		update #MaintTask1
		Set TaskOptions = 'Compact Large Objects = '+Case when (RTRIM(SUBSTRING(PlanText,CHARINDEX('SQLTask:CompactLargeObjects="',PlanText)+LEN('SQLTask:CompactLargeObjects="'),CHARINDEX('" xmlns:SQLTask="',PlanText,CHARINDEX('SQLTask:CompactLargeObjects="',PlanText))-(CHARINDEX('SQLTask:CompactLargeObjects="',PlanText)+LEN('SQLTask:CompactLargeObjects="'))))) = 'True' then 'Yes' Else 'No' end
		Where TaskType = 'DbMaintenanceDefragmentIndexTask'
		
		-- Grab Integrity Check Task Info
		update #MaintTask1
		Set TaskOptions = 'Include Indexes = '+Case when (RTRIM(SUBSTRING(PlanText,CHARINDEX('SQLTask:IncludeIndexes="',PlanText)+LEN('SQLTask:IncludeIndexes="'),CHARINDEX('" xmlns:SQLTask="',PlanText,CHARINDEX('SQLTask:IncludeIndexes="',PlanText))-(CHARINDEX('SQLTask:IncludeIndexes="',PlanText)+LEN('SQLTask:IncludeIndexes="'))))) = 'True' then 'Yes' Else 'No' end
		Where TaskType = 'DbMaintenanceCheckIntegrityTask'
		
		-- Grab Index Rebuild Task Option Info
		Declare @RebuildTaskID int, @RebuildOptions varchar(1000)

		Set @RebuildTaskID = (select MIN(id) from #MaintTask1 Where TaskType = 'DbMaintenanceReindexTask')

		While @RebuildTaskID <= (select max(id) from #MaintTask1 Where TaskType = 'DbMaintenanceReindexTask')
			BEGIN
				-- Tasks Info
				-- UseOriginalAmount = Original fill factor
				-- Percentage = Change %
				-- Sort = Sort in Tempdb
				-- KeepOnline = Online Index Rebuild
				
				Select @RebuildOptions = Case when (SUBSTRING(PlanText, CHARINDEX('SQLTask:UseOriginalAmount="', PlanText)+LEN('SQLTask:UseOriginalAmount="'), 1)) = 'T' Then 'Original fill factor' ELSE 'Change free space to: '+Replace(SUBSTRING(PlanText, CHARINDEX('SQLTask:Percentage="', PlanText)+LEN('SQLTask:Percentage="'), 3),'"','')+'%' END From #MaintTask1 Where id = @RebuildTaskID
				Set @RebuildOptions = @RebuildOptions+', '
				
				Select @RebuildOptions=@RebuildOptions+Case when (SUBSTRING(PlanText, CHARINDEX('SQLTask:KeepOnline="', PlanText)+LEN('SQLTask:KeepOnline="'), 1)) = 'T' Then 'Online Rebuild' Else 'Offline Rebuild' end From #MaintTask1 Where id = @RebuildTaskID
								
				Select @RebuildOptions=@RebuildOptions+Case when (SUBSTRING(PlanText, CHARINDEX('SQLTask:Sort="', PlanText)+LEN('SQLTask:Sort="'), 1)) = 'T' Then ', Sort in Tempdb' Else '' end From #MaintTask1 Where id = @RebuildTaskID
								
				update #MaintTask1
				Set TaskOptions = @RebuildOptions
				Where id = @RebuildTaskID
				
				Set @RebuildTaskID = (select case when MIN(id) > 1 then MIN(id) else @RebuildTaskID + 1 end from #MaintTask1 Where TaskType = 'DbMaintenanceReindexTask' and id > @RebuildTaskID)
			END
		
		-- Grab History Cleanup Task Option Info
		Declare @HistoryTaskID int, @HistoryOptions varchar(1000)

		Set @HistoryTaskID = (select MIN(id) from #MaintTask1 Where TaskType = 'DbMaintenanceHistoryCleanupTask')

		While @HistoryTaskID <= (select max(id) from #MaintTask1 Where TaskType = 'DbMaintenanceHistoryCleanupTask')
			BEGIN
				-- Tasks Info
				-- RemoveBackupRestoreHistory 
				-- RemoveAgentHistory 
				-- RemoveDbMaintHistory 
				-- RemoveOlderThan 
				-- TimeUnitsType = 5=Hours, 0=Days, 1=Weeks, 2=Months, 3=Years
				
				Set @HistoryOptions = 'Remove '
				Select @HistoryOptions = @HistoryOptions+Case when (SUBSTRING(PlanText, CHARINDEX('SQLTask:RemoveBackupRestoreHistory="', PlanText)+LEN('SQLTask:RemoveBackupRestoreHistory="'), 1)) = 'T' Then 'Backup and Restore'  ELSE '' END From #MaintTask1 Where id = @HistoryTaskID
				
				IF 	LEN(@HistoryOptions) > 6
					Set @HistoryOptions = @HistoryOptions+'/'
				Select @HistoryOptions=@HistoryOptions+Case when (SUBSTRING(PlanText, CHARINDEX('SQLTask:RemoveAgentHistory="', PlanText)+LEN('SQLTask:RemoveAgentHistory="'), 1)) = 'T' Then 'Agent' Else '' end From #MaintTask1 Where id = @HistoryTaskID
				
				IF 	LEN(@HistoryOptions) > 6
					Set @HistoryOptions = @HistoryOptions+'/'
				Select @HistoryOptions=@HistoryOptions+Case when (SUBSTRING(PlanText, CHARINDEX('SQLTask:RemoveDbMaintHistory="', PlanText)+LEN('SQLTask:RemoveDbMaintHistory="'), 1)) = 'T' Then 'DB Maint' Else '' end From #MaintTask1 Where id = @HistoryTaskID
				
				IF 	LEN(@HistoryOptions) > 6
					Select @HistoryOptions = substring(@HistoryOptions, 1, LEN(@HistoryOptions))+ 'History older than '
				
				Select @HistoryOptions = @HistoryOptions+RTRIM(SUBSTRING(PlanText,CHARINDEX('SQLTask:RemoveOlderThan="',PlanText)+LEN('SQLTask:RemoveOlderThan="'),CHARINDEX('" SQLTask:TimeUnitsType',PlanText,CHARINDEX('SQLTask:RemoveOlderThan="',PlanText))-(CHARINDEX('SQLTask:RemoveOlderThan="',PlanText)+LEN('SQLTask:RemoveOlderThan="')))) From #MaintTask1 Where id = @HistoryTaskID
				Select @HistoryOptions=@HistoryOptions+Case when (SUBSTRING(PlanText, CHARINDEX('SQLTask:TimeUnitsType="', PlanText)+LEN('SQLTask:TimeUnitsType="'), 1)) = '5' Then ' Hours' when (SUBSTRING(PlanText, CHARINDEX('SQLTask:TimeUnitsType="', PlanText)+LEN('SQLTask:TimeUnitsType="'), 1)) = '0' Then ' Days' when (SUBSTRING(PlanText, CHARINDEX('SQLTask:TimeUnitsType="', PlanText)+LEN('SQLTask:TimeUnitsType="'), 1)) = '1' Then ' Weeks' when (SUBSTRING(PlanText, CHARINDEX('SQLTask:TimeUnitsType="', PlanText)+LEN('SQLTask:TimeUnitsType="'), 1)) = '2' Then ' Months' when (SUBSTRING(PlanText, CHARINDEX('SQLTask:TimeUnitsType="', PlanText)+LEN('SQLTask:TimeUnitsType="'), 1)) = '3' Then ' Years' Else '' end From #MaintTask1 Where id = @HistoryTaskID
				
				update #MaintTask1
				Set TaskOptions = @HistoryOptions
				Where id = @HistoryTaskID
				
				--Select @HistoryOptions
				Set @HistoryTaskID = (select case when MIN(id) > 1 then MIN(id) else @HistoryTaskID + 1 end from #MaintTask1 Where TaskType = 'DbMaintenanceHistoryCleanupTask' and id > @HistoryTaskID)
			END	
		
		-- Grab Update Stats Task Option Info
		Declare @UpdateStatsTaskID int, @UpdateStatsOptions varchar(1000)

		Set @UpdateStatsTaskID = (select MIN(id) from #MaintTask1 Where TaskType = 'DbMaintenanceUpdateStatisticsTask')

		While @UpdateStatsTaskID <= (select max(id) from #MaintTask1 Where TaskType = 'DbMaintenanceUpdateStatisticsTask')
			BEGIN
				-- Tasks Info
				-- UpdateStatisticsType = 2=All Existing Stats, 1=Column Stats Only, 0=Index Stats Only
				-- UpdateScanType = 3=Full Scan, 1=Percent, 2=Rows
				-- UpdateSampleValue = Sample Value
						
				Select @UpdateStatsOptions = Case when (SUBSTRING(PlanText, CHARINDEX('SQLTask:UpdateStatisticsType="', PlanText)+LEN('SQLTask:UpdateStatisticsType="'), 1)) = '2' Then 'Update All existing stats' when (SUBSTRING(PlanText, CHARINDEX('SQLTask:UpdateStatisticsType="', PlanText)+LEN('SQLTask:UpdateStatisticsType="'), 1)) = '1' Then 'Update Column stats only' when (SUBSTRING(PlanText, CHARINDEX('SQLTask:UpdateStatisticsType="', PlanText)+LEN('SQLTask:UpdateStatisticsType="'), 1)) = '0' Then 'Update Index stats only' END From #MaintTask1 Where id = @UpdateStatsTaskID
				Set @UpdateStatsOptions = @UpdateStatsOptions+' with a scan type of '
				
				Select @UpdateStatsOptions=@UpdateStatsOptions+Case when (SUBSTRING(PlanText, CHARINDEX('SQLTask:UpdateScanType="', PlanText)+LEN('SQLTask:UpdateScanType="'), 1)) = '1' Then RTRIM(SUBSTRING(PlanText,CHARINDEX('SQLTask:UpdateSampleValue="',PlanText)+LEN('SQLTask:UpdateSampleValue="'),CHARINDEX('" xmlns:SQLTask="',PlanText,CHARINDEX('SQLTask:UpdateSampleValue="',PlanText))-(CHARINDEX('SQLTask:UpdateSampleValue="',PlanText)+LEN('SQLTask:UpdateSampleValue="'))))+'%' when (SUBSTRING(PlanText, CHARINDEX('SQLTask:UpdateScanType="', PlanText)+LEN('SQLTask:UpdateScanType="'), 1)) = '2' Then RTRIM(SUBSTRING(PlanText,CHARINDEX('SQLTask:UpdateSampleValue="',PlanText)+LEN('SQLTask:UpdateSampleValue="'),CHARINDEX('" xmlns:SQLTask="',PlanText,CHARINDEX('SQLTask:UpdateSampleValue="',PlanText))-(CHARINDEX('SQLTask:UpdateSampleValue="',PlanText)+LEN('SQLTask:UpdateSampleValue="'))))+' Rows'  Else 'Full' end From #MaintTask1 Where id = @UpdateStatsTaskID
				
				update #MaintTask1
				Set TaskOptions = @UpdateStatsOptions
				Where id = @UpdateStatsTaskID
				
				Set @UpdateStatsTaskID = (select case when MIN(id) > 1 then MIN(id) else @UpdateStatsTaskID + 1 end from #MaintTask1 Where TaskType = 'DbMaintenanceUpdateStatisticsTask' and id > @UpdateStatsTaskID)
			END
		
		-- Grab Database Shrink Task Option Info
		Declare @ShrinkTaskID int, @ShrinkOptions varchar(1000)

		Set @ShrinkTaskID = (select MIN(id) from #MaintTask1 Where TaskType = 'DbMaintenanceShrinkTask')

		While @ShrinkTaskID <= (select max(id) from #MaintTask1 Where TaskType = 'DbMaintenanceShrinkTask')
			BEGIN
				-- Tasks Info
				-- DatabaseSizeLimit = Grows Beyond MB
				-- DatabasePercentLimit = Percent to leave free
				-- DatabaseReturnFreeSpace = Return Free Space to O/S (True) or leave in database (False)
						
				Select @ShrinkOptions='Shrink Database if larger then '+RTRIM(SUBSTRING(PlanText,CHARINDEX('SQLTask:DatabaseSizeLimit="',PlanText)+LEN('SQLTask:DatabaseSizeLimit="'),CHARINDEX('" SQLTask:DatabasePercentLimit="',PlanText,CHARINDEX('SQLTask:DatabaseSizeLimit="',PlanText))-(CHARINDEX('SQLTask:DatabaseSizeLimit="',PlanText)+LEN('SQLTask:DatabaseSizeLimit="')))) +'MB' From #MaintTask1 Where id = @ShrinkTaskID
				
				Select @ShrinkOptions=@ShrinkOptions+', Leave'+RTRIM(SUBSTRING(PlanText,CHARINDEX('SQLTask:DatabasePercentLimit="',PlanText)+LEN('SQLTask:DatabasePercentLimit="'),CHARINDEX('" SQLTask:DatabaseReturnFreeSpace="',PlanText,CHARINDEX('SQLTask:DatabasePercentLimit="',PlanText))-(CHARINDEX('SQLTask:DatabasePercentLimit="',PlanText)+LEN('SQLTask:DatabasePercentLimit="')))) +'% free in the database' From #MaintTask1 Where id = @ShrinkTaskID
				
				Select @ShrinkOptions=@ShrinkOptions+', '+Case When SUBSTRING(PlanText, CHARINDEX('SQLTask:DatabaseReturnFreeSpace="', PlanText)+LEN('SQLTask:DatabaseReturnFreeSpace="'), 1) = 'T' then 'Return freed space to O/S' Else 'Leave freed space in database' END From #MaintTask1 Where id = @ShrinkTaskID
						
				update #MaintTask1
				Set TaskOptions = @ShrinkOptions
				Where id = @ShrinkTaskID
				
				Set @ShrinkTaskID = (select case when MIN(id) > 1 then MIN(id) else @ShrinkTaskID + 1 end from #MaintTask1 Where TaskType = 'DbMaintenanceShrinkTask' and id > @ShrinkTaskID)
			END

		-- Grab File Cleanup Task Option Info
		Declare @MaintCleanupTaskID int, @MaintCleanupOptions varchar(2000)

		Set @MaintCleanupTaskID = (select MIN(id) from #MaintTask1 Where TaskType = 'DbMaintenanceFileCleanupTask')

		While @MaintCleanupTaskID <= (select max(id) from #MaintTask1 Where TaskType = 'DbMaintenanceFileCleanupTask')
			BEGIN
				-- Tasks Info
				-- FileTypeSelected = Backups=0, Report Files=1 
				-- FilePath = Specific File
				-- FolderPath = Folder to check
				-- CleanSubFolders = Check SubFolders (T/F)
				-- FileExtension
				-- AgeBased = Delete file based on age (T/F)
				-- DeleteSpecificFile = Delete specific file (T/F) *Requires FilePath
				-- TimeUnitsType  = 5=Hours, 0=Days, 1=Weeks, 2=Months, 3=Years
				-- RemoveOlderThan
						
				Select @MaintCleanupOptions=Case When SUBSTRING(PlanText, CHARINDEX('SQLTask:FileTypeSelected="', PlanText)+LEN('SQLTask:FileTypeSelected="'), 1) = '1' then 'Delete Maintenance plan text report(s)' When SUBSTRING(PlanText, CHARINDEX('SQLTask:FileTypeSelected="', PlanText)+LEN('SQLTask:FileTypeSelected="'), 1) = '0' then 'Delete file(s)' end From #MaintTask1 Where id = @MaintCleanupTaskID
				
				If (select SUBSTRING(PlanText, CHARINDEX('SQLTask:DeleteSpecificFile="', PlanText)+LEN('SQLTask:DeleteSpecificFile="'), 1) From #MaintTask1 Where id = @MaintCleanupTaskID) = 'T' -- Check for DeleteSpecificFile 
					Select @MaintCleanupOptions='Delete specific file='+RTRIM(SUBSTRING(PlanText,CHARINDEX('SQLTask:FilePath="',PlanText)+LEN('SQLTask:FilePath="'),CHARINDEX('" SQLTask:FolderPath="',PlanText,CHARINDEX('SQLTask:FilePath="',PlanText))-(CHARINDEX('SQLTask:FilePath="',PlanText)+LEN('SQLTask:FilePath="')))) From #MaintTask1 Where id = @MaintCleanupTaskID
				
				IF (Select SUBSTRING(PlanText, CHARINDEX('SQLTask:AgeBased="', PlanText)+LEN('SQLTask:AgeBased="'), 1) From #MaintTask1 Where id = @MaintCleanupTaskID)= 'T' 
					BEGIN
						Select @MaintCleanupOptions=@MaintCleanupOptions+', When file(s) older than '
						Select @MaintCleanupOptions=@MaintCleanupOptions+RTRIM(SUBSTRING(PlanText,CHARINDEX('SQLTask:RemoveOlderThan="',PlanText)+LEN('SQLTask:RemoveOlderThan="'),CHARINDEX('" SQLTask:TimeUnitsType="',PlanText,CHARINDEX('SQLTask:RemoveOlderThan="',PlanText))-(CHARINDEX('SQLTask:RemoveOlderThan="',PlanText)+LEN('SQLTask:RemoveOlderThan="')))) From #MaintTask1 Where id = @MaintCleanupTaskID
						Select @MaintCleanupOptions=@MaintCleanupOptions+case When SUBSTRING(PlanText, CHARINDEX('SQLTask:TimeUnitsType="', PlanText)+LEN('SQLTask:TimeUnitsType="'), 1) = '5' then ' Hours' When SUBSTRING(PlanText, CHARINDEX('SQLTask:TimeUnitsType="', PlanText)+LEN('SQLTask:TimeUnitsType="'), 1) = '0' then ' Days' When SUBSTRING(PlanText, CHARINDEX('SQLTask:TimeUnitsType="', PlanText)+LEN('SQLTask:TimeUnitsType="'), 1) = '1' then ' Weeks' When SUBSTRING(PlanText, CHARINDEX('SQLTask:TimeUnitsType="', PlanText)+LEN('SQLTask:TimeUnitsType="'), 1) = '2' then ' Months' When SUBSTRING(PlanText, CHARINDEX('SQLTask:TimeUnitsType="', PlanText)+LEN('SQLTask:TimeUnitsType="'), 1) = '3' then ' Years' END From #MaintTask1 Where id = @MaintCleanupTaskID
					END
				
				If (select SUBSTRING(PlanText, CHARINDEX('SQLTask:DeleteSpecificFile="', PlanText)+LEN('SQLTask:DeleteSpecificFile="'), 1) From #MaintTask1 Where id = @MaintCleanupTaskID) = 'F' -- Check for DeleteSpecificFile 
					BEGIN
						Select @MaintCleanupOptions=@MaintCleanupOptions+', with extension ''.'+RTRIM(SUBSTRING(PlanText,CHARINDEX('SQLTask:FileExtension="',PlanText)+LEN('SQLTask:FileExtension="'),CHARINDEX('" SQLTask:AgeBased="',PlanText,CHARINDEX('SQLTask:FileExtension="',PlanText))-(CHARINDEX('SQLTask:FileExtension="',PlanText)+LEN('SQLTask:FileExtension="'))))+'''' From #MaintTask1 Where id = @MaintCleanupTaskID
						Select @MaintCleanupOptions=@MaintCleanupOptions+', in folder: '''+RTRIM(SUBSTRING(PlanText,CHARINDEX('SQLTask:FolderPath="',PlanText)+LEN('SQLTask:FolderPath="'),CHARINDEX('" SQLTask:CleanSubFolders="',PlanText,CHARINDEX('SQLTask:FolderPath="',PlanText))-(CHARINDEX('SQLTask:FolderPath="',PlanText)+LEN('SQLTask:FolderPath="'))))+'''' From #MaintTask1 Where id = @MaintCleanupTaskID
						IF (Select SUBSTRING(PlanText, CHARINDEX('SQLTask:CleanSubFolders="', PlanText)+LEN('SQLTask:CleanSubFolders="'), 1) From #MaintTask1 Where id = @MaintCleanupTaskID)= 'T'
							Select @MaintCleanupOptions=@MaintCleanupOptions+', including first-level subfolders'
						
					END
				
				update #MaintTask1
				Set TaskOptions = @MaintCleanupOptions
				Where id = @MaintCleanupTaskID
						
				Set @MaintCleanupTaskID = (select case when MIN(id) > 1 then MIN(id) else @MaintCleanupTaskID + 1 end from #MaintTask1 Where TaskType = 'DbMaintenanceFileCleanupTask' and id > @MaintCleanupTaskID)
			END

		-- Grab File Cleanup Task Option Info
		Declare @BackupTaskID int, @BackupOptions varchar(2000)

		Set @BackupTaskID = (select MIN(id) from #MaintTask1 Where TaskType = 'DbMaintenanceBackupTask')

		While @BackupTaskID <= (select max(id) from #MaintTask1 Where TaskType = 'DbMaintenanceBackupTask')
			BEGIN
				-- Tasks Info
				-- BackupAction = Full/Diff = 0, Tran =2 
				-- BackupIsIncremental = False = Full, True = Diff
				-- BackupFileGroupsFiles
				-- BackupDeviceType = Disk=2
				-- BackupPhisycalDestinationType = ? stripe?
				-- BackupDestinationType = ? stripe?
				-- BackupDestinationAutoFolderPath = Backup Directory
				-- BackupActionForExistingBackups = Append=0,Overwrite=1
				-- BackupCreateSubFolder = Create in Subfolder
				-- BackupFileExtension = default = bak
				-- BackupVerifyIntegrity
				-- ExpireDate *Requires UseExpiration
				-- RetainDays *Requires UseExpiration
				-- InDays = RetainDays is int days *Requires UseExpiration
				-- UseExpiration
				-- BackupCompressionAction
				-- BackupTailLog
								
				Select @BackupOptions=case When SUBSTRING(PlanText, CHARINDEX('SQLTask:BackupAction="', PlanText)+LEN('SQLTask:BackupAction="'), 1) = '2' Then 'Transaction Log Backup' When SUBSTRING(PlanText, CHARINDEX('SQLTask:BackupAction="', PlanText)+LEN('SQLTask:BackupAction="'), 1) = 0 and SUBSTRING(PlanText, CHARINDEX('SQLTask:BackupIsIncremental="', PlanText)+LEN('SQLTask:BackupIsIncremental="'), 1) = 'T' Then 'Differential Backup' When SUBSTRING(PlanText, CHARINDEX('SQLTask:BackupAction="', PlanText)+LEN('SQLTask:BackupAction="'), 1) = 0 and SUBSTRING(PlanText, CHARINDEX('SQLTask:BackupIsIncremental="', PlanText)+LEN('SQLTask:BackupIsIncremental="'), 1) = 'F' Then 'Full Backup' Else 'Full Backup' End From #MaintTask1 Where id = @BackupTaskID
				
				If (select SUBSTRING(PlanText, CHARINDEX('SQLTask:BackupFileGroupsFiles="', PlanText)+LEN('SQLTask:BackupFileGroupsFiles="'), 1) From #MaintTask1 Where id = @BackupTaskID) <> '"' -- Check for Filegroup backups
					select @BackupOptions=@BackupOptions+' of filegroup(s): '+RTRIM(SUBSTRING(PlanText,CHARINDEX('SQLTask:BackupFileGroupsFiles="',PlanText)+LEN('SQLTask:BackupFileGroupsFiles="'),CHARINDEX('" SQLTask:BackupDeviceType="',PlanText,CHARINDEX('SQLTask:BackupFileGroupsFiles="',PlanText))-(CHARINDEX('SQLTask:BackupFileGroupsFiles="',PlanText)+LEN('SQLTask:BackupFileGroupsFiles="')))) From #MaintTask1 Where id = @BackupTaskID
				
				-- BackupDeviceType = Disk=2
				-- BackupPhisycalDestinationType = ? stripe?
				-- BackupDestinationType = ? stripe?
								
				If (select SUBSTRING(PlanText, CHARINDEX('SQLTask:BackupDestinationAutoFolderPath="', PlanText)+LEN('SQLTask:BackupDestinationAutoFolderPath="'), 1) From #MaintTask1 Where id = @BackupTaskID) <> '"'
					select @BackupOptions=@BackupOptions+', to disk='''+RTRIM(SUBSTRING(PlanText,CHARINDEX('SQLTask:BackupDestinationAutoFolderPath="',PlanText)+LEN('SQLTask:BackupDestinationAutoFolderPath="'),CHARINDEX('" SQLTask:BackupActionForExistingBackups="',PlanText,CHARINDEX('SQLTask:BackupDestinationAutoFolderPath="',PlanText))-(CHARINDEX('SQLTask:BackupDestinationAutoFolderPath="',PlanText)+LEN('SQLTask:BackupDestinationAutoFolderPath="'))))+'''' From #MaintTask1 Where id = @BackupTaskID 
				
				IF (select charindex('SQLTask:BackupDestinationLocation="',PlanText) From #MaintTask1 Where id = @BackupTaskID) > 0
					BEGIN
						select @BackupOptions=@BackupOptions+', to disk='+Replace(Replace(''''+RTRIM(SUBSTRING(PlanText,CHARINDEX('SQLTask:BackupDestinationList SQLTask:BackupDestinationLocation="',PlanText)+LEN('SQLTask:BackupDestinationList SQLTask:BackupDestinationLocation="'),CHARINDEX('"/></SQLTask:SqlTaskData></DTS:ObjectData>',PlanText,CHARINDEX('SQLTask:BackupDestinationList SQLTask:BackupDestinationLocation="',PlanText))-(CHARINDEX('SQLTask:BackupDestinationList SQLTask:BackupDestinationLocation="',PlanText)+LEN('SQLTask:BackupDestinationList SQLTask:BackupDestinationLocation="'))))+'''', '"/><SQLTask:BackupDestinationList SQLTask:BackupDestinationLocation="', ''', '''), '''1,','''') From #MaintTask1 Where id = @BackupTaskID 
						select @BackupOptions=@BackupOptions+case When SUBSTRING(PlanText, CHARINDEX('SQLTask:BackupActionForExistingBackups="', PlanText)+LEN('SQLTask:BackupActionForExistingBackups="'), 1) = '0' then ',aAppend existing backup' When SUBSTRING(PlanText, CHARINDEX('SQLTask:BackupActionForExistingBackups="', PlanText)+LEN('SQLTask:BackupActionForExistingBackups="'), 1) = '1' Then ', overwrite existing backup' END From #MaintTask1 Where id = @BackupTaskID
						
					END
					
				If (select SUBSTRING(PlanText, CHARINDEX('SQLTask:BackupCreateSubFolder="', PlanText)+LEN('SQLTask:BackupCreateSubFolder="'), 1) From #MaintTask1 Where id = @BackupTaskID)= 'T'
					  select @BackupOptions=@BackupOptions+', into their own subfolders'
					
				select @BackupOptions=@BackupOptions+Case When LEN(RTRIM(SUBSTRING(PlanText,CHARINDEX('SQLTask:BackupFileExtension="',PlanText)+LEN('SQLTask:BackupFileExtension="'),CHARINDEX('" SQLTask:BackupVerifyIntegrity="',PlanText,CHARINDEX('SQLTask:BackupFileExtension="',PlanText))-(CHARINDEX('SQLTask:BackupFileExtension="',PlanText)+LEN('SQLTask:BackupFileExtension="'))))) > 0 Then ', with extension: ''.'+RTRIM(SUBSTRING(PlanText,CHARINDEX('SQLTask:BackupFileExtension="',PlanText)+LEN('SQLTask:BackupFileExtension="'),CHARINDEX('" SQLTask:BackupVerifyIntegrity="',PlanText,CHARINDEX('SQLTask:BackupFileExtension="',PlanText))-(CHARINDEX('SQLTask:BackupFileExtension="',PlanText)+LEN('SQLTask:BackupFileExtension="'))))+'''' when SUBSTRING(PlanText, CHARINDEX('SQLTask:BackupFileExtension="', PlanText)+LEN('SQLTask:BackupFileExtension="'), 1) = '"' then '' Else ', with extension: ''.bak''' END From #MaintTask1 Where id = @BackupTaskID 
				
				IF (select SUBSTRING(PlanText, CHARINDEX('SQLTask:BackupVerifyIntegrity="', PlanText)+LEN('SQLTask:BackupVerifyIntegrity="'), 1) From #MaintTask1 Where id = @BackupTaskID) = 'T'
					select @BackupOptions=@BackupOptions+', with verify backup'
				
				IF (select SUBSTRING(PlanText, CHARINDEX('SQLTask:UseExpiration="', PlanText)+LEN('SQLTask:UseExpiration="'), 1) From #MaintTask1 Where id = @BackupTaskID) = 'T'  -- Backup Expire
					BEGIN
						select @BackupOptions=@BackupOptions+', delete backup(s) older than '
						IF (select SUBSTRING(PlanText, CHARINDEX('SQLTask:InDays="', PlanText)+LEN('SQLTask:InDays="'), 1) From #MaintTask1 Where id = @BackupTaskID) = 'T'
							select @BackupOptions=@BackupOptions+RTRIM(SUBSTRING(PlanText,CHARINDEX('SQLTask:RetainDays="',PlanText)+LEN('SQLTask:RetainDays="'),CHARINDEX('" SQLTask:InDays="',PlanText,CHARINDEX('SQLTask:RetainDays="',PlanText))-(CHARINDEX('SQLTask:RetainDays="',PlanText)+LEN('SQLTask:RetainDays="'))))+' days' From #MaintTask1 Where id = @BackupTaskID
						  Else
							select @BackupOptions=@BackupOptions+''''+RTRIM(SUBSTRING(PlanText,CHARINDEX('SQLTask:ExpireDate="',PlanText)+LEN('SQLTask:ExpireDate="'),CHARINDEX('" SQLTask:RetainDays="',PlanText,CHARINDEX('SQLTask:ExpireDate="',PlanText))-(CHARINDEX('SQLTask:ExpireDate="',PlanText)+LEN('SQLTask:ExpireDate="'))))+'''' From #MaintTask1 Where id = @BackupTaskID
					END
				
				select @BackupOptions=@BackupOptions+case When SUBSTRING(PlanText, CHARINDEX('SQLTask:BackupCompressionAction="', PlanText)+LEN('SQLTask:BackupCompressionAction="'), 1) = '1' then ', with backup compression' When SUBSTRING(PlanText, CHARINDEX('SQLTask:BackupCompressionAction="', PlanText)+LEN('SQLTask:BackupCompressionAction="'), 1) = '2' then ', with no backup compression' When SUBSTRING(PlanText, CHARINDEX('SQLTask:BackupCompressionAction="', PlanText)+LEN('SQLTask:BackupCompressionAction="'), 1) = '0' and (select value_in_use from master.sys.configurations where name = 'backup compression default') = 0 then ', with no backup compression' When SUBSTRING(PlanText, CHARINDEX('SQLTask:BackupCompressionAction="', PlanText)+LEN('SQLTask:BackupCompressionAction="'), 1) = '0' and (select value_in_use from master.sys.configurations where name = 'backup compression default') = 1 then ', with backup compression' Else '' End From #MaintTask1 Where id = @BackupTaskID
				
				IF (select SUBSTRING(PlanText, CHARINDEX('SQLTask:BackupTailLog="', PlanText)+LEN('SQLTask:BackupTailLog="'), 1) From #MaintTask1 Where id = @BackupTaskID) = 'T'
					select @BackupOptions=@BackupOptions+', only backup the tail of the log'
				
				update #MaintTask1
				Set TaskOptions = @BackupOptions
				Where id = @BackupTaskID
				
				Set @BackupTaskID = (select case when MIN(id) > 1 then MIN(id) else @BackupTaskID + 1 end from #MaintTask1 Where TaskType = 'DbMaintenanceBackupTask' and id > @BackupTaskID)
			END







		
		
		-- Grab Server Connection Info
		Update #MaintTask1
		set Server = SUBSTRING(PlanText,CHARINDEX('SQLTask:Connection="{',PlanText)+LEN('SQLTask:Connection="{'),CHARINDEX('}"',PlanText,CHARINDEX('SQLTask:Connection="{',PlanText))-(CHARINDEX('SQLTask:Connection="{',PlanText)+LEN('SQLTask:Connection="{'))) 
		
		-- Report
		Insert into #MaintPlansReport 
		SELECT @MaintPlanName, b.SubPlanName, d.InstanceName, c.TaskName, c.TaskType, c.TaskEnabled, c.DatabaseSelectionType, c.IgnoreDatabaseState, c.TaskOptions
		FROM dbo.#SUBPLANS2 b
		LEFT Join [#MaintTask1] c on c.SubPlanID = b.id
		INNER JOIN #MaintPlanConnections2 d on d.ConnectionID=c.Server
		
		Set @MaintID = @MaintID + 1
	END
	
/*	
Select * from #SUBPLANS1
Select * from #SUBPLANS2
Select * from #MaintTask1
Select * from #MaintPlanConnections1
Select * from #MaintPlanConnections2
*/	
	
truncate table #MaintPlans

Select * from #MaintPlansReport order by 1,2
truncate table #MaintPlansReport

drop table #SUBPLANS1
drop table #SUBPLANS2
drop table #MaintTask1
drop table #MaintPlans
drop table #MaintPlansReport
drop table #MaintPlanConnections1
drop table #MaintPlanConnections2
GO