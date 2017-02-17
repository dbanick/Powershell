DECLARE @cmd nvarchar(500), @dbname nvarchar(255), @DbId int, @MaxDbId int

CREATE TABLE #DBInfoResults ([ParentObject] nvarchar(255), [Object] nvarchar(255), [Field] nvarchar(255), [value] nvarchar(255))
CREATE TABLE #Report ([id] int identity(1,1), [DatabaseName] nvarchar(255), [dbi_dbccFlags Value] nvarchar(5), [DBCC Syntax] nvarchar(500))

INSERT INTO #Report ([DatabaseName]) SELECT name from master..sysdatabases where (512 & status) <> 512 and (32 & status) <> 32 and cmptlevel > 70

SELECT @DbId = 1, @MaxDbId=MAX([id]) FROM #Report
DBCC TRACEON (3604); 

WHILE @DbId <= @MaxDbId
	BEGIN
		TRUNCATE TABLE #DBInfoResults

		SELECT @dbname = [DatabaseName] FROM #Report WHERE [id] = @DbId
		SET @cmd = 'DBCC DBINFO (N'''+@dbname+''') WITH TABLERESULTS'
		INSERT INTO #DBInfoResults
			EXEC(@cmd)

		UPDATE #Report 
			SET [dbi_dbccFlags Value] = (SELECT [value] FROM #DBInfoResults where [Field] = 'dbi_dbccFlags') 
			WHERE [id] = @DbId
		SET @DbId = @DbId + 1
	END

UPDATE #Report 
	SET [DBCC Syntax] = 'DBCC CHECKDB (N'''+[DatabaseName]+''') WITH DATA_PURITY, NO_INFOMSGS;' 
	WHERE [dbi_dbccFlags Value] = 0

SELECT [DatabaseName], [dbi_dbccFlags Value], [DBCC Syntax] FROM #Report 
	ORDER BY [DatabaseName]
GO

DROP TABLE #DBInfoResults
DROP TABLE #Report
GO

/*
Site references:
http://www.sqlskills.com/blogs/paul/bug-dbcc-checkdb-data-purity-checks-are-skipped-for-master-and-model/
http://www.sqlskills.com/blogs/paul/checkdb-from-every-angle-how-to-tell-if-data-purity-checks-will-be-run/
*/