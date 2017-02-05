<# 
    .SYNOPSIS
        Common tests for all resource modules in the DSC Resource Kit.
#>

Set-StrictMode -Version 'Latest'
$errorActionPreference = 'Stop'

$TestRunnerModulePath = Join-Path -Path $PSScriptRoot -ChildPath 'TestRunner.psm1'
Import-Module -Name $TestRunnerModulePath -Force

$moduleRootFilePath = Split-Path -Path $PSScriptRoot -Parent

Describe 'Invoke-DscResourceTests' {
    InModuleScope -ModuleName 'TestRunner' -ScriptBlock {

        Context -Name 'No params' -Fixture {
            Mock -CommandName 'Invoke-Pester' -MockWith { return [PSCustomObject]@{fakeTestResult=$true}}
            Mock -CommandName 'Push-TestArtifact' -Verifiable
            
            $results = Invoke-DscResourceTests 
            It "Should call Invoke-Pester with no path" {
                Assert-MockCalled -CommandName 'Invoke-Pester' -Times 1 -ParameterFilter {$null -eq $Path}
            }
            
            It "Should call Invoke-Pest with no CodeCoverage" {
                Assert-MockCalled -CommandName 'Invoke-Pester' -Times 1 -ParameterFilter {$null -eq $CodeCoverage}
            }

            It "Should call Invoke-Pest with OutputFormat='NUnitXml'" {
                Assert-MockCalled -CommandName 'Invoke-Pester' -Times 1 -ParameterFilter {'NUnitXml' -eq $OutputFormat}
            }

            It "Should call Invoke-Pest with OutputFile!=null" {
                Assert-MockCalled -CommandName 'Invoke-Pester' -Times 1 -ParameterFilter {$null -ne $OutputFile}
            }

            It "Should call -Verifiable mocks" {
                Assert-VerifiableMocks
            }

            It "should return test results" {
                $results.fakeTestResult | should be $true
            }
        }

        Context -Name 'Path param' -Fixture {
            Mock -CommandName 'Invoke-Pester' -MockWith { return [PSCustomObject]@{fakeTestResult=$true}}
            Mock -CommandName 'Push-TestArtifact' -Verifiable
            
            $resourcePath = 'C:\myResource'
            $results = Invoke-DscResourceTests -Path $resourcePath
            It "Should call Invoke-Pester with specified path" {
                Assert-MockCalled -CommandName 'Invoke-Pester' -Times 1 -ParameterFilter {$resourcePath -eq $Script}
            }
            
            It "Should call Invoke-Pest with no CodeCoverage" {
                Assert-MockCalled -CommandName 'Invoke-Pester' -Times 1 -ParameterFilter {$null -eq $CodeCoverage}
            }

            It "Should call Invoke-Pest with OutputFormat='NUnitXml'" {
                Assert-MockCalled -CommandName 'Invoke-Pester' -Times 1 -ParameterFilter {'NUnitXml' -eq $OutputFormat}
            }

            It "Should call -Verifiable mocks" {
                Assert-VerifiableMocks
            }

            It "should return test results" {
                $results.fakeTestResult | should be $true
            }
        }

        Context -Name 'CodeCoverage param' -Fixture {
            Mock -CommandName 'Invoke-Pester' -MockWith { return [PSCustomObject]@{fakeTestResult=$true}}
            Mock -CommandName 'Push-TestArtifact' -Verifiable
            
            $codeCoveragePaths = @('C:\myResource\myResource.psm1','C:\myResource\myResourceHelper.psm1')
            $results = Invoke-DscResourceTests -CodeCoverage $codeCoveragePaths
            It "Should call Invoke-Pester with no path" {
                Assert-MockCalled -CommandName 'Invoke-Pester' -Times 1 -ParameterFilter {$null -eq $Path}
            }
            
            It "Should call Invoke-Pest with specificed CodeCoverage" {
                Assert-MockCalled -CommandName 'Invoke-Pester' -Times 1 -ParameterFilter {!(Compare-Object -DifferenceObject $codeCoveragePaths -ReferenceObject $CodeCoverage)}
            }

            It "Should call Invoke-Pest with OutputFormat='NUnitXml'" {
                Assert-MockCalled -CommandName 'Invoke-Pester' -Times 1 -ParameterFilter {'NUnitXml' -eq $OutputFormat}
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


