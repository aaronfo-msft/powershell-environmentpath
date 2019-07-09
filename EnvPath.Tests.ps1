using namespace System;

Remove-Module EnvPath
Import-Module .\EnvPath.psm1 -Force

$AllScopesOrdered = @([EnvironmentVariableTarget]::Machine, [EnvironmentVariableTarget]::User, [EnvironmentVariableTarget]::Process)

Describe "Get-EnvPath tests" {
    Context "Implicit variable does not exist in any scope" {
        Mock -ModuleName EnvPath getEnvironmentVariable -MockWith { "" }
        It "Throws" {
            { Get-EnvPath } | Should Throw "does not exist"
        }
    }
    Context "Implicit variable exists at Machine scope only" {
        Mock -ModuleName EnvPath getEnvironmentVariable -MockWith { 
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
        Mock -ModuleName EnvPath getEnvironmentVariable -MockWith { 
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
        Mock -ModuleName EnvPath getEnvironmentVariable -MockWith { 
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
        Mock -ModuleName EnvPath getEnvironmentVariable -MockWith { 
            return "C:\"
        }
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
    Context "Implicit variable has duplicate entries" {
        Mock -ModuleName EnvPath getEnvironmentVariable -MockWith { 
            return "C:\;C:\"
        }
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
    Context "Implicit variable; hide empty paths" {
        Mock -ModuleName EnvPath getEnvironmentVariable -MockWith { 
            Param ($Variable, $Scope)
            return @{ Machine = ";C:\;C:\"; User = "C:\;;C:\"; Process = "C:\;C:\;" }["$Scope"]
        }
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

Describe "Add-EnvPath tests, Implicit scope and implicit path" -Tags "Add-EnvPath" {
    Mock -ModuleName EnvPath setEnvironmentVariable { } #safety net
    Mock -ModuleName EnvPath Get-Location { return @{Path = "C:\" } }
    Context "No pre-existing paths" {
        Mock -ModuleName EnvPath getEnvironmentVariable { return "" }
        Mock -ModuleName EnvPath setEnvironmentVariable { } -Verifiable -ParameterFilter { $Value -eq "C:\" -and $Scope -eq "User" }
        Mock -ModuleName EnvPath setEnvironmentVariable { } -Verifiable -ParameterFilter { $Value -eq "C:\" -and $Scope -eq "Process" }
        DoBasicAddEnvPathTest
    }
    Context "Process contains more paths than User" {
        Mock -ModuleName EnvPath getEnvironmentVariable { return @{ User = "C:\foo"; Process = "C:\foo;C:\bar" }["$Scope"] }
        Mock -ModuleName EnvPath setEnvironmentVariable { } -Verifiable -ParameterFilter { $Value -eq "C:\foo;C:\" -and $Scope -eq "User" }
        Mock -ModuleName EnvPath setEnvironmentVariable { } -Verifiable -ParameterFilter { $Value -eq "C:\foo;C:\bar;C:\" -and $Scope -eq "Process" }
        DoBasicAddEnvPathTest
    }
    Context "Process already contains path, User does not" {
        Mock -ModuleName EnvPath getEnvironmentVariable { return @{ User = "C:\foo"; Process = "C:\foo;C:\bar;C:\" }["$Scope"] }
        Mock -ModuleName EnvPath setEnvironmentVariable { } -Verifiable -ParameterFilter { $Value -eq "C:\foo;C:\" -and $Scope -eq "User" }
        Mock -ModuleName EnvPath setEnvironmentVariable { } -Verifiable -ParameterFilter { $Scope -eq "Process" }
        $result = Add-EnvPath
        It "Nothing returned" {
            $result | Should Be $null
        }
        It "User path set" {
            Assert-MockCalled -ModuleName EnvPath setEnvironmentVariable -Times 1 -ParameterFilter { $Value -eq "C:\foo;C:\" -and $Scope -eq "User" }
        }
        It "Process path not set" {
            Assert-MockCalled -ModuleName EnvPath setEnvironmentVariable -Times 0 -ParameterFilter { $Scope -eq "Process" }
        }
    }
}