using namespace System;

#Safety net
[string]$PathEnvironmentVariable = if ($Host.Name -eq "Visual Studio Code Host") { "TEST_PATH" } else { "PATH" }

class VariableNotFoundException : Exception {
    VariableNotFoundException([string]$message) : base($message) { }
}

function Add-EnvPath() {
    [CmdletBinding(
        SupportsShouldProcess = $true,
        ConfirmImpact = 'Low')]
    Param (
        [Parameter(Position = 0)]
        [ValidateScript( { Test-Path $_ })]
        [string] $Path = (Get-Location).Path
    )

    try {
        $userCurrent = (getEnvironmentVariable -scope User).TrimEnd(";") + ";"
        $processCurrent = (getEnvironmentVariable -scope Process).TrimEnd(";") + ";"
    }
    catch { }

    if (($userCurrent -split ";").Contains($Path)) {
        throw "The current environment path already contains '" + $Path + "'"
    }

    if (!$PSCmdlet.ShouldProcess($Path)) {
        return
    }

    setEnvironmentVariable ($userCurrent + $Path).trim(";") User

    if (!(($processCurrent -split ";").Contains($Path))) {
        setEnvironmentVariable ($processCurrent + $Path).trim(";") Process
    }
} 

function Get-EnvPath {
    $allScopes = @([EnvironmentVariableTarget]::Machine, [EnvironmentVariableTarget]::User, [EnvironmentVariableTarget]::Process)
    $exceptionCount = 0
    $resultsHash = [ordered]@{ }
    $allScopes | ForEach-Object {
        try {
            $scope = $_
            getPathArray -scope $scope | ForEach-Object {
                if (!$_) {
                    return
                }

                if (!($resultsHash[$_])) {
                    $resultsHash[$_] = [ordered]@{ }
                }

                ($resultsHash[$_])[$scope] = $true
            }
        }
        catch [VariableNotFoundException] {
            $exceptionCount++
            if (!$firstException) {
                $firstException = $_
            }
        }
    }
    
    if ($exceptionCount -eq $allScopes.Count) {
        throw $firstException
    }
    
    $resultsHash.Keys | ForEach-Object { New-Object psobject -Property @{Path = $_; Scope = @($resultsHash[$_].Keys) } }
}

function Update-EnvPath {
    Param (
        [string] $EnvironmentVariable = $DefaultEnvironmentVariable
    )

    $machine = getTrimmedPath -scope Machine
    $user = getTrimmedPath -scope User
    $process = getTrimmedPath -scope Process
    $newpath = ($machine + ';' + $user + ';' + $process).trim(';');
    setEnvironmentVariable $EnvironmentVariable $newpath [EnvironmentVariableTarget]::Process
    Set-Item -Path Env:$EnvironmentVariable -Value $newpath
}

function getTrimmedPath {
    Param ([Parameter(Mandatory = $true)][EnvironmentVariableTarget]$scope)
    (getVariable -scope $scope).trim(";")
}

function getPathArray {
    Param ([Parameter(Mandatory = $true)][EnvironmentVariableTarget]$scope)
    (getTrimmedPath -scope $scope) -split ';' 
}

function getVariable {
    Param ([Parameter(Mandatory = $true)][EnvironmentVariableTarget]$scope)

    $var = getEnvironmentVariable $scope
    if (!$var) {
        throw [VariableNotFoundException]::new("Environment variable ""$envvar"" does not exist")
    }
    $var
}

function setEnvironmentVariable {
    Param(
        [string]$Value,
        [EnvironmentVariableTarget]$Scope
    )
    [Environment]::SetEnvironmentVariable($PathEnvironmentVariable, $Value, $Scope)
}

function getEnvironmentVariable {
    Param([EnvironmentVariableTarget]$Scope)
    [Environment]::GetEnvironmentVariable($PathEnvironmentVariable, $Scope)
}

Export-ModuleMember -Function Add-EnvPath, Get-EnvPath
