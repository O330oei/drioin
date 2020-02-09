# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

Describe 'Get-Error tests' -Tag CI {
    It 'Get-Error resolves $error[0] and includes InnerException' {
        try {
            1/0
        }
        catch {
        }

        $out = Get-Error | Out-String
        $out | Should -BeLikeExactly '*InnerException*'

        $err = Get-Error
        $err | Should -BeOfType System.Management.Automation.ErrorRecord
        $err.PSObject.TypeNames | Should -Not -Contain 'System.Management.Automation.ErrorRecord'
        $err.PSObject.TypeNames | Should -Contain 'System.Management.Automation.ErrorRecord#PSExtendedError'

        # need to exercise the formatter to validate that the internal types are removed from the error object
        $null = $err | Out-String
        $err | Should -BeOfType System.Management.Automation.ErrorRecord
        $err.PSObject.TypeNames | Should -Contain 'System.Management.Automation.ErrorRecord'
        $err.PSObject.TypeNames | Should -Not -Contain 'System.Management.Automation.ErrorRecord#PSExtendedError'
    }

    It 'Get-Error -Newest `<count>` works: <scenario>' -TestCases @(
        @{ scenario = 'less than total'; count = 1; paramname = 'Newest' }
        @{ scenario = 'equal to total'; count = 2; paramname = 'Last' }
        @{ scenario = 'greater than total'; count = 9999; paramname = 'Newest' }
    ){
        param ($count, $paramname)

        try {
            1/0
        }
        catch {
        }

        try {
            get-item (new-guid) -ErrorAction SilentlyContinue
        }
        catch {
        }

        $params = @{ $paramname = $count }

        $out = Get-Error @params

        $expected = $count
        if ($count -eq 9999) {
            $expected = $error.Count
        }

        $out.Count | Should -Be $expected
    }

    It 'Get-Error -Newest with invalid value `<value>` should fail' -TestCases @(
        @{ value = 0 }
        @{ value = -2 }
    ){
        param($value)

        { Get-Error -Newest $value } | Should -Throw -ErrorId 'ParameterArgumentValidationError,Microsoft.PowerShell.Commands.GetErrorCommand'
    }

    It 'Get-Error will accept pipeline input' {
        try {
            1/0
        }
        catch {
        }

        $out = $error[0] | Get-Error | Out-String
        $out | Should -BeLikeExactly '*-2146233087*'
    }

    It 'Get-Error will handle Exceptions' {
        $e = [Exception]::new('myexception')
        $error.Insert(0, $e)

        $out = Get-Error | Out-String
        $out | Should -BeLikeExactly '*myexception*'

        $err = Get-Error
        $err | Should -BeOfType System.Exception
        $err.PSObject.TypeNames | Should -Not -Contain 'System.Exception'
        $err.PSObject.TypeNames | Should -Contain 'System.Exception#PSExtendedError'

        # need to exercise the formatter to validate that the internal types are removed from the error object
        $null = $err | Out-String
        $err | Should -BeOfType System.Exception
        $err.PSObject.TypeNames | Should -Contain 'System.Exception'
        $err.PSObject.TypeNames | Should -Not -Contain 'System.Exception#PSExtendedError'
    }

    It 'Get-Error will not modify the original error object' {
        try {
            1 / 0
        }
        catch {
        }

        $null = Get-Error

        $error[0].pstypenames | Should -Be System.Management.Automation.ErrorRecord, System.Object
    }

    It 'Get-Error adds ExceptionType for Exceptions' {
        try {
            [System.Net.DNS]::GetHostByName((New-Guid))
        }
        catch {
        }

        $out = Get-Error | Out-String
        $out | Should -BeLikeExactly '*Type*'

        if ($IsWindows) {
            $expectedExceptionType = "System.Management.Automation.ParentContainsErrorRecordException"
        }
        else {
            $expectedExceptionType = "System.Net.Internals.SocketExceptionFactory+ExtendedSocketException"
        }

        $out | Should -BeLikeExactly "*$expectedExceptionType*"
    }
}
