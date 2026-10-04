using namespace System.Management.Automation

<#
.SYNOPSIS
    Creates a new Nitpick rule.

.DESCRIPTION
    Creates a new Nitpick rule object with the specified properties.

.EXAMPLE
    Create scriptblock based Nitpick rule

    $NitpickParams = @{
        Name = 'MyNitpick'
        Callable = { param($word) $word }
        Source = 'MyModule'
    }
    $Nitpick = New-Nitpick @NitpickParams

.EXAMPLE
    Create function based Nitpick rule

    $NitpickParams = @{
        Callable = 'Get-Command'
    }
    $Nitpick = New-Nitpick @NitpickParams
#>
function New-Nitpick {
    [CmdletBinding()]
    [OutputType([object])]
    param (
        [Parameter(Mandatory,ValueFromPipeline)]
        [ValidateScript({
            $_ -is [string] -or
            $_ -is [scriptblock] -or
            $_ -is [FunctionInfo] -or
            $_ -is [CmdletInfo]
        })]
        [object] $Callable,

        [ArgumentCompleter({ Complete-NitpickCategory $args })]
        [string] $Category = 'Other',

        [bool] $EditorEnabled = $true,

        [Parameter(HelpMessage='The name of the nitpick. Mandatory only when using a scriptblock')]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(HelpMessage='The source of the nitpick. Mandatory only when using a scriptblock')]
        [ValidateNotNullOrEmpty()]
        [string] $Source
    )

    process {
        $Overrides = @{}
        foreach ($Property in 'Name', 'Category', 'EditorEnabled', 'Source') {
            if ($PSBoundParameters.ContainsKey($Property)) {
                $Overrides[$Property] = $PSBoundParameters[$Property]
            }
        }

        Write-Output ([NitpickRule]::new($Callable, $Overrides))
    }
}
