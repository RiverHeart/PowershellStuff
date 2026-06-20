function OnComplete {
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [scriptblock] $ScriptBlock
    )

    [pscustomobject]@{
        PSTypeName  = 'WPF.OnCompleteSpec'
        ScriptBlock = $ScriptBlock
    }
}
