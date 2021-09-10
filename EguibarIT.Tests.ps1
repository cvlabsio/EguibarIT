$PSVersionTable.PSVersion

$ModuleName = (Get-ChildItem $PSScriptRoot\*.psd1).BaseName
$PrimaryModule = Get-ChildItem -Path $PSScriptRoot -Filter '*.psd1' -Recurse -ErrorAction SilentlyContinue -Depth 1
if (-not $PrimaryModule) {
    throw "Path $PSScriptRoot doesn't contain PSD1 files. Failing tests."
}
if ($PrimaryModule.Count -ne 1) {
    throw 'More than one PSD1 files detected. Failing tests.'
}

$PSDInformation = Import-PowerShellDataFile -Path $PrimaryModule.FullName
$RequiredModules = @(
    'Pester'
    if ($PSDInformation.RequiredModules) {
        $PSDInformation.RequiredModules
    }
)

foreach ($Module in $RequiredModules) {
    if ($Module -is [System.Collections.IDictionary]) {
        $Exists = Get-Module -ListAvailable -Name $Module.ModuleName
        if (-not $Exists) {
            Write-Warning "$ModuleName - Downloading $($Module.ModuleName) from PSGallery"
            Install-Module -Name $Module.ModuleName -Force -SkipPublisherCheck
        }
    } else {
        $Exists = Get-Module -ListAvailable $Module -ErrorAction SilentlyContinue
        if (-not $Exists) {
            Install-Module -Name $Module -Force -SkipPublisherCheck
        }
    }
}

Import-Module $PSScriptRoot\*.psd1 -Force

$result = Invoke-Pester -Path $PSScriptRoot\Tests  -Verbose -EnableExit #-Output Detailed

if ($result.FailedCount -gt 0) {
    throw "$($result.FailedCount) tests failed."
}