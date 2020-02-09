# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

Describe 'Tests for $ErrorView' -Tag CI {

    It '$ErrorView is an enum' {
        $ErrorView | Should -BeOfType System.Management.Automation.ErrorView
    }

    It '$ErrorView should have correct default value' {
        $expectedDefault = 'ConciseView'

        $ErrorView | Should -BeExactly $expectedDefault
    }

    It 'Exceptions not thrown do not get formatted as ErrorRecord' {
        $exp = [System.Exception]::new('test') | Out-String
        $exp | Should -BeLike "*Message        : test*"
    }

    Context 'ConciseView tests' {
        BeforeEach {
            $testScriptPath = Join-Path -Path $TestDrive -ChildPath 'test.ps1'
        }

        AfterEach {
            Remove-Item -Path $testScriptPath -Force -ErrorAction SilentlyContinue
        }

        It 'Cmdlet error should be one line of text' {
            Get-Item (New-Guid) -ErrorVariable e -ErrorAction SilentlyContinue
            ($e | Out-String).Trim().Count | Should -Be 1
        }

        It 'Script error should contain path to script and line for error' {
            $testScript = @'
                [cmdletbinding()]
                param()
                $a = 1
                123)
                $b = 2
'@

            Set-Content -Path $testScriptPath -Value $testScript
            $e = { & $testScriptPath } | Should -Throw -ErrorId 'UnexpectedToken' -PassThru | Out-String
            $e | Should -BeLike "*${testScriptPath}:4*"
            # validate line number is shown
            $e | Should -BeLike '* 4 *'
        }

        It "Remote errors show up correctly" {
            Start-Job -ScriptBlock { get-item (new-guid) } | Wait-Job | Receive-Job -ErrorVariable e -ErrorAction SilentlyContinue
            ($e | Out-String).Trim().Count | Should -Be 1
        }

        It "Activity shows up correctly for scriptblocks" {
            $e = & "$PSHOME/pwsh" -noprofile -command 'Write-Error 'myError' -ErrorAction SilentlyContinue; $error[0] | Out-String'
            [string]::Join('', $e).Trim() | Should -BeLike "*Write-Error:*myError*" # wildcard due to VT100
        }

        It "Function shows up correctly" {
            function test-myerror { [cmdletbinding()] param() write-error 'myError' }

            $e = & "$PSHOME/pwsh" -noprofile -command 'function test-myerror { [cmdletbinding()] param() write-error "myError" }; test-myerror -ErrorAction SilentlyContinue; $error[0] | Out-String'
            [string]::Join('', $e).Trim() | Should -BeLike "*test-myerror:*myError*" # wildcard due to VT100
        }

        It "Pester Should shows test file and not pester" {
            $testScript = '1 + 1 | Should -Be 3'

            Set-Content -Path $testScriptPath -Value $testScript
            $e = { & $testScriptPath } | Should -Throw -ErrorId 'PesterAssertionFailed' -PassThru | Out-String
            $e | Should -BeLike "*$testScriptPath*"
            $e | Should -Not -BeLike '*pester*'
        }

        It "Long lines should be rendered correctly with indentation" {
            $testscript = @'
                        $myerrors = [System.Collections.ArrayList]::new()
                        Copy-Item (New-Guid) (New-Guid) -ErrorVariable +myerrors -ErrorAction SilentlyContinue
                $error[0]
'@

            Set-Content -Path $testScriptPath -Value $testScript
            $e = & $testScriptPath | Out-String
            $e | Should -BeLike "*${testScriptPath}:2*"
            # validate line number is shown
            $e | Should -BeLike '* 2 *'
        }
    }

    Context 'NormalView tests' {

        It 'Error shows up when using strict mode' {
            try {
                $ErrorView = 'NormalView'
                Set-StrictMode -Version 2
                throw 'Oops!'
            }
            catch {
                $e = $_ | Out-String
            }
            finally {
                Set-StrictMode -Off
            }

            $e | Should -BeLike '*Oops!*'
        }
    }
}
