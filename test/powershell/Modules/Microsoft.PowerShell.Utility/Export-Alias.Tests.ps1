# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

Import-Module HelpersCommon

Describe "Export-Alias DRT Unit Tests" -Tags "CI" {

	BeforeAll {
		$testAliasDirectory = Join-Path -Path $TestDrive -ChildPath ExportAliasTestDirectory
		$testAliases        = "TestAliases"
    	$fulltestpath       = Join-Path -Path $testAliasDirectory -ChildPath $testAliases

		remove-item alias:abcd* -force -ErrorAction SilentlyContinue
		remove-item alias:ijkl* -force -ErrorAction SilentlyContinue
		set-alias abcd01 efgh01
		set-alias abcd02 efgh02
		set-alias abcd03 efgh03
		set-alias abcd04 efgh04
		set-alias ijkl01 mnop01
		set-alias ijkl02 mnop02
		set-alias ijkl03 mnop03
		set-alias ijkl04 mnop04
	}

	AfterAll {
		remove-item alias:abcd* -force -ErrorAction SilentlyContinue
		remove-item alias:ijkl* -force -ErrorAction SilentlyContinue
	}

    BeforeEach {
		New-Item -Path $testAliasDirectory -ItemType Directory -Force
    }

	AfterEach {
		Remove-Item -Path $testAliasDirectory -Recurse -Force
	}

    It "Export-Alias for exist file should work"{
		New-Item -Path $fulltestpath -ItemType File -Force
		{Export-Alias $fulltestpath} | Should -Not -Throw
    }

	It "Export-Alias resolving to multiple files will throw ReadWriteMultipleFilesNotSupported" {
		$null = New-Item -Path $TestDrive\foo -ItemType File
		$null = New-Item -Path $TestDrive\bar -ItemType File
		{ Export-Alias $TestDrive\* } | Should -Throw -ErrorId "ReadWriteMultipleFilesNotSupported,Microsoft.PowerShell.Commands.ExportAliasCommand"

		Remove-Item $TestDrive\foo -Force -ErrorAction SilentlyContinue
		Remove-Item $TestDrive\bar -Force -ErrorAction SilentlyContinue
	}

	It "Export-Alias with Invalid Scope will throw PSArgumentException" {
		{ Export-Alias $fulltestpath -scope foobar } | Should -Throw -ErrorId "Argument,Microsoft.PowerShell.Commands.ExportAliasCommand"
	}

	It "Export-Alias for Default"{
		Export-Alias $fulltestpath abcd01 -passthru
		$fulltestpath | Should -FileContentMatchExactly '"abcd01","efgh01","","None"'
    }

	It "Export-Alias As CSV"{
		Export-Alias $fulltestpath abcd01 -As CSV -passthru
		$fulltestpath | Should -FileContentMatchExactly '"abcd01","efgh01","","None"'
    }

	It "Export-Alias As CSV With Description"{
		Export-Alias $fulltestpath abcd01 -As CSV -description "My Aliases" -passthru
		$fulltestpath | Should -FileContentMatchExactly '"abcd01","efgh01","","None"'
		$fulltestpath | Should -FileContentMatchExactly "My Aliases"
    }

	It "Export-Alias As CSV With Multiline Description"{
		Export-Alias $fulltestpath abcd01 -As CSV -description "My Aliases\nYour Aliases\nEveryones Aliases" -passthru
		$fulltestpath | Should -FileContentMatchExactly '"abcd01","efgh01","","None"'
		$fulltestpath | Should -FileContentMatchExactly "My Aliases"
		$fulltestpath | Should -FileContentMatchExactly "Your Aliases"
		$fulltestpath | Should -FileContentMatchExactly "Everyones Aliases"
    }

	It "Export-Alias As Script"{
		Export-Alias $fulltestpath abcd01 -As Script -passthru
		$fulltestpath | Should -FileContentMatchExactly 'set-alias -Name:"abcd01" -Value:"efgh01" -Description:"" -Option:"None"'
    }

	It "Export-Alias As Script With Multiline Description"{
		Export-Alias $fulltestpath abcd01 -As Script -description "My Aliases\nYour Aliases\nEveryones Aliases" -passthru
		$fulltestpath | Should -FileContentMatchExactly 'set-alias -Name:"abcd01" -Value:"efgh01" -Description:"" -Option:"None"'
		$fulltestpath | Should -FileContentMatchExactly "My Aliases"
		$fulltestpath | Should -FileContentMatchExactly "Your Aliases"
		$fulltestpath | Should -FileContentMatchExactly "Everyones Aliases"
    }

	It "Export-Alias for Force Test"{
		Export-Alias $fulltestpath abcd01
		Export-Alias $fulltestpath abcd02 -force
		$fulltestpath | Should -Not -FileContentMatchExactly '"abcd01","efgh01","","None"'
		$fulltestpath | Should -FileContentMatchExactly '"abcd02","efgh02","","None"'
    }

	It "Export-Alias for Force ReadOnly Test" -Skip:(Test-IsRoot) {
		Export-Alias $fulltestpath abcd01
		if ( $IsWindows )
		{
			attrib +r $fulltestpath
		}
		else
		{
			chmod 444 $fulltestpath
		}

		{ Export-Alias $fulltestpath abcd02 } | Should -Throw -ErrorId "FileOpenFailure,Microsoft.PowerShell.Commands.ExportAliasCommand"
		Export-Alias $fulltestpath abcd03 -force
		$fulltestpath | Should -Not -FileContentMatchExactly '"abcd01","efgh01","","None"'
		$fulltestpath | Should -Not -FileContentMatchExactly '"abcd02","efgh02","","None"'
		$fulltestpath | Should -FileContentMatchExactly '"abcd03","efgh03","","None"'

		if ( $IsWindows )
		{
			attrib -Recurse $fulltestpath
		}
		else
		{
			chmod 777 $fulltestpath
		}

    }
}

Describe "Export-Alias" -Tags "CI" {

	BeforeAll {
		$testAliasDirectory = Join-Path -Path $TestDrive -ChildPath ExportAliasTestDirectory
		$testAliases        = "TestAliases"
		$fulltestpath       = Join-Path -Path $testAliasDirectory -ChildPath $testAliases
	}

	BeforeEach {
		New-Item -Path $testAliasDirectory -ItemType Directory -Force
	}

	AfterEach {
		Remove-Item -Path $testAliasDirectory -Recurse -Force
	}

	It "Should be able to create a file in the specified location"{
		Export-Alias $fulltestpath
		Test-Path $fulltestpath | Should -BeTrue
  }

  It "Should create a file with the list of aliases that match the expected list" {
		Export-Alias $fulltestpath
		Test-Path $fulltestpath | Should -BeTrue

		$actual   = Get-Content $fulltestpath | Sort-Object
		$expected = Get-Command -CommandType Alias

		for ( $i=0; $i -lt $expected.Length; $i++)
		{
			# We loop through the expected list and not the other because the output writes some comments to the file.
			$expected[$i] | Should -Match $actual[$i].Name
		}
  }
}
