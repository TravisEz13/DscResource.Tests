<#
    .SYNOPSIS
        Runs all tests (including common tests) on all DSC resources in the given folder.

    .PARAMETER ResourcesPath
        The path to the folder containing the resources to be tested.

    .EXAMPLE
        Start-DscResourceTests -ResourcesPath C:\DscResources\DscResources
#>
function Start-DscResourceTests
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [String]
        $ResourcesPath
    )
    
    $testsPath = $pwd
    Push-Location -Path $ResourcesPath

    Get-ChildItem | ForEach-Object {
        $moduleName = $_.Name
        $destinationPath = Join-Path -Path $ResourcesPath -ChildPath $moduleName

        Write-Verbose -Message "Copying common tests from $testsPath to $destinationPath"
        Copy-Item -Path $testsPath -Destination $destinationPath -Recurse -Force 

        Push-Location -Path $moduleName
        
        Write-Verbose "Running tests for $moduleName"
        Invoke-Pester

        Pop-Location
    }

    Pop-Location
}

<#
    .SYNOPSIS
        Runs Pester tests and reports results

    .PARAMETER Path
        The Path to the tests to run

    .PARAMETER CodeCoverage
        An array of paths to files to run CodeCoverage for.

    .EXAMPLE
        Invoke-DscResourceTests -Path C:\myModule\tests -CodeCoverage @('C:\myModule\myModule.psm1')

#>
function Invoke-DscResourceTests {
    [CmdletBinding()]
    param
    (
        [CmdletBinding()]
        [string]
        $Path, 
        
        [Object[]] 
        $CodeCoverage
    )

    Write-Info "Running tests: $Path"
    $testResultPath = 'TestsResults.xml'
    
    $results = Invoke-Pester -OutputFormat NUnitXml -OutputFile $testResultPath -PassThru @PSBoundParameters

    if(${env:APPVEYOR_JOB_ID})
    {
        foreach($result in $results.TestResult)
        {
            [string] $describeName = $result.Describe -replace '\\', '/'
            [string] $contextName = $result.Context -replace '\\', '/'
            $componentName = '{0}; Context: {1}' -f $describeName, $contextName

            #Write-Info ('Adding test result {0} - {1}, Outcome: {2}, Duration {3}' -f $componentName, $result.Name, $result.Result, $result.Time.TotalMilliseconds)
            Add-AppveyorTest -Name $result.Name -Framework NUnit -Filename $componentName -Outcome $result.Result -Duration $result.Time.TotalMilliseconds
        }
    }
    else {
        Write-Info 'Not in AppVeyor.  Skipping uploading test results.'
    }


    Push-TestArtifact -Path $testResultPath

    Write-Info 'Done running tests.'
    Write-Info "Test result Type: $($results.gettype().fullname)"
    
    if ($results.FailedCount -gt 0) 
    { 
                throw "$($results.FailedCount) tests failed."    
    }

    return $results
}

<#
    .SYNOPSIS
        Writes information to the build log

    .PARAMETER Message
        The Message to write

    .EXAMPLE
        Write-Info -Message "Some build info"

#>
function Write-Info {
    [CmdletBinding()]
     param
     (
         [Parameter(Mandatory=$true, Position=0)]
         [string]
         $Message
     )

    Write-Host -ForegroundColor Yellow  "[Build Info] [$([datetime]::UtcNow)] $message"
}

<#
    .SYNOPSIS
        Uploads test artifacts

    .PARAMETER Path
        The path to the test artifacts

    .EXAMPLE
        Push-TestArtifact -Path .\TestArtifact.log

#>
function Push-TestArtifact
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true, Position=0)]
        [string]
        $Path
    )    

    $resolvedPath = (Resolve-Path $Path).ProviderPath
    if(${env:APPVEYOR_JOB_ID})
    {
        <# does not work with Pester 4.0.2
        $url = "https://ci.appveyor.com/api/testresults/nunit/$($env:APPVEYOR_JOB_ID)"
        Write-Info -Message "Uploading Test Results: $resolvedPath ; to: $url"
        (New-Object 'System.Net.WebClient').UploadFile($url, $resolvedPath)
        #>

        Write-Info -Message "Uploading Test Artifact: $resolvedPath"
        Push-AppveyorArtifact $resolvedPath
    }
    else
    {
        Write-Info -Message "Test Artifact: $resolvedPath"
    }
}

Export-ModuleMember -Function @( 'Start-DscResourceTests','Invoke-DscResourceTests' )
