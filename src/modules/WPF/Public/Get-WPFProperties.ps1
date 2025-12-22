function Get-WPFProperties {
    [OutputType([hashtable])]
    [Alias('Properties')]
    param(
        [Parameter(Mandatory)]
        [scriptblock] $ScriptBlock
    )

    return $ScriptBlock.ToString() |
        ConvertFrom-StringData |
        Add-Member -MemberType NoteProperty -Name 'WPF_TYPE' -Value 'Properties' -PassThru
}
