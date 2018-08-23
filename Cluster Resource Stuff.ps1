Get-ClusterGroup
Get-ClusterResource | where-object {$_.resourcetype -eq "IP Address"}

# Add Additional IP Address for Cluster Core Resource Group
$IPResourceName = “IP Address 10.10.0.10"

Add-ClusterResource –Name $IPResourceName –ResourceType “IP Address” –Group “Cluster Group”

$params = @{"Network"="Cluster Network 1";
          "Address"="10.10.0.10"; 
          "SubnetMask"="255.255.255.0";
          "OverrideAddressMatch"=0; 
          "EnableDhcp"=0}

Get-ClusterResource $IPResourceName | Set-ClusterParameter -Multiple $params
Get-ClusterResource "IP Address 10.10.0.10" | Get-ClusterParameter

# Add Additional IP Address for Tomcat Cluster Role
$IPResourceName = “IP Address 10.10.0.9"

Add-ClusterResource –Name $IPResourceName –ResourceType “IP Address” –Group “tomcat-cluster”

$params = @{"Network"="Cluster Network 1";
          "Address"="10.10.0.9"; 
          "ProbePort"="9999"; 
          "SubnetMask"="255.255.255.0";
          "OverrideAddressMatch"=0; 
          "EnableDhcp"=0}

Get-ClusterResource $IPResourceName | Set-ClusterParameter -Multiple $params
Get-ClusterResource "IP Address 10.10.0.9" | Get-ClusterParameter





Remove-ClusterResource -Name "DR Test IP"
Get-ClusterResource "IP Address 10.0.0.10" | Get-ClusterParameter
Get-ClusterResource "IP Address 10.10.0.10" | Get-ClusterParameter
Get-ClusterResource "IP Address 10.0.0.9" | Get-ClusterParameter
Get-ClusterResource "IP Address 10.10.0.9" | Get-ClusterParameter

$ClusterNetworkName = "Cluster Network 1"

$IPResourceName = “IP Address 10.10.0.9" 

$ILBIP = “10.0.0.9"

$params = @{"Address"="$ILBIP"; 
          "ProbePort"="9999"; 
          "SubnetMask"="255.255.255.0"; 
          "Network"="$ClusterNetworkName"; 
          "OverrideAddressMatch"=1; 
          "EnableDhcp"=0}


Get-ClusterResource $IPResourceName | Set-ClusterParameter -Multiple $params

