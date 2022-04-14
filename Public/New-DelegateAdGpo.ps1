function New-DelegateAdGpo
{
    <#
        .Synopsis
            Creates and Links new GPO
        .DESCRIPTION
            Create new custom delegated GPO, Delegate rights to an existing group and links it to
            the given OU.
            This function can import settings from an existing GPO backup.
        .EXAMPLE
            New-DelegateAdGpo -gpoDescription MyNewGPO -gpoScope C -gpoLinkPath "OU=Servers,OU=eguibarit,OU=local" -GpoAdmin "SL_GpoRight"
        .EXAMPLE
            New-DelegateAdGpo -gpoDescription MyNewGPO -gpoScope C -gpoLinkPath "OU=Servers,OU=eguibarit,OU=local" -GpoAdmin "SL_GpoRight" -gpoBackupID '1D872D71-D961-4FCE-87E0-1CD368B5616F' -gpoBackupPath 'C:\PsScripts\Backups'
        .EXAMPLE
            $Splat = @{
                gpoDescription = 'MyNewGPO'
                gpoScope       = 'C'
                gpoLinkPath    = 'OU=Servers,OU=eguibarit,OU=local'
                GpoAdmin       = 'SL_GpoRight'
                gpoBackupID    = '1D872D71-D961-4FCE-87E0-1CD368B5616F'
                gpoBackupPath  = 'C:\PsScripts\Backups'
            }
            New-DelegateAdGpo @Splat
        .PARAMETER gpoDescription
            Description of the GPO. Used to build the name. Only Characters a-z A-Z
        .PARAMETER gpoScope
            Scope of the GPO. U for Users and C for Computers DEFAULT is U. The non-used part of the GPO will get disabled
        .PARAMETER gpoLinkPath
            DistinguishedName where to link the newly created GPO
        .PARAMETER GpoAdmin
            Domain Local Group with GPO Rights to be assigned
        .PARAMETER gpoBackupID
            Restore GPO settings from backup using the BackupID GUID
        .PARAMETER gpoBackupPath
            Path where Backups are stored

        .OUTPUTS
            Microsoft.GroupPolicy.Gpo

        .NOTES
            Used Functions:
                Name                                   | Module
                ---------------------------------------|--------------------------
                Get-CurrentErrorToDisplay              | EguibarIT
                Get-ADDomaincontroller                 | ActiveDirectory
                Get-GPO                                | GroupPolicy
                Import-GPO                             | GroupPolicy
                New-GPO                                | GroupPolicy
                New-GPLink                             | GroupPolicy
                Set-GPPermissions                      | GroupPolicy
        .NOTES
            Version:         1.2
            DateModified:    21/Oct/2021
            LasModifiedBy:   Vicente Rodriguez Eguibar
                vicente@eguibar.com
                Eguibar Information Technology S.L.
                http://www.eguibarit.com
    #>
    [CmdletBinding(ConfirmImpact = 'Medium', DefaultParameterSetName = 'DelegatedAdGpo')]
    [OutputType([Microsoft.GroupPolicy.Gpo])]
    Param (
        # Param1 GPO description, used to generate name
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, ValueFromRemainingArguments = $false,
            HelpMessage = 'Description of the GPO. Used to build the name.',
        Position = 0)]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [string]
        $gpoDescription,

        # Param2 GPO scope. U = Users, C = Computers
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, ValueFromRemainingArguments = $false,
            HelpMessage = 'Scope of the GPO. U for Users and C for Computers DEFAULT is U. The non-used part of the GPO will get disabled',
        Position = 1)]
        [ValidateSet('U', 'C', ignorecase = $false)]
        [string]
        $gpoScope,

        # Param3 GPO Link to OU
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, ValueFromRemainingArguments = $false,
            HelpMessage = 'DistinguishedName where to link the newly created GPO',
        Position = 2)]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [string]
        $gpoLinkPath,

        # Param4 Domain Local Group with GPO Rights to be assigned
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, ValueFromRemainingArguments = $false,
            HelpMessage = 'Domain Local Group with GPO Rights to be assigned',
        Position = 3)]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [string]
        $GpoAdmin,

        # Param5 Restore GPO settings from backup using the BackupID GUID
        [Parameter(Mandatory = $false, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, ValueFromRemainingArguments = $false,
            HelpMessage = 'Restore GPO settings from backup using the BackupID GUID',
            ParameterSetName = 'DelegatedAdGpo',
        Position = 4)]
        [Parameter(ParameterSetName = 'GpoBackup', Position = 4)]
        [string]
        $gpoBackupID,

        # Param6 Path where Backups are stored
        [Parameter(Mandatory = $false, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, ValueFromRemainingArguments = $false,
            HelpMessage = 'Path where Backups are stored',
            ParameterSetName = 'GpoBackup',
        Position = 5)]
        [string]
        $gpoBackupPath

    )

    Begin {
        $error.Clear()

        Write-Verbose -Message '|=> ************************************************************************ <=|'
        Write-Verbose -Message (Get-Date).ToShortDateString()
        Write-Verbose -Message ('  Starting: {0}' -f $MyInvocation.Mycommand)

        #display PSBoundparameters formatted nicely for Verbose output
        $NL   = "`n"  # New Line
        $HTab = "`t"  # Horizontal Tab
        [string]$pb = ($PSBoundParameters | Format-Table -AutoSize | Out-String).TrimEnd()
        Write-Verbose -Message "Parameters used by the function... $NL$($pb.split($NL).Foreach({"$($HTab*4)$_"}) | Out-String) $NL"


        Import-Module -name ActiveDirectory -Verbose:$false
        Import-Module -name GroupPolicy     -Verbose:$false

        $gpoAlreadyExist = $null
        $gpoName = '{0}-{1}' -f $PSBoundParameters['gpoScope'], $PSBoundParameters['gpoDescription']
        #$adGroupName = Get-ADGroup -Identity $GpoAdmin
        $dcServer = (Get-ADDomaincontroller -Discover -Service 'PrimaryDC').HostName
    } # End Begin Section

    Process {
        # Check if the GPO already exist
        $gpoAlreadyExist = Get-GPO -Name $gpoName -ErrorAction SilentlyContinue
        # Clean the error if object does not exist. No need to log.
        $error.clear()

        if (-not $gpoAlreadyExist) {
            Write-Verbose -Message ('Policy: Create policy object {0}' -f $gpoName)
            $parameters = @{
                Name        = $gpoName
                Comment     = $gpoName
                Server      = $dcServer
                ErrorAction = 'SilentlyContinue'
                Verbose     = $true
            }
            $gpoAlreadyExist = New-GPO @parameters

            Write-Verbose -Message '1 second pause to give AD a chance to catch up'
            Start-Sleep -Seconds 1

            # Give Rights to SL_GpoAdminRight
            Write-Verbose -Message ('Add GpoAdminRight to {0}' -f $gpoAlreadyExist.Name)
            $parameters = @{
                GUID            = $gpoAlreadyExist.Id
                PermissionLevel = 'GpoEditDeleteModifySecurity'
                TargetName      = $GpoAdmin
                TargetType      = 'group'
                Server          = $dcServer
                ErrorAction     = 'SilentlyContinue'
                Verbose     = $true
            }
            Set-GPPermissions @parameters


            # Disable the corresponding Settings section of the GPO
            If ($gpoScope -eq 'C') {
                Write-Verbose -Message ('Disable Policy User Settings on GPO {0}' -f $gpoAlreadyExist.Name)
                $gpoAlreadyExist.GpoStatus = 'UserSettingsDisabled'
            } else {
                Write-Verbose -Message ('Disable Policy Computer Settings on GPO {0}' -f $gpoAlreadyExist.Name)
                $gpoAlreadyExist.GpoStatus = 'ComputerSettingsDisabled'
            }

            Write-Verbose -Message 'Add GPO-link to corresponding OU'
            If( Test-IsValidDN -ObjectDN $PSBoundParameters['gpoLinkPath'] ) {
                $parameters = @{
                    GUID        = $CurrentNewGPO.Id
                    Target      = $PSBoundParameters['gpoLinkPath']
                    LinkEnabled = 'Yes'
                    Server      = $dcServer
                }
                New-GPLink @parameters
            } # End If

            # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
            # Adding settings
            #Write-Host "Setting Screen saver timeout to 15 minutes"
            #Set-GPRegistryValue -Name $gpoName -key "HKCU\Software\Policies\Microsoft\Windows\Control Panel\Desktop" -ValueName ScreenSaveTimeOut -Type String -value 900

            #Write-Host "Enable Screen Saver"
            #Set-GPRegistryValue -Name $gpoName -key "HKCU\Software\Policies\Microsoft\Windows\Control Panel\Desktop" -ValueName ScreenSaveActive -Type String -value 1

        } else {
            Write-Verbose -Message ('{0} Policy already exist. Changing Permissions and disabling corresponding settings (User or Computer).' -f $gpoName)

            # Give Rights to SL_GpoAdminRight
            Write-Verbose -Message ('Add GpoAdminRight to {0}' -f $gpoName)
            $parameters = @{
                GUID            = $gpoAlreadyExist.Id
                PermissionLevel = 'GpoEditDeleteModifySecurity'
                TargetName      = $GpoAdmin
                TargetType      = 'group'
                Server          = $dcServer
                ErrorAction     = 'SilentlyContinue'
                Verbose     = $true
            }
            Set-GPPermissions @parameters

            # Disable the corresponding Settings section of the GPO
            If ($gpoScope -eq 'C') {
                Write-Verbose -Message 'Disable Policy User Settings'
                $gpoAlreadyExist.GpoStatus = 'UserSettingsDisabled'
            } else {
                Write-Verbose -Message 'Disable Policy Computer Settings'
                $gpoAlreadyExist.GpoStatus = 'ComputerSettingsDisabled'
            }
        } # End If


        # Check if Backup needs to be imported
        If($PSBoundParameters['gpoBackupID']) {

            # Import the Backup
            Write-Verbose -Message ('Importing GPO Backup {0} from path {1} to GPO {2}' -f $PSBoundParameters['gpoBackupID'], $PSBoundParameters['gpoBackupPath'], $gpoName)

            $parameters = @{
                BackupId   = $PSBoundParameters['gpoBackupID']
                TargetGuid = $gpoAlreadyExist.Id
                path       = $PSBoundParameters['gpoBackupPath']
                Verbose    = $true
            }
            Import-GPO @parameters

        } # End If

    } # End Process Section
    End {
        Write-Verbose -Message ('Function New-DelegateAdGpo Finished creating {0} GPO' -f $gpoName)
        Write-Verbose -Message ''
        Write-Verbose -Message '--------------------------------------------------------------------------------'
        Write-Verbose -Message ''

        return $gpoAlreadyExist
    } # End END Section
}