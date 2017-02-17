use DISCOVERY
CREATE TABLE stg_00 (
[Server Instance Name] varchar(255),
[SQL Server Edition] varchar(255),
[Bit Architecture] varchar(255),
[SQL Server Version] varchar(255),
[Authentication] varchar(255),
[Sort Order] varchar(255),
[Port] varchar(255),
[Name Pipe] varchar(255),
[Instance Home] varchar(255),
[Error Log Location] varchar(255),
[Log Shipping] varchar(255),
[Replication] varchar(255),
[Full Text Indexing] varchar(255),
[Connectivity Protocol] varchar(255)
)

use DISCOVERY
CREATE TABLE stg_01 (
[Hostname] varchar(255),[Server Name] varchar(255),[OS Version] varchar(255),
[SQL Server Edition] varchar(255),[SQL Version] varchar(255),[Clustered] varchar(255),
[Instance Owners] varchar(255),[Full Text Installed] varchar(255),[Security Mode] varchar(255),
[Collation] varchar(255),[Port] varchar(255),[Default Pipe] varchar(255),[Default Path] varchar(255),
[Errorlog Location] varchar(255),[Auto Restart SQL] varchar(255),
[SQL Server Startup Account] varchar(255),[Auto Restart Agent] varchar(255),
[SQL Agent Startup Account] varchar(255),[SQL Agent Mail Setup] varchar(255),
[Replication Installed] varchar(255),[Has 3GB Switch] varchar(255),[Has PAE Switch] varchar(255),
[Min Memory MB] varchar(255),[Max Memory MB] varchar(255),[AWE Enabled] varchar(255)
)

use DISCOVERY
CREATE TABLE stg_02 (
[dbname]varchar(255),[DatabaseOwner]varchar(255),[IsAutoClose]varchar(255),
[IsAutoShrink]varchar(255),[Recovery]varchar(255),[Status]varchar(255),
[IsAutoCreateStatistics]varchar(255),[IsAutoUpdateStatistics]varchar(255),
[PageVerify]varchar(255),[Updateability]varchar(255),[UserAccess]varchar(255)
,[IsPublished]varchar(255),[IsMergePublished]varchar(255),[IsSubscribed]varchar(255),
[FullTextIndexes]varchar(255),[Is Log Shipping Primary]varchar(255)
,[Is Log Shipping Secondary]varchar(255),[MirrorRole]varchar(255),[MirrorType]varchar(255)
,[MirrorPartner]varchar(255))

CREATE TABLE stg_03 (
[Database_Name]varchar(255),[Filegroup]varchar(255),[Logical_Name]varchar(255),[Size]varchar(255),[MaxSize]varchar(255),[used_mb]varchar(255),[percent_used]varchar(255),[Growth]varchar(255),[autogrow]varchar(255),[growth_check]varchar(255),[filename]varchar(255)
)

CREATE TABLE stg_04 (
[dbName]varchar(255),[LastFullBackupDate]varchar(255),[LastDiffBackupDate]varchar(255),[LastLogBackupDate]varchar(255),[RecoveryModel]varchar(255),[FullBackupIntv]varchar(255),[DiffBackupIntv]varchar(255),[LogBackupIntv]varchar(255)
)

CREATE TABLE stg_05 (
[DbName]varchar(255),[Type]varchar(255),[backup_start_date]varchar(255),[backup_finish_date]varchar(255),[DurationMINs]varchar(255),[size]varchar(255),[physical_device_name] varchar(255)
)


CREATE TABLE stg_06 (
DatabaseName varchar(255),LastRanDBCCCHECKDB varchar(255)
)


CREATE TABLE stg_07 (
[Index]varchar(255),[Name]varchar(255),[Internal_Value]varchar(255),[Character_Value]varchar(255)
)

CREATE TABLE stg_08 (
[Volume]varchar(255),[TotalGB]varchar(255),[AvailableGB]varchar(255),PercentUsed varchar(255)
)

CREATE TABLE stg_09 (
name varchar(255),value_in_use varchar(255)
)

CREATE TABLE stg_10 (
[Job Name]varchar(255),[Start Time]varchar(255),[Job Duration]varchar(255),[Schedule Description]varchar(255),[Enabled]varchar(255),[Category]varchar(255),[Job Owner]varchar(255),[Job Status]varchar(255),[Last Status Message]varchar(255)
)

CREATE TABLE stg_11 (
MaintPlanName varchar(255),SubPlanName varchar(255), InstanceName varchar(255), TaskName varchar(255), TaskType varchar(255), TaskEnabled varchar(255), DatabaseSelectionType varchar(255), IgnoreDatabaseState varchar(255), TaskOptions varchar(255)
)

CREATE TABLE stg_12 (
[LogDate]varchar(255),[ProcessInfo]varchar(255),[Text]varchar(2000)
)

CREATE TABLE stg_13 (
[SQLEngine]varchar(255),[SQLInstance]varchar(255),[SQLEdition]varchar(255),[SQLVersion]varchar(255)
)

CREATE TABLE stg_14 (
[DatabaseName]varchar(255),[dbi_dbccFlags Value]varchar(255),[DBCC Syntax]varchar(255)
)