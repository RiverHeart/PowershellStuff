function OnComplete {
    [OutputType([pscustomobject])]
    param(
        [scriptblock] $ScriptBlock
    )

    [pscustomobject]@{
        PSTypeName  = 'WPF.OnCompleteSpec'
        ScriptBlock = $ScriptBlock
    }
}
