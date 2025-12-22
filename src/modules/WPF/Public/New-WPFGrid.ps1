
function New-WPFGrid {
    [Alias('Grid')]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(Mandatory)]
        [ScriptBlock] $ScriptBlock
    )
    @"
    <Grid>
    $(if ($Name) { "Name=`"$Name`"" })
    $($ScriptBlock.Invoke())
    </Grid>
"@
}
