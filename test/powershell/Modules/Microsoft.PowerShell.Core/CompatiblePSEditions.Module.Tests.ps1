# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

$script:oldModulePath = $env:PSModulePath

function Add-ModulePath
{
    param([string]$Path, [switch]$Prepend)

    $script:oldModulePath = $env:PSModulePath

    if ($Prepend)
    {
        $env:PSModulePAth = $Path + [System.IO.Path]::PathSeparator + $env:PSModulePath
    }
    else
    {
        $env:PSModulePath = $env:PSModulePath + [System.IO.Path]::PathSeparator + $Path
    }
}

function Restore-ModulePath
{
    $env:PSModulePath = $script:oldModulePath
}

# Creates a new dummy module compatible with the given PSEditions
function New-EditionCompatibleModule
{
    param(
        [Parameter(Mandatory = $true)][string]$ModuleName,
        [string]$DirPath,
        [string[]]$CompatiblePSEditions,
        [string]$ErrorGenerationCode='')

    $modulePath = Join-Path $DirPath $ModuleName

    $manifestPath = Join-Path $modulePath "$ModuleName.psd1"

    $psm1Name = "$ModuleName.psm1"
    $psm1Path = Join-Path $modulePath $psm1Name

    New-Item -Path $modulePath -ItemType Directory

    New-Item -Path $psm1Path -Value "$ErrorGenerationCode function Test-$ModuleName { `$true } function Test-${ModuleName}PSEdition { `$PSVersionTable.PSEdition }" -Force

    if ($CompatiblePSEditions)
    {
        New-ModuleManifest -Path $manifestPath -CompatiblePSEditions $CompatiblePSEditions -RootModule $psm1Name
    }
    else
    {
        New-ModuleManifest -Path $manifestPath -RootModule $psm1Name
    }

    return $modulePath
}

function New-TestModules
{
    param([hashtable[]]$TestCases, [string]$BaseDir)

    for ($i = 0; $i -lt $TestCases.Count; $i++)
    {
        $path = New-EditionCompatibleModule -ModuleName $TestCases[$i].ModuleName -CompatiblePSEditions $TestCases[$i].Editions -Dir $BaseDir

        $TestCases[$i].Path = $path
        $TestCases[$i].Name = $TestCases[$i].Editions -join ","
    }
}

function New-TestNestedModule
{
    param(
        [string]$ModuleBase,
        [string]$ScriptModuleFilename,
        [string]$ScriptModuleContent,
        [string]$BinaryModuleFilename,
        [string]$BinaryModuleDllPath,
        [string]$RootModuleFilename,
        [string]$RootModuleContent,
        [string[]]$CompatiblePSEditions,
        [bool]$UseRootModule,
        [bool]$UseAbsolutePath
    )

    $nestedModules = [System.Collections.ArrayList]::new()

    # Create script module
    New-Item -Path (Join-Path $ModuleBase $ScriptModuleFileName) -Value $ScriptModuleContent
    $nestedModules.Add($ScriptModuleFilename)

    if ($BinaryModuleFilename -and $BinaryModuleDllPath)
    {
        # Create binary module
        Copy-Item -Path $BinaryModuleDllPath -Destination (Join-Path $ModuleBase $BinaryModuleFilename)
        $nestedModules.Add($BinaryModuleFilename)
    }

    # Create the root module if there is one
    if ($UseRootModule)
    {
        New-Item -Path (Join-Path $ModuleBase $RootModuleFilename) -Value $RootModuleContent
    }

    # Create the manifest command
    $moduleName = Split-Path -Leaf $ModuleBase
    $manifestPath = Join-Path $ModuleBase "$moduleName.psd1"

    $nestedModules = $nestedModules -join ','

    $newManifestCmd = "New-ModuleManifest -Path $manifestPath -NestedModules $nestedModules "
    if ($CompatiblePSEditions)
    {
        $compatibleModules = $CompatiblePSEditions -join ','
        $newManifestCmd += "-CompatiblePSEditions $compatibleModules "
    }
    if ($UseRootModule)
    {
        $newManifestCmd += "-RootModule $RootModuleFilename "
        $newManifestCmd += "-FunctionsToExport @('Test-RootModule','Test-RootModulePSEdition') "
    }
    else
    {
        $newManifestCmd += "-FunctionsToExport @('Test-ScriptModule','Test-ScriptModulePSEdition') "
    }

    $newManifestCmd += "-CmdletsToExport @() -VariablesToExport @() -AliasesToExport @() "

    # Create the manifest
    [scriptblock]::Create($newManifestCmd).Invoke()
}

Describe "Get-Module with CompatiblePSEditions-checked paths" -Tag "CI" {

    BeforeAll {
        if (-not $IsWindows)
        {
            return
        }

        $successCases = @(
            @{ Editions = "Core","Desktop"; ModuleName = "BothModule" },
            @{ Editions = "Core"; ModuleName = "CoreModule" }
        )

        $failCases = @(
            @{ Editions = "Desktop"; ModuleName = "DesktopModule" },
            @{ Editions = $null; ModuleName = "NeitherModule" }
        )

        $basePath = Join-Path $TestDrive "EditionCompatibleModules"
        New-TestModules -TestCases $successCases -BaseDir $basePath
        New-TestModules -TestCases $failCases -BaseDir $basePath

        # Emulate the System32 module path for tests
        [System.Management.Automation.Internal.InternalTestHooks]::SetTestHook("TestWindowsPowerShellPSHomeLocation", $basePath)
    }

    AfterAll {
        [System.Management.Automation.Internal.InternalTestHooks]::SetTestHook("TestWindowsPowerShellPSHomeLocation", $null)
    }

    Context "Loading from checked paths on the module path with no flags" {
        BeforeAll {
            Add-ModulePath $basePath
            $modules = Get-Module -ListAvailable
        }

        AfterAll {
            Restore-ModulePath
        }

        It "Lists compatible modules from the module path with -ListAvailable for PSEdition <Editions>" -TestCases $successCases -Skip:(-not $IsWindows) {
            param($Editions, $ModuleName)

            $modules.Name | Should -Contain $ModuleName
        }

        It "Does not list incompatible modules with -ListAvailable for PSEdition <Editions>" -TestCases $failCases -Skip:(-not $IsWindows) {
            param($Editions, $ModuleName)

            $modules.Name | Should -Not -Contain $ModuleName
        }
    }

    Context "Loading from checked paths by absolute path with no flags" {
        It "Lists compatible modules with -ListAvailable for PSEdition <Editions>" -TestCases $successCases -Skip:(-not $IsWindows) {
            param($Editions, $ModuleName)

            $modules = Get-Module -ListAvailable (Join-Path -Path $basePath -ChildPath $ModuleName)

            $modules.Name | Should -Contain $ModuleName
        }

        It "Does not list incompatible modules with -ListAvailable for PSEdition <Editions>" -TestCases $failCases -Skip:(-not $IsWindows) {
            param($Editions, $ModuleName)

            $modules = Get-Module -ListAvailable (Join-Path -Path $basePath -ChildPath $ModuleName)

            $modules.Name | Should -Not -Contain $ModuleName
        }
    }

    Context "Loading from checked paths on the module path with -SkipEditionCheck" {
        BeforeAll {
            Add-ModulePath $basePath
            $modules = Get-Module -ListAvailable -SkipEditionCheck
        }

        AfterAll {
            Restore-ModulePath
        }

        It "Lists all modules from the module path with -ListAvailable for PSEdition <Editions>" -TestCases ($successCases + $failCases) -Skip:(-not $IsWindows) {
            param($Editions, $ModuleName)

            $modules.Name | Should -Contain $ModuleName
        }
    }

    Context "Loading from checked paths by absolute path with -SkipEditionCheck" {
        It "Lists compatible modules with -ListAvailable for PSEdition <Editions>" -TestCases ($successCases + $failCases) -Skip:(-not $IsWindows) {
            param($Editions, $ModuleName)

            $modules = Get-Module -ListAvailable -SkipEditionCheck (Join-Path -Path $basePath -ChildPath $ModuleName)

            $modules.Name | Should -Contain $ModuleName
        }
    }
}

Describe "Import-Module from CompatiblePSEditions-checked paths" -Tag "CI" {
    BeforeAll {
        $successCases = @(
            @{ Editions = "Core","Desktop"; ModuleName = "BothModule"; Result = $true },
            @{ Editions = "Core"; ModuleName = "CoreModule"; Result = $true }
        )

        $failCases = @(
            @{ Editions = "Desktop"; ModuleName = "DesktopModule"; Result = $true },
            @{ Editions = $null; ModuleName = "NeitherModule"; Result = $true }
        )

        $basePath = Join-Path $TestDrive "EditionCompatibleModules"
        New-TestModules -TestCases $successCases -BaseDir $basePath
        New-TestModules -TestCases $failCases -BaseDir $basePath

        $allCases = $successCases + $failCases
        $allModules = $allCases.ModuleName
        $versionTestCases = @()
        foreach($versionString in @('1.0','2.0','3.0','4.0','5.0','5.1','5.1.14393.0'))
        {
            foreach($case in $allCases)
            {
                $versionTestCases += $case + @{WinPSVersion = $versionString}
            }
        }

        # make sure there are no ImplicitRemoting leftovers from previous tests
        Get-Module | Where-Object {$_.PrivateData.ImplicitRemoting} | Remove-Module -Force
        Get-PSSession -Name WinPSCompatSession -ErrorAction SilentlyContinue | Remove-PSSession

        # Emulate the System32 module path for tests
        [System.Management.Automation.Internal.InternalTestHooks]::SetTestHook("TestWindowsPowerShellPSHomeLocation", $basePath)
    }

    AfterAll {
        [System.Management.Automation.Internal.InternalTestHooks]::SetTestHook("TestWindowsPowerShellPSHomeLocation", $null)
    }

    AfterEach {
        Get-Module $allModules | Remove-Module -Force
    }

    Context "Imports from module path" {
        BeforeAll {
            Add-ModulePath $basePath
        }

        AfterAll {
            Restore-ModulePath
        }

        It "Successfully imports compatible modules from the module path with PSEdition <Editions>" -TestCases $successCases -Skip:(-not $IsWindows) {
            param($Editions, $ModuleName, $Result)

            Import-Module $ModuleName -Force
            & "Test-$ModuleName" | Should -Be $Result
        }

        It "Successfully imports incompatible modules from the module path with PSEdition <Editions> using WinCompat" -TestCases $failCases -Skip:(-not $IsWindows) {
            param($Editions, $ModuleName, $Result)

            Import-Module $ModuleName -Force -ErrorAction 'Stop'
            & "Test-$ModuleName" | Should -Be $Result
        }

        It "Imports an incompatible module from the module path with -SkipEditionCheck with PSEdition <Editions>" -TestCases ($successCases + $failCases) -Skip:(-not $IsWindows) {
            param($Editions, $ModuleName, $Result)

            Import-Module $ModuleName -SkipEditionCheck -Force
            & "Test-$ModuleName" | Should -Be $Result
        }

        It "Imports any module using WinCompat from the module path with -UseWindowsPowerShell with PSEdition <Editions>" -TestCases ($successCases + $failCases) -Skip:(-not $IsWindows) {
            param($Editions, $ModuleName, $Result)

            Import-Module $ModuleName -UseWindowsPowerShell -Force
            & "Test-${ModuleName}PSEdition" | Should -Be 'Desktop'
        }

        It "WinCompat works only with Windows PS 5.1 (when PSEdition <Editions> and WinPSVersion <WinPSVersion>)" -TestCases $versionTestCases -Skip:(-not $IsWindows) {
            param($Editions, $ModuleName, $Result, $WinPSVersion)

            try {
                [System.Management.Automation.Internal.InternalTestHooks]::SetTestHook("TestWindowsPowerShellVersionString", $WinPSVersion)
                if ($WinPSVersion.StartsWith('5.1')) {
                    Import-Module $ModuleName -UseWindowsPowerShell -Force
                    & "Test-${ModuleName}PSEdition" | Should -Be 'Desktop'
                }
                else {
                    { Import-Module $ModuleName -UseWindowsPowerShell -Force } | Should -Throw -ErrorId "InvalidOperationException"
                }
            }
            finally {
                [System.Management.Automation.Internal.InternalTestHooks]::SetTestHook("TestWindowsPowerShellVersionString", $null)
            }
        }
    }

    Context "Imports from absolute path" {
        It "Successfully imports compatible modules from an absolute path with PSEdition <Editions>" -TestCases $successCases -Skip:(-not $IsWindows) {
            param($Editions, $ModuleName, $Result)

            $path = Join-Path -Path $basePath -ChildPath $ModuleName

            Import-Module $path -Force
            & "Test-$ModuleName" | Should -Be $Result
        }

        It "Successfully imports incompatible modules from an absolute path with PSEdition <Editions> using WinCompat" -TestCases $failCases -Skip:(-not $IsWindows) {
            param($Editions, $ModuleName, $Result)

            $path = Join-Path -Path $basePath -ChildPath $ModuleName

            Import-Module $path -Force -ErrorAction 'Stop'
            & "Test-$ModuleName" | Should -Be $Result
        }

        It "Imports an incompatible module from an absolute path with -SkipEditionCheck with PSEdition <Editions>" -TestCases ($successCases + $failCases) -Skip:(-not $IsWindows) {
            param($Editions, $ModuleName, $Result)

            $path = Join-Path -Path $basePath -ChildPath $ModuleName

            Import-Module $path -SkipEditionCheck -Force
            & "Test-$ModuleName" | Should -Be $Result
        }

        It "Imports any module using WinCompat from an absolute path with -UseWindowsPowerShell with PSEdition <Editions>" -TestCases ($successCases + $failCases) -Skip:(-not $IsWindows) {
            param($Editions, $ModuleName, $Result)

            $path = Join-Path -Path $basePath -ChildPath $ModuleName

            Import-Module $path -UseWindowsPowerShell -Force
            & "Test-${ModuleName}PSEdition" | Should -Be 'Desktop'
        }
    }

    Context "Imports using CommandDiscovery\ModuleAutoload" {
        BeforeAll {
            Add-ModulePath $basePath
        }

        AfterAll {
            Restore-ModulePath
        }

        It "Successfully auto-imports compatible modules from the module path with PSEdition <Editions>" -TestCases $successCases -Skip:(-not $IsWindows) {
            param($Editions, $ModuleName, $Result)

            & "Test-$ModuleName" | Should -Be $Result
        }

        It "Successfully auto-imports incompatible modules from the module path with PSEdition <Editions> using WinCompat" -TestCases $failCases -Skip:(-not $IsWindows) {
            param($Editions, $ModuleName, $Result)

            & "Test-${ModuleName}PSEdition" | Should -Be 'Desktop'
        }
    }
}

Describe "Additional tests for Import-Module with WinCompat" -Tag "Feature" {

    BeforeAll {
        $originalDefaultParameterValues = $PSDefaultParameterValues.Clone()
        if ( ! $IsWindows ) {
            $PSDefaultParameterValues["it:skip"] = $true
        }

        $ModuleName = "DesktopModule"
        $ModuleName2 = "DesktopModule2"
        $basePath = Join-Path $TestDrive "WinCompatModules"
        Remove-Item -Path $basePath -Recurse -ErrorAction SilentlyContinue
        # create an incompatible module that generates an error on import
        New-EditionCompatibleModule -ModuleName $ModuleName -CompatiblePSEditions "Desktop" -Dir $basePath -ErrorGenerationCode '1/0;'
        # create an incompatible module
        New-EditionCompatibleModule -ModuleName $ModuleName2 -CompatiblePSEditions "Desktop" -Dir $basePath
    }

    AfterAll {
        $global:PSDefaultParameterValues = $originalDefaultParameterValues
    }

    Context "Tests that ErrorAction/WarningAction have effect when Import-Module with WinCompat is used" {
        BeforeAll {
            $pwsh = "$PSHOME/pwsh"
            Add-ModulePath $basePath
        }

        AfterAll {
            Restore-ModulePath
        }

        It "Verify that Error is generated with default ErrorAction" {
            $LogPath = Join-Path $TestDrive (New-Guid).ToString()
            & $pwsh -NoProfile -NonInteractive -c "[System.Management.Automation.Internal.InternalTestHooks]::SetTestHook('TestWindowsPowerShellPSHomeLocation', `'$basePath`');Import-Module $ModuleName" *> $LogPath
            $LogPath | Should -FileContentMatch 'divide by zero'
        }

        It "Verify that Warning is generated with default WarningAction" {
            $LogPath = Join-Path $TestDrive (New-Guid).ToString()
            & $pwsh -NoProfile -NonInteractive -c "[System.Management.Automation.Internal.InternalTestHooks]::SetTestHook('TestWindowsPowerShellPSHomeLocation', `'$basePath`');Import-Module $ModuleName" *> $LogPath
            $LogPath | Should -FileContentMatch 'loaded in Windows PowerShell'
        }

        It "Verify that Error is Not generated with -ErrorAction Ignore" {
            $LogPath = Join-Path $TestDrive (New-Guid).ToString()
            & $pwsh -NoProfile -NonInteractive -c "[System.Management.Automation.Internal.InternalTestHooks]::SetTestHook('TestWindowsPowerShellPSHomeLocation', `'$basePath`');Import-Module $ModuleName -ErrorAction Ignore" *> $LogPath
            $LogPath | Should -Not -FileContentMatch 'divide by zero'
        }

        It "Verify that Warning is Not generated with -WarningAction Ignore" {
            $LogPath = Join-Path $TestDrive (New-Guid).ToString()
            & $pwsh -NoProfile -NonInteractive -c "[System.Management.Automation.Internal.InternalTestHooks]::SetTestHook('TestWindowsPowerShellPSHomeLocation', `'$basePath`');Import-Module $ModuleName -WarningAction Ignore" *> $LogPath
            $LogPath | Should -Not -FileContentMatch 'loaded in Windows PowerShell'
        }

        It "Fails to import incompatible module if implicit WinCompat is disabled in config" {
            $LogPath = Join-Path $TestDrive (New-Guid).ToString()
            $ConfigPath = Join-Path $TestDrive 'powershell.config.json'
            '{"DisableImplicitWinCompat" : "True"}' | Out-File -Force $ConfigPath
            & $pwsh -NoProfile -NonInteractive -settingsFile $ConfigPath -c "[System.Management.Automation.Internal.InternalTestHooks]::SetTestHook('TestWindowsPowerShellPSHomeLocation', `'$basePath`');Import-Module $ModuleName2" *> $LogPath
            $LogPath | Should -FileContentMatch 'cannot be loaded implicitly using the Windows Compatibility'
        }

        It "Fails to auto-import incompatible module during CommandDiscovery\ModuleAutoload if implicit WinCompat is Disabled in config" {
            $LogPath = Join-Path $TestDrive (New-Guid).ToString()
            $ConfigPath = Join-Path $TestDrive 'powershell.config.json'
            '{"DisableImplicitWinCompat" : "True","Microsoft.PowerShell:ExecutionPolicy": "RemoteSigned"}' | Out-File -Force $ConfigPath
            & $pwsh -NoProfile -NonInteractive -settingsFile $ConfigPath -c "[System.Management.Automation.Internal.InternalTestHooks]::SetTestHook('TestWindowsPowerShellPSHomeLocation', `'$basePath`'); Test-$ModuleName2" *> $LogPath
            $LogPath | Should -FileContentMatch 'not recognized as the name of a cmdlet'
        }

        It "Successfully auto-imports incompatible module during CommandDiscovery\ModuleAutoload if implicit WinCompat is Enabled in config" {
            $LogPath = Join-Path $TestDrive (New-Guid).ToString()
            $ConfigPath = Join-Path $TestDrive 'powershell.config.json'
            '{"DisableImplicitWinCompat" : "False","Microsoft.PowerShell:ExecutionPolicy": "RemoteSigned"}' | Out-File -Force $ConfigPath
            & $pwsh -NoProfile -NonInteractive -settingsFile $ConfigPath -c "[System.Management.Automation.Internal.InternalTestHooks]::SetTestHook('TestWindowsPowerShellPSHomeLocation', `'$basePath`'); Test-$ModuleName2" *> $LogPath
            $LogPath | Should -FileContentMatch 'True'
        }
    }

    Context "Tests around Windows PowerShell Compatibility module deny list" {
        BeforeAll {
            $pwsh = "$PSHOME/pwsh"
            Add-ModulePath $basePath
            $ConfigPath = Join-Path $TestDrive 'powershell.config.json'
        }

        AfterAll {
            Restore-ModulePath
        }

        It "Successfully imports incompatible module when DenyList is not specified in powershell.config.json" {
            '{"Microsoft.PowerShell:ExecutionPolicy": "RemoteSigned"}' | Out-File -Force $ConfigPath
            & $pwsh -NoProfile -NonInteractive -settingsFile $ConfigPath -c "[System.Management.Automation.Internal.InternalTestHooks]::SetTestHook('TestWindowsPowerShellPSHomeLocation', `'$basePath`');Import-Module $ModuleName2 -WarningAction Ignore;Test-${ModuleName2}PSEdition" | Should -Be 'Desktop'
        }

        It "Successfully imports incompatible module when DenyList is empty" {
            '{"Microsoft.PowerShell:ExecutionPolicy": "RemoteSigned","WindowsPowerShellCompatibilityModuleDenyList": []}' | Out-File -Force $ConfigPath
            & $pwsh -NoProfile -NonInteractive -settingsFile $ConfigPath -c "[System.Management.Automation.Internal.InternalTestHooks]::SetTestHook('TestWindowsPowerShellPSHomeLocation', `'$basePath`');Import-Module $ModuleName2 -WarningAction Ignore;Test-${ModuleName2}PSEdition" | Should -Be 'Desktop'
        }

        It "Blocks DenyList module import by Import-Module <ModuleName> -UseWindowsPowerShell" {
            '{"WindowsPowerShellCompatibilityModuleDenyList": ["' + $ModuleName2 + '"]}' | Out-File -Force $ConfigPath
            $out = & $pwsh -NoProfile -NonInteractive -settingsFile $ConfigPath -c "[System.Management.Automation.Internal.InternalTestHooks]::SetTestHook('TestWindowsPowerShellPSHomeLocation', `'$basePath`');Import-Module $ModuleName2 -UseWindowsPowerShell -ErrorVariable z -ErrorAction SilentlyContinue;`$z.FullyQualifiedErrorId"
            $out | Should -BeExactly 'Modules_ModuleInWinCompatDenyList,Microsoft.PowerShell.Commands.ImportModuleCommand'
        }

        It "Blocks DenyList module import by Import-Module <ModuleName>" {
            '{"WindowsPowerShellCompatibilityModuleDenyList": ["' + $ModuleName2.ToLowerInvariant() + '"]}' | Out-File -Force $ConfigPath # also check case-insensitive comparison
            $out = & $pwsh -NoProfile -NonInteractive -settingsFile $ConfigPath -c "[System.Management.Automation.Internal.InternalTestHooks]::SetTestHook('TestWindowsPowerShellPSHomeLocation', `'$basePath`');Import-Module $ModuleName2 -ErrorVariable z -ErrorAction SilentlyContinue;`$z.FullyQualifiedErrorId"
            $out | Should -BeExactly 'Modules_ModuleInWinCompatDenyList,Microsoft.PowerShell.Commands.ImportModuleCommand'
        }

        It "Blocks DenyList module import by CommandDiscovery\ModuleAutoload" {
            '{"WindowsPowerShellCompatibilityModuleDenyList": ["RandomNameJustToMakeArrayOfSeveralModules","' + $ModuleName2 + '"]}' | Out-File -Force $ConfigPath
            $out = & $pwsh -NoProfile -NonInteractive -settingsFile $ConfigPath -c "[System.Management.Automation.Internal.InternalTestHooks]::SetTestHook('TestWindowsPowerShellPSHomeLocation', `'$basePath`');`$ErrorActionPreference = 'SilentlyContinue';Test-$ModuleName2;`$error[0].FullyQualifiedErrorId"
            $out | Should -BeExactly 'CouldNotAutoloadMatchingModule'
        }
    }
}

Describe "PSModulePath changes interacting with other PowerShell processes" -Tag "Feature" {
    BeforeAll {
        $pwsh = "$PSHOME/pwsh"
        $originalDefaultParameterValues = $PSDefaultParameterValues.Clone()
        if ( ! $IsWindows ) {
            $PSDefaultParameterValues["it:skip"] = $true
        }
    }

    AfterAll {
        $global:PSDefaultParameterValues = $originalDefaultParameterValues
    }

    Context "System32 module path prepended to PSModulePath" {
        BeforeAll {
            if (-not $IsWindows)
            {
                return
            }
            Add-ModulePath (Join-Path $env:windir "System32\WindowsPowerShell\v1.0\Modules") -Prepend
        }

        AfterAll {
            if (-not $IsWindows)
            {
                return
            }
            Restore-ModulePath
        }

        It "Allows Windows PowerShell subprocesses to call `$PSHOME modules still" {
            $errors = powershell.exe -Command "Get-ChildItem" 2>&1 | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] }
            $errors | Should -Be $null
        }

        It "Allows PowerShell subprocesses to call core modules" {
            $errors = & $pwsh -Command "Get-ChildItem" 2>&1 | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] }
            $errors | Should -Be $null
        }
    }

    # Remove Pending status and update test after issue #11575 is fixed
    It "Does not duplicate the System32 module path in subprocesses" -Pending:$true {
        $sys32ModPathCount = & $pwsh -C {
            & "$PSHOME/pwsh" -C '$null = $env:PSModulePath -match ([regex]::Escape((Join-Path $env:windir "System32" "WindowsPowerShell" "v1.0" "Modules"))); $Matches.Count'
        }

        $sys32ModPathCount | Should -Be 1
    }
}

Describe "Get-Module nested module behaviour with Edition checking" -Tag "Feature" {
    BeforeAll {
        $testConditions = @{
            SkipEditionCheck = @($true, $false)
            UseRootModule = @($true, $false)
            UseAbsolutePath = @($true, $false)
            MarkedEdition = @($null, "Desktop", "Core", @("Desktop","Core"))
        }

        # Combine all the test conditions into a list of test cases
        $testCases = @(@{})
        foreach ($condition in $testConditions.Keys)
        {
            $list = [System.Collections.Generic.List[hashtable]]::new()
            foreach ($obj in $testCases)
            {
                foreach ($value in $testConditions[$condition])
                {
                    $list.Add($obj + @{ $condition = $value })
                }
            }
            $testCases = $list
        }

        # Define nested script module
        $scriptModuleName = "NestedScriptModule"
        $scriptModuleFile = "$scriptModuleName.psm1"
        $scriptModuleContent = 'function Test-ScriptModule { return $true }'

        # Define nested binary module
        $binaryModuleName = "NestedBinaryModule"
        $binaryModuleFile = "$binaryModuleName.dll"
        $binaryModuleContent = 'public static class TestBinaryModuleClass { public static bool Test() { return true; } }'
        $binaryModuleSourcePath = Join-Path $TestDrive $binaryModuleFile
        Add-Type -OutputAssembly $binaryModuleSourcePath -TypeDefinition $binaryModuleContent

        # Define root module definition
        $rootModuleName = "RootModule"
        $rootModuleFile = "$rootModuleName.psm1"
        $rootModuleContent = 'function Test-RootModule { Test-ScriptModule }'

        # Module directory structure: $TestDrive/$compatibility/$guid/$moduleName/{module parts}
        $compatibleDir = "Compatible"
        $incompatibleDir = "Incompatible"
        $compatiblePath = Join-Path $TestDrive $compatibleDir
        $incompatiblePath = Join-Path $TestDrive $incompatibleDir

        foreach ($basePath in $compatiblePath,$incompatiblePath)
        {
            New-Item -Path $basePath -ItemType Directory
        }
    }

    Context "Modules ON the System32 test path" {
        BeforeAll {
            [System.Management.Automation.Internal.InternalTestHooks]::SetTestHook("TestWindowsPowerShellPSHomeLocation", $incompatiblePath)
        }

        AfterAll {
            [System.Management.Automation.Internal.InternalTestHooks]::SetTestHook("TestWindowsPowerShellPSHomeLocation", $null)
        }

        BeforeEach {
            # Create the module directory
            $guid = New-Guid
            $compatibilityDir = $incompatibleDir
            $containingDir = Join-Path $TestDrive $compatibilityDir $guid
            $moduleName = "CpseTestModule"
            $moduleBase = Join-Path $containingDir $moduleName
            New-Item -Path $moduleBase -ItemType Directory
            Add-ModulePath $containingDir
        }

        AfterEach {
            Restore-ModulePath
        }

        It "Get-Module -ListAvailable gets all compatible modules when SkipEditionCheck: <SkipEditionCheck>, using root module: <UseRootModule>, using absolute path: <UseAbsolutePath>, CompatiblePSEditions: <MarkedEdition>" -TestCases $testCases -Skip:(-not $IsWindows) {
            param([bool]$SkipEditionCheck, [bool]$UseRootModule, [bool]$UseAbsolutePath, [string[]]$MarkedEdition)

            New-TestNestedModule `
                -ModuleBase $moduleBase `
                -ScriptModuleFilename $scriptModuleFile `
                -ScriptModuleContent $scriptModuleContent `
                -BinaryModuleFilename $binaryModuleFile `
                -BinaryModuleDllPath $binaryModuleSourcePath `
                -RootModuleFilename $rootModuleFile `
                -RootModuleContent $rootModuleContent `
                -CompatiblePSEditions $MarkedEdition `
                -UseRootModule $UseRootModule `
                -UseAbsolutePath $UseAbsolutePath

            if ($UseAbsolutePath)
            {
                if ((-not $SkipEditionCheck) -and (-not ($MarkedEdition -contains "Core")))
                {
                    Get-Module -ListAvailable $moduleBase -ErrorAction Stop | Should -Be $null
                    return
                }

                $modules = if ($SkipEditionCheck)
                {
                    Get-Module -ListAvailable $moduleBase -SkipEditionCheck
                }
                else
                {
                    Get-Module -ListAvailable $moduleBase
                }

                $modules.Count | Should -Be 1
                $modules[0].Name | Should -Be $moduleName
                return
            }

            $modules = if ($SkipEditionCheck)
            {
                Get-Module -ListAvailable -SkipEditionCheck
            }
            else
            {
                Get-Module -ListAvailable
            }

            $modules = $modules | Where-Object { $_.Path.Contains($guid) }

            if ((-not $SkipEditionCheck) -and (-not ($MarkedEdition -contains "Core")))
            {
                $modules.Count | Should -Be 0
                return
            }

            $modules.Count | Should -Be 1
            $modules[0].Name | Should -Be $moduleName
        }

        It "Get-Module -ListAvailable -All gets all compatible modules when SkipEditionCheck: <SkipEditionCheck>, using root module: <UseRootModule>, using absolute path: <UseAbsolutePath>, CompatiblePSEditions: <MarkedEdition>" -TestCases $testCases -Skip:(-not $IsWindows){
            param([bool]$SkipEditionCheck, [bool]$UseRootModule, [bool]$UseAbsolutePath, [string[]]$MarkedEdition)

            New-TestNestedModule `
                -ModuleBase $moduleBase `
                -ScriptModuleFilename $scriptModuleFile `
                -ScriptModuleContent $scriptModuleContent `
                -BinaryModuleFilename $binaryModuleFile `
                -BinaryModuleDllPath $binaryModuleSourcePath `
                -RootModuleFilename $rootModuleFile `
                -RootModuleContent $rootModuleContent `
                -CompatiblePSEditions $MarkedEdition `
                -UseRootModule $UseRootModule `
                -UseAbsolutePath $UseAbsolutePath

            # Modules specified with an absolute path should only return themselves
            if ($UseAbsolutePath) {
                $modules = if ($SkipEditionCheck)
                {
                    Get-Module -ListAvailable -All -SkipEditionCheck $moduleBase
                }
                else
                {
                    Get-Module -ListAvailable -All $moduleBase
                }

                $modules.Count | Should -Be 1
                $modules[0].Name  | Should -BeExactly $moduleName
                return
            }

            $modules = if ($SkipEditionCheck)
            {
                Get-Module -ListAvailable -All -SkipEditionCheck | Where-Object { $_.Path.Contains($guid) }
            }
            else
            {
                Get-Module -ListAvailable -All | Where-Object { $_.Path.Contains($guid) }
            }

            if ($UseRootModule)
            {
                $modules.Count | Should -Be 4
            }
            else
            {
                $modules.Count | Should -Be 3
            }

            $names = $modules.Name
            $names | Should -Contain $moduleName
            $names | Should -Contain $scriptModuleName
            $names | Should -Contain $binaryModuleName
        }
    }

    Context "Modules OFF the System32 module path" {
        BeforeEach {
            # Create the module directory
            $guid = New-Guid
            $compatibilityDir = $compatibleDir
            $containingDir = Join-Path $TestDrive $compatibilityDir $guid
            $moduleName = "CpseTestModule"
            $moduleBase = Join-Path $containingDir $moduleName
            New-Item -Path $moduleBase -ItemType Directory
            Add-ModulePath $containingDir
        }

        AfterEach {
            Restore-ModulePath
        }

        It "Get-Module -ListAvailable gets all compatible modules when SkipEditionCheck: <SkipEditionCheck>, using root module: <UseRootModule>, using absolute path: <UseAbsolutePath>, CompatiblePSEditions: <MarkedEdition>" -TestCases $testCases {
            param([bool]$SkipEditionCheck, [bool]$UseRootModule, [bool]$UseAbsolutePath, [string[]]$MarkedEdition)

            New-TestNestedModule `
                -ModuleBase $moduleBase `
                -ScriptModuleFilename $scriptModuleFile `
                -ScriptModuleContent $scriptModuleContent `
                -BinaryModuleFilename $binaryModuleFile `
                -BinaryModuleDllPath $binaryModuleSourcePath `
                -RootModuleFilename $rootModuleFile `
                -RootModuleContent $rootModuleContent `
                -CompatiblePSEditions $MarkedEdition `
                -UseRootModule $UseRootModule `
                -UseAbsolutePath $UseAbsolutePath

            if ($UseAbsolutePath)
            {
                $modules = if ($SkipEditionCheck)
                {
                    Get-Module -ListAvailable $moduleBase -SkipEditionCheck
                }
                else
                {
                    Get-Module -ListAvailable $moduleBase
                }

                $modules.Count | Should -Be 1
                $modules[0].Name | Should -Be $moduleName
                return
            }

            $modules = if ($SkipEditionCheck)
            {
                Get-Module -ListAvailable -SkipEditionCheck
            }
            else
            {
                Get-Module -ListAvailable
            }

            $modules = $modules | Where-Object { $_.Path.Contains($guid) }
            $modules.Count | Should -Be 1
            $modules[0].Name | Should -Be $moduleName
        }

        It "Get-Module -ListAvailable -All gets all compatible modules when SkipEditionCheck: <SkipEditionCheck>, using root module: <UseRootModule>, using absolute path: <UseAbsolutePath>, CompatiblePSEditions: <MarkedEdition>" -TestCases $testCases {
            param([bool]$SkipEditionCheck, [bool]$UseRootModule, [bool]$UseAbsolutePath, [string[]]$MarkedEdition)

            New-TestNestedModule `
                -ModuleBase $moduleBase `
                -ScriptModuleFilename $scriptModuleFile `
                -ScriptModuleContent $scriptModuleContent `
                -BinaryModuleFilename $binaryModuleFile `
                -BinaryModuleDllPath $binaryModuleSourcePath `
                -RootModuleFilename $rootModuleFile `
                -RootModuleContent $rootModuleContent `
                -CompatiblePSEditions $MarkedEdition `
                -UseRootModule $UseRootModule `
                -UseAbsolutePath $UseAbsolutePath

            # Modules specified with an absolute path should only return themselves
            if ($UseAbsolutePath)
            {
                $modules = Get-Module -ListAvailable -All $moduleBase

                $modules.Count | Should -Be 1
                $modules[0].Name  | Should -BeExactly $moduleName
                return
            }

            $modules = if ($SkipEditionCheck)
            {
                Get-Module -ListAvailable -All -SkipEditionCheck | Where-Object { $_.Path.Contains($guid) }
            }
            else
            {
                Get-Module -ListAvailable -All | Where-Object { $_.Path.Contains($guid) }
            }

            if ($UseRootModule)
            {
                $modules.Count | Should -Be 4
            }
            else
            {
                $modules.Count | Should -Be 3
            }

            $names = $modules.Name
            $names | Should -Contain $moduleName
            $names | Should -Contain $scriptModuleName
            $names | Should -Contain $binaryModuleName
        }
    }
}

Describe "Import-Module nested module behaviour with Edition checking" -Tag "Feature" {
    BeforeAll {
        $testConditions = @{
            SkipEditionCheck = @($true, $false)
            UseRootModule = @($true, $false)
            UseAbsolutePath = @($true, $false)
            MarkedEdition = @($null, "Desktop", "Core", @("Desktop","Core"))
            UseWindowsPowerShell = @($true, $false)
        }

        # Combine all the test conditions into a list of test cases
        $testCases = @(@{})
        foreach ($condition in $testConditions.Keys)
        {
            $list = [System.Collections.Generic.List[hashtable]]::new()
            foreach ($obj in $testCases)
            {
                foreach ($value in $testConditions[$condition])
                {
                    $list.Add($obj + @{ $condition = $value })
                }
            }
            $testCases = $list
        }

        # Define nested script module
        $scriptModuleName = "NestedScriptModule"
        $scriptModuleFile = "$scriptModuleName.psm1"
        $scriptModuleContent = 'function Test-ScriptModule { return $true } function Test-ScriptModulePSEdition { $PSVersionTable.PSEdition }'

        # Define root module definition
        $rootModuleName = "RootModule"
        $rootModuleFile = "$rootModuleName.psm1"
        $rootModuleContent = 'function Test-RootModule { Test-ScriptModule } function Test-RootModulePSEdition { Test-ScriptModulePSEdition }'

        # Module directory structure: $TestDrive/$compatibility/$guid/$moduleName/{module parts}
        $compatibleDir = "Compatible"
        $incompatibleDir = "Incompatible"
        $compatiblePath = Join-Path $TestDrive $compatibleDir
        $incompatiblePath = Join-Path $TestDrive $incompatibleDir

        foreach ($basePath in $compatiblePath,$incompatiblePath)
        {
            New-Item -Path $basePath -ItemType Directory
        }

        # make sure there are no ImplicitRemoting leftovers from previous tests
        Get-Module | Where-Object {$_.PrivateData.ImplicitRemoting} | Remove-Module -Force
        Get-PSSession -Name WinPSCompatSession -ErrorAction SilentlyContinue | Remove-PSSession
    }

    Context "Modules ON the System32 test path" {
        BeforeAll {
            [System.Management.Automation.Internal.InternalTestHooks]::SetTestHook("TestWindowsPowerShellPSHomeLocation", $incompatiblePath)
        }

        AfterAll {
            [System.Management.Automation.Internal.InternalTestHooks]::SetTestHook("TestWindowsPowerShellPSHomeLocation", $null)
        }

        BeforeEach {
            # Create the module directory
            $guid = New-Guid
            $compatibilityDir = $incompatibleDir
            $containingDir = Join-Path $TestDrive $compatibilityDir $guid
            $moduleName = "CpseTestModule"
            $moduleBase = Join-Path $containingDir $moduleName
            New-Item -Path $moduleBase -ItemType Directory
            Add-ModulePath $containingDir
        }

        AfterEach {
            Get-Module $moduleName | Remove-Module -Force
            Restore-ModulePath
        }

        It "Import-Module when SkipEditionCheck: <SkipEditionCheck>, using root module: <UseRootModule>, using absolute path: <UseAbsolutePath>, CompatiblePSEditions: <MarkedEdition>, UseWindowsPowerShell: <UseWindowsPowerShell>" -TestCases $testCases -Skip:(-not $IsWindows) {
            param([bool]$SkipEditionCheck, [bool]$UseRootModule, [bool]$UseAbsolutePath, [string[]]$MarkedEdition, [bool]$UseWindowsPowerShell)

            New-TestNestedModule `
                -ModuleBase $moduleBase `
                -ScriptModuleFilename $scriptModuleFile `
                -ScriptModuleContent $scriptModuleContent `
                -RootModuleFilename $rootModuleFile `
                -RootModuleContent $rootModuleContent `
                -CompatiblePSEditions $MarkedEdition `
                -UseRootModule $UseRootModule `
                -UseAbsolutePath $UseAbsolutePath

            if ($UseAbsolutePath)
            {
                if ((-not $SkipEditionCheck) -and (-not ($MarkedEdition -contains "Core")))
                {
                    # this goes through WinCompat code
                    { Import-Module $moduleBase -ErrorAction Stop } | Should -Not -Throw
                    Get-Module -Name $moduleName | Should -Not -BeNullOrEmpty
                    return
                }

                if ($SkipEditionCheck -and $UseWindowsPowerShell)
                {
                    { Import-Module $moduleBase -SkipEditionCheck -UseWindowsPowerShell } | Should -Throw -ErrorId "AmbiguousParameterSet"
                    return
                }
                elseif ($SkipEditionCheck)
                {
                    Import-Module $moduleBase -SkipEditionCheck
                }
                elseif ($UseWindowsPowerShell)
                {
                    Import-Module $moduleBase -UseWindowsPowerShell
                }
                else
                {
                    Import-Module $moduleBase
                }

                if ($UseRootModule)
                {
                    Test-RootModule | Should -BeTrue
                    { Test-ScriptModule } | Should -Throw -ErrorId "CommandNotFoundException"
                    if ($UseWindowsPowerShell)
                    {
                        Test-RootModulePSEdition | Should -Be 'Desktop'
                        { Test-ScriptModulePSEdition } | Should -Throw -ErrorId "CommandNotFoundException"
                    }
                    return
                }

                Test-ScriptModule | Should -BeTrue
                { Test-RootModule } | Should -Throw -ErrorId "CommandNotFoundException"
                if ($UseWindowsPowerShell)
                {
                    Test-ScriptModulePSEdition | Should -Be 'Desktop'
                    { Test-RootModulePSEdition } | Should -Throw -ErrorId "CommandNotFoundException"
                }
                return
            }

            if ((-not $SkipEditionCheck) -and (-not ($MarkedEdition -contains "Core")))
            {
                # this goes through WinCompat code
                { Import-Module $moduleName -ErrorAction Stop } | Should -Not -Throw
                Get-Module -Name $moduleName | Should -Not -BeNullOrEmpty
                return
            }


            if ($SkipEditionCheck -and $UseWindowsPowerShell)
            {
                 { Import-Module $moduleName -SkipEditionCheck -UseWindowsPowerShell } | Should -Throw -ErrorId "AmbiguousParameterSet"
                return
            }
            elseif ($SkipEditionCheck)
            {
                Import-Module $moduleName -SkipEditionCheck
            }
            elseif ($UseWindowsPowerShell)
            {
                Import-Module $moduleName -UseWindowsPowerShell
            }
            else
            {
                Import-Module $moduleName
            }

            if ($UseRootModule)
            {
                Test-RootModule | Should -BeTrue
                { Test-ScriptModule } | Should -Throw -ErrorId "CommandNotFoundException"
                if ($UseWindowsPowerShell)
                {
                    Test-RootModulePSEdition | Should -Be 'Desktop'
                    { Test-ScriptModulePSEdition } | Should -Throw -ErrorId "CommandNotFoundException"
                }
                return
            }

            Test-ScriptModule | Should -BeTrue
            { Test-RootModule } | Should -Throw -ErrorId "CommandNotFoundException"
            if ($UseWindowsPowerShell)
            {
                Test-ScriptModulePSEdition | Should -Be 'Desktop'
                { Test-RootModulePSEdition } | Should -Throw -ErrorId "CommandNotFoundException"
            }
        }
    }

    Context "Modules OFF the System32 module path" {
        BeforeEach {
            # Create the module directory
            $guid = New-Guid
            $compatibilityDir = $compatibleDir
            $containingDir = Join-Path $TestDrive $compatibilityDir $guid
            $moduleName = "CpseTestModule"
            $moduleBase = Join-Path $containingDir $moduleName
            New-Item -Path $moduleBase -ItemType Directory
            Add-ModulePath $containingDir
        }

        AfterEach {
            Get-Module $moduleName | Remove-Module -Force
            Restore-ModulePath
        }

        It "Import-Module when SkipEditionCheck: <SkipEditionCheck>, using root module: <UseRootModule>, using absolute path: <UseAbsolutePath>, CompatiblePSEditions: <MarkedEdition>, UseWindowsPowerShell: <UseWindowsPowerShell>" -TestCases $testCases {
            param([bool]$SkipEditionCheck, [bool]$UseRootModule, [bool]$UseAbsolutePath, [string[]]$MarkedEdition, [bool]$UseWindowsPowerShell)

            if ($UseWindowsPowerShell -and (-not $IsWindows))
            {
                Set-ItResult -Skipped -Because 'UseWindowsPowerShell parameter is supported only on Windows'
            }

            New-TestNestedModule `
                -ModuleBase $moduleBase `
                -ScriptModuleFilename $scriptModuleFile `
                -ScriptModuleContent $scriptModuleContent `
                -RootModuleFilename $rootModuleFile `
                -RootModuleContent $rootModuleContent `
                -CompatiblePSEditions $MarkedEdition `
                -UseRootModule $UseRootModule `
                -UseAbsolutePath $UseAbsolutePath

            if ($UseAbsolutePath)
            {
                if ($SkipEditionCheck -and $UseWindowsPowerShell)
                {
                    { Import-Module $moduleBase -SkipEditionCheck -UseWindowsPowerShell } | Should -Throw -ErrorId "AmbiguousParameterSet"
                    return
                }
                elseif ($SkipEditionCheck)
                {
                    Import-Module $moduleBase -SkipEditionCheck
                }
                elseif ($UseWindowsPowerShell)
                {
                    Import-Module $moduleBase -UseWindowsPowerShell
                }
                else
                {
                    Import-Module $moduleBase
                }
            }
            elseif ($SkipEditionCheck -and $UseWindowsPowerShell)
            {
                { Import-Module $moduleName -SkipEditionCheck -UseWindowsPowerShell } | Should -Throw -ErrorId "AmbiguousParameterSet"
                return
            }
            elseif ($SkipEditionCheck)
            {
                Import-Module $moduleName -SkipEditionCheck
            }
            elseif ($UseWindowsPowerShell)
            {
                Import-Module $moduleName -UseWindowsPowerShell
            }
            else
            {
                Import-Module $moduleName
            }

            if ($UseRootModule)
            {
                Test-RootModule | Should -BeTrue
                { Test-ScriptModule } | Should -Throw -ErrorId "CommandNotFoundException"
                if ($UseWindowsPowerShell)
                {
                    Test-RootModulePSEdition | Should -Be 'Desktop'
                    { Test-ScriptModulePSEdition } | Should -Throw -ErrorId "CommandNotFoundException"
                }
                return
            }

            Test-ScriptModule | Should -BeTrue
            { Test-RootModule } | Should -Throw -ErrorId "CommandNotFoundException"
            if ($UseWindowsPowerShell)
            {
                Test-ScriptModulePSEdition | Should -Be 'Desktop'
                { Test-RootModulePSEdition } | Should -Throw -ErrorId "CommandNotFoundException"
            }
        }
    }
}
