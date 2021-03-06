######################################
# Discovery Powershell Script        #
############################################
# Created 9/19/14                          #
# By: Nick Patti                           #
# Owned by dbaDirect/ Clear Measures       #
# Discovery Scripts created by Morgan Jung #
########################################################################################
# This Powershell script calls all the discovery scripts within the SQL_Scripts folder #
# Runs each script against each server                                                 #
# Generates a seperate output folder for each server                                   #
# Saves the output as a .csv file                                                      #
# There is another script that will compile the output into an spreadsheet per server  #
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

Write-Host "dbaDirect Discovery via Powershell"
Write-Host "Created by Nick Patti"
Write-Host "Last modified 10/2/2014 by Nick Patti"

Write-Host "Please be sure to update 'servers.txt' before starting."
Start-Sleep -s 1
Write-Host "If you encounter errors, be sure you run Powershell as Administrator and set the Policy with the command ""Set-ExecutionPolicy RemoteSigned"". Refer to http://technet.microsoft.com/en-us/library/ee176961.aspx  "
Start-Sleep -s 1
Write-Host "Refer to the CSVSuccess.txt and CSVFailures.txt logs when finished to see which servers completed and which failed."
Start-Sleep -s 1
Write-Host "Starting in 5 seconds"
Start-Sleep -s 1
Write-Host "Starting in 4 seconds"
Start-Sleep -s 1
Write-Host "Starting in 3 seconds"
Start-Sleep -s 1
Write-Host "Starting in 2 seconds"
Start-Sleep -s 1
Write-Host "Starting in 1 seconds"
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

    $queryTimeout = 600
    $ConnectionTimeout = 60
    $scriptPath = Resolve-Path "SQL_Scripts"
    $servers = Resolve-Path "servers.txt"
    $outputCSV = "CSV"
    $LogPath = "logs"
    $pct = 0
    $workingCount =1

#Main TRY block
TRY
{    
$Target= @()
	ForEach ($instance in Get-Content $servers){ ## Loop through each server in the text file
TRY
{   
    $count = (Get-Content $servers).count

    Write-Host ""
    Start-Sleep -s 1
    Write-Host "By my count, we have $count servers to process. Hang on to your seats!"
    Write-Host ""
    
    #Create main CSV output folder if not exists
    if(!(Test-Path -Path $outputCSV ))
        {
        New-Item -ItemType directory -Path $outputCSV | Out-Null
        }
    $outputCSV = Resolve-Path "CSV"

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
        
    #Create output file for each instance        
    if(!(Test-Path -Path $outputFolder ))
        {
        New-Item -ItemType directory -Path $outputFolder | Out-Null
        }
    
    #Output working instance
    Write-Host "Working on instance: $instance"
    Write-Host "Output folder is: $outputFolder"
    Write-Host ""
    
    #Loop through scripts
    Write-Host "Executing scripts from: $scriptPath"
    Write-Host "Log files are being written to $LogPath"
    Write-Host ""
    
    #Find Files
    $files = Get-ChildItem $scriptPath

    #For each file, extract content into $query
    #Set the $OutputFile to the $OutputFolder plus file name with .csv extension
    #Run each query, passing query timeout, instance name, query, and output file
    for ($i=0; $i -lt $files.Count; $i++) {
        Write-Host "Executing script: " $files[$i].FullName
        $query = Get-Content $files[$i].FullName | Out-String

        
        #Determine Output file for this script
        $outputFile = $outputFolder + [io.path]::GetFileNameWithoutExtension($files[$i].FullName) + '.csv'
        Write-Host "Writing results to file: $outputFile"
        invoke-sqlcmd -inputfile $files[$i].FullName -serverinstance $instance -QueryTimeout $QueryTimeout | export-csv $outputFile -notype
        
    } #Close File Loop
    
    Write-Host ""
    Write-Host -Fore Green “CSV Discovery on $instance has completed successfully”
    Write-Host ""
    $DateTime = Get-Date
    echo "Instance $instance discovery completed successfully on $DateTime." | Out-File $LogPath\CSVSuccess.txt -append
    echo " " | Out-File $LogPath\CSVSuccess.txt -append
    

} ##End Try
CATCH
{
    Write-Host ""
    Write-Host -Fore Red "Something went wrong with the conversion on $instance ..."
    Write-Host ""
    $DateTime = Get-Date
    echo "Instance $instance encountered an error on $DateTime. Please verify connectivity before rerunning." | Out-File $LogPath\CSVFailures.txt -append
    echo " " | Out-File $LogPath\CSVFailures.txt -append
    echo "$instance" | Out-File .\servers_redo.txt -append
    
    #Cleanup blank files
    get-childItem "$outputFolder" | where {$_.length -eq 0} | Remove-Item
    
    #Cleanup empty folders
    Get-ChildItem "$outputCSV" -recurse | Where {$_.PSIsContainer -and @(Get-ChildItem -Lit $_.Fullname -r | Where {!$_.PSIsContainer}).Length -eq 0} | Remove-Item -recurse
    
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
Start-Sleep -s 1
Write-Host ""
Write-Host "A list of servers that need to be redone are in servers_redo.txt - but check the log files as well"
Start-Sleep -s 1
Write-Host ""
Write-Host "The CSV folder should be compressed and copied up to your laptop to C:\Powershell\Discovery"    
Start-Sleep -s 1
Write-Host ""
Write-Host "Then unzip and use the Compile script locally to generate a summary spreadsheet"
Start-Sleep -s 1 
Write-Host ""
Write-Host "Don't cry because it's over. Smile because it happened. - Dr. Seuss"
