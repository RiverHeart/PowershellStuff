function Add-WPFHandler {
    [CmdletBinding()]
    [Alias('Handler')]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Event,

        [Parameter(Mandatory)]
        [scriptblock] $ScriptBlock
    )

    return @{
        Event = $Event
        ScriptBlock = $ScriptBlock
    } | Add-Member -MemberType NoteProperty -Name 'WPF_TYPE' -Value 'Handler' -PassThru
}
