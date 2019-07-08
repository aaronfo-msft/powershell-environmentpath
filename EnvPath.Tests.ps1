using namespace System;

Remove-Module EnvPath
Import-Module .\EnvPath.psm1 -Force

$AllScopesOrdered = @([EnvironmentVariableTarget]::Machine, [EnvironmentVariableTarget]::User, [EnvironmentVariableTarget]::Process)

Describe "Get-EnvPath tests" {
    Context "Implicit variable does not exist in any scope" {
        Mock -ModuleName EnvPath getEnvironmentVariable -MockWith { "" }
        It "Throws" {
            { Get-EnvPath } | Should Throw "Exception of type 'VariableNotFoundException' was thrown."
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

Describe "Add-EnvPath tests" -Tags "Add-EnvPath" {
    Mock -ModuleName EnvPath setEnvironmentVariable { } #safety net
    Context "Implicit scope and implicit path" {
        Mock -ModuleName EnvPath Get-Location { return @{Path = "C:\" } }
        Mock -ModuleName EnvPath getEnvironmentVariable { return "" }
        Mock -ModuleName EnvPath setEnvironmentVariable { } -Verifiable -ParameterFilter { $Value -eq "C:\" -and $Scope -eq "User" }
        Mock -ModuleName EnvPath setEnvironmentVariable { } -Verifiable -ParameterFilter { $Value -eq "C:\" -and $Scope -eq "Process" }
        $result = Add-EnvPath
        It "Nothing returned" {
            $result | Should Be $null
        }
        It "Verifiable mocks called" {
            Assert-VerifiableMocks
        }
    }
}