<#
.SYNOPSIS
    Creates a per-user application storage context.

.DESCRIPTION
    Creates an application-specific directory under LocalApplicationData and
    returns a context for the WPF stored-item commands.

.PARAMETER Application
    Application name used as a directory name.

.PARAMETER Publisher
    Publisher namespace used as a directory name. Defaults to WPF.

.PARAMETER RootPath
    Base directory for storage. Defaults to the current user's LocalApplicationData directory.

.EXAMPLE
    Create a storage context for the application 'MyApp' under the current user's
    LocalApplicationData\WPF directory.

    $Storage = New-WPFAppStorage -Application 'MyApp'
#>
function New-WPFAppStorage {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Application,

        [ValidateNotNullOrEmpty()]
        [string] $Publisher,

        [ValidateNotNullOrEmpty()]
        [string] $RootPath = [Environment]::GetFolderPath('LocalApplicationData')
    )

    foreach ($Segment in @($Publisher, $Application)) {
        if ($Segment -in '.', '..' -or
            $Segment.IndexOfAny([System.IO.Path]::GetInvalidFileNameChars()) -ge 0 -or
            $Segment.EndsWith('.') -or
            $Segment.EndsWith(' ')
        ) {
            Write-Error "Storage path segment '$Segment' is not a valid directory name." -Category InvalidArgument
            return
        }
    }

    $StoragePath = [System.IO.Path]::Combine($RootPath, $Publisher, $Application)
    $null = New-Item -Path $StoragePath -ItemType Directory -Force

    [pscustomobject] @{
        PSTypeName  = 'WPF.ApplicationStorage'
        Application = $Application
        Publisher   = $Publisher
        RootPath    = $StoragePath
    }
}
