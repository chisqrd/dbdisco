#Requires -Modules AzureRM.Profile,AzureRM.OperationalInsights,AzureRM.Insights
Param
(
    [Parameter (Mandatory= $true)]
    [string] $subscriptionId,

    [Parameter (Mandatory= $true)]
    [string] $resourceGroupName,
    
    [Parameter (Mandatory= $true)]
    [string] $principalName,

    [Parameter (Mandatory= $true)]
    [SecureString] $principalPassword,

    [Parameter (Mandatory= $true)]
    [string] $workspaceId,

    [Parameter (Mandatory= $true)]
    [string] $automationAccountName
)

try {
    Login-AzureRmAccount
    $sp = New-AzureRmADServicePrincipal -DisplayName $principalName -Password $principalPassword
    "Waiting for service principal creation"
    Start-Sleep 20
    New-AzureRmRoleAssignment -RoleDefinitionName Contributor -ServicePrincipalName $sp.ApplicationId

    $connectionName = $principalName
    try
    {

        # Get the connection "AzureRunAsConnection "
        $servicePrincipalConnection=Get-AutomationConnection -Name $connectionName         
    
        "Logging in to Azure..."
        Add-AzureRmAccount `
            -ServicePrincipal `
            -TenantId $servicePrincipalConnection.TenantId `
            -ApplicationId $servicePrincipalConnection.ApplicationId `
            -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint 
    }
    catch {
        if (!$servicePrincipalConnection)
        {
            $ErrorMessage = "Connection $connectionName not found."
            throw $ErrorMessage
        } else{
            Write-Error -Message $_.Exception
            throw $_.Exception
        }
    }

    # "Importing 1 of 2 required modules: AzureRM.Insights"
    # Import-Module 'AzureRM.Insights'
    # "Importing 2 of 2 required modules: AzureRM.OperationalInsights"
    # Import-Module 'AzureRM.OperationalInsights'

    #$automationAccountName = (Get-AzureRmAutomationAccount -ResourceGroupName $resourceGroupName).AutomationAccountName    
    #$workspaceId = (Get-AzureRmOperationalInsightsWorkspace -ResourceGroupName $resourceGroupName).ResourceId

    #$subscriptionId = (Get-AzureRmContext).Subscription.Id
    $automationAccountId = "/subscriptions/$subscriptionid/resourceGroups/$resourceGroupName/providers/Microsoft.Automation/automationAccounts/$automationAccountName"
 
    #Get-AzureRmDiagnosticSetting -ResourceId $automationAccountId
    Set-AzureRmDiagnosticSetting -ResourceId $automationAccountId -WorkspaceId $workspaceId -Enabled $true
    Get-AzureRmDiagnosticSetting -ResourceId $automationAccountId
}
catch {
    Write-Error -Message $_.Exception
}