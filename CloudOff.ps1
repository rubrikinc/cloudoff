<#

.SYNOPSIS
This PowerShell script will migrate an AWS instance to vSphere.

.DESCRIPTION
This PowerShell will migrate an AWS Instance to vSphere. It only works for VMs that were imported to AWS using vmimport. VMs that were migrated to AWS using Rubrik CloudOn or Cloud Conversion meet this criteria. The basic methodology used by CloudOff to migrate an instance from AWS to vSphere is this:

1. Shutdown the instance in AWS.
2. Convert the instance to VMDK format and export as an OVA file to an AWS bucket (vmexport) (https://docs.aws.amazon.com/vm-import/latest/userguide/vmexport.html)).
3. Download exported OVA to local storage.
4. Deploy OVA on vSphere
5. Power on exported VM

.EXAMPLE
PowerCLI C:\CloudOff> .\CloudOff.ps1

cmdlet CloudOff.ps1 at command pipeline position 1
Supply values for the following parameters:
instanceId: i-1234567890abcdef
region: us-west-1
bucket: cloudoff-bucket
downloadDirectory: C:\CloudOff
vCenter: myvcenter.mycompany.com
vmNetwork: VM Network
dataStore: mydatastore

.NOTES
In order for this script to work the Instance must have orginally been a VM that was imported using AWS VM Import.

This script requires:

- Powershell 5.1
- PowerCLI 6.5 R1
- AWS CLI
- AWS Tools for PowerShell

.LINK
https://github.com/rubrik-devops/CloudOff

#>

param(
  # The AWS Instance ID of the Instance that is to be exported
  [Parameter(Mandatory=$True)]
  [string]$instanceId,

  # The region that the AWS Instance is running in and where the S3 bucket to use for exports is.
  [Parameter(Mandatory=$True)]
  [string]$region,

  # The name of the S3 bucket to use for exporting the Instance.
  [Parameter(Mandatory=$True)]
  [string]$bucket,

  # The directory on the system where this script is running where an OVA of the Instance will be written.
  [Parameter(Mandatory=$True)]
  [string]$downloadDirectory,

  # The vSphere vCenter that the downloaded OVA for the exported VM will be deployed into.
  [Parameter(Mandatory=$True)]
  [string]$vCenter,

  # The vSphere cluster to deploy the exported VM into.
  [Parameter(Mandatory=$True)]
  [string]$cluster,

  # The vSphere DataStore to deploy the exported VM on to.
  [Parameter(Mandatory=$True)]
  [string]$dataStore,

  # The vSphere network to attach the exported VM to.
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

$vmDatastore = Get-DatastoreCluster -Name "$dataStore"
$vmCluster = Get-Cluster -name "$cluster"
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

