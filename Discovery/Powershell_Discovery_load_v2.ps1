######################################
# Discovery Powershell Script        #
############################################
# Created 9/19/14                          #
# By: Nick Patti                           #
# Owned by Data Intensity                  #
# Discovery Scripts created by Morgan Jung #
########################################################################################
# This Powershell script loads all the discovery results within the CSV folder         #
# Loops through each subfolder at a time                                               #
# Imports each CSV file into stgx_ table, does some formatting, then loads to p_ table #
# Then calls usp_GenerateRecommendations with the discovery ID                         #
# Creates a recommendations CSV to add to the original CSV folder to be compiled later #
########################################################################################
############################## Change Control ##########################################
# Version 1.0                                                                          #
# Date:                                                                                #
# Modified By:                                                                         #
# Change Log:                                                                          #
#  1.
#
#  2.
#
########################################################################################

cls

$directoryPath = Split-Path $MyInvocation.MyCommand.Path

Write-Host "dbaDirect Discovery LOAD via Powershell"
Write-Host "Created by Nick Patti"
Write-Host "Last modified 2/12/2015 by Nick Patti"


Write-Host "Please be sure to update 'servers.txt' before starting."
Start-Sleep -s 1
Write-Host "If you encounter errors, be sure you run Powershell as Administrator and set the Policy with the command ""Set-ExecutionPolicy RemoteSigned"". Refer to http://technet.microsoft.com/en-us/library/ee176961.aspx  "
Start-Sleep -s 1
Write-Host "Refer to the CSVSuccess.txt and CSVFailures.txt logs when finished to see which servers completed and which failed."
Start-Sleep -s 1


[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | out-null

TRY{
./Initialize-SqlpsEnvironment.ps1
Write-Host "Initializing Powershell"
}
CATCH{
Write-Host "Cannot add Windows PowerShell snap-in SqlServerCmdletSnapin100 because it is already added."
}

#Let's give some info on where we are starting
Write-Host ""
Start-Sleep -s 1
Write-Host "Working out of directory $directoryPath\"
cd $directoryPath

    $queryTimeout = 60
    $ConnectionTimeout = 60
    $servers = Resolve-Path "servers.txt"
    $outputCSV = Resolve-Path "CSV"
    $LogPath = "logs"
    $pct = 0
    $workingCount =1
    $loadServer = "NPATTI2-520"

#Main TRY block
TRY
{    
$Target= @()
	ForEach ($instance in Get-Content $servers){ ## Loop through each server in the text file
TRY
{   
    if ((Get-Content $servers).count -gt 1)
        {
            $count = (Get-Content $servers).count
        }
   else 
        {
            $count = 1
        }
    

    Write-Host ""
    Start-Sleep -s 1
    Write-Host "By my count, we have $count servers to process. Hang on to your seats!"
    Write-Host ""
    

    #Create log folder if not exists
    if(!(Test-Path -Path $LogPath ))
        {
        New-Item -ItemType directory -Path $LogPath | Out-Null
        }
    $LogPath = Resolve-Path "logs"
    
    $s = New-Object ('Microsoft.SqlServer.Management.Smo.Server') $instance
   
    #Create a friendly name for named instance
    $instance_friendly = $instance.replace("\", "_") 
    
    #Designate an output folder for each instance
    $outputFolder = [io.path]::Combine($outputCSV, $instance_friendly)+'\'
        
    
    #Output working instance
    Write-Host "Working on instance: $instance"
    Write-Host "CSV folder is: $outputFolder"
    Write-Host ""
    
    #Find out when the original discovery was ran, so we can compare dates later
    $discRunDate = Get-ChildItem -Path $outputFolder | Where-Object{($_.FullName -match "\\[0-9][0-9].\\?")} | Sort CreationTime | select -First 1    
        
    #Find Files that start with two numbers and a period
    $files = Get-ChildItem $outputFolder | Where-Object{($_.FullName -match "\\[0-9][0-9].\\?")}
    
    #$instance_friendly
    #$files
    
    #Log information about this load - generate an ID, server name, friendly name(for use in naming CSVs/folders), and time
    $SQLQuery = "INSERT INTO Discovery.dbo.DiscoveryLoad (disc_instance, disc_instanceFriendly, disc_runDate) VALUES ('$instance','$instance_friendly', '$($discRunDate.creationtime)' ) "
    #$SQLQuery
    Invoke-Sqlcmd –Query $SQLQuery -ServerInstance $loadServer -QueryTimeout 600

    #Return our ID for use later
    $SQLdiscID = (Invoke-Sqlcmd -server $loadServer -query "select TOP 1 disc_id from [Discovery].[dbo].[DiscoveryLoad] where disc_instanceFriendly = '$instance_friendly' order by disc_loadDate desc")[0]
    Write-Host "Your discovery ID is $SQLdiscID"

    
    # Drop any tables named 'stgx' which are the temp stage tables for loading each server, which may be left over from last time
    Invoke-Sqlcmd -server $loadServer -query "exec [Discovery].[dbo].[usp_droptemp]"

    #For each file, grab the full name to be used in the BULK INSERT statement
    #Process each file, doing the following tasks:
        ############################################
        #1) Make a copy of the "stg_" table for each discovery script to temporarily load CSV results - name as stgx_<instance>___<script number>
        #2) Load the data into the stgx_% tables
        #3) Run proc which cleans up the extra quotes from the CSV
        #4) Copy data from stgx_% tables into respective permanent table p_<discovery script number> for archival purposes
        #5) Cleanup stgx_tables once we are done
        ############################################
    for ($i=0; $i -lt $files.Count; $i++) {
        Write-Host "Importing CSV: " $files[$i].FullName
        $CSVinfo = $files[$i].FullName 
        
        #Setting table names as variables
        $stgtbl = "stgx_"+$instance_friendly + "___" + $files[$i].Name.Substring(0,2)
        $origtbl = "stg_"+$files[$i].Name.Substring(0,2)
        $finaltbl = "p_"+$files[$i].Name.Substring(0,2)
        #$stgtbl
        
        #1) Make a copy of the "stg_" table for each discovery script to temporarily load CSV results - name as stgx_<instance>___<script number>
        $SQLImportSTGQuery = "SELECT * INTO Discovery.dbo.[$stgtbl] FROM Discovery.dbo.$origtbl where 1=2"
        #$SQLImportSTGQuery
        invoke-sqlcmd -Query $SQLImportSTGQuery -ServerInstance $loadServer -QueryTimeout 600 
         
        
        #Determine last row of data to import (to exclude blank line at the end of files)
        if ((Import-Csv $files[$i].FullName).count -gt 1)
            {
                $LastRow = (Import-Csv $files[$i].FullName).count +1
            }
        else 
            {
                $LastRow = 2
            }
        #$LastRow

        #2) Load the data into the stgx_% tables
        $SQLImportQuery = "BULK INSERT Discovery.dbo.[$stgtbl] FROM '$CSVinfo' WITH (FIRSTROW = 2, LASTROW=$LastRow, FIELDTERMINATOR = '"",""', ROWTERMINATOR = '\n')"
        #$SQLImportQuery
        invoke-sqlcmd -Query $SQLImportQuery -ServerInstance $loadServer -QueryTimeout $QueryTimeout 
        
        #3) Run proc which cleans up the extra quotes from the CSV
        invoke-Sqlcmd -ServerInstance $loadServer -query "exec [Discovery].[dbo].[usp_cleanupData] '$stgtbl'"
        
        #4) Copy data from stgx_% tables into respective permanent table p_<discovery script number> for archival purposes
        $SQLCopyQuery = "INSERT INTO Discovery.dbo.$finaltbl SELECT $SQLdiscID, * FROM Discovery.dbo.[$stgtbl]"
        #$SQLCopyQuery
        invoke-sqlcmd -Query $SQLCopyQuery -ServerInstance $loadServer -QueryTimeout $QueryTimeout
        
        #5) Cleanup stgx_tables once we are done
        invoke-Sqlcmd -ServerInstance $loadServer -query "drop table [Discovery].[dbo].[$stgtbl]"
        
    } #Close File Loop
    

    #### - To Do - ####
    #Generate Recommendations by calling proc, passing the discovery batch ID
    invoke-Sqlcmd -ServerInstance $loadServer -query "exec [Discovery].[dbo].[usp_GenerateRecommendations] @discoveryID = $SQLdiscID"
    
    #Export results of Discovery Recommendations to CSV file in same folder
    $outputFile = $outputFolder + '_Recommendations.csv'
    $exportRecommendations = "SELECT DISTINCT * FROM [Discovery].[dbo].[_Recommendations] WHERE [discID] = $SQLdiscID ORDER BY [RequiredToMonitor] DESC, [Priority] DESC"
    invoke-sqlcmd -query $exportRecommendations -serverinstance $loadServer -QueryTimeout $QueryTimeout | export-csv $outputFile -notype
    

    
    Write-Host ""
    Write-Host -Fore Green “CSV LOAD on $instance with ID: $SQLdiscID has completed successfully”
    Write-Host ""
    Write-Host -Fore Green “Recommendations for $instance has been generated and placed in $outputFolder”
    $DateTime = Get-Date
    echo "Instance $instance discovery LOAD completed successfully on $DateTime and has ID of $SQLdiscID." | Out-File $LogPath\CSVSuccess.txt -append
    echo " " | Out-File $LogPath\CSVSuccess.txt -append
    

} ##End Try
CATCH
{
    Write-Host ""
    Write-Host -Fore Red "Something went wrong with the load on $instance ..."
    Write-Host ""
    $DateTime = Get-Date
    echo "Instance $instance encountered an error on $DateTime. Please verify CSV files before rerunning." | Out-File $LogPath\CSVFailures.txt -append
    echo "Last File processed is $CSVinfo and discovery id of $SQLdiscID" | Out-File $LogPath\CSVFailures.txt -append
    echo " " | Out-File $LogPath\CSVFailures.txt -append
    echo "$instance" | Out-File .\servers_redo.txt -append
    
        
} ##End Catch


$pct = $workingCount/$count*100
Write-Host ""
Write-Host "$pct% complete ..."
Write-Host ""
$workingCount = $workingCount + 1

} ##Close server loop

} #Close Main TRY
CATCH
{
Write-Host ""
Write-Host -Fore Red "Something is broken ..."
Write-Host ""
}
Write-Host ""
Write-Host "Be sure to review the CSVSuccess.txt and CSVFailures.txt to see if any servers need it reran"
Write-Host ""
Write-Host "The next step is to compile the CSV files into a spreadsheet per Powershell_Discovery_compile.ps1"
Write-Host ""
