Set-AzureRmVMCustomScriptExtension -ResourceGroupName clustertesting-asr -VMName "node1-test" -Location "West US" -FileUri myURL -Run 'myScript.ps1' -Name StartClusterExtension

$ProtectedSettings = @{"commandToExecute" = "powershell -ExecutionPolicy Unrestricted -File \\node1\c$\Script\startcluster.ps1"};

Set-AzureRmVMExtension -ResourceGroupName "clustertesting-asr" `
    -Location "West US"`
    -VMName "node1-test" `
    -Name "StartCluster" `
    -Publisher "Microsoft.Compute" `
    -ExtensionType "CustomScriptExtension" `
    -TypeHandlerVersion "1.9" `
    -ForceRerun "$(Get-Date)" `
    -ProtectedSettings $ProtectedSettings

$subscriptions = Get-AzureRmSubscription

foreach ($subscription in $subscriptions) {
  Select-AzureRmSubscription -Subscription $subscription.Id
  Get-AzureRmNetworkInterface | where {$_.ProvisioningState -ne "Succeeded"} | ft Name, ResourceGroupName, Location, ProvisioningState
}
