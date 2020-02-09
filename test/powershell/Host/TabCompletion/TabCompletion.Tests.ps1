# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.
Describe "TabCompletion" -Tags CI {
    BeforeAll {
        $separator = [System.IO.Path]::DirectorySeparatorChar
        $nullConditionalFeatureDisabled = -not $EnabledExperimentalFeatures.Contains('PSNullConditionalOperators')
    }

    It 'Should complete Command' {
        $res = TabExpansion2 -inputScript 'Get-Com' -cursorColumn 'Get-Com'.Length
        $res.CompletionMatches[0].CompletionText | Should -BeExactly 'Get-Command'
    }

    It 'Should complete abbreviated cmdlet' {
        $res = (TabExpansion2 -inputScript 'i-psdf' -cursorColumn 'pschr'.Length).CompletionMatches.CompletionText
        $res | Should -HaveCount 1
        $res | Should -BeExactly 'Import-PowerShellDataFile'
    }

    It 'Should complete abbreviated function' {
        function Test-AbbreviatedFunctionExpansion {}
        $res = (TabExpansion2 -inputScript 't-afe' -cursorColumn 't-afe'.Length).CompletionMatches.CompletionText
        $res.Count | Should -BeGreaterOrEqual 1
        $res | Should -BeExactly 'Test-AbbreviatedFunctionExpansion'
    }

    It 'Should complete native exe' -Skip:(!$IsWindows) {
        $res = TabExpansion2 -inputScript 'notep' -cursorColumn 'notep'.Length
        $res.CompletionMatches[0].CompletionText | Should -BeExactly 'notepad.exe'
    }

    It 'Should complete dotnet method' {
        $res = TabExpansion2 -inputScript '(1).ToSt' -cursorColumn '(1).ToSt'.Length
        $res.CompletionMatches[0].CompletionText | Should -BeExactly 'ToString('
    }

    It 'Should complete dotnet method with null conditional operator' -skip:$nullConditionalFeatureDisabled {
        $res = TabExpansion2 -inputScript '(1)?.ToSt' -cursorColumn '(1)?.ToSt'.Length
        $res.CompletionMatches[0].CompletionText | Should -BeExactly 'ToString('
    }

    It 'Should complete dotnet method with null conditional operator without first letter' -skip:$nullConditionalFeatureDisabled {
        $res = TabExpansion2 -inputScript '(1)?.' -cursorColumn '(1)?.'.Length
        $res.CompletionMatches[0].CompletionText | Should -BeExactly 'CompareTo('
    }

    It 'Should complete Magic foreach' {
        $res = TabExpansion2 -inputScript '(1..10).Fo' -cursorColumn '(1..10).Fo'.Length
        $res.CompletionMatches[0].CompletionText | Should -BeExactly 'ForEach('
    }

    It "Should complete Magic where" {
        $res = TabExpansion2 -inputScript '(1..10).wh' -cursorColumn '(1..10).wh'.Length
        $res.CompletionMatches[0].CompletionText | Should -BeExactly 'Where('
    }

    It 'Should complete types' {
        $res = TabExpansion2 -inputScript '[pscu' -cursorColumn '[pscu'.Length
        $res.CompletionMatches[0].CompletionText | Should -BeExactly 'pscustomobject'
    }

    It 'Should complete namespaces' {
        $res = TabExpansion2 -inputScript 'using namespace Sys' -cursorColumn 'using namespace Sys'.Length
        $res.CompletionMatches[0].CompletionText | Should -BeExactly 'System'
    }

    It 'Should complete format-table hashtable' {
        $res = TabExpansion2 -inputScript 'Get-ChildItem | Format-Table @{ ' -cursorColumn 'Get-ChildItem | Format-Table @{ '.Length
        $res.CompletionMatches | Should -HaveCount 5
        $completionText = $res.CompletionMatches.CompletionText | Sort-Object
        $completionText -join ' ' | Should -BeExactly 'Alignment Expression FormatString Label Width'
    }

    It 'Should complete format-* hashtable on GroupBy: <cmd>' -TestCases (
        @{cmd = 'Format-Table'},
        @{cmd = 'Format-List'},
        @{cmd = 'Format-Wide'},
        @{cmd = 'Format-Custom'}
    ) {
        param($cmd)
        $res = TabExpansion2 -inputScript "Get-ChildItem | $cmd -GroupBy @{ " -cursorColumn "Get-ChildItem | $cmd -GroupBy @{ ".Length
        $res.CompletionMatches | Should -HaveCount 3
        $completionText = $res.CompletionMatches.CompletionText | Sort-Object
        $completionText -join ' ' | Should -BeExactly 'Expression FormatString Label'
    }

    It 'Should complete format-list hashtable' {
        $res = TabExpansion2 -inputScript 'Get-ChildItem | Format-List @{ ' -cursorColumn 'Get-ChildItem | Format-List @{ '.Length
        $res.CompletionMatches | Should -HaveCount 3
        $completionText = $res.CompletionMatches.CompletionText | Sort-Object
        $completionText -join ' ' | Should -BeExactly 'Expression FormatString Label'
    }

    It 'Should complete format-wide hashtable' {
        $res = TabExpansion2 -inputScript 'Get-ChildItem | Format-Wide @{ ' -cursorColumn 'Get-ChildItem | Format-Wide @{ '.Length
        $res.CompletionMatches | Should -HaveCount 2
        $completionText = $res.CompletionMatches.CompletionText | Sort-Object
        $completionText -join ' ' | Should -BeExactly 'Expression FormatString'
    }

    It 'Should complete format-custom hashtable' {
        $res = TabExpansion2 -inputScript 'Get-ChildItem | Format-Custom @{ ' -cursorColumn 'Get-ChildItem | Format-Custom @{ '.Length
        $res.CompletionMatches | Should -HaveCount 2
        $completionText = $res.CompletionMatches.CompletionText | Sort-Object
        $completionText -join ' ' | Should -BeExactly 'Depth Expression'
    }

    It 'Should complete Select-Object hashtable' {
        $res = TabExpansion2 -inputScript 'Get-ChildItem | Select-Object @{ ' -cursorColumn 'Get-ChildItem | Select-Object @{ '.Length
        $res.CompletionMatches | Should -HaveCount 2
        $completionText = $res.CompletionMatches.CompletionText | Sort-Object
        $completionText -join ' ' | Should -BeExactly 'Expression Name'
    }

    It 'Should complete Sort-Object hashtable' {
        $res = TabExpansion2 -inputScript 'Get-ChildItem | Sort-Object @{ ' -cursorColumn 'Get-ChildItem | Sort-Object @{ '.Length
        $res.CompletionMatches | Should -HaveCount 3
        $completionText = $res.CompletionMatches.CompletionText | Sort-Object
        $completionText -join ' ' | Should -BeExactly 'Ascending Descending Expression'
    }

    It 'Should complete New-Object hashtable' {
        class X {
            $A
            $B
            $C
        }
        $res = TabExpansion2 -inputScript 'New-Object -TypeName X -Property @{ ' -cursorColumn 'New-Object -TypeName X -Property @{ '.Length
        $res.CompletionMatches | Should -HaveCount 3
        $res.CompletionMatches.CompletionText -join ' ' | Should -BeExactly 'A B C'
    }

    It 'Should complete "Get-Process -Id " with Id and name in tooltip' {
        Set-StrictMode -Version 3.0
        $cmd = 'Get-Process -Id '
        [System.Management.Automation.CommandCompletion]$res = TabExpansion2 -inputScript $cmd  -cursorColumn $cmd.Length
        $res.CompletionMatches[0].CompletionText -match '^\d+$' | Should -BeTrue
        $res.CompletionMatches[0].ListItemText -match '^\d+ -' | Should -BeTrue
        $res.CompletionMatches[0].ToolTip -match '^\d+ -' | Should -BeTrue
    }

    It 'Should complete "Get-Process" with process names' {
        $cmd = "Get-Process "
        $res = TabExpansion2 -inputScript $cmd  -cursorColumn $cmd.Length
        # Can't compare to number of processes since macOS has a large number of processes
        # that have empty Name which should be skipped
        $res.CompletionMatches.Count | Should -BeGreaterThan 0
    }

    It 'Should complete keyword' -skip {
        $res = TabExpansion2 -inputScript 'using nam' -cursorColumn 'using nam'.Length
        $res.CompletionMatches[0].CompletionText | Should -BeExactly 'namespace'
    }

    It 'Should first suggest -Full and then -Functionality when using Get-Help -Fu<tab>' -skip {
        $res = TabExpansion2 -inputScript 'Get-Help -Fu' -cursorColumn 'Get-Help -Fu'.Length
        $res.CompletionMatches[0].CompletionText | Should -BeExactly '-Full'
        $res.CompletionMatches[1].CompletionText | Should -BeExactly '-Functionality'
    }

    It 'Should first suggest -Full and then -Functionality when using help -Fu<tab>' -skip {
        $res = TabExpansion2 -inputScript 'help -Fu' -cursorColumn 'help -Fu'.Length
        $res.CompletionMatches[0].CompletionText | Should -BeExactly '-Full'
        $res.CompletionMatches[1].CompletionText | Should -BeExactly '-Functionality'
    }

    It 'Should work for variable assignment of enum type: <inputStr>' -TestCases @(
        @{ inputStr = '$ErrorActionPreference = '; filter = ''; doubleQuotes = $false }
        @{ inputStr = '$ErrorActionPreference='; filter = ''; doubleQuotes = $false }
        @{ inputStr = '$ErrorActionPreference="'; filter = ''; doubleQuotes = $true }
        @{ inputStr = '$ErrorActionPreference = ''s'; filter = '| Where-Object { $_ -like "''s*" }'; doubleQuotes = $false }
        @{ inputStr = '$ErrorActionPreference = "siL'; filter = '| Where-Object { $_ -like ''"sil*'' }'; doubleQuotes = $true }
        @{ inputStr = '[System.Management.Automation.ActionPreference]$e='; filter = ''; doubleQuotes = $false }
        @{ inputStr = '[System.Management.Automation.ActionPreference]$e = '; filter = ''; doubleQuotes = $false }
        @{ inputStr = '[System.Management.Automation.ActionPreference]$e = "'; filter = ''; doubleQuotes = $true }
        @{ inputStr = '[System.Management.Automation.ActionPreference]$e = "s'; filter = '| Where-Object { $_ -like """s*" }'; doubleQuotes = $true }
        @{ inputStr = '[System.Management.Automation.ActionPreference]$e = "x'; filter = '| Where-Object { $_ -like """x*" }'; doubleQuotes = $true }
    ){
        param($inputStr, $filter, $doubleQuotes)

        $quote = ''''
        if ($doubleQuotes) {
            $quote = '"'
        }

        $sb = [scriptblock]::Create(@"
            [cmdletbinding()] param([Parameter(ValueFromPipeline=`$true)]`$obj) process { `$obj $filter }
"@)

        $expectedValues = [enum]::GetValues("System.Management.Automation.ActionPreference") | ForEach-Object { $quote + $_.ToString() + $quote } | & $sb | Sort-Object
        if ($expectedValues.Count -gt 0) {
            $expected = [string]::Join(",",$expectedValues)
        }
        else {
            $expected = ''
        }

        $res = TabExpansion2 -inputScript $inputStr -cursorColumn $inputStr.Length
        if ($res.CompletionMatches.Count -gt 0) {
            $actual = [string]::Join(",",$res.CompletionMatches.completiontext)
        }
        else {
            $actual = ''
        }

        $actual | Should -BeExactly $expected
    }

    It 'Should work for variable assignment of custom enum: <inputStr>' -TestCases @(
        @{ inputStr = '[Animal]$c="g'; expected = '"Giraffe"','"Goose"' }
        @{ inputStr = '[Animal]$c='; expected = "'Duck'","'Giraffe'","'Goose'","'Horse'" }
        @{ inputStr = '$script:test = "g'; expected = '"Giraffe"','"Goose"' }
        @{ inputStr = '$script:test='; expected = "'Duck'","'Giraffe'","'Goose'","'Horse'" }
        @{ inputStr = '$script:test = "x'; expected = @() }
    ){
        param($inputStr, $expected)

        enum Animal { Duck; Goose; Horse; Giraffe }
        [Animal]$script:test = 'Duck'

        $res = TabExpansion2 -inputScript $inputStr -cursorColumn $inputStr.Length
        if ($res.CompletionMatches.Count -gt 0) {
            $actual = [string]::Join(",",$res.CompletionMatches.completiontext)
        }
        else {
            $actual = ''
        }

        $actual | Should -BeExactly ([string]::Join(",",$expected))
    }

    It 'Should work for assignment of variable with validateset of strings: <inputStr>' -TestCases @(
        @{ inputStr = '$test='; expected = "'a'","'aa'","'aab'","'b'"; doubleQuotes = $false }
        @{ inputStr = '$test="a'; expected = "'a'","'aa'","'aab'"; doubleQuotes = $true }
        @{ inputStr = '$test = "aa'; expected = "'aa'","'aab'"; doubleQuotes = $true }
        @{ inputStr = '$test=''aab'; expected = "'aab'"; doubleQuotes = $false }
        @{ inputStr = '$test="c'; expected = ''; doubleQuotes = $true }
    ){
        param($inputStr, $expected, $doubleQuotes)

        [ValidateSet('a','aa','aab','b')][string]$test = 'b'

        $expected = [string]::Join(",",$expected)
        if ($doubleQuotes) {
            $expected = $expected.Replace("'", """")
        }

        $res = TabExpansion2 -inputScript $inputStr -cursorColumn $inputStr.Length
        if ($res.CompletionMatches.Count -gt 0) {
            $actual = [string]::Join(",",$res.CompletionMatches.completiontext)
        }
        else {
            $actual = ''
        }

        $actual | Should -BeExactly $expected
    }

    It 'Should work for assignment of variable with validateset of int: <inputStr>' -TestCases @(
        @{ inputStr = '$test='; expected = 2,3,11,112 }
        @{ inputStr = '$test = 1'; expected = 11,112 }
        @{ inputStr = '$test =11'; expected = 11,112 }
        @{ inputStr = '$test =4'; expected = @() }
    ){
        param($inputStr, $expected)

        [ValidateSet(2,3,11,112)][int]$test = 2

        $res = TabExpansion2 -inputScript $inputStr -cursorColumn $inputStr.Length
        if ($res.CompletionMatches.Count -gt 0) {
            $actual = [string]::Join(",",$res.CompletionMatches.completiontext)
        }
        else {
            $actual = ''
        }

        $actual | Should -BeExactly ([string]::Join(",",$expected))
    }

    It 'Should work for assignment of variable with validateset of strings: <inputStr>' -TestCases @(
        @{ inputStr = '[validateset("a","aa","aab","b")][string]$test='; expected = "'a'","'aa'","'aab'","'b'"; doubleQuotes = $false }
        @{ inputStr = '[validateset("a","aa","aab","b")][string]$test="a'; expected = "'a'","'aa'","'aab'"; doubleQuotes = $true }
        @{ inputStr = '[validateset("a","aa","aab","b")][string]$test = "aa'; expected = "'aa'","'aab'"; doubleQuotes = $true }
        @{ inputStr = '[validateset("a","aa","aab","b")][string]$test=''aab'; expected = "'aab'"; doubleQuotes = $false }
        @{ inputStr = '[validateset("a","aa","aab","b")][string]$test=''c'; expected = ''; doubleQuotes = $false }
    ){
        param($inputStr, $expected, $doubleQuotes)

        $expected = [string]::Join(",",$expected)
        if ($doubleQuotes) {
            $expected = $expected.Replace("'", """")
        }

        $res = TabExpansion2 -inputScript $inputStr -cursorColumn $inputStr.Length
        if ($res.CompletionMatches.Count -gt 0) {
            $actual = [string]::Join(",",$res.CompletionMatches.completiontext)
        }
        else {
            $actual = ''
        }

        $actual | Should -BeExactly $expected
    }

    Context NativeCommand {
        BeforeAll {
            $nativeCommand = (Get-Command -CommandType Application -TotalCount 1).Name
        }
        It 'Completes native commands with -' {
            Register-ArgumentCompleter -Native -CommandName $nativeCommand -ScriptBlock {
                param($wordToComplete, $ast, $cursorColumn)
                if ($wordToComplete -eq '-') {
                    return "-flag"
                }
                else {
                    return "unexpected wordtocomplete"
                }
            }
            $line = "$nativeCommand -"
            $res = TabExpansion2 -inputScript $line -cursorColumn $line.Length
            $res.CompletionMatches | Should -HaveCount 1
            $res.CompletionMatches.CompletionText | Should -BeExactly "-flag"
        }

        It 'Completes native commands with --' {
            Register-ArgumentCompleter -Native -CommandName $nativeCommand -ScriptBlock {
                param($wordToComplete, $ast, $cursorColumn)
                if ($wordToComplete -eq '--') {
                    return "--flag"
                }
                else {
                    return "unexpected wordtocomplete"
                }
            }
            $line = "$nativeCommand --"
            $res = TabExpansion2 -inputScript $line -cursorColumn $line.Length
            $res.CompletionMatches | Should -HaveCount 1
            $res.CompletionMatches.CompletionText | Should -BeExactly "--flag"
        }

        It 'Completes native commands with --f' {
            Register-ArgumentCompleter -Native -CommandName $nativeCommand -ScriptBlock {
                param($wordToComplete, $ast, $cursorColumn)
                if ($wordToComplete -eq '--f') {
                    return "--flag"
                }
                else {
                    return "unexpected wordtocomplete"
                }
            }
            $line = "$nativeCommand --f"
            $res = TaBexpansion2 -inputScript $line -cursorColumn $line.Length
            $res.CompletionMatches | Should -HaveCount 1
            $res.CompletionMatches.CompletionText | Should -BeExactly "--flag"
        }

        It 'Completes native commands with -o' {
            Register-ArgumentCompleter -Native -CommandName $nativeCommand -ScriptBlock {
                param($wordToComplete, $ast, $cursorColumn)
                if ($wordToComplete -eq '-o') {
                    return "-option"
                }
                else {
                    return "unexpected wordtocomplete"
                }
            }
            $line = "$nativeCommand -o"
            $res = TaBexpansion2 -inputScript $line -cursorColumn $line.Length
            $res.CompletionMatches | Should -HaveCount 1
            $res.CompletionMatches.CompletionText | Should -BeExactly "-option"
        }
    }

    It 'Should complete "Export-Counter -FileFormat" with available output formats' -Pending {
        $res = TabExpansion2 -inputScript 'Export-Counter -FileFormat ' -cursorColumn 'Export-Counter -FileFormat '.Length
        $res.CompletionMatches | Should -HaveCount 3
        $completionText = $res.CompletionMatches.CompletionText | Sort-Object
        $completionText -join ' ' | Should -BeExactly 'blg csv tsv'
    }

    Context "Script name completion" {
        BeforeAll {
            setup -f 'install-powershell.ps1' -content ""
            setup -f 'remove-powershell.ps1' -content ""

            $scriptWithWildcardCases = @(
                @{
                    command = '.\install-*.ps1'
                    expectedCommand = Join-Path -Path '.' -ChildPath 'install-powershell.ps1'
                    name = "'$(Join-Path -Path '.' -ChildPath 'install-powershell.ps1')'"
                }
                @{
                    command = (Join-Path ${TestDrive}  -ChildPath 'install-*.ps1')
                    expectedCommand = (Join-Path ${TestDrive}  -ChildPath 'install-powershell.ps1')
                    name = "'$(Join-Path -Path '.' -ChildPath 'install-powershell.ps1')' by fully qualified path"
                }
                @{
                    command = '.\?emove-powershell.ps1'
                    expectedCommand = Join-Path -Path '.' -ChildPath 'remove-powershell.ps1'
                    name = "'$(Join-Path -Path '.' -ChildPath '?emove-powershell.ps1')'"
                }
                @{
                    # [] cause the parser to create a new token.
                    # So, the command must be quoted to tab complete.
                    command = "'.\[ra]emove-powershell.ps1'"
                    expectedCommand = "'$(Join-Path -Path '.' -ChildPath 'remove-powershell.ps1')'"
                    name = "'$(Join-Path -Path '.' -ChildPath '[ra]emove-powershell.ps1')'"
                }
            )

            Push-Location ${TestDrive}\
        }

        AfterAll {
            Pop-Location
        }

        it "Input <name> should successfully complete" -TestCases $scriptWithWildcardCases {
            param($command, $expectedCommand)
            $res = TabExpansion2 -inputScript $command -cursorColumn $command.Length
            $res.CompletionMatches.Count | Should -BeGreaterThan 0
            $res.CompletionMatches[0].CompletionText | Should -BeExactly $expectedCommand
        }
    }

    Context "File name completion" {
        BeforeAll {
            $tempDir = Join-Path -Path $TestDrive -ChildPath "baseDir"
            $oneSubDir = Join-Path -Path $tempDir -ChildPath "oneSubDir"
            $oneSubDirPrime = Join-Path -Path $tempDir -ChildPath "prime"
            $twoSubDir = Join-Path -Path $oneSubDir -ChildPath "twoSubDir"
            $caseTestPath = Join-Path $testdrive "CaseTest"

            New-Item -Path $tempDir -ItemType Directory -Force > $null
            New-Item -Path $oneSubDir -ItemType Directory -Force > $null
            New-Item -Path $oneSubDirPrime -ItemType Directory -Force > $null
            New-Item -Path $twoSubDir -ItemType Directory -Force > $null

            $testCases = @(
                @{ inputStr = "ab"; name = "abc"; localExpected = ".${separator}abc"; oneSubExpected = "..${separator}abc"; twoSubExpected = "..${separator}..${separator}abc" }
                @{ inputStr = "asaasas"; name = "asaasas!popee"; localExpected = ".${separator}asaasas!popee"; oneSubExpected = "..${separator}asaasas!popee"; twoSubExpected = "..${separator}..${separator}asaasas!popee" }
                @{ inputStr = "asaasa"; name = "asaasas!popee"; localExpected = ".${separator}asaasas!popee"; oneSubExpected = "..${separator}asaasas!popee"; twoSubExpected = "..${separator}..${separator}asaasas!popee" }
                @{ inputStr = "bbbbbbbbbb"; name = 'bbbbbbbbbb`'; localExpected = "& '.${separator}bbbbbbbbbb``'"; oneSubExpected = "& '..${separator}bbbbbbbbbb``'"; twoSubExpected = "& '..${separator}..${separator}bbbbbbbbbb``'" }
                @{ inputStr = "bbbbbbbbb"; name = "bbbbbbbbb#"; localExpected = ".${separator}bbbbbbbbb#"; oneSubExpected = "..${separator}bbbbbbbbb#"; twoSubExpected = "..${separator}..${separator}bbbbbbbbb#" }
                @{ inputStr = "bbbbbbbb"; name = "bbbbbbbb{"; localExpected = "& '.${separator}bbbbbbbb{'"; oneSubExpected = "& '..${separator}bbbbbbbb{'"; twoSubExpected = "& '..${separator}..${separator}bbbbbbbb{'" }
                @{ inputStr = "bbbbbbb"; name = "bbbbbbb}"; localExpected = "& '.${separator}bbbbbbb}'"; oneSubExpected = "& '..${separator}bbbbbbb}'"; twoSubExpected = "& '..${separator}..${separator}bbbbbbb}'" }
                @{ inputStr = "bbbbbb"; name = "bbbbbb("; localExpected = "& '.${separator}bbbbbb('"; oneSubExpected = "& '..${separator}bbbbbb('"; twoSubExpected = "& '..${separator}..${separator}bbbbbb('" }
                @{ inputStr = "bbbbb"; name = "bbbbb)"; localExpected = "& '.${separator}bbbbb)'"; oneSubExpected = "& '..${separator}bbbbb)'"; twoSubExpected = "& '..${separator}..${separator}bbbbb)'" }
                @{ inputStr = "bbbb"; name = "bbbb$"; localExpected = "& '.${separator}bbbb$'"; oneSubExpected = "& '..${separator}bbbb$'"; twoSubExpected = "& '..${separator}..${separator}bbbb$'" }
                @{ inputStr = "bbb"; name = "bbb'"; localExpected = "& '.${separator}bbb'''"; oneSubExpected = "& '..${separator}bbb'''"; twoSubExpected = "& '..${separator}..${separator}bbb'''" }
                @{ inputStr = "bb"; name = "bb,"; localExpected = "& '.${separator}bb,'"; oneSubExpected = "& '..${separator}bb,'"; twoSubExpected = "& '..${separator}..${separator}bb,'" }
                @{ inputStr = "b"; name = "b;"; localExpected = "& '.${separator}b;'"; oneSubExpected = "& '..${separator}b;'"; twoSubExpected = "& '..${separator}..${separator}b;'" }
            )

            try {
                Push-Location -Path $tempDir
                foreach ($entry in $testCases) {
                    New-Item -Path $tempDir -Name $entry.name -ItemType File -ErrorAction SilentlyContinue > $null
                }
            } finally {
                Pop-Location
            }
        }

        BeforeEach {
            New-Item -ItemType Directory -Path $caseTestPath > $null
        }

        AfterAll {
            Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        AfterEach {
            Pop-Location
            Remove-Item -Path $caseTestPath -Recurse -Force -ErrorAction SilentlyContinue
        }

        It "Input '<inputStr>' should successfully complete" -TestCases $testCases {
            param ($inputStr, $localExpected)

            Push-Location -Path $tempDir
            $res = TabExpansion2 -inputScript $inputStr -cursorColumn $inputStr.Length
            $res.CompletionMatches.Count | Should -BeGreaterThan 0
            $res.CompletionMatches[0].CompletionText | Should -BeExactly $localExpected
        }

        It "Input '<inputStr>' should successfully complete with relative path '..\'" -TestCases $testCases {
            param ($inputStr, $oneSubExpected)

            Push-Location -Path $oneSubDir
            $inputStr = "..\${inputStr}"
            $res = TabExpansion2 -inputScript $inputStr -cursorColumn $inputStr.Length
            $res.CompletionMatches.Count | Should -BeGreaterThan 0
            $res.CompletionMatches[0].CompletionText | Should -BeExactly $oneSubExpected
        }

        It "Input '<inputStr>' should successfully complete with relative path '..\..\'" -TestCases $testCases {
            param ($inputStr, $twoSubExpected)

            Push-Location -Path $twoSubDir
            $inputStr = "../../${inputStr}"
            $res = TabExpansion2 -inputScript $inputStr -cursorColumn $inputStr.Length
            $res.CompletionMatches.Count | Should -BeGreaterThan 0
            $res.CompletionMatches[0].CompletionText | Should -BeExactly $twoSubExpected
        }

        It "Input '<inputStr>' should successfully complete with relative path '..\..\..\ba*\'" -TestCases $testCases {
            param ($inputStr, $twoSubExpected)

            Push-Location -Path $twoSubDir
            $inputStr = "..\..\..\ba*\${inputStr}"
            $res = TabExpansion2 -inputScript $inputStr -cursorColumn $inputStr.Length
            $res.CompletionMatches.Count | Should -BeGreaterThan 0
            $res.CompletionMatches[0].CompletionText | Should -BeExactly $twoSubExpected
        }

        It "Test relative path" {
            Push-Location -Path $oneSubDir
            $beforeTab = "twoSubDir/../../pri"
            $afterTab = "..${separator}prime"
            $res = TabExpansion2 -inputScript $beforeTab -cursorColumn $beforeTab.Length
            $res.CompletionMatches | Should -HaveCount 1
            $res.CompletionMatches[0].CompletionText | Should -BeExactly $afterTab
        }

        It "Test path with both '\' and '/'" {
            Push-Location -Path $twoSubDir
            $beforeTab = "..\../..\ba*/ab"
            $afterTab = "..${separator}..${separator}abc"
            $res = TabExpansion2 -inputScript $beforeTab -cursorColumn $beforeTab.Length
            $res.CompletionMatches | Should -HaveCount 1
            $res.CompletionMatches[0].CompletionText | Should -BeExactly $afterTab
        }

        It "Test case insensitive <type> path" -Skip:(!$IsLinux) -TestCases @(
            @{ type = "File"     ; beforeTab = "Get-Content f" },
            @{ type = "Directory"; beforeTab = "cd f" }
        ) {
            param ($type, $beforeTab)

            $testItems = "foo", "Foo", "fOO"
            $testItems | ForEach-Object {
                $itemPath = Join-Path $caseTestPath $_
                New-Item -ItemType $type -Path $itemPath
            }
            Push-Location $caseTestPath
            $res = TabExpansion2 -inputScript $beforeTab -cursorColumn $beforeTab.Length
            $res.CompletionMatches | Should -HaveCount $testItems.Count

            # order isn't guaranteed so we'll sort them first
            $completions = ($res.CompletionMatches | Sort-Object CompletionText -CaseSensitive).CompletionText -join ":"
            $expected = ($testItems | Sort-Object -CaseSensitive | ForEach-Object { "./$_" }) -join ":"

            $completions | Should -BeExactly $expected
        }

        It "Test case insensitive file and folder path completing for <type>" -Skip:(!$IsLinux) -TestCases @(
            @{ type = "File"     ; beforeTab = "Get-Content f"; expected = "foo","Foo" },  # Get-Content passes thru to provider
            @{ type = "Directory"; beforeTab = "cd f"         ; expected = "Foo" }  # Set-Location is aware of Files vs Folders
        ) {
            param ($beforeTab, $expected)

            $filePath = Join-Path $caseTestPath "foo"
            $folderPath = Join-Path $caseTestPath "Foo"
            New-Item -ItemType File -Path $filePath
            New-Item -ItemType Directory -Path $folderPath
            Push-Location $caseTestPath
            $res = TabExpansion2 -inputScript $beforeTab -cursorColumn $beforeTab.Length
            $res.CompletionMatches | Should -HaveCount $expected.Count

            # order isn't guaranteed so we'll sort them first
            $completions = ($res.CompletionMatches | Sort-Object CompletionText -CaseSensitive).CompletionText -join ":"
            $expected = ($expected | Sort-Object -CaseSensitive | ForEach-Object { "./$_" }) -join ":"

        }
    }

    Context "Cmdlet name completion" {
        BeforeAll {
            $testCases = @(
                @{ inputStr = "get-c*item"; expected = "Get-ChildItem" }
                @{ inputStr = "set-alia?"; expected = "Set-Alias" }
                @{ inputStr = "s*-alias"; expected = "Set-Alias" }
                @{ inputStr = "se*-alias"; expected = "Set-Alias" }
                @{ inputStr = "set-al"; expected = "Set-Alias" }
                @{ inputStr = "set-a?i"; expected = "Set-Alias" }
                @{ inputStr = "set-?lias"; expected = "Set-Alias" }
                @{ inputStr = "get-c*ditem"; expected = "Get-ChildItem" }
                @{ inputStr = "Microsoft.PowerShell.Management\get-c*item"; expected = "Microsoft.PowerShell.Management\Get-ChildItem" }
                @{ inputStr = "Microsoft.PowerShell.Utility\set-alia?"; expected = "Microsoft.PowerShell.Utility\Set-Alias" }
                @{ inputStr = "Microsoft.PowerShell.Utility\s*-alias"; expected = "Microsoft.PowerShell.Utility\Set-Alias" }
                @{ inputStr = "Microsoft.PowerShell.Utility\se*-alias"; expected = "Microsoft.PowerShell.Utility\Set-Alias" }
                @{ inputStr = "Microsoft.PowerShell.Utility\set-al"; expected = "Microsoft.PowerShell.Utility\Set-Alias" }
                @{ inputStr = "Microsoft.PowerShell.Utility\set-a?i"; expected = "Microsoft.PowerShell.Utility\Set-Alias" }
                @{ inputStr = "Microsoft.PowerShell.Utility\set-?lias"; expected = "Microsoft.PowerShell.Utility\Set-Alias" }
                @{ inputStr = "Microsoft.PowerShell.Management\get-*ditem"; expected = "Microsoft.PowerShell.Management\Get-ChildItem" }
            )
        }

        It "Input '<inputStr>' should successfully complete" -TestCases $testCases {
            param($inputStr, $expected)

            $res = TabExpansion2 -inputScript $inputStr -cursorColumn $inputStr.Length
            $res.CompletionMatches[0].CompletionText | Should -BeExactly $expected
        }
    }

    Context "Miscellaneous completion tests" {
        BeforeAll {
            $testCases = @(
                @{ inputStr = "get-childitem -"; expected = "-Path"; setup = $null }
                @{ inputStr = "get-childitem -Fil"; expected = "-Filter"; setup = $null }
                @{ inputStr = '$arg'; expected = '$args'; setup = $null }
                @{ inputStr = '$args.'; expected = 'Count'; setup = $null }
                @{ inputStr = '$Host.UI.Ra'; expected = 'RawUI'; setup = $null }
                @{ inputStr = '$Host.UI.WriteD'; expected = 'WriteDebugLine('; setup = $null }
                @{ inputStr = '$MaximumHistoryCount.'; expected = 'CompareTo('; setup = $null }
                @{ inputStr = '$A=[datetime]::now;$A.'; expected = 'Date'; setup = $null }
                @{ inputStr = '$e=$null;try { 1/0 } catch {$e=$_};$e.'; expected = 'CategoryInfo'; setup = $null }
                @{ inputStr = '$x= gps pwsh;$x.*pm'; expected = 'NPM'; setup = $null }
                @{ inputStr = 'function Get-ScrumData {}; Get-Scrum'; expected = 'Get-ScrumData'; setup = $null }
                @{ inputStr = 'function write-output {param($abcd) $abcd};Write-Output -a'; expected = '-abcd'; setup = $null }
                @{ inputStr = 'function write-output {param($abcd) $abcd};Microsoft.PowerShell.Utility\Write-Output -'; expected = '-InputObject'; setup = $null }
                @{ inputStr = '[math]::Co'; expected = 'CopySign('; setup = $null }
                @{ inputStr = '[math]::PI.GetT'; expected = 'GetType('; setup = $null }
                @{ inputStr = '[math]'; expected = '::E'; setup = $null }
                @{ inputStr = '[math].'; expected = 'Assembly'; setup = $null }
                @{ inputStr = '[math].G'; expected = 'GenericParameterAttributes'; setup = $null }
                @{ inputStr = '[Environment+specialfolder]::App'; expected = 'ApplicationData'; setup = $null }
                @{ inputStr = 'icm {get-pro'; expected = 'Get-Process'; setup = $null }
                @{ inputStr = 'write-ouput (get-pro'; expected = 'Get-Process'; setup = $null }
                @{ inputStr = 'iex "get-pro'; expected = '"Get-Process"'; setup = $null }
                @{ inputStr = '$variab'; expected = '$variableA'; setup = { $variableB = 2; $variableA = 1 } }
                @{ inputStr = 'a -'; expected = '-keys'; setup = { function a {param($keys) $a} } }
                @{ inputStr = 'Get-Content -Li'; expected = '-LiteralPath'; setup = $null }
                @{ inputStr = 'New-Item -W'; expected = '-WhatIf'; setup = $null }
                @{ inputStr = 'Get-Alias gs'; expected = 'gsn'; setup = $null }
                @{ inputStr = 'Get-Alias -Definition cd'; expected = 'cd..'; setup = $null }
                @{ inputStr = 'remove-psdrive fun'; expected = 'Function'; setup = $null }
                @{ inputStr = 'new-psdrive -PSProvider fi'; expected = 'FileSystem'; setup = $null }
                @{ inputStr = 'Get-PSDrive -PSProvider En'; expected = 'Environment'; setup = $null }
                @{ inputStr = 'remove-psdrive fun'; expected = 'Function'; setup = $null }
                @{ inputStr = 'get-psprovider ali'; expected = 'Alias'; setup = $null }
                @{ inputStr = 'Get-PSDrive -PSProvider Variable '; expected = 'Variable'; setup = $null }
                @{ inputStr = 'Get-Command Get-Chil'; expected = 'Get-ChildItem'; setup = $null }
                @{ inputStr = 'Get-Variable psver'; expected = 'PSVersionTable'; setup = $null }
                @{ inputStr = 'Get-Help get-c*ditem'; expected = 'Get-ChildItem'; setup = $null }
                @{ inputStr = 'Trace-Command e'; expected = 'ETS'; setup = $null }
                @{ inputStr = 'Get-TraceSource e'; expected = 'ETS'; setup = $null }
                @{ inputStr = '[int]:: max'; expected = 'MaxValue'; setup = $null }
                @{ inputStr = '"string". l*'; expected = 'Length'; setup = $null }
                @{ inputStr = '("a" * 5).e'; expected = 'EndsWith('; setup = $null }
                @{ inputStr = '([string][int]1).e'; expected = 'EndsWith('; setup = $null }
                @{ inputStr = '(++$i).c'; expected = 'CompareTo('; setup = $null }
                @{ inputStr = '"a".Length.c'; expected = 'CompareTo('; setup = $null }
                @{ inputStr = '@(1, "a").c'; expected = 'Count'; setup = $null }
                @{ inputStr = '{1}.is'; expected = 'IsConfiguration'; setup = $null }
                @{ inputStr = '@{ }.'; expected = 'Count'; setup = $null }
                @{ inputStr = '@{abc=1}.a'; expected = 'Add('; setup = $null }
                @{ inputStr = '$a.f'; expected = "'fo-o'"; setup = { $a = @{'fo-o'='bar'} } }
                @{ inputStr = 'dir | % { $_.Full'; expected = 'FullName'; setup = $null }
                @{ inputStr = '@{a=$(exit)}.Ke'; expected = 'Keys'; setup = $null }
                @{ inputStr = '@{$(exit)=1}.Va'; expected = 'Values'; setup = $null }
                @{ inputStr = 'switch -'; expected = '-CaseSensitive'; setup = $null }
                @{ inputStr = 'gm -t'; expected = '-Type'; setup = $null }
                @{ inputStr = 'foo -aa -aa'; expected = '-aaa'; setup = { function foo {param($a, $aa, $aaa)} } }
                @{ inputStr = 'switch ( gps -'; expected = '-Name'; setup = $null }
                @{ inputStr = 'set-executionpolicy '; expected = 'AllSigned'; setup = $null }
                @{ inputStr = 'Set-ExecutionPolicy -exe: b'; expected = 'Bypass'; setup = $null }
                @{ inputStr = 'Set-ExecutionPolicy -exe:b'; expected = 'Bypass'; setup = $null }
                @{ inputStr = 'Set-ExecutionPolicy -ExecutionPolicy:'; expected = 'AllSigned'; setup = $null }
                @{ inputStr = 'Set-ExecutionPolicy by -for:'; expected = '$true'; setup = $null }
                @{ inputStr = 'Import-Csv -Encoding '; expected = 'ascii'; setup = $null }
                @{ inputStr = 'Get-Process | % ModuleM'; expected = 'ModuleMemorySize'; setup = $null }
                @{ inputStr = 'Get-Process | % {$_.MainModule} | % Com'; expected = 'Company'; setup = $null }
                @{ inputStr = 'Get-Process | % MainModule | % Com'; expected = 'Company'; setup = $null }
                @{ inputStr = '$p = Get-Process; $p | % ModuleM'; expected = 'ModuleMemorySize'; setup = $null }
                @{ inputStr = 'gmo Microsoft.PowerShell.U'; expected = 'Microsoft.PowerShell.Utility'; setup = $null }
                @{ inputStr = 'rmo Microsoft.PowerShell.U'; expected = 'Microsoft.PowerShell.Utility'; setup = $null }
                @{ inputStr = 'gcm -Module Microsoft.PowerShell.U'; expected = 'Microsoft.PowerShell.Utility'; setup = $null }
                @{ inputStr = 'gmo -list PackageM'; expected = 'PackageManagement'; setup = $null }
                @{ inputStr = 'gcm -Module PackageManagement Find-Pac'; expected = 'Find-Package'; setup = $null }
                @{ inputStr = 'ipmo PackageM'; expected = 'PackageManagement'; setup = $null }
                @{ inputStr = 'Get-Process pws'; expected = 'pwsh'; setup = $null }
                @{ inputStr = "function bar { [OutputType('System.IO.FileInfo')][OutputType('System.Diagnostics.Process')]param() }; bar | ? { `$_.ProcessN"; expected = 'ProcessName'; setup = $null }
                @{ inputStr = "function bar { [OutputType('System.IO.FileInfo')][OutputType('System.Diagnostics.Process')]param() }; bar | ? { `$_.LastAc"; expected = 'LastAccessTime'; setup = $null }
                @{ inputStr = "& 'get-comm"; expected = "'Get-Command'"; setup = $null }
                @{ inputStr = 'alias:dir'; expected = Join-Path 'Alias:' 'dir'; setup = $null }
                @{ inputStr = 'gc alias::ipm'; expected = 'alias::ipmo'; setup = $null }
                @{ inputStr = 'gc enVironment::psmod'; expected = 'enVironment::PSModulePath'; setup = $null }
                ## tab completion safe expression evaluator tests
                @{ inputStr = '@{a=$(exit)}.Ke'; expected = 'Keys'; setup = $null }
                @{ inputStr = '@{$(exit)=1}.Ke'; expected = 'Keys'; setup = $null }
                ## tab completion variable names
                @{ inputStr = '@PSVer'; expected = '@PSVersionTable'; setup = $null }
                @{ inputStr = '$global:max'; expected = '$global:MaximumHistoryCount'; setup = $null }
                @{ inputStr = '$PSMod'; expected = '$PSModuleAutoLoadingPreference'; setup = $null }
                ## tab completion for variable in path
                ## if $PSHOME contains a space tabcompletion adds ' around the path
                @{ inputStr = 'cd $PSHOME\Modu'; expected = if($PSHOME.Contains(' ')) { "'$(Join-Path $PSHOME 'Modules')'" } else { Join-Path $PSHOME 'Modules' }; setup = $null }
                @{ inputStr = 'cd "$PSHOME\Modu"'; expected = "`"$(Join-Path $PSHOME 'Modules')`""; setup = $null }
                @{ inputStr = '$PSHOME\System.Management.Au'; expected = if($PSHOME.Contains(' ')) { "`& '$(Join-Path $PSHOME 'System.Management.Automation.dll')'" }  else { Join-Path $PSHOME 'System.Management.Automation.dll'; setup = $null }}
                @{ inputStr = '"$PSHOME\System.Management.Au"'; expected = "`"$(Join-Path $PSHOME 'System.Management.Automation.dll')`""; setup = $null }
                @{ inputStr = '& "$PSHOME\System.Management.Au"'; expected = "`"$(Join-Path $PSHOME 'System.Management.Automation.dll')`""; setup = $null }
                ## tab completion AST-based tests
                @{ inputStr = 'get-date | ForEach-Object { $PSItem.h'; expected = 'Hour'; setup = $null }
                @{ inputStr = '$a=gps;$a[0].h'; expected = 'Handle'; setup = $null }
                @{ inputStr = "`$(1,'a',@{})[-1].k"; expected = 'Keys'; setup = $null }
                @{ inputStr = "`$(1,'a',@{})[1].tri"; expected = 'Trim('; setup = $null }
                ## tab completion for type names
                @{ inputStr = '[ScriptBlockAst'; expected = 'System.Management.Automation.Language.ScriptBlockAst'; setup = $null }
                @{ inputStr = 'New-Object dict'; expected = 'System.Collections.Generic.Dictionary'; setup = $null }
                @{ inputStr = 'New-Object System.Collections.Generic.List[datet'; expected = "'System.Collections.Generic.List[datetime]'"; setup = $null }
                @{ inputStr = '[System.Management.Automation.Runspaces.runspacef'; expected = 'System.Management.Automation.Runspaces.RunspaceFactory'; setup = $null }
                @{ inputStr = '[specialfol'; expected = 'System.Environment+SpecialFolder'; setup = $null }
                ## tab completion for variable names in '{}'
                @{ inputStr = '${PSDefault'; expected = '$PSDefaultParameterValues'; setup = $null }
            )
        }

        It "Input '<inputStr>' should successfully complete" -TestCases $testCases {
            param($inputStr, $expected, $setup)

            if ($null -ne $setup) { . $setup }
            $res = TabExpansion2 -inputScript $inputStr -cursorColumn $inputStr.Length
            $res.CompletionMatches.Count | Should -BeGreaterThan 0
            $res.CompletionMatches.CompletionText | Should -Contain $expected
        }

        It "Tab completion UNC path" -Skip:(!$IsWindows) {
            $homeDrive = $env:HOMEDRIVE.Replace(":", "$")
            $beforeTab = "\\localhost\$homeDrive\wind"
            $afterTab = "& '\\localhost\$homeDrive\Windows'"
            $res = TabExpansion2 -inputScript $beforeTab -cursorColumn $beforeTab.Length
            $res.CompletionMatches.Count | Should -BeGreaterThan 0
            $res.CompletionMatches[0].CompletionText | Should -BeExactly $afterTab
        }

        It "Tab completion for registry" -Skip:(!$IsWindows) {
            $beforeTab = 'registry::HKEY_l'
            $afterTab = 'registry::HKEY_LOCAL_MACHINE'
            $res = TabExpansion2 -inputScript $beforeTab -cursorColumn $beforeTab.Length
            $res.CompletionMatches | Should -HaveCount 1
            $res.CompletionMatches[0].CompletionText | Should -BeExactly $afterTab
        }

        It "Tab completion for wsman provider" -Skip:(!$IsWindows) {
            $beforeTab = 'wsman::localh'
            $afterTab = 'wsman::localhost'
            $res = TabExpansion2 -inputScript $beforeTab -cursorColumn $beforeTab.Length
            $res.CompletionMatches | Should -HaveCount 1
            $res.CompletionMatches[0].CompletionText | Should -BeExactly $afterTab
        }

        It "Tab completion for filesystem provider qualified path" {
            $tempFolder = [System.IO.Path]::GetTempPath()
            try
            {
                New-Item -ItemType Directory -Path "$tempFolder/helloworld" > $null
                $tempFolder | Should -Exist
                $beforeTab = 'filesystem::{0}hello' -f $tempFolder
                $afterTab = 'filesystem::{0}helloworld' -f $tempFolder
                $res = TabExpansion2 -inputScript $beforeTab -cursorColumn $beforeTab.Length
                $res.CompletionMatches.Count | Should -BeGreaterThan 0
                $res.CompletionMatches[0].CompletionText | Should -BeExactly $afterTab
            }
            finally
            {
                Remove-Item -Path "$tempFolder/helloworld" -Force -ErrorAction SilentlyContinue
            }
        }

        It "Tab completion dynamic parameter of a custom function" {
            function Test-DynamicParam {
                [CmdletBinding()]
                PARAM( $DeFirst )

                DYNAMICPARAM {
                    $paramDictionary = [System.Management.Automation.RuntimeDefinedParameterDictionary]::new()
                    $attributeCollection = [System.Collections.ObjectModel.Collection[Attribute]]::new()
                    $attributeCollection.Add([Parameter]::new())
                    $deSecond = [System.Management.Automation.RuntimeDefinedParameter]::new('DeSecond', [System.Array], $attributeCollection)
                    $deThird = [System.Management.Automation.RuntimeDefinedParameter]::new('DeThird', [System.Array], $attributeCollection)
                    $null = $paramDictionary.Add('DeSecond', $deSecond)
                    $null = $paramDictionary.Add('DeThird', $deThird)
                    return $paramDictionary
                }

                PROCESS {
                    Write-Host 'Hello'
                    Write-Host $PSBoundParameters
                }
            }

            $inputStr = "Test-DynamicParam -D"
            $res = TabExpansion2 -inputScript $inputStr -cursorColumn $inputStr.Length
            $res.CompletionMatches.Count | Should -BeGreaterThan 3
            $res.CompletionMatches[0].CompletionText | Should -BeExactly '-DeFirst'
            $res.CompletionMatches[1].CompletionText | Should -BeExactly '-DeSecond'
            $res.CompletionMatches[2].CompletionText | Should -BeExactly '-DeThird'
        }

        It "Tab completion dynamic parameter '-CodeSigningCert'" -Skip:(!$IsWindows) {
            try {
                Push-Location cert:\
                $inputStr = "gci -co"
                $res = TabExpansion2 -inputScript $inputStr -cursorColumn $inputStr.Length
                $res.CompletionMatches[0].CompletionText | Should -BeExactly '-CodeSigningCert'
            } finally {
                Pop-Location
            }
        }

        It "Tab completion for file system takes precedence over functions" {
            try {
                Push-Location $TestDrive
                New-Item -Name myf -ItemType File -Force
                function MyFunction { "Hi there" }

                $inputStr = "myf"
                $res = TabExpansion2 -inputScript $inputStr -cursorColumn $inputStr.Length
                $res.CompletionMatches | Should -HaveCount 2
                $res.CompletionMatches[0].CompletionText | Should -BeExactly (Resolve-Path myf -Relative)
                $res.CompletionMatches[1].CompletionText | Should -BeExactly "MyFunction"
            } finally {
                Remove-Item -Path myf -Force
                Pop-Location
            }
        }

        It "Tab completion for validateSet attribute" {
            function foo { param([ValidateSet('cat','dog')]$p) }
            $inputStr = "foo "
            $res = TabExpansion2 -inputScript $inputStr -cursorColumn $inputStr.Length
            $res.CompletionMatches | Should -HaveCount 2
            $res.CompletionMatches[0].CompletionText | Should -BeExactly 'cat'
            $res.CompletionMatches[1].CompletionText | Should -BeExactly 'dog'
        }

        It "Tab completion for ArgumentCompleter when AST is passed to CompleteInput" {
            $scriptBl = {
                function Test-Completion {
                    param (
                        [String]$TestVal
                    )
                }
                [scriptblock]$completer = {
                    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

                    @('Val1', 'Val2')
                }
                Register-ArgumentCompleter -CommandName Test-Completion -ParameterName TestVal -ScriptBlock $completer
            }
            $pwsh = [PowerShell]::Create()
            $pwsh.AddScript($scriptBl)
            $pwsh.Invoke()

            $completeInput_Input = $scriptBl.ToString()
            $completeInput_Input += "`nTest-Completion -TestVal "
            $res = [System.Management.Automation.CommandCompletion]::CompleteInput($completeInput_Input, $completeInput_Input.Length, $null, $pwsh)
            $res.CompletionMatches | Should -HaveCount 2
            $res.CompletionMatches[0].CompletionText | Should -BeExactly 'Val1'
            $res.CompletionMatches[1].CompletionText | Should -BeExactly 'Val2'
        }

        It "Tab completion for enum type parameter of a custom function" {
            function baz ([consolecolor]$name, [ValidateSet('cat','dog')]$p){}
            $inputStr = "baz -name "
            $res = TabExpansion2 -inputScript $inputStr -cursorColumn $inputStr.Length
            $res.CompletionMatches | Should -HaveCount 16
            $res.CompletionMatches[0].CompletionText | Should -BeExactly 'Black'

            $inputStr = "baz Black "
            $res = TabExpansion2 -inputScript $inputStr -cursorColumn $inputStr.Length
            $res.CompletionMatches | Should -HaveCount 2
            $res.CompletionMatches[0].CompletionText | Should -BeExactly 'cat'
            $res.CompletionMatches[1].CompletionText | Should -BeExactly 'dog'
        }

        It "Tab completion for enum members after comma" {
            $inputStr = "Get-Command -Type Alias,c"
            $res = TabExpansion2 -inputScript $inputStr -cursorColumn $inputStr.Length
            $res.CompletionMatches | Should -HaveCount 2
            $res.CompletionMatches[0].CompletionText | Should -BeExactly 'Cmdlet'
            $res.CompletionMatches[1].CompletionText | Should -BeExactly 'Configuration'
        }

        It "Test [CommandCompletion]::GetNextResult" {
            $inputStr = "Get-Command -Type Alias,c"
            $res = TabExpansion2 -inputScript $inputStr -cursorColumn $inputStr.Length
            $res.CompletionMatches | Should -HaveCount 2
            $res.GetNextResult($false).CompletionText | Should -BeExactly 'Configuration'
            $res.GetNextResult($true).CompletionText | Should -BeExactly 'Cmdlet'
            $res.GetNextResult($true).CompletionText | Should -BeExactly 'Configuration'
        }

        It "Test history completion" {
            $startDate = Get-Date
            $endDate = $startDate.AddSeconds(1)
            $history = [pscustomobject]@{
                CommandLine = "Test history completion"
                ExecutionStatus = "Stopped"
                StartExecutionTime = $startDate
                EndExecutionTime = $endDate
            }
            Add-History -InputObject $history
            $res = TabExpansion2 -inputScript "#" -cursorColumn 1
            $res.CompletionMatches.Count | Should -BeGreaterThan 0
            $res.CompletionMatches[0].CompletionText | Should -BeExactly "Test history completion"
        }

        It "Test Attribute member completion" {
            $inputStr = "function bar { [parameter(]param() }"
            $res = TabExpansion2 -inputScript $inputStr -cursorColumn ($inputStr.IndexOf('(') + 1)
            $res.CompletionMatches | Should -HaveCount 10
            $entry = $res.CompletionMatches | Where-Object CompletionText -EQ "Position"
            $entry.CompletionText | Should -BeExactly "Position"
        }

        It "Test completion with line continuation" {
            $inputStr = @'
dir -Recurse `
-Lite
'@
            $res = TabExpansion2 -inputScript $inputStr -cursorColumn $inputStr.Length
            $res.CompletionMatches | Should -HaveCount 1
            $res.CompletionMatches[0].CompletionText | Should -BeExactly "-LiteralPath"
        }

        It "Test member completion of a static method invocation" {
            $inputStr = '[powershell]::Create().'
            $res = TabExpansion2 -inputScript $inputStr -cursorColumn $inputStr.Length
            $res.CompletionMatches | Should -HaveCount 33
            $res.CompletionMatches[0].CompletionText | Should -BeExactly "Commands"
        }

        It "Test completion with common parameters" {
            $inputStr = 'invoke-webrequest -out'
            $res = TabExpansion2 -inputScript $inputStr -cursorColumn $inputStr.Length
            $res.CompletionMatches | Should -HaveCount 3
            [string]::Join(',', ($res.CompletionMatches.completiontext | Sort-Object)) | Should -BeExactly "-OutBuffer,-OutFile,-OutVariable"
        }

        It "Test completion with exact match" {
            $inputStr = 'get-content -wa'
            $res = TabExpansion2 -inputScript $inputStr -cursorColumn $inputStr.Length
            $res.CompletionMatches | Should -HaveCount 4
            [string]::Join(',', ($res.CompletionMatches.completiontext | Sort-Object)) | Should -BeExactly "-wa,-Wait,-WarningAction,-WarningVariable"
        }
    }

    Context "Module completion for 'using module'" {
        BeforeAll {
            $tempDir = Join-Path -Path $TestDrive -ChildPath "UsingModule"
            New-Item -Path $tempDir -ItemType Directory -Force > $null
            New-Item -Path "$tempDir\testModule.psm1" -ItemType File -Force > $null

            Push-Location -Path $tempDir
        }

        AfterAll {
            Pop-Location
            Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        It "Test complete module file name" {
            $inputStr = "using module test"
            $res = TabExpansion2 -inputScript $inputStr -cursorColumn $inputStr.Length
            $res.CompletionMatches | Should -HaveCount 1
            $res.CompletionMatches[0].CompletionText | Should -BeExactly ".${separator}testModule.psm1"
        }

        It "Test complete module name" {
            $inputStr = "using module PSRead"
            $res = TabExpansion2 -inputScript $inputStr -cursorColumn $inputStr.Length
            $res.CompletionMatches.Count | Should -BeGreaterThan 0
            $res.CompletionMatches[0].CompletionText | Should -BeExactly "PSReadLine"
        }

        It "Test complete module name with wildcard" {
            $inputStr = "using module *ReadLi"
            $res = TabExpansion2 -inputScript $inputStr -cursorColumn $inputStr.Length
            $res.CompletionMatches.Count | Should -BeGreaterThan 0
            $res.CompletionMatches[0].CompletionText | Should -BeExactly "PSReadLine"
        }
    }

    Context "Completion on 'comma', 'redirection' and 'minus' tokens" {
        BeforeAll {
            $tempDir = Join-Path -Path $TestDrive -ChildPath "CommaTest"
            New-Item -Path $tempDir -ItemType Directory -Force > $null
            New-Item -Path "$tempDir\commaA.txt" -ItemType File -Force > $null

            $redirectionTestCases = @(
                @{ inputStr = "gps >";  expected = ".${separator}commaA.txt" }
                @{ inputStr = "gps >>"; expected = ".${separator}commaA.txt" }
                @{ inputStr = "dir con 2>";  expected = ".${separator}commaA.txt" }
                @{ inputStr = "dir con 2>>"; expected = ".${separator}commaA.txt" }
                @{ inputStr = "gps 2>&1>";   expected = ".${separator}commaA.txt" }
                @{ inputStr = "gps 2>&1>>";  expected = ".${separator}commaA.txt" }
            )

            Push-Location -Path $tempDir
        }

        AfterAll {
            Pop-Location
            Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        It "Test comma with file array element" {
            $inputStr = "dir .\commaA.txt,"
            $expected = ".${separator}commaA.txt"
            $res = TabExpansion2 -inputScript $inputStr -cursorColumn $inputStr.Length
            $res.CompletionMatches | Should -HaveCount 1
            $res.CompletionMatches[0].CompletionText | Should -BeExactly $expected
        }

        It "Test comma with Enum array element" {
            $inputStr = "gcm -CommandType Cmdlet,"
            $res = TabExpansion2 -inputScript $inputStr -cursorColumn $inputStr.Length
            $res.CompletionMatches | Should -HaveCount ([System.Enum]::GetNames([System.Management.Automation.CommandTypes]).Count)
            $res.CompletionMatches[0].CompletionText | Should -BeExactly "Alias"
        }

        It "Test redirection operator '<inputStr>'" -TestCases $redirectionTestCases {
            param($inputStr, $expected)

            $res = TabExpansion2 -inputScript $inputStr -cursorColumn $inputStr.Length
            $res.CompletionMatches | Should -HaveCount 1
            $res.CompletionMatches[0].CompletionText | Should -BeExactly $expected
        }

        It "Test complete the minus token to operators" {
            $inputStr = "55 -"
            $res = TabExpansion2 -inputScript $inputStr -cursorColumn $inputStr.Length
            $res.CompletionMatches | Should -HaveCount ([System.Management.Automation.CompletionCompleters]::CompleteOperator("").Count)
            $res.CompletionMatches[0].CompletionText | Should -BeExactly '-and'
        }
    }

    Context "Folder/File path tab completion with special characters" {
        BeforeAll {
            $tempDir = Join-Path -Path $TestDrive -ChildPath "SpecialChar"
            New-Item -Path $tempDir -ItemType Directory -Force > $null

            New-Item -Path "$tempDir\My [Path]" -ItemType Directory -Force > $null
            New-Item -Path "$tempDir\My [Path]\test.ps1" -ItemType File -Force > $null
            New-Item -Path "$tempDir\)file.txt" -ItemType File -Force > $null

            $testCases = @(
                @{ inputStr = "cd My"; expected = "'.${separator}My ``[Path``]'" }
                @{ inputStr = "Get-Help '.\My ``[Path``]'\"; expected = "'.${separator}My ``[Path``]${separator}test.ps1'" }
                @{ inputStr = "Get-Process >My"; expected = "'.${separator}My ``[Path``]'" }
                @{ inputStr = "Get-Process >'.\My ``[Path``]\'"; expected = "'.${separator}My ``[Path``]${separator}test.ps1'" }
                @{ inputStr = "Get-Process >${tempDir}\My"; expected = "'${tempDir}${separator}My ``[Path``]'" }
                @{ inputStr = "Get-Process > '${tempDir}\My ``[Path``]\'"; expected = "'${tempDir}${separator}My ``[Path``]${separator}test.ps1'" }
            )

            Push-Location -Path $tempDir
        }

        AfterAll {
            Pop-Location
            Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        It "Complete special relative path '<inputStr>'" -TestCases $testCases {
            param($inputStr, $expected)

            $res = TabExpansion2 -inputScript $inputStr -cursorColumn $inputStr.Length
            $res.CompletionMatches.Count | Should -BeGreaterThan 0
            $res.CompletionMatches[0].CompletionText | Should -BeExactly $expected
        }

        It "Complete file name starting with special char" {
            $inputStr = ")"
            $res = TabExpansion2 -inputScript $inputStr -cursorColumn $inputStr.Length
            $res.CompletionMatches | Should -HaveCount 1
            $res.CompletionMatches[0].CompletionText | Should -BeExactly "& '.${separator})file.txt'"
        }
    }

    Context "Local tab completion with AST" {
        BeforeAll {
            $testCases = @(
                @{ inputStr = '$p = Get-Process; $p | % ProcessN '; bareWord = 'ProcessN'; expected = 'ProcessName' }
                @{ inputStr = 'function bar { Get-Ali* }'; bareWord = 'Get-Ali*'; expected = 'Get-Alias' }
                @{ inputStr = 'function baz ([string]$version, [consolecolor]$name){} baz version bl'; bareWord = 'bl'; expected = 'Black' }
            )
        }

        It "Input '<inputStr>' should successfully complete via AST" -TestCases $testCases {
            param($inputStr, $bareWord, $expected)

            $tokens = $null
            $ast = [System.Management.Automation.Language.Parser]::ParseInput($inputStr, [ref] $tokens, [ref]$null)
            $elementAst = $ast.Find(
                { $args[0] -is [System.Management.Automation.Language.StringConstantExpressionAst] -and $args[0].Value -eq $bareWord },
                $true
            )

            $res = TabExpansion2 -ast $ast -tokens $tokens -positionOfCursor $elementAst.Extent.EndScriptPosition
            $res.CompletionMatches.Count | Should -BeGreaterThan 0
            $res.CompletionMatches[0].CompletionText | Should -BeExactly $expected
        }
    }

    Context "User-overridden TabExpansion implementations" {
        It "Override TabExpansion with function" {
            function TabExpansion ($line, $lastword) {
                "Overridden-TabExpansion-Function"
            }

            $inputStr = '$PID.'
            $res = [System.Management.Automation.CommandCompletion]::CompleteInput($inputStr, $inputst.Length, $null)
            $res.CompletionMatches | Should -HaveCount 1
            $res.CompletionMatches[0].CompletionText | Should -BeExactly 'Overridden-TabExpansion-Function'
        }

        It "Override TabExpansion with alias" {
            function OverrideTabExpansion ($line, $lastword) {
                "Overridden-TabExpansion-Alias"
            }
            Set-Alias -Name TabExpansion -Value OverrideTabExpansion

            $inputStr = '$PID.'
            $res = [System.Management.Automation.CommandCompletion]::CompleteInput($inputStr, $inputst.Length, $null)
            $res.CompletionMatches | Should -HaveCount 1
            $res.CompletionMatches[0].CompletionText | Should -BeExactly "Overridden-TabExpansion-Alias"
        }
    }

    Context "No tab completion tests" {
        BeforeAll {
            $testCases = @(
                @{ inputStr = 'function new-' }
                @{ inputStr = 'filter new-' }
                @{ inputStr = '@pid.' }
            )
        }

        It "Input '<inputStr>' should not complete to anything" -TestCases $testCases {
            param($inputStr)

            $res = TabExpansion2 -inputScript $inputStr -cursorColumn $inputStr.Length
            $res.CompletionMatches | Should -BeNullOrEmpty
        }
    }

    Context "Tab completion error tests" {
        BeforeAll {
            $ast = {}.Ast;
            $tokens = [System.Management.Automation.Language.Token[]]@()
            $testCases = @(
                @{ inputStr = {[System.Management.Automation.CommandCompletion]::MapStringInputToParsedInput('$PID.', 7)}; expected = "PSArgumentException" }
                @{ inputStr = {[System.Management.Automation.CommandCompletion]::CompleteInput($null, $null, $null, $null)}; expected = "PSArgumentNullException" }
                @{ inputStr = {[System.Management.Automation.CommandCompletion]::CompleteInput($ast, $null, $null, $null)}; expected = "PSArgumentNullException" }
                @{ inputStr = {[System.Management.Automation.CommandCompletion]::CompleteInput($ast, $tokens, $null, $null)}; expected = "PSArgumentNullException" }
                @{ inputStr = {[System.Management.Automation.CommandCompletion]::CompleteInput('$PID.', 7, $null, $null)}; expected = "PSArgumentException" }
                @{ inputStr = {[System.Management.Automation.CommandCompletion]::CompleteInput('$PID.', 5, $null, $null)}; expected = "PSArgumentNullException" }
                @{ inputStr = {[System.Management.Automation.CommandCompletion]::CompleteInput($null, $null, $null, $null, $null)}; expected = "PSArgumentNullException" }
                @{ inputStr = {[System.Management.Automation.CommandCompletion]::CompleteInput($ast, $null, $null, $null, $null)}; expected = "PSArgumentNullException" }
                @{ inputStr = {[System.Management.Automation.CommandCompletion]::CompleteInput($ast, $tokens, $null, $null, $null)}; expected = "PSArgumentNullException" }
                @{ inputStr = {[System.Management.Automation.CommandCompletion]::CompleteInput($ast, $tokens, $ast.Extent.EndScriptPosition, $null, $null)}; expected = "PSArgumentNullException" }
            )
        }

        It "Input '<inputStr>' should throw in tab completion" -TestCases $testCases {
            param($inputStr, $expected)
            $inputStr | Should -Throw -ErrorId $expected
        }
    }

    Context "DSC tab completion tests" {
        BeforeAll {
            $testCases = @(
                @{ inputStr = 'Configura'; expected = 'Configuration' }
                @{ inputStr = '$extension = New-Object [System.Collections.Generic.List[string]]; $extension.wh'; expected = "Where(" }
                @{ inputStr = '$extension = New-Object [System.Collections.Generic.List[string]]; $extension.fo'; expected = 'ForEach(' }
                @{ inputStr = 'Configuration foo { node $SelectedNodes.'; expected = 'Where(' }
                @{ inputStr = 'Configuration foo { node $SelectedNodes.fo'; expected = 'ForEach(' }
                @{ inputStr = 'Configuration foo { node $AllNodes.'; expected = 'Where(' }
                @{ inputStr = 'Configuration foo { node $ConfigurationData.AllNodes.'; expected = 'Where(' }
                @{ inputStr = 'Configuration foo { node $ConfigurationData.AllNodes.fo'; expected = 'ForEach(' }
                @{ inputStr = 'Configuration bar { File foo { Destinat'; expected = 'DestinationPath = ' }
                @{ inputStr = 'Configuration bar { File foo { Content'; expected = 'Contents = ' }
                @{ inputStr = 'Configuration bar { Fil'; expected = 'File' }
                @{ inputStr = 'Configuration bar { Import-Dsc'; expected = 'Import-DscResource' }
                @{ inputStr = 'Configuration bar { Import-DscResource -Modu'; expected = '-ModuleName' }
                @{ inputStr = 'Configuration bar { Import-DscResource -ModuleName blah -Modu'; expected = '-ModuleVersion' }
                @{ inputStr = 'Configuration bar { Scri'; expected = 'Script' }
                @{ inputStr = 'configuration foo { Script ab {Get'; expected = 'GetScript = ' }
                @{ inputStr = 'configuration foo { Script ab { '; expected = 'DependsOn = ' }
                @{ inputStr = 'configuration foo { File ab { Attributes ='; expected = "'Archive'" }
                @{ inputStr = "configuration foo { File ab { Attributes = "; expected = "'Archive'" }
                @{ inputStr = "configuration foo { File ab { Attributes = ar"; expected = "Archive" }
                @{ inputStr = "configuration foo { File ab { Attributes = 'ar"; expected = "Archive" }
                @{ inputStr = 'configuration foo { File ab { Attributes =('; expected = "'Archive'" }
                @{ inputStr = 'configuration foo { File ab { Attributes =( '; expected = "'Archive'" }
                @{ inputStr = "configuration foo { File ab { Attributes =('Archive',"; expected = "'Hidden'" }
                @{ inputStr = "configuration foo { File ab { Attributes =('Archive', "; expected = "'Hidden'" }
                @{ inputStr = "configuration foo { File ab { Attributes =('Archive', 'Hi"; expected = "Hidden" }
            )
        }

        It "Input '<inputStr>' should successfully complete" -TestCases $testCases -Skip:(!$IsWindows) {
            param($inputStr, $expected)

            $res = TabExpansion2 -inputScript $inputStr -cursorColumn $inputStr.Length
            $res.CompletionMatches.Count | Should -BeGreaterThan 0
            $res.CompletionMatches[0].CompletionText | Should -BeExactly $expected
        }
    }

    Context "CIM cmdlet completion tests" {
        BeforeAll {
            $testCases = @(
                @{ inputStr = "Invoke-CimMethod -ClassName Win32_Process -MethodName Crea"; expected = "Create" }
                @{ inputStr = "Get-CimInstance -ClassName Win32_Process | Invoke-CimMethod -MethodName AttachDeb"; expected = "AttachDebugger" }
                @{ inputStr = 'Get-CimInstance Win32_Process | ?{ $_.ProcessId -eq $PID } | Get-CimAssociatedInstance -ResultClassName Win32_Co*uterSyst'; expected = "Win32_ComputerSystem" }
                @{ inputStr = "Get-CimInstance -ClassName Win32_Environm"; expected = "Win32_Environment" }
                @{ inputStr = "New-CimInstance -ClassName Win32_Environm"; expected = "Win32_Environment" }
                @{ inputStr = 'New-CimInstance -ClassName Win32_Process | %{ $_.Captio'; expected = "Caption" }
                @{ inputStr = "Invoke-CimMethod -ClassName Win32_Environm"; expected = 'Win32_Environment' }
                @{ inputStr = "Get-CimClass -ClassName Win32_Environm"; expected = 'Win32_Environment' }
                @{ inputStr = 'Get-CimInstance -ClassName Win32_Process | Invoke-CimMethod -MethodName SetPriorit'; expected = 'SetPriority' }
                @{ inputStr = 'Invoke-CimMethod -Namespace root/StandardCimv2 -ClassName MSFT_NetIPAddress -MethodName Crea'; expected = 'Create' }
                @{ inputStr = '$win32_process = Get-CimInstance -ClassName Win32_Process; $win32_process | Invoke-CimMethod -MethodName AttachDe'; expected = 'AttachDebugger' }
                @{ inputStr = '$win32_process = Get-CimInstance -ClassName Win32_Process; Invoke-CimMethod -InputObject $win32_process -MethodName AttachDe'; expected = 'AttachDebugger' }
                @{ inputStr = 'Get-CimInstance Win32_Process | ?{ $_.ProcessId -eq $PID } | Get-CimAssociatedInstance -ResultClassName Win32_ComputerS'; expected = 'Win32_ComputerSystem' }
                @{ inputStr = 'Get-CimInstance -Namespace root/Interop -ClassName Win32_PowerSupplyP'; expected = 'Win32_PowerSupplyProfile' }
                @{ inputStr = 'Get-CimInstance __NAMESP'; expected = '__NAMESPACE' }
                @{ inputStr = 'Get-CimInstance -Namespace root/Inter'; expected = 'root/Interop' }
                @{ inputStr = 'Get-CimInstance -Namespace root/Int*ro'; expected = 'root/Interop' }
                @{ inputStr = 'Get-CimInstance -Namespace root/Interop/'; expected = 'root/Interop/ms_409' }
                @{ inputStr = 'New-CimInstance -Namespace root/Inter'; expected = 'root/Interop' }
                @{ inputStr = 'Invoke-CimMethod -Namespace root/Inter'; expected = 'root/Interop' }
                @{ inputStr = 'Get-CimClass -Namespace root/Inter'; expected = 'root/Interop' }
                @{ inputStr = 'Register-CimIndicationEvent -Namespace root/Inter'; expected = 'root/Interop' }
                @{ inputStr = '[Microsoft.Management.Infrastructure.CimClass]$c = $null; $c.CimClassNam'; expected = 'CimClassName' }
                @{ inputStr = '[Microsoft.Management.Infrastructure.CimClass]$c = $null; $c.CimClassName.Substrin'; expected = 'Substring(' }
                @{ inputStr = 'Get-CimInstance -ClassName Win32_Process | %{ $_.ExecutableP'; expected = 'ExecutablePath' }
            )
        }

        It "CIM cmdlet input '<inputStr>' should successfully complete" -TestCases $testCases -Skip:(!$IsWindows) {
            param($inputStr, $expected)

            $res = TabExpansion2 -inputScript $inputStr -cursorColumn $inputStr.Length
            $res.CompletionMatches.Count | Should -BeGreaterThan 0
            $res.CompletionMatches[0].CompletionText | Should -BeExactly $expected
        }
    }

    Context "Module cmdlet completion tests" {
        It "ArugmentCompleter for PSEdition should work for '<cmd>'" -TestCases @(
            @{cmd = "Get-Module -PSEdition "; expected = "Desktop", "Core"}
        ) {
            param($cmd, $expected)
            $res = TabExpansion2 -inputScript $cmd -cursorColumn $cmd.Length
            $res.CompletionMatches | Should -HaveCount $expected.Count
            $completionOptions = ""
            foreach ($completion in $res.CompletionMatches) {
                $completionOptions += $completion.ListItemText
            }
            $completionOptions | Should -BeExactly ([string]::Join("", $expected))
        }
    }

    Context "Tab completion help test" {
        BeforeAll {
            if ([System.Management.Automation.Platform]::IsWindows) {
                $userHelpRoot = Join-Path $HOME "Documents/PowerShell/Help/"
            } else {
                $userModulesRoot = [System.Management.Automation.Platform]::SelectProductNameForDirectory([System.Management.Automation.Platform+XDG_Type]::USER_MODULES)
                $userHelpRoot = Join-Path $userModulesRoot -ChildPath ".." -AdditionalChildPath "Help"
            }
        }

        It 'Should complete about help topic' {
            $aboutHelpPathUserScope = Join-Path $userHelpRoot (Get-Culture).Name
            $aboutHelpPathAllUsersScope = Join-Path $PSHOME (Get-Culture).Name

            ## If help content does not exist, tab completion will not work. So update it first.
            $userScopeHelp = Test-Path (Join-Path $aboutHelpPathUserScope "about_Splatting.help.txt")
            $allUserScopeHelp = Test-Path (Join-Path $aboutHelpPathAllUsersScope "about_Splatting.help.txt")
            if ((-not $userScopeHelp) -and (-not $aboutHelpPathAllUsersScope)) {
                Update-Help -Force -ErrorAction SilentlyContinue -Scope 'CurrentUser'
            }

            # If help content is present on both scopes, expect 2 or else expect 1 completion.
            $expectedCompletions = if ($userScopeHelp -and $allUserScopeHelp) { 2 } else { 1 }

            $res = TabExpansion2 -inputScript 'get-help about_spla' -cursorColumn 'get-help about_spla'.Length
            $res.CompletionMatches | Should -HaveCount $expectedCompletions
            $res.CompletionMatches[0].CompletionText | Should -BeExactly 'about_Splatting'
        }
    }
}

Describe "Tab completion tests with remote Runspace" -Tags Feature,RequireAdminOnWindows {
    BeforeAll {
        if ($IsWindows) {
            $session = New-RemoteSession
            $powershell = [powershell]::Create()
            $powershell.Runspace = $session.Runspace

            $testCases = @(
                @{ inputStr = 'Get-Proc'; expected = 'Get-Process' }
                @{ inputStr = 'Get-Process | % ProcessN'; expected = 'ProcessName' }
                @{ inputStr = 'Get-ChildItem alias: | % { $_.Defini'; expected = 'Definition' }
            )

            $testCasesWithAst = @(
                @{ inputStr = '$p = Get-Process; $p | % ProcessN '; bareWord = 'ProcessN'; expected = 'ProcessName' }
                @{ inputStr = 'function bar { Get-Ali* }'; bareWord = 'Get-Ali*'; expected = 'Get-Alias' }
                @{ inputStr = 'function baz ([string]$version, [consolecolor]$name){} baz version bl'; bareWord = 'bl'; expected = 'Black' }
            )
        } else {
            $defaultParameterValues = $PSDefaultParameterValues.Clone()
            $PSDefaultParameterValues["It:Skip"] = $true
        }
    }
    AfterAll {
        if ($IsWindows) {
            Remove-PSSession $session
            $powershell.Dispose()
        } else {
            $Global:PSDefaultParameterValues = $defaultParameterValues
        }
    }

    It "Input '<inputStr>' should successfully complete in remote runspace" -TestCases $testCases {
        param($inputStr, $expected)
        $res = [System.Management.Automation.CommandCompletion]::CompleteInput($inputStr, $inputStr.Length, $null, $powershell)
        $res.CompletionMatches.Count | Should -BeGreaterThan 0
        $res.CompletionMatches[0].CompletionText | Should -BeExactly $expected
    }

    It "Input '<inputStr>' should successfully complete via AST in remote runspace" -TestCases $testCasesWithAst {
        param($inputStr, $bareWord, $expected)

        $tokens = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseInput($inputStr, [ref] $tokens, [ref]$null)
        $elementAst = $ast.Find(
            { $args[0] -is [System.Management.Automation.Language.StringConstantExpressionAst] -and $args[0].Value -eq $bareWord },
            $true
        )

        $res = [System.Management.Automation.CommandCompletion]::CompleteInput($ast, $tokens, $elementAst.Extent.EndScriptPosition, $null, $powershell)
        $res.CompletionMatches.Count | Should -BeGreaterThan 0
        $res.CompletionMatches[0].CompletionText | Should -BeExactly $expected
    }
}

Describe "WSMan Config Provider tab complete tests" -Tags Feature,RequireAdminOnWindows {

    BeforeAll {
        $originalDefaultParameterValues = $PSDefaultParameterValues.Clone()
        $PSDefaultParameterValues["it:skip"] = !$IsWindows
    }

    AfterAll {
        $Global:PSDefaultParameterValues = $originalDefaultParameterValues
    }

    It "Tab completion works correctly for Listeners" {
        $path = "wsman:\localhost\listener\listener"
        $res = TabExpansion2 -inputScript $path -cursorColumn $path.Length
        $listener = Get-ChildItem WSMan:\localhost\Listener
        $res.CompletionMatches.Count | Should -Be $listener.Count
        $res.CompletionMatches.ListItemText | Should -BeIn $listener.Name
    }

    It "Tab completion gets dynamic parameters for '<path>' using '<parameter>'" -TestCases @(
        @{path = ""; parameter = "-conn"; expected = "ConnectionURI"},
        @{path = ""; parameter = "-op"; expected = "OptionSet"},
        @{path = ""; parameter = "-au"; expected = "Authentication"},
        @{path = ""; parameter = "-ce"; expected = "CertificateThumbprint"},
        @{path = ""; parameter = "-se"; expected = "SessionOption"},
        @{path = ""; parameter = "-ap"; expected = "ApplicationName"},
        @{path = ""; parameter = "-po"; expected = "Port"},
        @{path = ""; parameter = "-u"; expected = "UseSSL"},
        @{path = "localhost\plugin"; parameter = "-pl"; expected = "Plugin"},
        @{path = "localhost\plugin"; parameter = "-sd"; expected = "SDKVersion"},
        @{path = "localhost\plugin"; parameter = "-re"; expected = "Resource"},
        @{path = "localhost\plugin"; parameter = "-ca"; expected = "Capability"},
        @{path = "localhost\plugin"; parameter = "-xm"; expected = "XMLRenderingType"},
        @{path = "localhost\plugin"; parameter = "-fi"; expected = @("FileName", "File")},
        @{path = "localhost\plugin"; parameter = "-ru"; expected = "RunAsCredential"},
        @{path = "localhost\plugin"; parameter = "-us"; expected = "UseSharedProcess"},
        @{path = "localhost\plugin"; parameter = "-au"; expected = "AutoRestart"},
        @{path = "localhost\plugin"; parameter = "-pr"; expected = "ProcessIdleTimeoutSec"},
        @{path = "localhost\Plugin\microsoft.powershell\Resources\"; parameter = "-re"; expected = "ResourceUri"},
        @{path = "localhost\Plugin\microsoft.powershell\Resources\"; parameter = "-ca"; expected = "Capability"}
    ) {
        param($path, $parameter, $expected)
        $script = "new-item wsman:\$path $parameter"
        $res = TabExpansion2 -inputScript $script
        $res.CompletionMatches | Should -HaveCount $expected.Count
        $completionOptions = ""
        foreach ($completion in $res.CompletionMatches) {
            $completionOptions += $completion.ListItemText
        }
        $completionOptions | Should -BeExactly ([string]::Join("", $expected))
    }

    It "Tab completion get dynamic parameters for initialization parameters" -Pending -TestCases @(
        @{path = "localhost\Plugin\microsoft.powershell\InitializationParameters\"; parameter = "-pa"; expected = @("ParamName", "ParamValue")}
    ) {
        # https://github.com/PowerShell/PowerShell/issues/4744
        # TODO: move to test cases above once working
    }
}
