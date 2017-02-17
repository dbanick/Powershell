use master
go
DECLARE @version numeric(4,2), @servicePak int, @ExecCmd varchar(600)

SET @version = (SELECT CAST(SUBSTRING(CAST(SERVERPROPERTY('ProductVersion') as varchar(50)), 1,CHARINDEX('.',CAST(SERVERPROPERTY('ProductVersion') as varchar(50)))+1 ) as numeric(4,2)))
set @servicePak = (select CONVERT(int,CASE WHEN ISNUMERIC(RIGHT(CAST(serverproperty('ProductLevel') as varchar(3)),1)) = 1 THEN RIGHT(CAST(serverproperty('ProductLevel') as varchar(3)),1) ELSE 0 END))

CREATE TABLE #DriveSpace
	(
	Volume varchar(300),
	TotalGB varchar(20) DEFAULT 'N/A' NOT NULL,
	AvailableGB numeric(20,2) NOT NULL,
	PercentUsed varchar(20) DEFAULT 'N/A' NOT NULL
	)

IF @version >= 11 OR (@version = 10.5 AND RIGHT(@servicePak,1) >= 1)
	BEGIN
		SET @ExecCmd = '
SELECT DISTINCT
	b.volume_mount_point as Volume, 
	CAST(ROUND(CAST(b.total_bytes as numeric(20,2))/1024.00/1024.00/1024.00,2) AS numeric(20,2)) as TotalGB, 
	CAST(ROUND(CAST(b.available_bytes as numeric(20,2))/1024.00/1024.00/1024.00,2) AS numeric(20,2)) as AvailableGB,
	CAST(ROUND(((CAST(b.total_bytes as numeric(20,2))-CAST(b.available_bytes as numeric(20,2)))/CAST(b.total_bytes as numeric(20,2)))*100,2) AS numeric(20,2)) as PercentUsed
FROM sys.master_files a
OUTER APPLY [sys].[dm_os_volume_stats](a.database_id,a.file_id) b'
		
		INSERT INTO #DriveSpace 
			(Volume,TotalGB,AvailableGB,PercentUsed)
			EXEC(@ExecCmd)
	END

 ELSE
	BEGIN
		INSERT INTO #DriveSpace 
			(Volume,AvailableGB)
			EXEC xp_fixeddrives
		
		UPDATE #DriveSpace
			SET AvailableGB = CAST(ROUND((AvailableGB/1024.00),2) as numeric(20,2))
	END

SELECT * FROM #DriveSpace ORDER BY Volume

DROP TABLE #DriveSpace
GO