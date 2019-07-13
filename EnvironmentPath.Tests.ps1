using namespace System;

Remove-Module EnvironmentPath
Import-Module .\EnvironmentPath.psm1 -Force

$AllScopesOrdered = @([EnvironmentVariableTarget]::Machine, [EnvironmentVariableTarget]::User, [EnvironmentVariableTarget]::Process)

function DoAllScopeGetEnvironmentPathTest {
    $actual = @(Get-EnvironmentPath)
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

Describe "Get-EnvironmentPath tests" {
    Context "Implicit variable does not exist in any scope" {
        Mock -ModuleName EnvironmentPath getRawPath -MockWith { "" }
        Mock -ModuleName EnvironmentPath getVariableName -MockWith { "MOCK_PATH" }
        It "Throws" {
            { Get-EnvironmentPath } | Should Throw "Environment variable ""MOCK_PATH"" does not exist"
        }
    }
    Context "Implicit variable exists at Machine scope only" {
        Mock -ModuleName EnvironmentPath getRawPath -MockWith { 
            Param ($Variable, $Scope)
            if ($Scope -eq [EnvironmentVariableTarget]::Machine) {
                return "C:\"
            }
        }
        $actual = Get-EnvironmentPath
        It "Path is correct" {
            $actual.Path | Should Be "C:\"
        }
        It "Scope is correct" {
            $actual.Scope | Should Be Machine
        }
    }
    Context "Implicit variable exists at User scope only" {
        Mock -ModuleName EnvironmentPath getRawPath -MockWith { 
            Param ($Variable, $Scope)
            if ($Scope -eq [EnvironmentVariableTarget]::User) {
                return "C:\"
            }
        }
        $actual = Get-EnvironmentPath
        It "Path is correct" {
            $actual.Path | Should Be "C:\"
        }
        It "Scope is correct" {
            $actual.Scope | Should Be User
        }
    }
    Context "Implicit variable exists at Process scope only" {
        Mock -ModuleName EnvironmentPath getRawPath -MockWith { 
            Param ($Variable, $Scope)
            if ($Scope -eq [EnvironmentVariableTarget]::Process) {
                return "C:\"
            }
        }
        $actual = Get-EnvironmentPath
        It "Path is correct" {
            $actual.Path | Should Be "C:\"
        }
        It "Scope is correct" {
            $actual.Scope | Should Be Process
        }
    }
    Context "Implicit variable exists in all scopes" {
        Mock -ModuleName EnvironmentPath getRawPath -MockWith {  return "C:\" }
        DoAllScopeGetEnvironmentPathTest
    }
    Context "Implicit variable has duplicate entries" {
        Mock -ModuleName EnvironmentPath getRawPath -MockWith {  return "C:\;C:\" }
        DoAllScopeGetEnvironmentPathTest
    }

    Context "Implicit variable; hide empty paths" {
        Mock -ModuleName EnvironmentPath getRawPath -MockWith {  return @{ Machine = ";C:\;C:\"; User = "C:\;;C:\"; Process = "C:\;C:\;" }["$Scope"] }
        DoAllScopeGetEnvironmentPathTest
    }
}

function DoBasicAddEnvironmentPathTest {
    $result = Add-EnvironmentPath
    It "Nothing returned" {
        $result | Should Be $null
    }
    It "Verifiable mocks called" {
        Assert-VerifiableMocks
    }
}

Describe "Add-EnvironmentPath tests" -Tags "Add-EnvironmentPath" {
    Mock -ModuleName EnvironmentPath setRawPath { } #safety net
    Mock -ModuleName EnvironmentPath Get-Location { return @{Path = "C:\" } }
    Context "No pre-existing paths" {
        Mock -ModuleName EnvironmentPath getRawPath { return "" }
        Mock -ModuleName EnvironmentPath setRawPath { } -Verifiable -ParameterFilter { $Value -eq "C:\" -and $Scope -eq "User" }
        Mock -ModuleName EnvironmentPath setRawPath { } -Verifiable -ParameterFilter { $Value -eq "C:\" -and $Scope -eq "Process" }
        DoBasicAddEnvironmentPathTest
    }
    Context "Process contains more paths than User" {
        Mock -ModuleName EnvironmentPath getRawPath { return @{ User = "C:\foo"; Process = "C:\foo;C:\bar" }["$Scope"] }
        Mock -ModuleName EnvironmentPath setRawPath { } -Verifiable -ParameterFilter { $Value -eq "C:\foo;C:\" -and $Scope -eq "User" }
        Mock -ModuleName EnvironmentPath setRawPath { } -Verifiable -ParameterFilter { $Value -eq "C:\foo;C:\bar;C:\" -and $Scope -eq "Process" }
        DoBasicAddEnvironmentPathTest
    }
    Context "Process already contains path, User does not" {
        Mock -ModuleName EnvironmentPath getRawPath { return @{ User = "C:\foo"; Process = "C:\foo;C:\bar;C:\" }["$Scope"] }
        Mock -ModuleName EnvironmentPath setRawPath { } -Verifiable -ParameterFilter { $Value -eq "C:\foo;C:\" -and $Scope -eq "User" }
        Mock -ModuleName EnvironmentPath setRawPath { } -Verifiable -ParameterFilter { $Scope -eq "Process" }
        $result = Add-EnvironmentPath
        It "Nothing returned" {
            $result | Should Be $null
        }
        It "User path set" {
            Assert-MockCalled -ModuleName EnvironmentPath setRawPath -Times 1 -ParameterFilter { $Value -eq "C:\foo;C:\" -and $Scope -eq "User" }
        }
        It "Process path not set" {
            Assert-MockCalled -ModuleName EnvironmentPath setRawPath -Times 0 -ParameterFilter { $Scope -eq "Process" }
        }
    }
    Context "Explicit path doesn't exist" {
        It "Throws" {
            $guid = New-Guid
            { Add-EnvironmentPath "C:\$guid" } | Should Throw
        }
    }
}

Describe "Update-EnvironmentPath tests" -Tags "Update-EnvironmentPath" {
    Mock -ModuleName EnvironmentPath setRawPath { } #safety net
    Context "Process has some but not all User and Machine paths" {
        $expectedPath = "machineUnique;machineCommon;userUnique;userCommon;processUnique"
        Mock -ModuleName EnvironmentPath getRawPath { return @{ Machine = "machineUnique;machineCommon"; User = "userUnique;userCommon"; Process = "machineCommon;userCommon;processUnique" }["$Scope"] }
        Mock -ModuleName EnvironmentPath setRawPath { } -Verifiable -ParameterFilter { $Value -eq $expectedPath -and $Scope -eq "Process" }
        Mock -ModuleName EnvironmentPath setRawPath { } -Verifiable -ParameterFilter { $Scope -eq "Machine" -or $Scope -eq "User" }
        Update-EnvironmentPath | Should Be $null
        It "Process path set" {
            Assert-MockCalled -ModuleName EnvironmentPath setRawPath -Times 1 -ParameterFilter { $Value -eq $expectedPath -and $Scope -eq "Process" }
        }
        It "Neither Machine nor User paths set" {
            Assert-MockCalled -ModuleName EnvironmentPath setRawPath -Times 0 -ParameterFilter { $Scope -eq "Machine" -or $Scope -eq "User" }
        }
    }
    Context "Variable is empty in all scopes" {
        Mock -ModuleName EnvironmentPath getRawPath { return "" }
        It "Throws" {
            { Update-EnvironmentPath } | Should Throw
        }
        It "Does not call set" {
            Assert-MockCalled -ModuleName EnvironmentPath setRawPath -Times 0
        } 
    }
    Context "Variable exists in all but Machine scope" {
        Mock -ModuleName EnvironmentPath getRawPath { return @{ Machine = ""; User = "somepath"; Process = "somepath" }["$Scope"] }
        Mock -ModuleName EnvironmentPath setRawPath { } -Verifiable -ParameterFilter { $Value -eq "somepath" -and $Scope -eq "Process" }
        Mock -ModuleName EnvironmentPath setRawPath { } -Verifiable -ParameterFilter { $Scope -eq "Machine" -or $Scope -eq "User" }
        Update-EnvironmentPath
        It "Process path set" {
            Assert-MockCalled -ModuleName EnvironmentPath setRawPath -Times 1 -ParameterFilter { $Value -eq "somepath" -and $Scope -eq "Process" }
        }
        It "Neither Machine nor User paths set" {
            Assert-MockCalled -ModuleName EnvironmentPath setRawPath -Times 0 -ParameterFilter { $Scope -eq "Machine" -or $Scope -eq "User" }
        } 
    }
}