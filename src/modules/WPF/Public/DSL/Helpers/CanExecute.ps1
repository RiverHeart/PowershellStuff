function CanExecute {
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [scriptblock] $ScriptBlock
    )

    [pscustomobject]@{
        PSTypeName  = 'WPF.CanExecuteSpec'
        ScriptBlock = $ScriptBlock
    }
}
