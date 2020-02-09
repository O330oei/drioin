# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.
Describe 'Basic engine APIs' -Tags "CI" {
    Context 'powershell::Create' {
        It 'can create default instance' {
            [powershell]::Create() | Should -Not -BeNullOrEmpty
        }

        It 'can create instance with runspace' {
            $rs = [runspacefactory]::CreateRunspace()
            $ps = [powershell]::Create($rs)
            $ps | Should -Not -BeNullOrEmpty
            $ps.Runspace | Should -Be $rs
            $ps.Dispose()
            $rs.Dispose()
        }

        It 'cannot create instance with null runspace' {
            { [powershell]::Create([runspace]$null) } | Should -Throw -ErrorId 'PSArgumentNullException'
        }

        It "can load the default snapin 'Microsoft.WSMan.Management'" -skip:(-not $IsWindows) {
            $ps = [powershell]::Create()
            $ps.AddScript("Get-Command -Name Test-WSMan") > $null

            $result = $ps.Invoke()
            $result.Count | Should -Be 1
            $result[0].Source | Should -BeExactly "Microsoft.WSMan.Management"
        }
    }

    Context 'executioncontext' {
        It 'args are passed correctly' {
            $result = $ExecutionContext.SessionState.InvokeCommand.InvokeScript('"`$args:($args); `$input:($input)"', 1, 2, 3)
            $result | Should -BeExactly '$args:(1 2 3); $input:()'
        }
    }
}

Describe "Clean up open Runspaces when exit powershell process" -Tags "Feature" {
    It "PowerShell process should not freeze at exit" {
        $command = @'
-c $rs = [runspacefactory]::CreateRunspacePool(1,5)
$rs.Open()
$ps = [powershell]::Create()
$ps.RunspacePool = $rs
$null = $ps.AddScript(1).Invoke()
"should_not_stop_responding_at_exit"
exit
'@
        $outputFile = New-Item -Path $TestDrive\output.txt -ItemType File
        $process = Start-Process "$PSHOME/pwsh" -ArgumentList $command -PassThru -RedirectStandardOutput $outputFile
        Wait-UntilTrue -sb { $process.HasExited } -TimeoutInMilliseconds 5000 -IntervalInMilliseconds 1000 | Should -BeTrue
        $hasExited = $process.HasExited

        $verboseMessage = Get-Content $outputFile

        if (-not $hasExited) {
            Stop-Process $process -Force
        }

        $hasExited | Should -BeTrue -Because "Process did not exit in 5 seconds as: $verboseMessage"
    }
}

Describe "EndInvoke() should return a collection of results" -Tags "CI" {
    BeforeAll {
        $ps = [powershell]::Create()
        $ps.AddScript("'Hello'; 'World'") > $null
    }

    It "BeginInvoke() and then EndInvoke() should return a collection of results" {
        $async = $ps.BeginInvoke()
        $result = $ps.EndInvoke($async)

        $result.Count | Should -BeExactly 2
        $result[0] | Should -BeExactly "Hello"
        $result[1] | Should -BeExactly "World"
    }

    It "BeginInvoke() and then EndInvoke() should return a collection of results after a previous Stop() call" {
        $async = $ps.BeginInvoke()
        $ps.Stop()

        $async = $ps.BeginInvoke()
        $result = $ps.EndInvoke($async)

        $result.Count | Should -BeExactly 2
        $result[0] | Should -BeExactly "Hello"
        $result[1] | Should -BeExactly "World"
    }

    It "BeginInvoke() and then EndInvoke() should return a collection of results after a previous BeginStop()/EndStop() call" {
        $asyncInvoke = $ps.BeginInvoke()
        $asyncStop = $ps.BeginStop($null, $null)
        $ps.EndStop($asyncStop)

        $asyncInvoke = $ps.BeginInvoke()
        $result = $ps.EndInvoke($asyncInvoke)

        $result.Count | Should -BeExactly 2
        $result[0] | Should -BeExactly "Hello"
        $result[1] | Should -BeExactly "World"
    }
}
