#The name of the Automation Credential Asset this runbook will use to authenticate to Azure.
$CredentialAssetName = 'DefaultAzureCredential'
    
#Get the credential with the above name from the Automation Asset store
$Cred = Get-AutomationPSCredential -Name $CredentialAssetName
if(!$Cred) {
    Throw "Could not find an Automation Credential Asset named '${CredentialAssetName}'. Make sure you have created one in this Automation Account."
}
    
#Connect to your Azure Account
$Account = Add-AzureAccount -Credential $Cred
if(!$Account) {
    Throw "Could not authenticate to Azure using the credential asset '${CredentialAssetName}'. Make sure the user name and password are correct."
}
    
Write-Verbose "Querying WMI" -Verbose
#Get-WmiObject -Namespace "root\Microsoft\SqlServer\ComputerManagement13"  -Class SqlServiceAdvancedProperty |  Format-Table ServiceName, PropertyName, PropertyNumValue, PropertyStrValue -AutoSize
$mc = $null
$mcName = $null
$sqlServices = $null

#Get the WMI info we care about. DisplayName, Name, PathName, StartName, StartMode, State
$mc = Get-WmiObject -Query "select name from win32_computersystem"
$mcName = $mc.Name

$sqlServices = @(
    Get-WmiObject -query "select * from win32_service where Name LIKE 'MSSQL%'" -ErrorAction stop  |
    #This regex matches MSSQLServer and MSSQL$*
    Where-Object {$_.Name -match "^MSSQL(Server$|\$)"} |
    select Name
    )

foreach($sqlService in $sqlServices){
    $instanceName = $sqlService.Name.Replace('MSSQL$','')
    Write-Verbose "Processing $mcName\$instanceName" -Verbose
    $databases = $null
    $databases = @(Invoke-Sqlcmd -Query "use master;with fs as (select database_id, type, size * 8.0 / 1024 size from sys.master_files) select SERVERPROPERTY('MachineName') AS [ServerName], SERVERPROPERTY('ServerName') AS [ServerInstanceName], SERVERPROPERTY('InstanceName') AS [Instance], SERVERPROPERTY('Edition') AS [Edition], SERVERPROPERTY('ProductVersion') AS [ProductVersion], Left(@@Version, Charindex('-', @@version) - 2) As VersionName,db.name as [DatabaseName],db.state,db.compatibility_level,db.collation_name,db.recovery_model_desc,db.is_fulltext_enabled,db.is_broker_enabled,db.is_cdc_enabled,(select sum (size) from fs where type = 0 and fs.database_id = db.database_id) DataFileSizeMB,(select sum(size) from fs where type = 1 and fs.database_id = db.database_id) LogFileSizeMB from sys.databases db;" -ServerInstance "$mcName\$instanceName")
#    $databases = @(Invoke-Sqlcmd -Query "use master;select database_id, type, cast((size * 8.0 / 1024) as decimal(10,2)) as size from sys.master_files;" -ServerInstance "$mcName\$instanceName")
    if($databases.Count -gt 0)
    {
        Write-Verbose "InstanceName,DatabaseName,State,Compat,Collation,Recovery Model,Fulltext,Broker,CDC,DataFileSizeMB,LogFileSizeMB"
        foreach($database in $databases){
            Write-Output $database
            #$dbName = $database.name
            #$dbState = $database.state
            #$dbCompat = $database.compatibility_level
            #$dbCollation = $database.collation_name
            #$dbRecovery = $database.recovery_model
            #$dbFullText = $database.is_fulltext_enabled
            #$dbBroker = $database.is_broker_enabled
            #$dbCdc = $database.is_cdc_enabled
            #$dbDataSize = $database.DataFileSizeMB
            #$dbLogSize = $database.LogFileSizeMB
            #Write-Output "$mcName\$instanceName,$dbName,$dbState,$dbCompat,$dbCollation,$dbRecovery,$dbFullText,$dbBroker,$dbCdc,$dbDataSize,$dbLogSize"
        }
    }
}