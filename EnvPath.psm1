using namespace System;

class VariableNotFoundException : Exception { }

function Add-EnvPath() {
    [CmdletBinding(
        SupportsShouldProcess = $true,
        ConfirmImpact = 'Low')]
    Param (
        [Parameter(Position = 0)]
        [ValidateScript( { Test-Path $_ } )]
        [string] $Path = (Get-Location).Path
    )

    try {
        $userCurrent = (getRawPath -scope User).TrimEnd(";") + ";"
        $processCurrent = (getRawPath -scope Process).TrimEnd(";") + ";"
    }
    catch { }

    if (($userCurrent -split ";").Contains($Path)) {
        throw "The current environment path already contains '" + $Path + "'"
    }

    if (!$PSCmdlet.ShouldProcess($Path)) {
        return
    }

    setRawPath ($userCurrent + $Path).trim(";") User

    if (!(($processCurrent -split ";").Contains($Path))) {
        setRawPath ($processCurrent + $Path).trim(";") Process
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
        $variableName = getVariableName
        throw "Environment variable ""$variableName"" does not exist"
    }
    
    $resultsHash.Keys | ForEach-Object { New-Object psobject -Property @{Path = $_; Scope = @($resultsHash[$_].Keys) } }
}

function Update-EnvPath {
    $newPath = @((Get-EnvPath).Path) -join ";"
    setRawPath $newPath Process
}

function getPathArray {
    Param ([Parameter(Mandatory = $true)][EnvironmentVariableTarget]$scope)
    $var = getRawPath $scope
    if (!$var) {
        throw [VariableNotFoundException]::new()
    }
    $var.trim(";") -split ';'
}

function getVariableName {
    #Safety net
    if ($Host.Name -eq "Visual Studio Code Host") { "TEST_PATH" } else { "PATH" }
}

function setRawPath {
    Param(
        [string]$Value,
        [EnvironmentVariableTarget]$Scope
    )
    [Environment]::SetEnvironmentVariable((getVariableName), $Value, $Scope)
}

function getRawPath {
    Param([EnvironmentVariableTarget]$Scope)
    [Environment]::GetEnvironmentVariable((getVariableName), $Scope)
}

Export-ModuleMember -Function Add-EnvPath, Get-EnvPath, Update-EnvPath
