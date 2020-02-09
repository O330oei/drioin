# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

Describe "Verify Markdown Links" {
    BeforeAll {
        if(!(Get-Command -Name 'markdown-link-check' -ErrorAction SilentlyContinue))
        {
            Write-Verbose "installing markdown-link-check ..." -Verbose
            start-nativeExecution {
                sudo yarn global add markdown-link-check@3.7.2
            }
        }

        if(!(Get-Module -Name 'ThreadJob' -ListAvailable -ErrorAction SilentlyContinue))
        {
            Install-Module -Name ThreadJob -Scope CurrentUser
        }

        # Cleanup jobs for reliability
        get-job | remove-job -force
    }

    AfterAll {
        # Cleanup jobs to leave the process the same
        get-job | remove-job -force
    }

    $groups = Get-ChildItem -Path "$PSScriptRoot\..\..\..\*.md" -Recurse | Where-Object {$_.DirectoryName -notlike '*node_modules*'} | Group-Object -Property directory

    $jobs = @{}
    # start all link verification in parallel
    Foreach($group in $groups)
    {
        Write-Verbose -verbose "starting jobs for $($group.Name) ..."
        $job = Start-ThreadJob {
            param([object] $group)
            foreach($file in $group.Group)
            {
                $results = markdown-link-check $file 2>&1
                Write-Output ([PSCustomObject]@{
                    file = $file
                    results = $results
                })
            }
        } -ArgumentList @($group)
        $jobs.add($group.name,$job)
    }

    Write-Verbose -verbose "Getting results ..."
    # Get the results and verify
    foreach($key in $jobs.keys)
    {
        $job = $jobs.$key
        $results = Receive-Job -Job $job -Wait
        Remove-job -job $Job
        foreach($jobResult in $results)
        {
            $file = $jobResult.file
            $result = $jobResult.results
            Context "Verify links in $file" {
                # failures look like `[✖] https://someurl` (perhaps without the https://)
                # passes look like `[✓] https://someurl` (perhaps without the https://)
                $failures = $result -like '*[✖]*' | ForEach-Object { $_.Substring(4).Trim() }
                $passes = $result -like '*[✓]*' | ForEach-Object {
                    @{url=$_.Substring(4).Trim() }
                }
                $trueFailures = @()
                $verifyFailures = @()
                foreach ($failure in $failures) {
                    if($failure -like 'https://www.amazon.com*')
                    {
                        # In testing amazon links often failed when they are valid
                        # Verify manually
                        $verifyFailures += @{url = $failure}
                    }
                    else
                    {
                        $trueFailures += @{url = $failure}
                    }
                }

                # must have some code in the test for it to pass
                function noop {
                }

                if($passes)
                {
                    it "<url> should work" -TestCases $passes {
                        noop
                    }
                }

                if($trueFailures)
                {
                    it "<url> should work" -TestCases $trueFailures  {
                        param($url)

                        # there could be multiple reasons why a failure is ok
                        # check against the allowed failures
                        $allowedFailures = [System.Net.HttpStatusCode[]](
                            503, # Service Unavailable
                            504  # Gateway Timeout
                        )

                        $prefix = $url.Substring(0,7)

                        # Logging for diagnosability.  Azure DevOps sometimes redacts the full url.
                        Write-Verbose "prefix: '$prefix'" -Verbose
                        if($url -match '^http(s)?:')
                        {
                            # If invoke-WebRequest can handle the URL, re-verify, with 6 retries
                            try
                            {
                                $null = Invoke-WebRequest -uri $url -RetryIntervalSec 10 -MaximumRetryCount 6
                            }
                            catch [Microsoft.PowerShell.Commands.HttpResponseException]
                            {
                                if ( $allowedFailures -notcontains $_.Exception.Response.StatusCode )  {
                                    throw "Failed to complete request to `"$url`". $($_.Exception.Message)"
                                }
                            }
                        }
                        else {
                            throw "Tool reported URL as unreachable."
                        }
                    }
                }

                if($verifyFailures)
                {
                    it "<url> should work" -TestCases $verifyFailures -Pending  {
                    }
                }

                if(!$passes -and !$trueFailures -and !$verifyFailures)
                {
                    It "has no links" {
                        noop
                    }
                }
            }
        }
    }
}
