<# 
    .SYNOPSIS
        Tests for TestRunner.psm1.  Name _tests so they will not run with every resource (as it breaks the loaded module and adds time).
#>

Set-StrictMode -Version 'Latest'
$errorActionPreference = 'Stop'
$moduleName = 'TestRunner'
$TestRunnerModulePath = Join-Path -Path $PSScriptRoot -ChildPath "$moduleName.psm1"
Import-Module -Name $TestRunnerModulePath -Force

try {
    
    $moduleRootFilePath = Split-Path -Path $PSScriptRoot -Parent

    Describe 'Invoke-DscResourceTests' {
        Context -Name 'No params' -Fixture {
            Mock -CommandName 'Invoke-Pester' -MockWith { return [PSCustomObject]@{fakeTestResult=$true}} -ModuleName $moduleName
            Mock -CommandName 'Push-TestArtifact' -Verifiable -ModuleName $moduleName
            
            $results = Invoke-DscResourceTests 
            It "Should call Invoke-Pester with no path" {
                Assert-MockCalled -CommandName 'Invoke-Pester' -Times 1 -ParameterFilter {$null -eq $Script} -ModuleName $moduleName
            }
            
            It "Should call Invoke-Pest with no CodeCoverage" {
                Assert-MockCalled -CommandName 'Invoke-Pester' -Times 1 -ParameterFilter {$null -eq $CodeCoverage} -ModuleName $moduleName
            }

            It "Should call Invoke-Pest with OutputFormat='NUnitXml'" {
                Assert-MockCalled -CommandName 'Invoke-Pester' -Times 1 -ParameterFilter {'NUnitXml' -eq $OutputFormat} -ModuleName $moduleName
            }

            It "Should call Invoke-Pest with OutputFile!=null" {
                Assert-MockCalled -CommandName 'Invoke-Pester' -Times 1 -ParameterFilter {$null -ne $OutputFile} -ModuleName $moduleName
            }

            It "Should call -Verifiable mocks" {
                Assert-VerifiableMocks
            }

            It "should return test results" {
                $results.fakeTestResult | should be $true
            }
        }

        Context -Name 'Path param' -Fixture {
            Mock -CommandName 'Invoke-Pester' -MockWith { return [PSCustomObject]@{fakeTestResult=$true}} -ModuleName $moduleName
            Mock -CommandName 'Push-TestArtifact' -Verifiable -ModuleName $moduleName
            
            $resourcePath = 'C:\myResource'
            $results = Invoke-DscResourceTests -Path $resourcePath
            It "Should call Invoke-Pester with specified path" {
                Assert-MockCalled -CommandName 'Invoke-Pester' -Times 1 -ParameterFilter {$resourcePath -eq $Script} -ModuleName $moduleName
            }
            
            It "Should call Invoke-Pest with no CodeCoverage" {
                Assert-MockCalled -CommandName 'Invoke-Pester' -Times 1 -ParameterFilter {$null -eq $CodeCoverage} -ModuleName $moduleName
            }

            It "Should call Invoke-Pest with OutputFormat='NUnitXml'" {
                Assert-MockCalled -CommandName 'Invoke-Pester' -Times 1 -ParameterFilter {'NUnitXml' -eq $OutputFormat} -ModuleName $moduleName
            }

            It "Should call -Verifiable mocks" {
                Assert-VerifiableMocks
            }

            It "should return test results" {
                $results.fakeTestResult | should be $true
            }
        }

        Context -Name 'CodeCoverage param' -Fixture {
            Mock -CommandName 'Invoke-Pester' -MockWith { return [PSCustomObject]@{fakeTestResult=$true}} -ModuleName $moduleName
            Mock -CommandName 'Push-TestArtifact' -Verifiable -ModuleName $moduleName
            
            $codeCoveragePaths = @('C:\myResource\myResource.psm1','C:\myResource\myResourceHelper.psm1')
            $results = Invoke-DscResourceTests -CodeCoverage $codeCoveragePaths
            It "Should call Invoke-Pester with no path" {
                Assert-MockCalled -CommandName 'Invoke-Pester' -Times 1 -ParameterFilter {$null -eq $Script} -ModuleName $moduleName
            }
            
            It "Should call Invoke-Pest with specificed CodeCoverage" {
                Assert-MockCalled -CommandName 'Invoke-Pester' -Times 1 -ParameterFilter {!(Compare-Object -DifferenceObject $codeCoveragePaths -ReferenceObject $CodeCoverage)} -ModuleName $moduleName
            }

            It "Should call Invoke-Pest with OutputFormat='NUnitXml'" {
                Assert-MockCalled -CommandName 'Invoke-Pester' -Times 1 -ParameterFilter {'NUnitXml' -eq $OutputFormat} -ModuleName $moduleName
            }

            It "Should call -Verifiable mocks" {
                Assert-VerifiableMocks
            }

            It "should return test results" {
                $results.fakeTestResult | should be $true
            }
        }
    }
}
finally
{
    Remove-Module -Name $moduleName -Force -ErrorAction SilentlyContinue
    Import-Module -Name $TestRunnerModulePath -Force -Scope Global
}
