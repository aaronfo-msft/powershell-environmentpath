using namespace System;

Remove-Module EnvPath
Import-Module .\EnvPath.psm1 -Force

$AllScopesOrdered = @([EnvironmentVariableTarget]::Machine, [EnvironmentVariableTarget]::User, [EnvironmentVariableTarget]::Process)

function DoAllScopeGetEnvPathTest {
    $actual = @(Get-EnvPath)
    It "Result has only one element" {
        $actual.Count | Should Be 1
    }
    It "Path is correct" {
        $actual[0].Path | Should Be "C:\"
    }
    It "Scope has three elements" {
        $actual[0].Scope.Count | Should Be 3
    }
    for ($i = 0; $i -lt 3; $i++) {
        $scopeToCheck = $AllScopesOrdered[$i]
        It "Scope contains $scopeToCheck" {
            $actual[0].Scope[$i] | Should Be $scopeToCheck
        }
    }
}

Describe "Get-EnvPath tests" {
    Context "Implicit variable does not exist in any scope" {
        Mock -ModuleName EnvPath getRawPath -MockWith { "" }
        It "Throws" {
            { Get-EnvPath } | Should Throw "does not exist"
        }
    }
    Context "Implicit variable exists at Machine scope only" {
        Mock -ModuleName EnvPath getRawPath -MockWith { 
            Param ($Variable, $Scope)
            if ($Scope -eq [EnvironmentVariableTarget]::Machine) {
                return "C:\"
            }
        }
        $actual = Get-EnvPath
        It "Path is correct" {
            $actual.Path | Should Be "C:\"
        }
        It "Scope is correct" {
            $actual.Scope | Should Be Machine
        }
    }
    Context "Implicit variable exists at User scope only" {
        Mock -ModuleName EnvPath getRawPath -MockWith { 
            Param ($Variable, $Scope)
            if ($Scope -eq [EnvironmentVariableTarget]::User) {
                return "C:\"
            }
        }
        $actual = Get-EnvPath
        It "Path is correct" {
            $actual.Path | Should Be "C:\"
        }
        It "Scope is correct" {
            $actual.Scope | Should Be User
        }
    }
    Context "Implicit variable exists at Process scope only" {
        Mock -ModuleName EnvPath getRawPath -MockWith { 
            Param ($Variable, $Scope)
            if ($Scope -eq [EnvironmentVariableTarget]::Process) {
                return "C:\"
            }
        }
        $actual = Get-EnvPath
        It "Path is correct" {
            $actual.Path | Should Be "C:\"
        }
        It "Scope is correct" {
            $actual.Scope | Should Be Process
        }
    }
    Context "Implicit variable exists in all scopes" {
        Mock -ModuleName EnvPath getRawPath -MockWith {  return "C:\" }
        DoAllScopeGetEnvPathTest
    }
    Context "Implicit variable has duplicate entries" {
        Mock -ModuleName EnvPath getRawPath -MockWith {  return "C:\;C:\" }
        DoAllScopeGetEnvPathTest
    }

    Context "Implicit variable; hide empty paths" {
        Mock -ModuleName EnvPath getRawPath -MockWith {  return @{ Machine = ";C:\;C:\"; User = "C:\;;C:\"; Process = "C:\;C:\;" }["$Scope"] }
        DoAllScopeGetEnvPathTest
    }
}

function DoBasicAddEnvPathTest {
    $result = Add-EnvPath
    It "Nothing returned" {
        $result | Should Be $null
    }
    It "Verifiable mocks called" {
        Assert-VerifiableMocks
    }
}

Describe "Add-EnvPath tests" -Tags "Add-EnvPath" {
    Mock -ModuleName EnvPath setRawPath { } #safety net
    Mock -ModuleName EnvPath Get-Location { return @{Path = "C:\" } }
    Context "No pre-existing paths" {
        Mock -ModuleName EnvPath getRawPath { return "" }
        Mock -ModuleName EnvPath setRawPath { } -Verifiable -ParameterFilter { $Value -eq "C:\" -and $Scope -eq "User" }
        Mock -ModuleName EnvPath setRawPath { } -Verifiable -ParameterFilter { $Value -eq "C:\" -and $Scope -eq "Process" }
        DoBasicAddEnvPathTest
    }
    Context "Process contains more paths than User" {
        Mock -ModuleName EnvPath getRawPath { return @{ User = "C:\foo"; Process = "C:\foo;C:\bar" }["$Scope"] }
        Mock -ModuleName EnvPath setRawPath { } -Verifiable -ParameterFilter { $Value -eq "C:\foo;C:\" -and $Scope -eq "User" }
        Mock -ModuleName EnvPath setRawPath { } -Verifiable -ParameterFilter { $Value -eq "C:\foo;C:\bar;C:\" -and $Scope -eq "Process" }
        DoBasicAddEnvPathTest
    }
    Context "Process already contains path, User does not" {
        Mock -ModuleName EnvPath getRawPath { return @{ User = "C:\foo"; Process = "C:\foo;C:\bar;C:\" }["$Scope"] }
        Mock -ModuleName EnvPath setRawPath { } -Verifiable -ParameterFilter { $Value -eq "C:\foo;C:\" -and $Scope -eq "User" }
        Mock -ModuleName EnvPath setRawPath { } -Verifiable -ParameterFilter { $Scope -eq "Process" }
        $result = Add-EnvPath
        It "Nothing returned" {
            $result | Should Be $null
        }
        It "User path set" {
            Assert-MockCalled -ModuleName EnvPath setRawPath -Times 1 -ParameterFilter { $Value -eq "C:\foo;C:\" -and $Scope -eq "User" }
        }
        It "Process path not set" {
            Assert-MockCalled -ModuleName EnvPath setRawPath -Times 0 -ParameterFilter { $Scope -eq "Process" }
        }
    }
    Context "Explicit path doesn't exist" {
        It "Throws" {
            $guid = New-Guid
            { Add-EnvPath "C:\$guid" } | Should Throw
        }
    }
}

Describe "Update-EnvPath tests" -Tags "Update-EnvPath" {
    Mock -ModuleName EnvPath setRawPath { } #safety net
    Context "Process has some but not all User and Machine paths" {
        $expectedPath = "machineUnique;machineCommon;userUnique;userCommon;processUnique"
        Mock -ModuleName EnvPath getRawPath { return @{ Machine = "machineUnique;machineCommon"; User = "userUnique;userCommon"; Process = "machineCommon;userCommon;processUnique" }["$Scope"] }
        Mock -ModuleName EnvPath setRawPath { } -Verifiable -ParameterFilter { $Value -eq $expectedPath -and $Scope -eq "Process" }
        Mock -ModuleName EnvPath setRawPath { } -Verifiable -ParameterFilter { $Scope -eq "Machine" -or $Scope -eq "User" }
        Update-EnvPath | Should Be $null
        It "Process path set" {
            Assert-MockCalled -ModuleName EnvPath setRawPath -Times 1 -ParameterFilter { $Value -eq $expectedPath -and $Scope -eq "Process" }
        }
        It "Neither Machine nor User paths set" {
            Assert-MockCalled -ModuleName EnvPath setRawPath -Times 0 -ParameterFilter { $Scope -eq "Machine" -or $Scope -eq "User" }
        }
    }
}