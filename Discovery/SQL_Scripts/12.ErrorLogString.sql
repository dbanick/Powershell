use master
go

Declare @Cmd varchar(8000)
Declare @LogCount int
set nocount on
set quoted_identifier off

declare @version int
set @version = (select cast(substring(CAST(serverproperty('ProductVersion') as varchar(50)), 1,patindex('%.%',CAST(serverproperty('ProductVersion') as varchar(50)))-1 ) as int))
--select @version

IF @version = 8
	Begin
		set @Cmd = "create table #t1 ([ErrorLog] varchar(4000),CRow int)
					insert into #t1 exec xp_readerrorlog
					insert into #t1 exec xp_readerrorlog 1
					insert into #t1 exec xp_readerrorlog 2 
					insert into #t1 exec xp_readerrorlog 3
					insert into #t1 exec xp_readerrorlog 4
					
					select substring(ErrorLog, 1, patindex('%.%',ErrorLog)+2) as 'Date', ErrorLog from #t1 
						Where ErrorLog like '%AWE%' or ErrorLog like '%Locked%' or ErrorLog like '%Replication%' or ErrorLog like '%Backup Failed%' or ErrorLog like '%EXCEPTION_ACCESS_VIOLATION%' or ErrorLog like '%Stack Signature%' or ErrorLog like '%SUSPECT%' or ErrorLog like '%Error: 822%' or ErrorLog like '%Error: 926%' or ErrorLog like '%SQLServiceControlHandler%' or ErrorLog like '%The handle is invalid%' or ErrorLog like '%Could not allocate%' or ErrorLog like '%A significant part of sql server memory has been paged out%' or ErrorLog like '%A significant part of sql server process memory has been paged out%' or ErrorLog like '%Using locked pages for buffer pool%' or ErrorLog like '%Address Windowing Extensions%' or ErrorLog like '%lock memory privilege was not granted%'
						order by 1
					
					Drop table #t1"
		exec(@Cmd)
	End
IF @version > 8
	Begin
		create table #t2 (LogDate datetime, ProcessInfo nvarchar(20), [Text] nvarchar(4000))
		set @LogCount = 0
		While @LogCount <= 4
			Begin
				set @Cmd = "Declare @Param1 int, @Param2 int, @Param3 nvarchar(255), @Param4 nvarchar(255), @Param5 datetime, @Param6 Datetime, @Param7 nvarchar(4), @StartTime Datetime, @EndTIme Datetime
							set @Param1 = "+cast(@LogCount as varchar(2))+"			
							set @Param2 = 1			
							set @Param3 = 'AWE'		
							set @Param4 = null		
							set @Param5 = @StartTime	
							set @Param6 = @EndTIme		
							set @Param7 = 'asc'		

							--select @StartTime,@EndTIme	--debug

							insert into #t2 exec xp_readerrorlog @Param1, @Param2, @Param3, @Param4, @Param5, @Param6, @Param7

							set @Param1 = "+cast(@LogCount as varchar(2))+"			
							set @Param2 = 1			
							set @Param3 = 'Locked'		
							set @Param4 = null		
							set @Param5 = @StartTime	
							set @Param6 = @EndTIme		
							set @Param7 = 'asc'		

							--select @StartTime,@EndTIme	--debug

							insert into #t2 exec xp_readerrorlog @Param1, @Param2, @Param3, @Param4, @Param5, @Param6, @Param7

							set @Param1 = "+cast(@LogCount as varchar(2))+"			
							set @Param2 = 1			
							set @Param3 = 'Replication'		
							set @Param4 = null		
							set @Param5 = @StartTime	
							set @Param6 = @EndTIme		
							set @Param7 = 'asc'		

							--select @StartTime,@EndTIme	--debug

							insert into #t2 exec xp_readerrorlog @Param1, @Param2, @Param3, @Param4, @Param5, @Param6, @Param7

							set @Param1 = "+cast(@LogCount as varchar(2))+"			
							set @Param2 = 1			
							set @Param3 = 'Backup Failed'		
							set @Param4 = null		
							set @Param5 = @StartTime	
							set @Param6 = @EndTIme		
							set @Param7 = 'asc'		

							--select @StartTime,@EndTIme	--debug

							insert into #t2 exec xp_readerrorlog @Param1, @Param2, @Param3, @Param4, @Param5, @Param6, @Param7

							set @Param1 = "+cast(@LogCount as varchar(2))+"			
							set @Param2 = 1			
							set @Param3 = 'EXCEPTION_ACCESS_VIOLATION'		
							set @Param4 = null		
							set @Param5 = @StartTime	
							set @Param6 = @EndTIme		
							set @Param7 = 'asc'		

							--select @StartTime,@EndTIme	--debug

							insert into #t2 exec xp_readerrorlog @Param1, @Param2, @Param3, @Param4, @Param5, @Param6, @Param7

							set @Param1 = "+cast(@LogCount as varchar(2))+"			
							set @Param2 = 1			
							set @Param3 = 'Stack Signature'		
							set @Param4 = null		
							set @Param5 = @StartTime	
							set @Param6 = @EndTIme		
							set @Param7 = 'asc'		

							--select @StartTime,@EndTIme	--debug

							insert into #t2 exec xp_readerrorlog @Param1, @Param2, @Param3, @Param4, @Param5, @Param6, @Param7

							set @Param1 = "+cast(@LogCount as varchar(2))+"			
							set @Param2 = 1			
							set @Param3 = 'SUSPECT'		
							set @Param4 = null		
							set @Param5 = @StartTime	
							set @Param6 = @EndTIme		
							set @Param7 = 'asc'		

							--select @StartTime,@EndTIme	--debug

							insert into #t2 exec xp_readerrorlog @Param1, @Param2, @Param3, @Param4, @Param5, @Param6, @Param7

							set @Param1 = "+cast(@LogCount as varchar(2))+"			
							set @Param2 = 1			
							set @Param3 = 'Error: 822'		
							set @Param4 = null		
							set @Param5 = @StartTime	
							set @Param6 = @EndTIme		
							set @Param7 = 'asc'		

							--select @StartTime,@EndTIme	--debug

							insert into #t2 exec xp_readerrorlog @Param1, @Param2, @Param3, @Param4, @Param5, @Param6, @Param7

							set @Param1 = "+cast(@LogCount as varchar(2))+"			
							set @Param2 = 1			
							set @Param3 = 'Error: 926'		
							set @Param4 = null		
							set @Param5 = @StartTime	
							set @Param6 = @EndTIme		
							set @Param7 = 'asc'		

							--select @StartTime,@EndTIme	--debug

							insert into #t2 exec xp_readerrorlog @Param1, @Param2, @Param3, @Param4, @Param5, @Param6, @Param7

							set @Param1 = "+cast(@LogCount as varchar(2))+"			
							set @Param2 = 1			
							set @Param3 = 'SQLServiceControlHandler'		
							set @Param4 = null		
							set @Param5 = @StartTime	
							set @Param6 = @EndTIme		
							set @Param7 = 'asc'		

							--select @StartTime,@EndTIme	--debug

							insert into #t2 exec xp_readerrorlog @Param1, @Param2, @Param3, @Param4, @Param5, @Param6, @Param7

							set @Param1 = "+cast(@LogCount as varchar(2))+"			
							set @Param2 = 1			
							set @Param3 = 'The handle is invalid'		
							set @Param4 = null		
							set @Param5 = @StartTime	
							set @Param6 = @EndTIme		
							set @Param7 = 'asc'		

							--select @StartTime,@EndTIme	--debug

							insert into #t2 exec xp_readerrorlog @Param1, @Param2, @Param3, @Param4, @Param5, @Param6, @Param7

							set @Param1 = "+cast(@LogCount as varchar(2))+"			
							set @Param2 = 1			
							set @Param3 = 'Could not allocate'		
							set @Param4 = null		
							set @Param5 = @StartTime	
							set @Param6 = @EndTIme		
							set @Param7 = 'asc'		

							--select @StartTime,@EndTIme	--debug

							insert into #t2 exec xp_readerrorlog @Param1, @Param2, @Param3, @Param4, @Param5, @Param6, @Param7

							set @Param1 = "+cast(@LogCount as varchar(2))+"			
							set @Param2 = 1			
							set @Param3 = 'A significant part of sql server memory has been paged out'		
							set @Param4 = null		
							set @Param5 = @StartTime	
							set @Param6 = @EndTIme		
							set @Param7 = 'asc'		

							--select @StartTime,@EndTIme	--debug

							insert into #t2 exec xp_readerrorlog @Param1, @Param2, @Param3, @Param4, @Param5, @Param6, @Param7

							set @Param1 = "+cast(@LogCount as varchar(2))+"			
							set @Param2 = 1			
							set @Param3 = 'A significant part of sql server process memory has been paged out'		
							set @Param4 = null		
							set @Param5 = @StartTime	
							set @Param6 = @EndTIme		
							set @Param7 = 'asc'		

							--select @StartTime,@EndTIme	--debug

							insert into #t2 exec xp_readerrorlog @Param1, @Param2, @Param3, @Param4, @Param5, @Param6, @Param7
							
							set @Param1 = "+cast(@LogCount as varchar(2))+"			
							set @Param2 = 1			
							set @Param3 = 'Using locked pages for buffer pool'		
							set @Param4 = null		
							set @Param5 = @StartTime	
							set @Param6 = @EndTIme		
							set @Param7 = 'asc'		

							--select @StartTime,@EndTIme	--debug

							insert into #t2 exec xp_readerrorlog @Param1, @Param2, @Param3, @Param4, @Param5, @Param6, @Param7

							set @Param1 = "+cast(@LogCount as varchar(2))+"			
							set @Param2 = 1			
							set @Param3 = 'Address Windowing Extensions'		
							set @Param4 = null		
							set @Param5 = @StartTime	
							set @Param6 = @EndTIme		
							set @Param7 = 'asc'		

							--select @StartTime,@EndTIme	--debug

							insert into #t2 exec xp_readerrorlog @Param1, @Param2, @Param3, @Param4, @Param5, @Param6, @Param7
							
							set @Param1 = "+cast(@LogCount as varchar(2))+"			
							set @Param2 = 1			
							set @Param3 = 'lock memory privilege was not granted'		
							set @Param4 = null		
							set @Param5 = @StartTime	
							set @Param6 = @EndTIme		
							set @Param7 = 'asc'		

							--select @StartTime,@EndTIme	--debug

							insert into #t2 exec xp_readerrorlog @Param1, @Param2, @Param3, @Param4, @Param5, @Param6, @Param7

							set @Param1 = "+cast(@LogCount as varchar(2))+"			
							set @Param2 = 1			
							set @Param3 = 'Autogrow of file'		
							set @Param4 = null		
							set @Param5 = @StartTime	
							set @Param6 = @EndTIme		
							set @Param7 = 'asc'		

							--select @StartTime,@EndTIme	--debug

							insert into #t2 exec xp_readerrorlog @Param1, @Param2, @Param3, @Param4, @Param5, @Param6, @Param7

							set @Param1 = "+cast(@LogCount as varchar(2))+"			
							set @Param2 = 1			
							set @Param3 = 'I/O is frozen'		
							set @Param4 = null		
							set @Param5 = @StartTime	
							set @Param6 = @EndTIme		
							set @Param7 = 'asc'		

							--select @StartTime,@EndTIme	--debug

							insert into #t2 exec xp_readerrorlog @Param1, @Param2, @Param3, @Param4, @Param5, @Param6, @Param7"
							
						Exec(@Cmd)
						Set @LogCount = @LogCount + 1
						--print @Cmd
			END
			
			select * from #t2 order by LogDate
			drop table #t2
	END
go
