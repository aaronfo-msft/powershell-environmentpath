using namespace System;

Remove-Module EnvPath
Import-Module .\EnvPath.psm1 -Force

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
}