function Work {
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [scriptblock] $ScriptBlock
    )

    [pscustomobject]@{
        PSTypeName  = 'WPF.WorkSpec'
        ScriptBlock = $ScriptBlock
    }
}
