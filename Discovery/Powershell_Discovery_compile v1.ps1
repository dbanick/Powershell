######################################
# Discovery Powershell Script        #
############################################
# Created 10/2/14                          #
# By: Nick Patti                           #
# Owned by dbaDirect/ Clear Measures       #
# Discovery Scripts created by Morgan Jung #
#######################################################################
# This Powershell script compiles all the CSV files in the CSV folder #
# And creates a spreadsheet for each one                              #
#######################################################################
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

Write-Host "dbaDirect Discovery Compilation via Powershell"
Write-Host "Created by Nick Patti"
Write-Host "Last modified 10/2/2014 by Nick Patti"

Write-Host "If you encounter errors, be sure you run Powershell as Administrator and set the Policy with the command ""Set-ExecutionPolicy RemoteSigned"". Refer to http://technet.microsoft.com/en-us/library/ee176961.aspx  "
Start-Sleep -s 1
Write-Host "Refer to the CompileSuccess.txt and CompileFailures.txt logs when finished to see which servers completed and which failed."
Start-Sleep -s 1


[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | out-null

#Begin TRY/CATCH to add snap-ins if needed
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
    $compiledCSV = "Compiled_Spreadsheets"
    $processedCSV = "Processed_CSV"
    $LogPath = "logs"
    $pct = 0
   
#Begin main TRY block for processing all the CSV files
TRY
{   
       
    #Create compiled output folder if not exists
    if(!(Test-Path -Path $compiledCSV ))
        {
        New-Item -ItemType directory -Path $compiledCSV | Out-Null
        }
    $compiledCSV = Resolve-Path "Compiled_Spreadsheets"
    
    #Create processed folder for completed servers if not exists
    if(!(Test-Path -Path $processedCSV ))
        {
        New-Item -ItemType directory -Path $processedCSV | Out-Null
        }
    $processedCSV = Resolve-Path "Processed_CSV"
    
    #Create log folder if not exists
    if(!(Test-Path -Path $LogPath ))
        {
        New-Item -ItemType directory -Path $LogPath | Out-Null
        }
    $LogPath = Resolve-Path "logs"

    Write-Host ""
    Start-Sleep -s 1
    Write-Host "When finished, the compiled spreadsheets will be sent to $compiledCSV"
    Write-Host "And the processed CSV's will be sent to $processedCSV"
    Write-Host "The error logs will be written to $LogPath"
    
    
    ##Qualify the function used
     . .\ConvertCSV-ToExcel.ps1
    
        
    #Find Folders to process
    $files = Get-ChildItem $outputCSV 
    #Verify they are actually folders
    $folders = $files | where-object { $_.PSIsContainer }
    
    #Let's see how many folders we are dealing with
    If (!$folders.Count) 
    {
        $count=0
    }
    Else
    {  
        $count = $folders.Count
    }    
    
    #Let's let everyone know how much work we have to do
    Write-Host ""
    Start-Sleep -s 1
    Write-Host "By my count, we have $count folders to process. Hang on to your seats!"
    Write-Host ""
    
    
    #For each folder, run ConvertCSV-ToExcel function against *.csv
    #Set the spreadsheet name to "Discovery-" plus folder name with .csv extension
    for ($i=0; $i -lt $count; $i++) {

    #Begin TRY block for processing each folder
    TRY
    {
      
        #Move to the directory we will process to make life easier      
        $workingFolder = $folders[$i].FullName
        $workingFolderFriendly = $folders[$i].Name
        Write-Host "Processing CSV files in $workingFolder"
        cd $workingFolder
        
        #Build the output file name
        $report = "Discovery-$workingFolderFriendly.xlsx" 

        #Run the convert function against all CSV files in the current folder, generating the output file in same folder (for now)
        Get-ChildItem *.csv |  Sort -desc | ConvertCSV-ToExcel -output $report
        
        #If it succeeds, move the output file to the compiled folder, overwriting any existing entries
        Move-Item .\$report $compiledCSV -force | Out-Null
        Write-Host -Fore Green “File saved to $compiledCSV\$report”
        
        #Move out of the current directory so we can copy the processed folder to our desired location
        cd $processedCSV
        Move-Item $workingFolder $processedCSV -force  | Out-Null
        Write-Host -Fore Green “Compilation completed - moving $workingFolder to $processedCSV”
        
        $DateTime = Get-Date
        echo "Folder $workingFolderFriendly discovery completed successfully on $DateTime." | Out-File $LogPath\CompileSuccess.txt -append
        echo " " | Out-File $LogPath\CompileSuccess.txt -append
    }
    CATCH
    {
        Write-Host ""
        Write-Host -Fore Red "Something went wrong with the conversion on $workingFolderFriendly ..."
        Write-Host ""
        $DateTime = Get-Date
        echo "Folder $workingFolderFriendly encountered an error on $DateTime. Please review before rerunning." | Out-File $LogPath\CompileFailures.txt -append
        echo " " | Out-File $LogPath\CompileFailures.txt -append
    }
    #End block for trying each folder
    
    $pct = ($i+1)/$count*100
    Write-Host "$pct% complete ..."
    Write-Host ""
  
    } #Close Folder Loop
    


} 
CATCH
{
Write-Host ""
Write-Host -Fore Red "Something is broken ..."
Start-Sleep -s 1
} ##End main TRY/CATCH

Write-Host "" 
Write-Host "Be sure to review the CompileSuccess.txt and CompileFailures.txt to see if any folders need it reran."
Start-Sleep -s 1
Write-Host ""
Write-Host "Make sure the files were correctly converted."




