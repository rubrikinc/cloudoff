param(
  [Parameter(Mandatory=$True)]
  [string]$instanceId,
  [Parameter(Mandatory=$True)]
  [string]$region,
  [Parameter(Mandatory=$True)]
  [string]$bucket,
  [Parameter(Mandatory=$True)]
  [string]$downloadDirectory,
  [Parameter(Mandatory=$True)]
  [string]$vCenter,
  [Parameter(Mandatory=$True)]
  [string]$vmNetwork
)

$targetEnvironment = "vmware"
$containerFormat = "VMDK"
$AWSCLI = "C:\Program Files\Amazon\AWSCLI\aws.exe"

function getHost {

  $metrics = "mem.usage.average"



  $esx = Get-VMHost -Location $vmCLuster

  $stats = Get-Stat -Entity $esx -Stat $metrics -Realtime -MaxSamples 1

  $avg = $stats | Measure-Object -Property Value -Average | Select -ExpandProperty Average

  $stats | where{$_.Value -lt $avg} | Get-Random | Select -ExpandProperty Entity

}

write-host "$(Get-Date -Format G): Preparing for AWS Instance to vSphere VM Migration..."

write-host "$(Get-Date -Format G): Connecting to vCenter $vCenter..."

Connect-VIServer -Server $vCenter

$vmDatastore = Get-DatastoreCluster -Name demo-pure-dsc
$vmCluster = Get-Cluster -name "Demo"
$vmHost = getHost
$rk_object_name = (Get-EC2Tag -Region $region | where {$_.ResourceId -eq "$instanceId" -and $_.Key -eq "rk_object_name"}).value
$vmNewName = "$($rk_object_name)-from-AWS" 
$ovaFile = "$($downloadDirectory)\$($rk_object_name).ova"


write-host "$(Get-Date -Format G): Migrating AWS instance $instanceId to $vCenter as $vmNewName"

write-host "$(Get-Date -Format G): Stopping instance $instanceId with rk_object_name $rk_object_name..."

Stop-EC2Instance -InstanceId $instanceId -Region $region

while (($instanceState = (Get-EC2Instance -InstanceId  $instanceId -Region $region).Instances.state.name.value
) -ne 'stopped') { 
  write-host "$(Get-Date -Format G): Instance $instanceId power state is: $instanceState"
  Start-Sleep 30 
} 

write-host "$(Get-Date -Format G): Instance $instanceId power state has: $instanceState"

write-host "$(Get-Date -Format G): Exporting instance $instanceId with rk_object_name $rk_object_name to bucket $bucket..."

$exportTaskId = (& $AWSCLI ec2 create-instance-export-task --instance-id $instanceId --target-environment $targetEnvironment --region $region --export-to-s3-task DiskImageFormat=$containerFormat,ContainerFormat=ova,S3Bucket=$bucket,S3Prefix="$($rk_object_name)-" --output json | ConvertFrom-Json).ExportTask.ExportTaskId

while (($status = (Get-EC2ExportTask -ExportTaskId $exportTaskId -Region $region).State.Value) -ne 'completed') {
  Write-Host "$(Get-Date -Format G): AWS export task status is: $status"
  Start-Sleep 30
} 

Write-host "$(Get-Date -Format G): AWS export task has: $status"

write-host "$(Get-Date -Format G): Downloading exported VM $rk_object_name..."
 
Copy-S3Object -BucketName $bucket -Key "$($rk_object_name)-$($exportTaskId).ova" -LocalFile "$ovaFile" -Region $region

write-host "$(Get-Date -Format G): Updating network in $ovaFile"

$ovfConfig = Get-OvfConfiguration "$ovaFile"
$ovfConfig.NetworkMapping.VM_Network.Value = "$vmNetwork"


write-host "$(Get-Date -Format G): Uploading $ovafile to vCenter $vCenter in datacenter $datacenter on cluster $cluster..."

Import-VApp -Source "$ovaFile" -Name $vmNewName -Location $vmCluster -DataStore $vmDatastore -Server $vCenter -VMHost $vmHost -OvfConfiguration $ovfConfig

write-host "$(Get-Date -Format G): Powering on VM $vmNewName"

Get-VM -Name "$vmNewName" | Start-VM

write-host "$(Get-Date -Format G): Done"

