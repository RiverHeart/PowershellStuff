using namespace System.Windows
using namespace System.Windows.Controls

<#
.SYNOPSIS
    Creates a custom input box.

.DESCRIPTION
    Creates a custom input box.

    Reimplementation of the Microsoft WinForm example.

.LINK
    https://learn.microsoft.com/en-us/powershell/scripting/samples/creating-a-custom-input-box?view=powershell-7.5
#>

# Change to the script directory if we're not in it.
if (-not $PSScriptRoot -ne $PWD) {
    Set-Location $PSScriptRoot
}

$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName PresentationFramework

$Window = [Window] @{
    Name = 'Window'
    Title = 'Data Entry Form'
    WindowStartupLocation = [WindowStartupLocation]::CenterScreen
    TopMost = $True
    Height = 300
    Width = 300
}

# Set namescope manually
$Namescope = [NameScope]::new()
[NameScope]::SetNameScope($Window, $Namescope)

# Add children in a nested fashion
$Window.AddChild({
    $MainStackPanel = [StackPanel] @{
        Name = 'MainStackPanel'
        Margin = 5
    }

    $MainStackPanel.AddChild(
        [Label] @{
            Name = 'DataEntryLabel'
            Content = 'Please enter the information in the space below:'
        }
    )

    $MainStackPanel.AddChild({
        $DataEntryBox = [TextBox] @{
            Name = 'DataEntryBox'
            HorizontalAlignment = [HorizontalAlignment]::Left
            Width = 260
            Height = 20
        }
        $Window.RegisterName($DataEntryBox.Name, $DataEntryBox)
        return $DataEntryBox
    }.InvokeReturnAsIs())

    $MainStackPanel.AddChild({
        $ButtonPanel = [StackPanel] @{
            Name = 'ButtonPanel'
            Orientation = [Orientation]::Horizontal
        }

        $ButtonPanel.AddChild({
            $OKButton = [Button] @{
                Name = 'OKButton'
                Content = 'OK'
                Width = 75
                Margin = 5
            }

            $OKButton.Add_Click({
                $UserInput = $Window.FindName('DataEntryBox').Text
                Write-Host $UserInput
            })

            return $OKButton
        }.InvokeReturnAsIs())

        $ButtonPanel.AddChild({
            $CancelButton = [Button] @{
                Name = 'CancelButton'
                Content = 'Cancel'
                Width = 75
                Margin = 5
            }

            $CancelButton.Add_Click({
                Write-Host "User cancelled operation."
                $Window.Close()
            })

            return $CancelButton
        }.InvokeReturnAsIs())

        return $ButtonPanel
    }.InvokeReturnAsIs())

    return $MainStackPanel
}.InvokeReturnAsIs())

# Applications can't return anything on stdout.
if (-not [Application]::Current) {
    $App = [Application]::new()
}

try {
    $ExitCode = $App.Run($Window)
    Write-Host "Application exited with error code '$ExitCode'"
} catch {
    Write-Error "Application terminated with error: $_"
} finally {
    if ($App) {
        # Close any open windows
        if ($App.Windows.Count -gt 0) {
            $App.Windows.Close()
        }
    }
}
