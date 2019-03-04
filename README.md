# CloudOff

The CloudOff script is used to migrate AWS Instances to vSphere.

## Description

CloudOff will migrate an AWS Instance to vSphere. It only works for VMs that were imported to AWS using vmimport. VMs that were migrated to AWS using Rubrik CloudOn or Cloud Conversion meet this criteria. The basic methodology used by CloudOff to migrate an instance from AWS to vSphere is this:

1. Shutdown the instance in AWS.
2. Convert the instance to VMDK format and export as an OVA file to an AWS bucket ([vmexport](https://docs.aws.amazon.com/vm-import/latest/userguide/vmexport.html)).
3. Download exported OVA to local storage.
4. Deploy OVA on vSphere
5. Power on exported VM

## Prerequisites

- Powershell 5.1
- PowerCLI 6.5 R1
- AWS CLI
- AWS Tools for PowerShell

## Installation

1. Install [PowerShell 5.1](https://docs.microsoft.com/en-us/powershell/wmf/5.1/install-configure) or higher
2. Install [PowerCLI 6.5 R1](https://code.vmware.com/web/dp/tool/vmware-powercli/6.5) or higher
3. Install the current version of [AWSCLI](https://docs.aws.amazon.com/cli/latest/userguide/awscli-install-windows.html)
4. Install the current version of [AWS Tools for PowerShell](https://docs.aws.amazon.com/powershell/latest/userguide/pstools-getting-set-up-windows.html)
5. Download and save the [CloudOff](https://github.com/rubrik-devops/CloudOff) script from GitHub to a working directory.
6. Execute the CloudOff.ps1 script from a PowerCLI window.

## Usage Instructions

To use the script run `CloudOff.ps1` and provide the appropriate parameters. These include:

```text
NAME
    C:\CloudOff\CloudOff.ps1

SYNOPSIS
    This PowerShell script will migrate an AWS instance to vSphere.


SYNTAX
    C:\CloudOff\CloudOff.ps1 [-instanceId] <String> [-region] <String> [-bucket] <String> [-downloadDirectory] <String> [-vCenter]
    <String> [-cluster] <String> [-dataStore] <String> [-vmNetwork] <String> [<CommonParameters>]


DESCRIPTION
    This PowerShell will migrate an AWS Instance to vSphere. It only works for VMs that were imported to AWS using vmimport. VMs that were migrated to AWS using Rubrik CloudOn or
    Cloud Conversion meet this criteria. The basic methodology used by CloudOff to migrate an instance from AWS to vSphere is this:

    1. Shutdown the instance in AWS.
    2. Convert the instance to VMDK format and export as an OVA file to an AWS bucket using vmexport.
    3. Download exported OVA to local storage.
    4. Deploy OVA on vSphere
    5. Power on exported VM


PARAMETERS
    -instanceId <String>
        The AWS Instance ID of the Instance that is to be exported

    -region <String>
        The region that the AWS Instance is running in and where the S3 bucket to use for exports is.

    -bucket <String>
        The name of the S3 bucket to use for exporting the Instance.

    -downloadDirectory <String>
        The directory on the system where this script is running where an OVA of the Instance will be written.

    -vCenter <String>
        The vSphere vCenter that the downloaded OVA for the exported VM will be deployed into.

    -cluster <String>
        The vSphere cluster to deploy the exported VM into.

    -dataStore <String>
        The vSphere DataStore to deploy the exported VM on to.

    -vmNetwork <String>
        The vSphere network to attach the exported VM to.

    <CommonParameters>
        This cmdlet supports the common parameters: Verbose, Debug,
        ErrorAction, ErrorVariable, WarningAction, WarningVariable,
        OutBuffer, PipelineVariable, and OutVariable. For more information, see
        about_CommonParameters (http://go.microsoft.com/fwlink/?LinkID=113216).

    -------------------------- EXAMPLE 1 --------------------------

    PowerCLI C:\CloudOff>.\CloudOff.ps1

    cmdlet CloudOff.ps1 at command pipeline position 1
    Supply values for the following parameters:
    instanceId: i-1234567890abcdef
    region: us-west-1
    bucket: cloudoff-bucket
    downloadDirectory: C:\CloudOff
    vCenter: myvcenter.mycompany.com
    vmNetwork: VM Network
    dataStore: mydatastore
```

## Future

- Remove dependency on AWS CLI once AWS Tools for Powershell supports creating a vmexport job.

## Contribution

Create a fork of the project into your own repository. Make all your necessary changes and create a pull request with a description on what was added or removed and details explaining the changes in lines of code. If approved, project owners will merge it.

## Licensing

CloudOff is freely distributed under the [GPLv3 License](https://www.gnu.org/licenses/gpl-3.0.en.html "LICENSE"). See [LICENSE](https://github.com/rubrik-devops/CloudOff/blob/master/LICENSE) for details.

## Support

Please file bugs and issues on the Github issues page for this project. This is to help keep track and document everything related to this repo.
