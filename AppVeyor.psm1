<#
    .SYNOPSIS
        This module provides functions for building and testing DSC Resources in AppVeyor.

        These functions will only work if called within an AppVeyor CI build task.
#>

$customTasksModulePath = Join-Path -Path $env:APPVEYOR_BUILD_FOLDER `
                                   -ChildPath '.AppVeyor\CustomAppVeyorTasks.psm1'
if (Test-Path -Path $customTasksModulePath)
{
    Import-Module -Name $customTasksModulePath
    $customTaskModuleLoaded = $true
}
else
{
    $customTaskModuleLoaded = $false
}

<#
    .SYNOPSIS
        Prepares the AppVeyor build environment to perform tests and packaging on a
        DSC Resource module.

        Performs the following tasks:
        1. Installs Nuget Package Provider DLL.
        2. Installs Nuget.exe to the AppVeyor Build Folder.
        3. Installs the Pester PowerShell Module.
        4. Executes Start-CustomAppveyorInstallTask if defined in .AppVeyor\CustomAppVeyorTasks.psm1
           in resource module repository.
#>
function Start-AppveyorInstallTask
{
    [CmdletBinding(DefaultParametersetName='Default')]
    param
    (
    )

    # Load the test helper module
    $testHelperPath = Join-Path -Path $PSScriptRoot `
                                -ChildPath 'TestHelper.psm1'
    Import-Module -Name $testHelperPath -Force

    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force

    # Install Nuget.exe to enable package creation
    $nugetExePath = Join-Path -Path $env:APPVEYOR_BUILD_FOLDER `
                              -ChildPath 'nuget.exe'
    Install-NugetExe -OutFile $nugetExePath

    Install-Module -Name Pester -Force

    # Execute the custom install task if defined
    if ($customTaskModuleLoaded `
        -and (Get-Command -Module $CustomAppVeyorTasks `
                          -Name Start-CustomAppveyorInstallTask `
                          -ErrorAction SilentlyContinue))
    {
        Start-CustomAppveyorInstallTask
    }
}

<#
    .SYNOPSIS
        Executes the tests on a DSC Resource in the AppVeyor build environment.

        Executes Start-CustomAppveyorTestTask if defined in .AppVeyor\CustomAppVeyorTasks.psm1
        in resource module repository.

    .PARAMETER Type
        This controls the method of running the tests.
        To use execute tests using a test harness function specify 'Harness', otherwise
        leave empty to use default value 'Default'.

    .PARAMETER MainModulePath
        This is the relative path of the folder that contains the module manifest.
        If not specified it will default to the root folder of the repository.

    .PARAMETER HarnessModulePath
        This is the full path and filename of the test harness module.

    .PARAMETER HarnessFunctionName
        This is the function name in the harness module to call to execute tests.
#>
function Start-AppveyorTestScriptTask
{
    [CmdletBinding(DefaultParametersetName = 'Default')]
    param
    (
        [ValidateSet('Default','Harness')]
        [String]
        $Type = 'Default',

        [ValidateNotNullOrEmpty()]
        [String]
        $MainModulePath = $env:APPVEYOR_BUILD_FOLDER,

        [Parameter(ParameterSetName = 'Harness',
                   Mandatory = $true)]
        [String]
        $HarnessModulePath,

        [Parameter(ParameterSetName = 'Harness',
                   Mandatory = $true)]
        [String]
        $HarnessFunctionName
    )

    # Convert the Main Module path into an absolute path if it is relative
    if (-not ([System.IO.Path]::IsPathRooted($MainModulePath)))
    {
        $MainModulePath = Join-Path -Path $env:APPVEYOR_BUILD_FOLDER `
                                    -ChildPath $MainModulePath
    }

    $testResultsFile = Join-Path -Path $env:APPVEYOR_BUILD_FOLDER `
                                 -ChildPath 'TestsResults.xml'

    switch ($PsCmdlet.ParameterSetName)
    {
        'Default'
        {
            # Execute the standard tests using Pester.
            $result = Invoke-Pester -OutputFormat NUnitXml `
                                    -OutputFile $testResultsFile `
                                    -PassThru
            break
        }
        'Harness'
        {
            # Copy the DSCResource.Tests folder into the folder containing the resource PSD1 file.
            $dscTestsPath = Join-Path -Path $MainModulePath `
                                      -ChildPath 'DSCResource.Tests'
            Copy-Item -Path $PSScriptRoot -Destination $MainModulePath -Recurse
            $testHarnessPath = Join-Path -Path $env:APPVEYOR_BUILD_FOLDER `
                                         -ChildPath $HarnessModulePath

            # Execute the resource tests as well as the DSCResource.Tests\meta.tests.ps1
            Import-Module -Name $testHarnessPath
            $result = & $HarnessFunctionName -TestResultsFile $testResultsFile `
                                             -DscTestsPath $dscTestsPath

            # Delete the DSCResource.Tests folder because it is not needed
            Remove-Item -Path $dscTestsPath -Force -Recurse
            break
        }
    }

    # Execute custom test task if defined
    if ($customTaskModuleLoaded `
        -and (Get-Command -Module $CustomAppVeyorTasks `
                          -Name Start-CustomAppveyorTestTask `
                          -ErrorAction SilentlyContinue))
    {
        Start-CustomAppveyorTestTask
    }

    $webClient = New-Object -TypeName "System.Net.WebClient"
    $webClient.UploadFile("https://ci.appveyor.com/api/testresults/nunit/$($env:APPVEYOR_JOB_ID)",
                          $testResultsFile)

    if ($result.FailedCount -gt 0)
    {
        throw "$($result.FailedCount) tests failed."
    }
}

<#
    .SYNOPSIS
        Performs the after tests tasks for the AppVeyor build process.

        This includes:
        1. Optional: Produce and upload Wiki documentation to AppVeyor.
        2. Set version number in Module Manifest to build version
        3. Zip up the module content and produce a checksum file and upload to AppVeyor.
        4. Pack the module into a Nuget Package.
        5. Upload the Nuget Package to AppVeyor.

        Executes Start-CustomAppveyorAfterTestTask if defined in .AppVeyor\CustomAppVeyorTasks.psm1
        in resource module repository.

    .PARAMETER Type
        This controls the additional processes that can be run after testing.
        To produce wiki documentation specify 'Wiki', otherwise leave empty to use
        default value 'Default'.

    .PARAMETER MainModulePath
        This is the relative path of the folder that contains the module manifest.
        If not specified it will default to the root folder of the repository.

    .PARAMETER ResourceModuleName
        Name of the Resource Module being produced.
        If not specified will default to GitHub repository name.

    .PARAMETER Author
        The Author string to insert into the NUSPEC file for the package.
        If not specified will default to 'Microsoft'.

    .PARAMETER Owners
        The Owners string to insert into the NUSPEC file for the package.
        If not specified will default to 'Microsoft'.
#>
function Start-AppveyorAfterTestTask
{

    [CmdletBinding(DefaultParametersetName = 'Default')]
    param
    (
        [ValidateSet('Default','Wiki')]
        [String]
        $Type = 'Default',

        [ValidateNotNullOrEmpty()]
        [String]
        $MainModulePath = $env:APPVEYOR_BUILD_FOLDER,

        [String]
        $ResourceModuleName = (($env:APPVEYOR_REPO_NAME -split '/')[1]),

        [String]
        $Author = 'Microsoft',

        [String]
        $Owners = 'Microsoft'
    )

    # Convert the Main Module path into an absolute path if it is relative
    if (-not ([System.IO.Path]::IsPathRooted($MainModulePath)))
    {
        $MainModulePath = Join-Path -Path $env:APPVEYOR_BUILD_FOLDER `
                                    -ChildPath $MainModulePath
    }

    # Import so we can create zip files
    Add-Type -assemblyname System.IO.Compression.FileSystem

    if ($PsCmdlet.ParameterSetName -eq 'Wiki')
    {
        # Write the PowerShell help files
        $docoPath = Join-Path -Path $MainModuleFolder `
                              -ChildPath 'en-US'
        New-Item -Path $docoPath -ItemType Directory

        # Clone the DSCResources Module to the repository folder
        Start-Process -Wait -FilePath "git" -ArgumentList @(
            "clone",
            "-q",
            "https://github.com/PowerShell/DscResources",
            (Join-Path -Path $env:APPVEYOR_BUILD_FOLDER -ChildPath "DscResources")
        )

        $docoHelperPath = Join-Path -Path $env:APPVEYOR_BUILD_FOLDER `
                                    -ChildPath "DscResources\DscResource.DocumentationHelper"
        Import-Module -Name $docoHelperPath
        Write-DscResourcePowerShellHelp -OutputPath $docoPath -ModulePath $MainModulePath -Verbose

        # Generate the wiki content for the release and zip/publish it to appveyor
        $wikiContentPath = Join-Path -Path $env:APPVEYOR_BUILD_FOLDER -ChildPath "wikicontent"
        New-Item -Path $wikiContentPath -ItemType Directory
        Write-DscResourceWikiSite -OutputPath $wikiContentPath -ModulePath $MainModulePath -Verbose

        $zipFileName = Join-Path -Path $env:APPVEYOR_BUILD_FOLDER `
                                 -ChildPath "$($ResourceModuleName)_$($env:APPVEYOR_BUILD_VERSION)_wikicontent.zip"
        [System.IO.Compression.ZipFile]::CreateFromDirectory($wikiContentPath,$zipFileName)
        Get-ChildItem -Path $zipFileName | ForEach-Object -Process {
            Push-AppveyorArtifact $_.FullName -FileName $_.Name
        }

        # Remove the readme files that are used to generate documentation so they aren't shipped
        $readmePaths = Join-Path -Path $MainModuleFolder `
                                 -ChildPath '**\readme.md'
        Get-ChildItem -Path $readmePaths -Recurse | Remove-Item -Confirm:$false
    }

    # Set the Module Version in the Manifest to the AppVeyor build version
    $manifestPath = Join-Path -Path $MainModulePath `
                              -ChildPath "$ResourceModuleName.psd1"
    $manifestContent = Get-Content -Path $ManifestPath -Raw
    $regex = '(?<=ModuleVersion\s+=\s+'')(?<ModuleVersion>.*)(?='')'
    $manifestContent = $manifestContent -replace $regex,"ModuleVersion = '$env:APPVEYOR_BUILD_VERSION'"
    Set-Content -Path $manifestPath -Value $manifestContent -Force

    # Zip and Publish the Main Module Folder content
    $zipFileName = Join-Path -Path $env:APPVEYOR_BUILD_FOLDER `
                             -ChildPath "$($ResourceModuleName)_$($env:APPVEYOR_BUILD_VERSION).zip"
    [System.IO.Compression.ZipFile]::CreateFromDirectory($MainModulePath, $zipFileName)
    New-DscChecksum -Path $env:APPVEYOR_BUILD_FOLDER -Outpath $env:APPVEYOR_BUILD_FOLDER
    Get-ChildItem -Path $zipFileName | ForEach-Object -Process {
        Push-AppveyorArtifact $_.FullName -FileName $_.Name
    }
    Get-ChildItem -Path "$zipFileName.checksum" | ForEach-Object -Process {
        Push-AppveyorArtifact $_.FullName -FileName $_.Name
    }

    Push-Location
    Set-Location -Path $MainModulePath

    # Create the Nuspec file for the Nuget Package in the Main Module Folder
    $nuspecPath = Join-Path -Path $MainModulePath `
                            -ChildPath "$ResourceModuleName.nuspec"
    $nuspecParams = @{
        packageName = $ResourceModuleName
        destinationPath = $nuspecPath
        version = $env:APPVEYOR_BUILD_VERSION
        author = $Author
        owners = $Owners
        licenseUrl = "https://github.com/PowerShell/DscResources/blob/master/LICENSE"
        projectUrl = "https://github.com/$($env:APPVEYOR_REPO_NAME)"
        packageDescription = $ResourceModuleName
        tags = "DesiredStateConfiguration DSC DSCResourceKit"
    }
    New-Nuspec @nuspecParams

    # Create the Nuget Package
    $nugetExePath = Join-Path -Path $env:APPVEYOR_BUILD_FOLDER `
                              -ChildPath 'nuget.exe'
    Start-Process -FilePath $nugetExePath -Wait -ArgumentList @(
        "pack",
        $nuspecPath,
        "-outputdirectory $env:APPVEYOR_BUILD_FOLDER"
    )
    Write-Verbose -Verbose -Message ((Get-ChildItem -Path $env:APPVEYOR_BUILD_FOLDER) | Out-String)
    # Push the Nuget Package up to AppVeyor
    $nugetPackageName = Join-Path -Path $env:APPVEYOR_BUILD_FOLDER `
                                  -ChildPath "$ResourceModuleName.$($env:APPVEYOR_BUILD_VERSION).nupkg"
    Get-ChildItem $nugetPackageName | ForEach-Object -Process {
        Push-AppveyorArtifact $_.FullName -FileName $_.Name
    }

    Pop-Location

    # Execute custom after test task if defined
    if ($customTaskModuleLoaded `
        -and (Get-Command -Module $CustomAppVeyorTasks `
                          -Name Start-CustomAppveyorAfterTestTask `
                          -ErrorAction SilentlyContinue))
    {
        Start-CustomAppveyorAfterTestTask
    }
}

Export-ModuleMember -Function *
