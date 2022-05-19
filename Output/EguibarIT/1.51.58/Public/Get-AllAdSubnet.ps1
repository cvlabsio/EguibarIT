function Get-AllAdSubnet {
    <#
        .Synopsis
            Get AD subnets from current Forest
        .DESCRIPTION
            Reads all Subnets from the current Forest and store those on an array.
        .EXAMPLE
            Get-AdSubnets
        .INPUTS
            No input needed.
        .NOTES
            Version:         1.0
            DateModified:    31/Mar/2015
            LasModifiedBy:   Vicente Rodriguez Eguibar
                vicente@eguibar.com
                Eguibar Information Technology S.L.
                http://www.eguibarit.com
    #>
    [CmdletBinding(ConfirmImpact = 'Medium')]
    [OutputType([array])]
    Param ()

    Begin {
        Write-Verbose -Message '|=> ************************************************************************ <=|'
        Write-Verbose -Message (Get-Date).ToShortDateString()
        Write-Verbose -Message ('  Starting: {0}' -f $MyInvocation.Mycommand)

        #display PSBoundparameters formatted nicely for Verbose output
        $NL   = "`n"  # New Line
        $HTab = "`t"  # Horizontal Tab
        [string]$pb = ($PSBoundParameters | Format-Table -AutoSize | Out-String).TrimEnd()
        Write-Verbose -Message "Parameters used by the function... $NL$($pb.split($NL).Foreach({"$($HTab*4)$_"}) | Out-String) $NL"


        Import-Module -name ServerManager   -Verbose:$false
        Import-Module -name ActiveDirectory -Verbose:$false
    }
    Process {
        #Get a reference to the RootDSE of the current domain
        $ADConfigurationNamingContext = ([ADSI]'LDAP://RootDSE').configurationNamingContext

        [array] $ADSubnets = Get-ADObject -Filter {
            objectclass -eq 'subnet'
        } -SearchBase $ADConfigurationNamingContext -Properties *
    }
    End {

        Return $ADSubnets
        Write-Verbose -Message "Function $($MyInvocation.InvocationName) finished getting AD Subnets."
        Write-Verbose -Message ''
        Write-Verbose -Message '-------------------------------------------------------------------------------'
        Write-Verbose -Message ''
    }
}