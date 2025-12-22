function New-WPFButton {
    [Alias('Button')]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $Name,

        [Parameter(Mandatory)]
        [string] $Content,

        [scriptblock] $ScriptBlock
    )


    $Button = [System.Windows.Controls.Button] @{
        Name = $Name
        Content = $Content
    }
    if ($ScriptBlock) {
        foreach ($Item in $ScriptBlock.Invoke()) {
            if ($Item.WPF_TYPE -eq 'Properties') {
                foreach($KVP in $Item.GetEnumerator()) {
                    $Button.($KVP.Name) = $KVP.Value
                }
            }
            elseif ($Item.WPF_TYPE -eq 'Handler') {
                $Button."Add_$($Item.Event)"($Item.ScriptBlock)
            }
        }
    }

    return $Button
}
