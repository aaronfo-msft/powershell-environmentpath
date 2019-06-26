function Add-EnvPath()
{
    Param (
        [Parameter(Position=0)]
        [ValidateScript({Test-Path $_})]
        [string] $Path = (Get-Location).Path
    )

    if((Get-EnvPath | where { $_.Path -eq $Path }).count -ne 0)
    {
        throw "The current environment path already contains '" + $Path + "'"
    }

    $workingpath = [System.Environment]::GetEnvironmentVariable('PATH', [System.EnvironmentVariableTarget]::User)
    if ($workingpath -and !($workingpath -match ';$'))
    {
        $workingpath = $workingpath + ';'
    }

    $workingpath = $workingpath + $Path

    [System.Environment]::SetEnvironmentVariable('PATH', $workingpath, [System.EnvironmentVariableTarget]::User)
    Update-EnvPath
    New-Object PSObject -Property @{Path=$Path; Scope="User"}
}

function Get-EnvPath()
{
    ([System.Environment]::GetEnvironmentVariable('PATH', [System.EnvironmentVariableTarget]::Machine)+'').trim(';') -split ';' | % {New-Object PSObject -Property @{Path=$_; Scope="Machine"}} 
    ([System.Environment]::GetEnvironmentVariable('PATH', [System.EnvironmentVariableTarget]::User)+'').trim(';') -split ';' | % {New-Object PSObject -Property @{Path=$_; Scope="User"}} 
}

function Update-EnvPath()
{
    $machine = ([System.Environment]::GetEnvironmentVariable('PATH', [System.EnvironmentVariableTarget]::Machine)+'').trim(';')
    $user = ([System.Environment]::GetEnvironmentVariable('PATH', [System.EnvironmentVariableTarget]::User)+'').trim(';')
    [System.Environment]::SetEnvironmentVariable('PATH', ($machine + ';' + $user).trim(';'), [System.EnvironmentVariableTarget]::Process)
}

Export-ModuleMember -Function Add-EnvPath,Get-EnvPath
