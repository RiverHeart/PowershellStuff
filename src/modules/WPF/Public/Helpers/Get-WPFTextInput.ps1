<#
.SYNOPSIS
    Shows a native WPF text input dialog and returns user-entered text.

.DESCRIPTION
    Creates a small modal WPF dialog with prompt text, a textbox, and OK/Cancel
    buttons. Returns the textbox content when the user accepts; otherwise returns
    an empty string.

.PARAMETER Prompt
    Prompt text shown above the input box.

.PARAMETER Title
    Window title for the dialog.

.PARAMETER DefaultValue
    Initial text shown in the input box.

.PARAMETER Owner
    Optional owner window. When provided, the dialog centers over the owner.

.PARAMETER Numeric
    Enables numeric input mode. In this mode, non-numeric text is rejected
    during typing and paste operations, and the OK button remains disabled
    until the value is valid.

.PARAMETER Minimum
    Optional minimum value when -Numeric is used.

.PARAMETER Maximum
    Optional maximum value when -Numeric is used.

.PARAMETER AllowDecimal
    Allows decimal values in numeric mode. If omitted, only integer input is
    accepted.

.EXAMPLE
    $Name = Get-WPFTextInput -Prompt 'Enter display name:' -Title 'Profile' -DefaultValue 'alex'

.NOTES
    Future improvements may include culture-specific live hinting,
    configurable negative/scientific notation support, and richer
    inline validation visuals.
#>
function Get-WPFTextInput {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Prompt,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $Title = 'Input',

        [Parameter()]
        [AllowEmptyString()]
        [string] $DefaultValue = '',

        [Parameter()]
        [AllowNull()]
        [System.Windows.Window] $Owner,

        [Parameter()]
        [switch] $Numeric,

        [Parameter()]
        [Nullable[double]] $Minimum,

        [Parameter()]
        [Nullable[double]] $Maximum,

        [Parameter()]
        [switch] $AllowDecimal
    )

    if (-not $Numeric -and (
        $PSBoundParameters.ContainsKey('Minimum') -or
        $PSBoundParameters.ContainsKey('Maximum') -or
        $AllowDecimal
    )) {
        throw 'Get-WPFTextInput: -Minimum, -Maximum, and -AllowDecimal can only be used with -Numeric.'
    }

    if (
        $PSBoundParameters.ContainsKey('Minimum') -and
        $PSBoundParameters.ContainsKey('Maximum') -and
        [double] $Minimum -gt [double] $Maximum
    ) {
        throw 'Get-WPFTextInput: -Minimum cannot be greater than -Maximum.'
    }

    $Window = [System.Windows.Window]::new()
    $Window.Title = $Title
    $Window.WindowStyle = [System.Windows.WindowStyle]::SingleBorderWindow
    $Window.ResizeMode = [System.Windows.ResizeMode]::NoResize
    $Window.SizeToContent = [System.Windows.SizeToContent]::WidthAndHeight
    $Window.MinWidth = 420
    $Window.ShowInTaskbar = $false
    $Window.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterScreen

    if ($Owner) {
        $Window.Owner = $Owner
        $Window.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterOwner
    }

    $Root = [System.Windows.Controls.Grid]::new()
    $Root.Margin = [System.Windows.Thickness]::new(14)

    $null = $Root.RowDefinitions.Add([System.Windows.Controls.RowDefinition]::new())
    $null = $Root.RowDefinitions.Add([System.Windows.Controls.RowDefinition]::new())
    $null = $Root.RowDefinitions.Add([System.Windows.Controls.RowDefinition]::new())
    $null = $Root.RowDefinitions.Add([System.Windows.Controls.RowDefinition]::new())

    $PromptText = [System.Windows.Controls.TextBlock]::new()
    $PromptText.Text = $Prompt
    $PromptText.TextWrapping = [System.Windows.TextWrapping]::Wrap
    $PromptText.Margin = [System.Windows.Thickness]::new(0, 0, 0, 8)
    [System.Windows.Controls.Grid]::SetRow($PromptText, 0)
    $null = $Root.Children.Add($PromptText)

    $TextBox = [System.Windows.Controls.TextBox]::new()
    $TextBox.Text = $DefaultValue
    $TextBox.MinWidth = 360
    $TextBox.Margin = [System.Windows.Thickness]::new(0, 0, 0, 4)
    [System.Windows.Controls.Grid]::SetRow($TextBox, 1)
    $null = $Root.Children.Add($TextBox)

    $ValidationText = [System.Windows.Controls.TextBlock]::new()
    $ValidationText.TextWrapping = [System.Windows.TextWrapping]::Wrap
    $ValidationText.Foreground = [System.Windows.Media.Brushes]::IndianRed
    $ValidationText.FontSize = 12
    $ValidationText.Margin = [System.Windows.Thickness]::new(0, 0, 0, 12)
    $ValidationText.Visibility = [System.Windows.Visibility]::Collapsed
    [System.Windows.Controls.Grid]::SetRow($ValidationText, 2)
    $null = $Root.Children.Add($ValidationText)

    $Buttons = [System.Windows.Controls.StackPanel]::new()
    $Buttons.Orientation = [System.Windows.Controls.Orientation]::Horizontal
    $Buttons.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Right
    [System.Windows.Controls.Grid]::SetRow($Buttons, 3)

    $OkButton = [System.Windows.Controls.Button]::new()
    $OkButton.Content = 'OK'
    $OkButton.MinWidth = 80
    $OkButton.Margin = [System.Windows.Thickness]::new(0, 0, 8, 0)
    $OkButton.IsDefault = $true
    $null = $OkButton.add_Click({
        $Window.DialogResult = $true
    })
    $null = $Buttons.Children.Add($OkButton)

    $CancelButton = [System.Windows.Controls.Button]::new()
    $CancelButton.Content = 'Cancel'
    $CancelButton.MinWidth = 80
    $CancelButton.IsCancel = $true
    $null = $CancelButton.add_Click({
        $Window.DialogResult = $false
    })
    $null = $Buttons.Children.Add($CancelButton)

    $null = $Root.Children.Add($Buttons)
    $Window.Content = $Root

    $null = $Window.add_Loaded({
        $null = $TextBox.Focus()
        $TextBox.SelectAll()
    })

    if ($Numeric) {
        $decimalSeparator = [System.Globalization.CultureInfo]::CurrentCulture.NumberFormat.NumberDecimalSeparator
        $escapedSeparator = [System.Text.RegularExpressions.Regex]::Escape($decimalSeparator)
        $inputPattern = if ($AllowDecimal) {
            "^[+-]?\\d*($escapedSeparator\\d*)?$"
        } else {
            '^[+-]?\d*$'
        }

        $isValidNumericText = {
            param([string] $Text)

            if ([string]::IsNullOrWhiteSpace($Text)) {
                return $false
            }

            [double] $parsed = 0
            $isParsed = [double]::TryParse(
                $Text,
                [System.Globalization.NumberStyles]::Float,
                [System.Globalization.CultureInfo]::CurrentCulture,
                [ref] $parsed
            )

            if (-not $isParsed) {
                $isParsed = [double]::TryParse(
                    $Text,
                    [System.Globalization.NumberStyles]::Float,
                    [System.Globalization.CultureInfo]::InvariantCulture,
                    [ref] $parsed
                )
            }

            if (-not $isParsed) {
                return $false
            }

            if (-not $AllowDecimal -and $parsed -ne [Math]::Truncate($parsed)) {
                return $false
            }

            if ($Minimum.HasValue -and $parsed -lt $Minimum.Value) {
                return $false
            }

            if ($Maximum.HasValue -and $parsed -gt $Maximum.Value) {
                return $false
            }

            return $true
        }

        $getValidationMessage = {
            [string] $rangeMessage = ''
            if ($Minimum.HasValue -and $Maximum.HasValue) {
                $rangeMessage = " between $($Minimum.Value) and $($Maximum.Value)"
            } elseif ($Minimum.HasValue) {
                $rangeMessage = " >= $($Minimum.Value)"
            } elseif ($Maximum.HasValue) {
                $rangeMessage = " <= $($Maximum.Value)"
            }

            if ($AllowDecimal) {
                return "Enter a valid number$rangeMessage."
            }

            return "Enter a valid integer$rangeMessage."
        }

        $refreshNumericValidation = {
            $isValid = & $isValidNumericText $TextBox.Text
            $OkButton.IsEnabled = $isValid

            if ($isValid) {
                $ValidationText.Visibility = [System.Windows.Visibility]::Collapsed
                $ValidationText.Text = ''
            } else {
                $ValidationText.Visibility = [System.Windows.Visibility]::Visible
                $ValidationText.Text = & $getValidationMessage
            }
        }

        $null = $TextBox.add_TextChanged({
            & $refreshNumericValidation
        })

        $null = $TextBox.add_PreviewTextInput({
            param($sender, $event)

            $currentText = $sender.Text
            $start = $sender.SelectionStart
            $length = $sender.SelectionLength
            $prefix = if ($start -gt 0) { $currentText.Substring(0, $start) } else { '' }
            $suffixIndex = $start + $length
            $suffix = if ($suffixIndex -lt $currentText.Length) { $currentText.Substring($suffixIndex) } else { '' }
            $proposed = "$prefix$($event.Text)$suffix"

            if ($proposed -notmatch $inputPattern) {
                $event.Handled = $true
            }
        })

        [System.Windows.DataObject]::AddPastingHandler(
            $TextBox,
            [System.Windows.DataObjectPastingEventHandler] {
                param($sender, $event)

                if (-not $event.DataObject.GetDataPresent([System.Windows.DataFormats]::Text)) {
                    return
                }

                $pastedText = [string] $event.DataObject.GetData([System.Windows.DataFormats]::Text)
                $currentText = $sender.Text
                $start = $sender.SelectionStart
                $length = $sender.SelectionLength
                $prefix = if ($start -gt 0) { $currentText.Substring(0, $start) } else { '' }
                $suffixIndex = $start + $length
                $suffix = if ($suffixIndex -lt $currentText.Length) { $currentText.Substring($suffixIndex) } else { '' }
                $proposed = "$prefix$pastedText$suffix"

                if ($proposed -notmatch $inputPattern) {
                    $event.CancelCommand()
                }
            }
        )

        & $refreshNumericValidation
    }

    $DialogResult = Show-WPFWindow -Window $Window

    if ($DialogResult -eq $true) {
        return $TextBox.Text
    }

    return ''
}
