# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.
#
# Validates Get-Help for cmdlets in Microsoft.PowerShell.Core.

Import-Module HelpersCommon

$script:cmdletsToSkip = @(
    "Get-PSHostProcessInfo",
    "Out-Default",
    "Register-ArgumentCompleter",
    "New-PSRoleCapabilityFile",
    "Get-PSSessionCapability",
    "Disable-PSRemoting", # Content not available: Issue # https://github.com/PowerShell/PowerShell-Docs/issues/1790
    "Enable-PSRemoting",
    "Get-ExperimentalFeature",
    "Enable-ExperimentalFeature",
    "Disable-ExperimentalFeature"
)

function UpdateHelpFromLocalContentPath {
    param ([string]$ModuleName, [string] $Scope = 'CurrentUser')

    $helpContentPath = Join-Path $PSScriptRoot "assets"
    $helpFiles = @(Get-ChildItem "$helpContentPath\*" -ErrorAction SilentlyContinue)

    if ($helpFiles.Count -eq 0) {
        throw "Unable to find help content at '$helpContentPath'"
    }

    Update-Help -Module $ModuleName -SourcePath $helpContentPath -Force -ErrorAction Stop -Scope $Scope
}

function GetCurrentUserHelpRoot {
    if ([System.Management.Automation.Platform]::IsWindows) {
        $userHelpRoot = Join-Path $HOME "Documents/PowerShell/Help/"
    } else {
        $userModulesRoot = [System.Management.Automation.Platform]::SelectProductNameForDirectory([System.Management.Automation.Platform+XDG_Type]::USER_MODULES)
        $userHelpRoot = Join-Path $userModulesRoot -ChildPath ".." -AdditionalChildPath "Help"
    }

    return $userHelpRoot
}

Describe "Validate that <pshome>/<culture>/default.help.txt is present" -Tags @('CI') {

    It "Get-Help returns information about the help system" {

        $help = Get-Help
        $help.Name | Should -Be "default"
        $help.Category | Should -Be "HelpFile"
        $help.Synopsis | Should -Match "SHORT DESCRIPTION"
    }
}

Describe "Validate that the Help function can Run in strict mode" -Tags @('CI') {

    It "Help doesn't fail when strict mode is on" {

        $help = & {
            # run in nested scope to keep strict mode from affecting other tests
            Set-StrictMode -Version 3.0
            Help
        }
        # the help function renders the help content as text so just verify that there is content
        $help | Should -Not -BeNullOrEmpty
    }
}

Describe "Validate that get-help works for CurrentUserScope" -Tags @('CI') {
    BeforeAll {
        $SavedProgressPreference = $ProgressPreference
        $ProgressPreference = "SilentlyContinue"
        $moduleName = "Microsoft.PowerShell.Core"
    }
    AfterAll {
        $ProgressPreference = $SavedProgressPreference
    }

    Context "for module : $moduleName" {

        BeforeAll {
            UpdateHelpFromLocalContentPath $moduleName -Scope 'CurrentUser'
            $cmdlets = Get-Command -Module $moduleName
        }

        $testCases = @()

        ## Just testing first 3 in CI, Feature tests validate full list.
        $cmdlets | Where-Object { $script:cmdletsToSkip -notcontains $_ } | Select-Object -First 3 | ForEach-Object { $testCases += @{ cmdletName = $_.Name }}

        It "Validate -Description and -Examples sections in help content. Run 'Get-help -name <cmdletName>" -TestCases $testCases {
            param($cmdletName)
            $help = get-help -name $cmdletName
            $help.Description | Out-String | Should -Match $cmdletName
            $help.Examples | Out-String | Should -Match $cmdletName
        }
    }
}

Describe "Testing Get-Help Progress" -Tags @('Feature') {
    It "Last ProgressRecord should be Completed" {
        try {
            $j = Start-Job { Get-Help DoesNotExist }
            $j | Wait-Job
            $j.ChildJobs[0].Progress[-1].RecordType | Should -Be ([System.Management.Automation.ProgressRecordType]::Completed)
        }
        finally {
            $j | Remove-Job
        }
    }
}

Describe "Validate that get-help works for AllUsers Scope" -Tags @('Feature', 'RequireAdminOnWindows', 'RequireSudoOnUnix') {
    BeforeAll {
        $SavedProgressPreference = $ProgressPreference
        $ProgressPreference = "SilentlyContinue"
        $moduleName = "Microsoft.PowerShell.Core"
    }
    AfterAll {
        $ProgressPreference = $SavedProgressPreference
    }

    Context "for module : $moduleName" {

        BeforeAll {
            if (Test-CanWriteToPsHome) {
                UpdateHelpFromLocalContentPath $moduleName -Scope 'AllUsers'
            }
            $cmdlets = Get-Command -Module $moduleName
        }

        $testCases = @()
        $cmdlets | Where-Object { $cmdletsToSkip -notcontains $_ } | ForEach-Object { $testCases += @{ cmdletName = $_.Name }}

        It "Validate -Description and -Examples sections in help content. Run 'Get-help -name <cmdletName>" -TestCases $testCases -Skip:(!(Test-CanWriteToPsHome)) {
            param($cmdletName)
            $help = get-help -name $cmdletName
            $help.Description | Out-String | Should -Match $cmdletName
            $help.Examples | Out-String | Should -Match $cmdletName
        }
    }
}

Describe "Validate that get-help works for provider specific help" -Tags @('CI') {
    BeforeAll {
        $namespaces = @{
            command = 'http://schemas.microsoft.com/maml/dev/command/2004/10'
            dev     = 'http://schemas.microsoft.com/maml/dev/2004/10'
            maml    = 'http://schemas.microsoft.com/maml/2004/10'
            msh     = 'http://msh'
        }

        $helpFileRoot = Join-Path (GetCurrentUserHelpRoot) ([Globalization.CultureInfo]::CurrentUICulture)

        # Currently these test cases are verified only on Windows, because
        # - WSMan:\ and Cert:\ providers are not yet supported on non-Windows platforms.
        $testCases = @(
            @{
                helpFile    = "$helpFileRoot\System.Management.Automation.dll-help.xml"
                path        = "$userHelpRoot"
                helpContext = "[@id='FileSystem' or @ID='FileSystem']"
                verb        = 'Add'
                noun        = 'Content'
            }
        )

        if ($IsWindows) {
            $testCases += @(
                @{
                    helpFile    = "$helpFileRoot\Microsoft.WSMan.Management.dll-help.xml"
                    path        = 'WSMan:\localhost\ClientCertificate'
                    helpContext = "[@id='ClientCertificate' or @ID='ClientCertificate']"
                    cmdlet      = 'New-Item'
                }
                ,
                @{
                    helpFile    = "$helpFileRoot\Microsoft.PowerShell.Security.dll-help.xml"
                    path        = 'Cert:\'
                    helpContext = $null  # CertificateProvider uses only verb and noun in XPath query
                    verb        = 'New'
                    noun        = 'Item'
                }
            )

            UpdateHelpFromLocalContentPath -ModuleName 'Microsoft.WSMan.Management' -Scope 'CurrentUser'
            UpdateHelpFromLocalContentPath -ModuleName 'Microsoft.PowerShell.Security' -Scope 'CurrentUser'
        }

        UpdateHelpFromLocalContentPath -ModuleName 'Microsoft.PowerShell.Core' -Scope 'CurrentUser'
    }

    ## The tests are marked as pending since provider specific help content in not available in PS v6.*
    It "Shows contextual help when Get-Help is invoked for provider-specific path (Get-Help -Name <verb>-<noun> -Path <path>)" -TestCases $testCases -Pending {

        param(
            $helpFile,
            $path,
            $verb,
            $noun
        )

        # Path should exist or else Get-Help will fallback to default help text
        $path | Should -Exist

        $xpath = "/msh:helpItems/msh:providerHelp/msh:CmdletHelpPaths/msh:CmdletHelpPath$helpContext/command:command/command:details[command:verb='$verb' and command:noun='$noun']"
        $helpXmlNode = Select-Xml -Path $helpFile -XPath $xpath -Namespace $namespaces | Select-Object -ExpandProperty Node

        # Synopsis comes from command:command/command:details/maml:description
        $expected = Get-Help -Name "$verb-$noun" -Path $path | Select-Object -ExpandProperty Synopsis

        # System.Management.Automation.ProviderContext.GetProviderSpecificHelpInfo ignores extra whitespace, line breaks and
        # comments when loading help XML, but Select-Xml can not; use BeLikeExactly operator to omit trailing line breaks:
        $helpXmlNode.description.para -clike "$expected*" | Should -BeTrue
    }
}

Describe "Validate about_help.txt under culture specific folder works" -Tags @('CI', 'RequireAdminOnWindows', 'RequireSudoOnUnix') {
    BeforeAll {
        $modulePath = "$PSHOME\Modules\Test"
        if (Test-CanWriteToPsHome) {
            $null = New-Item -Path $modulePath\en-US -ItemType Directory -Force
            New-ModuleManifest -Path $modulePath\test.psd1 -RootModule test.psm1
            Set-Content -Path $modulePath\test.psm1 -Value "function foo{}"
            Set-Content -Path $modulePath\en-US\about_testhelp.help.txt -Value "Hello" -NoNewline
        }

        $aboutHelpPath = Join-Path (GetCurrentUserHelpRoot) (Get-Culture).Name

        ## If help content does not exist, update it first.
        if (-not (Test-Path (Join-Path $aboutHelpPath "about_Variables.help.txt"))) {
            UpdateHelpFromLocalContentPath -ModuleName 'Microsoft.PowerShell.Core' -Scope 'CurrentUser'
        }
    }

    AfterAll {
        if (Test-CanWriteToPsHome) {
            Remove-Item $modulePath -Recurse -Force
        }
        # Remove all the help content.
        Get-ChildItem -Path $aboutHelpPath -Include @('about_*.txt', "*help.xml") -Recurse | Remove-Item -Force -ErrorAction SilentlyContinue
    }

    It "Get-Help should return help text and not multiple HelpInfo objects when help is under `$PSHOME path" -Skip:(!(Test-CanWriteToPsHome)) {

        $help = Get-Help about_testhelp
        $help.count | Should -Be 1
        $help | Should -BeExactly "Hello"
    }

    It "Get-Help for about_Variable should return only one help object" {
        $help = Get-Help about_Variables
        $help.count | Should -Be 1
    }
}

Describe "About help files can be found in AllUsers scope" -Tags @('Feature', 'RequireAdminOnWindows', 'RequireSudoOnUnix') {
    BeforeAll {
        $aboutHelpPath = Join-Path $PSHOME (Get-Culture).Name

        ##clean up any CurrentUser if exists.

        $userHelpRoot = GetCurrentUserHelpRoot

        if (Test-Path $userHelpRoot) {
            Remove-Item $userHelpRoot -Force -Recurse -ErrorAction Stop
        }

        if (Test-CanWriteToPsHome) {
            UpdateHelpFromLocalContentPath -ModuleName 'Microsoft.PowerShell.Core' -Scope 'AllUsers'
        }
    }

    It "Get-Help for about_Variable should return only one help object" -Skip:(!(Test-CanWriteToPsHome)) {
        $help = Get-Help about_Variables
        $help.count | Should -Be 1
    }
}

Describe "Get-Help should find help info within help files" -Tags @('CI') {
    It "Get-Help should find help files under pshome" {
        $helpFile = "about_testCase.help.txt"
        $helpFolderPath = Join-Path (GetCurrentUserHelpRoot) (Get-Culture).Name
        $helpFilePath = Join-Path $helpFolderPath $helpFile

        if (!(Test-Path $helpFolderPath)) {
            $null = New-Item -ItemType Directory -Path $helpFolderPath -ErrorAction SilentlyContinue
        }

        try {
            $null = New-Item -ItemType File -Path $helpFilePath -Value "about_test" -ErrorAction SilentlyContinue
            $helpContent = Get-Help about_testCase
            $helpContent | Should -Match "about_test"
        } finally {
            Remove-Item $helpFilePath -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe "Get-Help should find pattern help files" -Tags "CI" {

    # There is a bug specific to Travis CI that suspends the test if "get-help" is used to search pattern string. This doesn't repro locally.
    # This occurs even if Unix system just returns "Directory.GetFiles(path, pattern);" as the windows' code does.
    # Since there's currently no way to get the vm from Travis CI and the test PASSES locally on both Ubuntu and MacOS, excluding pattern test under Unix system.

    BeforeAll {
        $helpFile1 = "about_testCase1.help.txt"
        $helpFile2 = "about_testCase.2.help.txt"
        $helpFolderPath = Join-Path (GetCurrentUserHelpRoot) (Get-Culture).Name
        $helpFilePath1 = Join-Path $helpFolderPath $helpFile1
        $helpFilePath2 = Join-Path $helpFolderPath $helpFile2
        $null = New-Item -ItemType Directory -Path $helpFolderPath -ErrorAction SilentlyContinue -Force
        # Create at least one help file matches "about*" pattern
        $null = New-Item -ItemType File -Path $helpFilePath1 -Value "about_test1" -ErrorAction SilentlyContinue
        $null = New-Item -ItemType File -Path $helpFilePath2 -Value "about_test2" -ErrorAction SilentlyContinue
    }

    # Remove the test files
    AfterAll {
        Remove-Item $helpFilePath1 -Force -ErrorAction SilentlyContinue
        Remove-Item $helpFilePath2 -Force -ErrorAction SilentlyContinue
    }

    BeforeEach {
        $currentPSModulePath = $env:PSModulePath
    }

    AfterEach {
        $env:PSModulePath = $currentPSModulePath
    }

    $testcases = @(
        @{command = {Get-Help about_testCas?1}; testname = "test ? pattern"; result = "about_test1"}
        @{command = {Get-Help about_testCase.?}; testname = "test ? pattern with dot"; result = "about_test2"}
        @{command = {(Get-Help about_testCase*).Count}; testname = "test * pattern"; result = "2"}
        @{command = {Get-Help about_testCas?.2*}; testname = "test ?, * pattern with dot"; result = "about_test2"}
    )

    It "Get-Help should find pattern help files - <testname>" -TestCases $testcases -Pending: (-not $IsWindows) {
        param (
            $command,
            $result
        )
        $command.Invoke() | Should -Be $result
    }

    It "Get-Help should fail expectedly searching for class help with hidden members" {
        $testModule = @'
        class foo
        {
            hidden static $monthNames = @('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun','Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec')
        }
'@
        $modulesFolder = Join-Path $TestDrive "Modules"
        $modulePath = Join-Path $modulesFolder "TestModule"
        New-Item -ItemType Directory -Path $modulePath -Force > $null
        Set-Content -Path (Join-Path $modulePath "TestModule.psm1") -Value $testModule
        $env:PSModulePath += [System.IO.Path]::PathSeparator + $modulesFolder

        { Get-Help -Category Class -Name foo -ErrorAction Stop } | Should -Throw -ErrorId "HelpNotFound,Microsoft.PowerShell.Commands.GetHelpCommand"
    }
}

Describe "Get-Help should find pattern alias" -Tags "CI" {
    BeforeAll {
        Set-Alias -Name testAlias1 -Value Where-Object
    }

    AfterAll {
        Remove-Item alias:\testAlias1 -ErrorAction SilentlyContinue
    }

    It "Get-Help should find alias as command" {
        (Get-Help where).Name | Should -BeExactly "Where-Object"
    }

    It "Get-Help should find alias with ? pattern" {
        $help = Get-Help wher?
        $help.Category | Should -BeExactly "Alias"
        $help.Synopsis | Should -BeExactly "Where-Object"
    }

    It "Get-Help should find alias with * pattern" {
        $help = Get-Help testAlias1*
        $help.Category | Should -BeExactly "Alias"
        $help.Synopsis | Should -BeExactly "Where-Object"
    }

    It "Help alias should be same as Get-Help alias" {
        $help1 = Get-Help testAlias*
        $help2 = help testAlias*
        Compare-Object $help1 $help2 | Should -BeNullOrEmpty
    }
}

Describe "help function uses full view by default" -Tags "CI" {
    It "help should return full view without -Full switch" {
        $gpsHelp = (help Microsoft.PowerShell.Management\Get-Process)
        $gpsHelp | Where-Object {$_ -cmatch '^PARAMETERS'} | Should -Not -BeNullOrEmpty
    }

    It "help should return full view even with -Full switch" {
        $gpsHelp = (help Microsoft.PowerShell.Management\Get-Process -Full)
        $gpsHelp | Where-Object {$_ -cmatch '^PARAMETERS'} | Should -Not -BeNullOrEmpty
    }

    It "help should not append -Full when not using AllUsersView parameter set" {
        $gpsHelp = (help Microsoft.PowerShell.Management\Get-Process -Parameter Name)
        $gpsHelp | Where-Object {$_ -cmatch '^PARAMETERS'} | Should -BeNullOrEmpty
    }
}

Describe 'help can be found for CurrentUser Scope' -Tags 'CI' {
    BeforeAll {
        $userHelpRoot = GetCurrentUserHelpRoot

        ## Clear all help from user scope.
        Remove-Item $userHelpRoot -Force -ErrorAction SilentlyContinue -Recurse
        UpdateHelpFromLocalContentPath -ModuleName 'Microsoft.PowerShell.Core' -Scope 'CurrentUser'
        UpdateHelpFromLocalContentPath -ModuleName 'Microsoft.PowerShell.Management' -Scope 'CurrentUser'
        UpdateHelpFromLocalContentPath -ModuleName 'Microsoft.PowerShell.Archive' -Scope 'CurrentUser' -Force
        UpdateHelpFromLocalContentPath -ModuleName 'PackageManagement' -Scope CurrentUser -Force

        ## Delete help from global scope if it exists.
        $currentCulture = (Get-Culture).Name

        $managementHelpFilePath = Join-Path $PSHOME -ChildPath $currentCulture -AdditionalChildPath 'Microsoft.PowerShell.Commands.Management.dll-Help.xml'
        if (Test-Path $managementHelpFilePath) {
            Remove-Item $managementHelpFilePath -Force -ErrorAction SilentlyContinue
        }

        $coreHelpFilePath = Join-Path $PSHOME -ChildPath $currentCulture -AdditionalChildPath 'System.Management.Automation.dll-Help.xml'
        if (Test-Path $coreHelpFilePath) {
            Remove-Item $coreHelpFilePath -Force -ErrorAction SilentlyContinue
        }

        $archiveHelpFilePath = Join-Path (Get-Module Microsoft.PowerShell.Archive -ListAvailable).ModuleBase -ChildPath $currentCulture -AdditionalChildPath 'Microsoft.PowerShell.Archive-help.xml'
        if (Test-Path $archiveHelpFilePath) {
            Remove-Item $archiveHelpFilePath -Force -ErrorAction SilentlyContinue
        }

        $TestCases = @(
            @{TestName = 'module under $PSHOME'; CmdletName = 'Add-Content'}
            @{TestName = 'module is a PSSnapin'; CmdletName = 'Get-Command' }
            @{TestName = 'module is under $PSHOME\Modules'; CmdletName = 'Compress-Archive' }
            @{TestName = 'module has a version folder'; CmdletName = 'Find-Package' }
        )
    }

    It 'help in user scope be found for <TestName>' -TestCases $TestCases {
        param($CmdletName)

        $helpObj = Get-Help -Name $CmdletName -Full
        $helpObj.description | Out-String | Should -Match $CmdletName
    }
}

Describe 'help can be found for AllUsers Scope' -Tags @('Feature', 'RequireAdminOnWindows', 'RequireSudoOnUnix') {
    BeforeAll {
        $userHelpRoot = GetCurrentUserHelpRoot

        ## Clear all help from user scope.
        Remove-Item $userHelpRoot -Force -ErrorAction SilentlyContinue -Recurse

        ## Delete help from global scope if it exists.
        $currentCulture = (Get-Culture).Name

        if (Test-CanWriteToPsHome) {
            $managementHelpFilePath = Join-Path $PSHOME -ChildPath $currentCulture -AdditionalChildPath 'Microsoft.PowerShell.Commands.Management.dll-Help.xml'
            if (Test-Path $managementHelpFilePath) {
                Remove-Item $managementHelpFilePath -Force -ErrorAction SilentlyContinue
            }

            $coreHelpFilePath = Join-Path $PSHOME -ChildPath $currentCulture -AdditionalChildPath 'System.Management.Automation.dll-Help.xml'
            if (Test-Path $coreHelpFilePath) {
                Remove-Item $coreHelpFilePath -Force -ErrorAction SilentlyContinue
            }

            $archiveHelpFilePath = Join-Path (Get-Module Microsoft.PowerShell.Archive -ListAvailable).ModuleBase -ChildPath $currentCulture -AdditionalChildPath 'Microsoft.PowerShell.Archive-help.xml'
            if (Test-Path $archiveHelpFilePath) {
                Remove-Item $archiveHelpFilePath -Force -ErrorAction SilentlyContinue
            }

            UpdateHelpFromLocalContentPath -ModuleName 'Microsoft.PowerShell.Core' -Scope 'AllUsers'
            UpdateHelpFromLocalContentPath -ModuleName 'Microsoft.PowerShell.Management' -Scope 'AllUsers'
            UpdateHelpFromLocalContentPath -ModuleName 'Microsoft.PowerShell.Archive' -Scope 'AllUsers' -Force
            UpdateHelpFromLocalContentPath -ModuleName 'PackageManagement' -Scope 'AllUsers' -Force
        }

        $TestCases = @(
            @{TestName = 'module under $PSHOME'; CmdletName = 'Add-Content'}
            @{TestName = 'module is a PSSnapin'; CmdletName = 'Get-Command' }
            @{TestName = 'module is under $PSHOME\Modules'; CmdletName = 'Compress-Archive' }
            @{TestName = 'module has a version folder'; CmdletName = 'Find-Package' }
        )
    }

    It 'help in user scope be found for <TestName>' -TestCases $TestCases -Skip:(!(Test-CanWriteToPsHome)) {
        param($CmdletName)

        $helpObj = Get-Help -Name $CmdletName -Full
        $helpObj.description | Out-String | Should -Match $CmdletName
    }
}

Describe "Get-Help should accept arrays as the -Parameter parameter value" -Tags @('CI') {

    BeforeAll {
        $userHelpRoot = GetCurrentUserHelpRoot

        ## Clear all help from user scope.
        Remove-Item $userHelpRoot -Force -ErrorAction SilentlyContinue -Recurse
        UpdateHelpFromLocalContentPath -ModuleName 'Microsoft.PowerShell.Core' -Scope 'CurrentUser'

        ## Delete help from global scope if it exists.
        $currentCulture = (Get-Culture).Name
        $coreHelpFilePath = Join-Path $PSHOME -ChildPath $currentCulture -AdditionalChildPath 'System.Management.Automation.dll-Help.xml'
        if (Test-Path $coreHelpFilePath) {
            Remove-Item $coreHelpFilePath -Force -ErrorAction SilentlyContinue
        }
    }

    It "Should return help objects for two parameters" {
        $help = Get-Help -Name Get-Command -Parameter Verb, Noun
        $help | Should -HaveCount 2
        $help[0].Name | Should -BeExactly 'Verb'
        $help[1].Name | Should -BeExactly 'Noun'
    }
}

Describe "Get-Help for function parameter should be consistent" -Tags 'CI' {
    BeforeAll {
        $test1 = @'
            function test1 {
                param (
                    $First
                )
            }
'@
        $test2 = @'
            function test2 {
                param (
                    $First,
                    $Second
                )
            }
'@
        $test1Path = Join-Path $TestDrive "test1.ps1"
        Set-Content -Path $test1Path -Value $test1

        $test2Path = Join-Path $TestDrive "test2.ps1"
        Set-Content -Path $test2Path -Value $test2

        Import-Module $test1Path
        Import-Module $test2Path
    }

    AfterAll {
        Remove-Module -Name "test1"
        Remove-Module -Name "test2"
    }

    It "Get-Help for function parameter should be consistent" {
        $test1HelpPSType = (Get-Help test1 -Parameter First).PSTypeNames
        $test2HelpPSType = (Get-Help test2 -Parameter First).PSTypeNames
        $test1HelpPSType | Should -BeExactly $test2HelpPSType
    }
}

Describe "Help failure cases" -Tags Feature {
    It "An error is returned for a topic that doesn't exist: <command>" -TestCases @(
        @{ command = "help" },
        @{ command = "get-help" }
    ) {
        param($command)

        { & $command foobar -ErrorAction Stop } | Should -Throw -ErrorId "HelpNotFound,Microsoft.PowerShell.Commands.GetHelpCommand"
    }
}

Describe 'help renders when using a PAGER with a space in the path' -Tags 'CI' {
    BeforeAll {
        $fakePager = @'
        param(
            [Parameter]
            $customCommandArgs,

            [Parameter(ValueFromPipelineByPropertyName)]
            $Name
        )

        $b = [System.Text.Encoding]::UTF8.GetBytes($Name)
        return [System.Convert]::ToBase64String($b)
'@
        $fakePagerFolder = Join-Path $TestDrive "path with space"
        $fakePagerPath = Join-Path $fakePagerFolder "fakepager.ps1"
        New-Item -ItemType File -Path $fakePagerPath -Force > $null
        Set-Content -Path $fakePagerPath -Value $fakePager

        $SavedEnvPager = $env:PAGER
        $env:PAGER = $fakePagerPath
    }
    AfterAll {
        $env:PAGER = $SavedEnvPager
    }

    It 'help renders when using a PAGER with a space in the path' {
        help Get-Command | Should -Be "R2V0LUNvbW1hbmQ="
    }
}
