USE msdb 
GO 
Set quoted_identifier off 
Set nocount on
declare @DelFunc bit, @cmd varchar(5000),@version int
If OBJECT_ID('udf_schedule_description') > 0
	set @DelFunc = 0
 Else
	set @DelFunc = 1

--select @DelFunc	--debug

set @cmd = "
CREATE FUNCTION [dbo].[udf_schedule_description] (@freq_type INT , 
  @freq_interval INT , 
  @freq_subday_type INT , 
  @freq_subday_interval INT , 
  @freq_relative_interval INT , 
  @freq_recurrence_factor INT , 
  @active_start_date INT , 
  @active_end_date INT, 
  @active_start_time INT , 
  @active_end_time INT ) 
RETURNS NVARCHAR(255) AS 
BEGIN 
DECLARE @schedule_description NVARCHAR(255) 
DECLARE @loop INT 
DECLARE @idle_cpu_percent INT 
DECLARE @idle_cpu_duration INT 

IF (@freq_type = 0x1) -- OneTime 
BEGIN 
SELECT @schedule_description = N'Once on ' + CONVERT(NVARCHAR, @active_start_date) + N' at ' + CONVERT(NVARCHAR, cast((@active_start_time / 10000) as varchar(10)) + ':' + right('00' + cast((@active_start_time % 10000) / 100 as varchar(10)),2)) 
RETURN @schedule_description 
END 
IF (@freq_type = 0x4) -- Daily 
BEGIN 
SELECT @schedule_description = N'Every day ' 
END 
IF (@freq_type = 0x8) -- Weekly 
BEGIN 
SELECT @schedule_description = N'Every ' + CONVERT(NVARCHAR, @freq_recurrence_factor) + N' week(s) on ' 
SELECT @loop = 1 
WHILE (@loop <= 7) 
BEGIN 
IF (@freq_interval & POWER(2, @loop - 1) = POWER(2, @loop - 1)) 
SELECT @schedule_description = @schedule_description + DATENAME(dw, N'1996120' + CONVERT(NVARCHAR, @loop)) + N', ' 
SELECT @loop = @loop + 1 
END 
IF (RIGHT(@schedule_description, 2) = N', ') 
SELECT @schedule_description = SUBSTRING(@schedule_description, 1, (DATALENGTH(@schedule_description) / 2) - 2) + N' ' 
END 
IF (@freq_type = 0x10) -- Monthly 
BEGIN 
SELECT @schedule_description = N'Every ' + CONVERT(NVARCHAR, @freq_recurrence_factor) + N' months(s) on day ' + CONVERT(NVARCHAR, @freq_interval) + N' of that month ' 
END 
IF (@freq_type = 0x20) -- Monthly Relative 
BEGIN 
SELECT @schedule_description = N'Every ' + CONVERT(NVARCHAR, @freq_recurrence_factor) + N' months(s) on the ' 
SELECT @schedule_description = @schedule_description + 
CASE @freq_relative_interval 
WHEN 0x01 THEN N'first ' 
WHEN 0x02 THEN N'second ' 
WHEN 0x04 THEN N'third ' 
WHEN 0x08 THEN N'fourth ' 
WHEN 0x10 THEN N'last ' 
END + 
CASE 
WHEN (@freq_interval > 00) 
AND (@freq_interval < 08) THEN DATENAME(dw, N'1996120' + CONVERT(NVARCHAR, @freq_interval)) 
WHEN (@freq_interval = 08) THEN N'day' 
WHEN (@freq_interval = 09) THEN N'week day' 
WHEN (@freq_interval = 10) THEN N'weekend day' 
END + N' of that month ' 
END 
IF (@freq_type = 0x40) -- AutoStart 
BEGIN 
SELECT @schedule_description = FORMATMESSAGE(14579) 
RETURN @schedule_description 
END 
IF (@freq_type = 0x80) -- OnIdle 
BEGIN 
EXECUTE master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE', 
N'SOFTWARE\Microsoft\MSSQLServer\SQLServerAgent', 
N'IdleCPUPercent', 
@idle_cpu_percent OUTPUT, 
N'no_output' 
EXECUTE master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE', 
N'SOFTWARE\Microsoft\MSSQLServer\SQLServerAgent', 
N'IdleCPUDuration', 
@idle_cpu_duration OUTPUT, 
N'no_output' 
SELECT @schedule_description = FORMATMESSAGE(14578, ISNULL(@idle_cpu_percent, 10), ISNULL(@idle_cpu_duration, 600)) 
RETURN @schedule_description 
END 
-- Subday stuff 
SELECT @schedule_description = @schedule_description + 
CASE @freq_subday_type 
WHEN 0x1 THEN N'at ' + CONVERT(NVARCHAR, cast((@active_start_time / 10000) as varchar(10)) + ':' + right('00' + cast((@active_start_time % 10000) / 100 as varchar(10)),2)) 
WHEN 0x2 THEN N'every ' + CONVERT(NVARCHAR, @freq_subday_interval) + N' second(s)' 
WHEN 0x4 THEN N'every ' + CONVERT(NVARCHAR, @freq_subday_interval) + N' minute(s)' 
WHEN 0x8 THEN N'every ' + CONVERT(NVARCHAR, @freq_subday_interval) + N' hour(s)' 
END 
IF (@freq_subday_type IN (0x2, 0x4, 0x8)) 
SELECT @schedule_description = @schedule_description + N' between ' + 
CONVERT(NVARCHAR, cast((@active_start_time / 10000) as varchar(10)) + ':' + right('00' + cast((@active_start_time % 10000) / 100 as varchar(10)),2) ) + N' and ' + CONVERT(NVARCHAR, cast((@active_end_time / 10000) as varchar(10)) + ':' + right('00' + cast((@active_end_time % 10000) / 100 as varchar(10)),2) ) 

RETURN @schedule_description 
END"
IF @DelFunc = 1
	exec (@cmd)

set @cmd = ''

set @version = (select cast(substring(CAST(serverproperty('ProductVersion') as varchar(50)), 1,patindex('%.%',CAST(serverproperty('ProductVersion') as varchar(50)))-1 ) as int))

If @version = 8
	Begin
		set @cmd = "
		select 
		name as 'Job Name',
		active_start_time,
		CONVERT(varchar(6), JobDuration/3600) + ':' + RIGHT('0' + CONVERT(varchar(2), (JobDuration % 3600) / 60), 2) + ':' + RIGHT('0' + CONVERT(varchar(2), JobDuration % 60), 2) as 'Job Duration',
		case when ScheduleDscr is null then '*Job is not scheduled' else ScheduleDscr end as 'Schedule Description',
		case when enabled = 1 then 'Yes' else 'No' end as 'Enabled', 
		(select name from dbo.syscategories where category_id = catID) As 'Category',
		SUSER_SNAME(owner_sid) as 'Job Owner',
		case 
			when [Status] = 0 then 'Failed'
			when [Status] = 1 then 'Succeeded'
			when [Status] = 2 then 'Retry'
			when [Status] = 3 then 'Canceled'
			when [Status] = 4 then 'In progress'
			else '*No job history'
				end as 'Job Status',
		LastRunStatusMessage as 'Last Status Message'

		From
		(SELECT sysjobs.name, CAST((sysjobschedules.active_start_time / 10000) AS VARCHAR(10)) + ':' + 
		RIGHT('00' + CAST((sysjobschedules.active_start_time % 10000) / 100 AS VARCHAR(10)),2) active_start_time,  
		dbo.udf_schedule_description(sysjobschedules.freq_type, sysjobschedules.freq_interval,  
		sysjobschedules.freq_subday_type, sysjobschedules.freq_subday_interval, sysjobschedules.freq_relative_interval,  
		sysjobschedules.freq_recurrence_factor, sysjobschedules.active_start_date, sysjobschedules.active_end_date,  
		sysjobschedules.active_start_time, sysjobschedules.active_end_time) AS ScheduleDscr, sysjobs.enabled, 
		sysjobs.category_id as catID,
		dbo.sysjobs.owner_sid as owner_sid,
		(select top 1 run_status from dbo.sysjobhistory where dbo.sysjobhistory.job_id = dbo.sysjobs.job_id order by run_date desc,run_time desc) as 'Status',
		(select top 1 message from dbo.sysjobhistory where dbo.sysjobhistory.job_id = dbo.sysjobs.job_id and dbo.sysjobhistory.step_id = 0 order by run_date desc,run_time desc) as 'LastRunStatusMessage',
		(select last_run_duration from dbo.sysjobservers where dbo.sysjobservers.job_id = dbo.sysjobs.job_id) as 'JobDuration'
		FROM sysjobs INNER JOIN 
		sysjobschedules ON sysjobs.job_id = sysjobschedules.job_id) as a
		order by name"
	END

If @version = 9
	Begin
		set @cmd = "
		select name as 'Job Name', active_start_time as 'Start Time', 
		stuff(stuff(replace(str(JobDuration,6,0),' ','0'),3,0,':'),6,0,':') as 'Job Duration',
		case when ScheduleDscr is null then '*Job is not scheduled' else ScheduleDscr end as 'Schedule Description', 
		case when enabled = 1 then 'Yes' else 'No' end as 'Enabled',
		(select name from dbo.syscategories where category_id = catID) As 'Category',
		SUSER_SNAME(owner_sid) as 'Job Owner',
		case when [Status] = 0 then 'Failed'
		when [Status] = 1 then 'Succeeded'
		when [Status] = 2 then 'Retry'
		when [Status] = 3 then 'Canceled'
		when [Status] = 4 then 'In progress'
		else '*No job history'
		end as 'Job Status'

		from (
		SELECT dbo.sysjobs.name, CAST(dbo.sysschedules.active_start_time / 10000 AS VARCHAR(10))   
		+ ':' + RIGHT('00' + CAST(dbo.sysschedules.active_start_time % 10000 / 100 AS VARCHAR(10)), 2) AS active_start_time,   
		dbo.udf_schedule_description(dbo.sysschedules.freq_type, dbo.sysschedules.freq_interval,  
		dbo.sysschedules.freq_subday_type, dbo.sysschedules.freq_subday_interval, dbo.sysschedules.freq_relative_interval,  
		dbo.sysschedules.freq_recurrence_factor, dbo.sysschedules.active_start_date, dbo.sysschedules.active_end_date,  
		dbo.sysschedules.active_start_time, dbo.sysschedules.active_end_time) AS ScheduleDscr, 
		dbo.sysjobs.enabled,
		dbo.sysjobs.category_id as catID,
		dbo.sysjobs.job_id as jobID,
		dbo.sysjobs.owner_sid as owner_sid,
		(select top 1 run_status from dbo.sysjobhistory where dbo.sysjobhistory.job_id = dbo.sysjobs.job_id order by run_date desc,run_time desc) as 'Status',
		(select top 1 message from dbo.sysjobhistory where dbo.sysjobhistory.job_id = dbo.sysjobs.job_id and dbo.sysjobhistory.step_id = 0 order by run_date desc,run_time desc) as 'LastRunStatusMessage',
		(select last_run_duration from dbo.sysjobservers where dbo.sysjobservers.job_id = dbo.sysjobs.job_id) as 'JobDuration'
		FROM dbo.sysjobs left JOIN  
		dbo.sysjobschedules ON dbo.sysjobs.job_id = dbo.sysjobschedules.job_id left JOIN  
		dbo.sysschedules ON dbo.sysjobschedules.schedule_id = dbo.sysschedules.schedule_id) as a
		order by name"
	End

If @version > 9
	Begin
		set @cmd = "
		select name as 'Job Name', active_start_time as 'Start Time', 
		stuff(stuff(replace(str(JobDuration,6,0),' ','0'),3,0,':'),6,0,':') as 'Job Duration', 
		case when ScheduleDscr is null then '*Job is not scheduled' else ScheduleDscr end as 'Schedule Description', 
		case when enabled = 1 then 'Yes' else 'No' end as 'Enabled',
		(select name from dbo.syscategories where category_id = catID) As 'Category',
		SUSER_SNAME(owner_sid) as 'Job Owner',
		case 
			when [Status] = 0 then 'Failed'
			when [Status] = 1 then 'Succeeded'
			when [Status] = 2 then 'Retry'
			when [Status] = 3 then 'Canceled'
			when [Status] = 4 then 'In progress'
			else '*No job history'
				end as 'Job Status',
		LastRunStatusMessage as 'Last Status Message'

		from (
		SELECT dbo.sysjobs.name, CAST(dbo.sysschedules.active_start_time / 10000 AS VARCHAR(10))   
		+ ':' + RIGHT('00' + CAST(dbo.sysschedules.active_start_time % 10000 / 100 AS VARCHAR(10)), 2) AS active_start_time,   
		dbo.udf_schedule_description(dbo.sysschedules.freq_type, dbo.sysschedules.freq_interval,  
		dbo.sysschedules.freq_subday_type, dbo.sysschedules.freq_subday_interval, dbo.sysschedules.freq_relative_interval,  
		dbo.sysschedules.freq_recurrence_factor, dbo.sysschedules.active_start_date, dbo.sysschedules.active_end_date,  
		dbo.sysschedules.active_start_time, dbo.sysschedules.active_end_time) AS ScheduleDscr, 
		dbo.sysjobs.enabled,
		dbo.sysjobs.category_id as catID,
		dbo.sysjobs.job_id as jobID,
		dbo.sysjobs.owner_sid as owner_sid,
		(select top 1 run_status from dbo.sysjobhistory where dbo.sysjobhistory.job_id = dbo.sysjobs.job_id order by run_date desc,run_time desc) as 'Status',
		(select top 1 message from dbo.sysjobhistory where dbo.sysjobhistory.job_id = dbo.sysjobs.job_id and dbo.sysjobhistory.step_id = 0 order by run_date desc,run_time desc) as 'LastRunStatusMessage',
		(select last_run_duration from dbo.sysjobservers where dbo.sysjobservers.job_id = dbo.sysjobs.job_id) as 'JobDuration'
		FROM dbo.sysjobs 
		left JOIN  
			dbo.sysjobschedules ON dbo.sysjobs.job_id = dbo.sysjobschedules.job_id 
		left JOIN  
			dbo.sysschedules ON dbo.sysjobschedules.schedule_id = dbo.sysschedules.schedule_id) as a
		order by name"
	End
	
Exec(@cmd)

IF @DelFunc = 1
	Drop Function [udf_schedule_description]
go