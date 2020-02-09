# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

Describe 'Clipboard cmdlet tests' -Tag CI {
    BeforeAll {
        $xclip = Get-Command xclip -CommandType Application -ErrorAction Ignore
    }

    Context 'Text' {
        BeforeAll {
            $defaultParamValues = $PSDefaultParameterValues.Clone()
            $PSDefaultParameterValues["it:skip"] = ($IsWindows -and $env:PROCESSOR_ARCHITECTURE.Contains("arm")) -or ($IsLinux -and $xclip -eq $null)
        }

        AfterAll {
            $PSDefaultParameterValues = $defaultParamValues
        }

        It 'Get-Clipboard returns what is in Set-Clipboard' {
            $guid = New-Guid
            Set-Clipboard -Value $guid
            Get-Clipboard | Should -BeExactly $guid
        }

        It 'Get-Clipboard returns an array' {
            1,2 | Set-Clipboard
            $out = Get-Clipboard
            $out.Count | Should -Be 2
            $out[0] | Should -Be 1
            $out[1] | Should -Be 2
        }

        It 'Get-Clipboard -Raw returns one item' {
            1,2 | Set-Clipboard
            (Get-Clipboard -Raw).Count | Should -Be 1
            Get-Clipboard -Raw | Should -BeExactly "1$([Environment]::NewLine)2"
        }

        It 'Set-Clipboard -Append will add text' {
            'hello' | Set-Clipboard
            'world' | Set-Clipboard -Append
            Get-Clipboard -Raw | Should -BeExactly "hello$([Environment]::NewLine)world"
        }
    }
}
