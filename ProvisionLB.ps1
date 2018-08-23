<#
    .DESCRIPTION
    

    .NOTES
        AUTHOR:
        LASTEDIT:
#>

$connectionName = "AzureRunAsConnection"
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

# Values Used for Script Execution
$VNetResourceGroupName = "bobroud-asrtesting"       # Existing Resource group name for Vnet
$VNetName = "drnet"                                 # Existing Virtual network name
$SubnetName = "default"                             # Existing Subnet name
$ILBName = "clusterlb"                              # Existing ILB name                      
$ILBIP = "10.10.0.9"                                # New IP address
$LBResourceGroupName = "clustertesting-asr"         # Existing Resource group name for LB
$LBResourceGroupLoc = "West US"                     # Resource Group Name for LB
$VMNames = "node1-test","node2-test"                # Exisiting cluster Virtual machine names
$VMResourceGroupName = "clustertesting-asr"         # Existing Resource group name for VM
$ProbePort = "9999"                                 # Probe port - MUST be unique value per LB
$lbruletimeout = "10"
$Ports = "8080"

Write-Output $VMNames

# Create Blank LB if one Doesn't Exist
Get-AzureRmLoadBalancer -Name $ILBName -ResourceGroupName $LBResourceGroupname -ev notPresent -ea 0 | Out-Null
if ($notPresent)
{    
  Write-Output "Load Balancer doesn't exist...creating." 
  $ILB = New-AzureRmLoadBalancer -ResourceGroupName $LBResourceGroupName -Name $ILBName -Location $LBResourceGroupLoc
} else {
    $ILB = Get-AzureRmLoadBalancer -Name $ILBName -ResourceGroupName $LBResourceGroupName
}

# Change the prefix for FE/BE and Probe Names Here if Desired
$count = $ILB.FrontendIpConfigurations.Count + 1
$FrontEndConfigurationName ="lbFrontend$count"        # Name for LB FE Configuration
$LBProbeName = "lbProbe$count"                        # name for LB Probe for LB Rules
$BackEndConfigurationName  = "backendPool$count"      # name for LB BE Pool Configuration

# Get the Azure VNet and Subnet
$VNet = Get-AzureRmVirtualNetwork -Name $VNetName -ResourceGroupName $VNetResourceGroupName
$Subnet = Get-AzureRmVirtualNetworkSubnetConfig -VirtualNetwork $VNet -Name $SubnetName

# Add Frontend and Probe config
Write-Output "Adding new front end IP Pool '$FrontEndConfigurationName' ..."
$ILB | Add-AzureRmLoadBalancerFrontendIpConfig -Name $FrontEndConfigurationName -PrivateIpAddress $ILBIP -SubnetId $Subnet.Id 
$ILB | Add-AzureRmLoadBalancerProbeConfig -Name $LBProbeName  -Protocol Tcp -Port $Probeport -ProbeCount 2 -IntervalInSeconds 10  | Set-AzureRmLoadBalancer

#Get new updated config
$ILB = Get-AzureRmLoadBalancer -Name $ILBname -ResourceGroupName $LBResourceGroupName

# Get new updated LP FrontendIP Config
$FEConfig = Get-AzureRmLoadBalancerFrontendIpConfig -Name $FrontEndConfigurationName -LoadBalancer $ILB
$HealthProbe  = Get-AzureRmLoadBalancerProbeConfig -Name $LBProbeName -LoadBalancer $ILB

# Add new backend config into ILB
Write-Output "Adding new backend Pool '$BackEndConfigurationName' ..."
$BEConfig = Add-AzureRmLoadBalancerBackendAddressPoolConfig -Name $BackEndConfigurationName -LoadBalancer $ILB | Set-AzureRmLoadBalancer 

# Get New Updated Config
$ILB = Get-AzureRmLoadBalancer -Name $ILBname -ResourceGroupName $LBResourceGroupName

# Assign VM NICs to backend pool
$BEPool = Get-AzureRmLoadBalancerBackendAddressPoolConfig -Name $BackEndConfigurationName -LoadBalancer $ILB 
foreach($VMName in $VMNames){
        $VM = Get-AzureRmVM -ResourceGroupName $VMResourceGroupName -Name $VMName 
        $NICName = ($VM.NetworkProfile.NetworkInterfaces[0].Id.Split('/') | select -last 1)        
        $NIC = Get-AzureRmNetworkInterface -name $NICName -ResourceGroupName $VMResourceGroupName
        # Command to add BEPool changes if LB configuration already exists
        If ($NIC.IpConfigurations[0].LoadBalancerBackendAddressPools) {
          $NIC.IpConfigurations[0].LoadBalancerBackendAddressPools += $BEPool
        } else {
          $NIC.IpConfigurations[0].LoadBalancerBackendAddressPools = $BEPool
        }          
        Write-Output "Assigning network card '$NICName' of the '$VMName' VM to the backend pool '$BackEndConfigurationName' ..."
        Set-AzureRmNetworkInterface -NetworkInterface $NIC
        #start-AzureRmVM -ResourceGroupName $VMResourceGroupName -Name $VM.Name 
}

# Create Load Balancing Rules
$ILB = Get-AzureRmLoadBalancer -Name $ILBname -ResourceGroupName $LBResourceGroupName
$FEConfig = get-AzureRMLoadBalancerFrontendIpConfig -Name $FrontEndConfigurationName -LoadBalancer $ILB
$BEConfig = Get-AzureRmLoadBalancerBackendAddressPoolConfig -Name $BackEndConfigurationName -LoadBalancer $ILB 
$HealthProbe  = Get-AzureRmLoadBalancerProbeConfig -Name $LBProbeName -LoadBalancer $ILB

Write-Output "Creating load balancing rules for the ports: '$Ports' ... "

foreach ($Port in $Ports) {
		
        $LBConfigrulename = "lbrule$Port" + "_$count"
        Write-Output "Creating load balancing rule '$LBConfigrulename' for the port '$Port' ..."
        
        $ILB | Add-AzureRmLoadBalancerRuleConfig -Name $LBConfigRuleName -FrontendIpConfiguration $FEConfig -BackendAddressPool $BEConfig -Probe $HealthProbe -Protocol tcp -FrontendPort $Port -BackendPort $Port -IdleTimeoutInMinutes $lbruletimeout -LoadDistribution Default
}

$ILB | Set-AzureRmLoadBalancer

Write-Output "Succesfully added new IP '$ILBIP' to the internal load balancer '$ILBName'!"
