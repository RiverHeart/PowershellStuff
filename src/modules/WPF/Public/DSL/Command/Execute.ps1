function Execute {
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [scriptblock] $ScriptBlock
    )

    [pscustomobject]@{
        PSTypeName  = 'WPF.ExecuteSpec'
        ScriptBlock = $ScriptBlock
    }
}
