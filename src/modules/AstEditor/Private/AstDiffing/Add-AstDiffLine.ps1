using namespace System.Text

<#
.SYNOPSIS
    Appends a diff line with an optional line number and color to a builder.
#>
function Add-AstDiffLine {
    param (
        [Parameter(Mandatory)]
        [StringBuilder] $Builder,

        [Parameter(Mandatory)]
        [int] $NumberWidth,

        [Parameter(Mandatory)]
        [string] $Marker,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Content,

        [Nullable[int]] $LineNumber,

        [ValidateSet('Red', 'Green')]
        [string] $Color
    )

    $Reset = if ($Color) { "`e[0m" } else { '' }
    $ColorCode = switch ($Color) {
        'Red' { "`e[31m" }
        'Green' { "`e[32m" }
        default { '' }
    }

    $Gutter =
        if ($null -eq $LineNumber) { ' ' * $NumberWidth }
        else { ([string] $LineNumber).PadLeft($NumberWidth) }

    [void] $Builder.AppendLine("$ColorCode  $Gutter $Marker ${Content}$Reset")
}
