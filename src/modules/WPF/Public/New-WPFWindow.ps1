function New-WPFWindow {
    [Alias('Window')]
    [OutputType([System.Windows.Window])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Title,

        [Parameter(Mandatory)]
        [uint32] $Width,

        [Parameter(Mandatory)]
        [uint32] $Height,

        [Parameter(Mandatory)]
        [ScriptBlock] $ScriptBlock
    )

    $Window = [System.Windows.Window] @{
        Title = $Title
        Height = $Height
        Width = $Width
    }
    foreach ($Control in $ScriptBlock.Invoke()) {
        $Window.AddChild($Control)
    }
    return $Window
}
