using namespace System.Globalization
using namespace System.Windows
using namespace System.Windows.Controls
using namespace System.Windows.Media

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
    $Name = Get-WPFTextInput `
        -Prompt 'Enter display name:' `
        -Title 'Profile' `
        -DefaultValue 'John Doe'

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
        [Window] $Owner,

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

    $Window = [Window]::new()
    $Window.Title = $Title
    $Window.WindowStyle = [WindowStyle]::SingleBorderWindow
    $Window.ResizeMode = [ResizeMode]::NoResize
    $Window.SizeToContent = [SizeToContent]::WidthAndHeight
    $Window.MinWidth = 420
    $Window.ShowInTaskbar = $false
    $Window.WindowStartupLocation = [WindowStartupLocation]::CenterScreen

    if ($Owner) {
        $Window.Owner = $Owner
        $Window.WindowStartupLocation = [WindowStartupLocation]::CenterOwner
    }

    $Root = [Grid]::new()
    $Root.Margin = [Thickness]::new(14)

    $null = $Root.RowDefinitions.Add([RowDefinition]::new())
    $null = $Root.RowDefinitions.Add([RowDefinition]::new())
    $null = $Root.RowDefinitions.Add([RowDefinition]::new())
    $null = $Root.RowDefinitions.Add([RowDefinition]::new())

    $PromptText = [TextBlock]::new()
    $PromptText.Text = $Prompt
    $PromptText.TextWrapping = [TextWrapping]::Wrap
    $PromptText.Margin = [Thickness]::new(0, 0, 0, 8)
    [Grid]::SetRow($PromptText, 0)
    $null = $Root.Children.Add($PromptText)

    $TextBox = [TextBox]::new()
    $TextBox.Text = $DefaultValue
    $TextBox.MinWidth = 360
    $TextBox.Margin = [Thickness]::new(0, 0, 0, 4)
    [Grid]::SetRow($TextBox, 1)
    $null = $Root.Children.Add($TextBox)

    $ValidationText = [TextBlock]::new()
    $ValidationText.TextWrapping = [TextWrapping]::Wrap
    $ValidationText.Foreground = [Brushes]::IndianRed
    $ValidationText.FontSize = 12
    $ValidationText.Margin = [Thickness]::new(0, 0, 0, 12)
    $ValidationText.Visibility = [Visibility]::Collapsed
    [Grid]::SetRow($ValidationText, 2)
    $null = $Root.Children.Add($ValidationText)

    $Buttons = [StackPanel]::new()
    $Buttons.Orientation = [Orientation]::Horizontal
    $Buttons.HorizontalAlignment = [HorizontalAlignment]::Right
    [Grid]::SetRow($Buttons, 3)

    $OkButton = [Button]::new()
    $OkButton.Content = 'OK'
    $OkButton.MinWidth = 80
    $OkButton.Margin = [Thickness]::new(0, 0, 8, 0)
    $OkButton.IsDefault = $true
    $null = $OkButton.add_Click({
        $Window.DialogResult = $true
    })
    $null = $Buttons.Children.Add($OkButton)

    $CancelButton = [Button]::new()
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
        $decimalSeparator = [CultureInfo]::CurrentCulture.NumberFormat.NumberDecimalSeparator
        $escapedSeparator = [System.Text.RegularExpressions.Regex]::Escape($decimalSeparator)
        $inputPattern = if ($AllowDecimal) {
            "^[+-]?\d*($escapedSeparator\d*)?$"
        } else {
            '^[+-]?\d*$'
        }

        Write-Debug (
            'Get-WPFTextInput numeric mode initialized. AllowDecimal={0}; MinBound={1}; MaxBound={2}; Pattern={3}' -f
            [bool] $AllowDecimal,
            $Minimum.HasValue,
            $Maximum.HasValue,
            $inputPattern
        )

        $isValidNumericText = {
            param([string] $Text)

            if ([string]::IsNullOrWhiteSpace($Text)) {
                return $false
            }

            [double] $parsed = 0
            $isParsed = [double]::TryParse(
                $Text,
                [NumberStyles]::Float,
                [CultureInfo]::CurrentCulture,
                [ref] $parsed
            )

            if (-not $isParsed) {
                $isParsed = [double]::TryParse(
                    $Text,
                    [NumberStyles]::Float,
                    [CultureInfo]::InvariantCulture,
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

            Write-Debug (
                'Get-WPFTextInput validation refresh. TextLength={0}; IsValid={1}; OkEnabled={2}' -f
                $TextBox.Text.Length,
                $isValid,
                $OkButton.IsEnabled
            )

            if ($isValid) {
                $ValidationText.Visibility = [Visibility]::Collapsed
                $ValidationText.Text = ''
            } else {
                $ValidationText.Visibility = [Visibility]::Visible
                $ValidationText.Text = & $getValidationMessage
            }
        }

        $null = $TextBox.add_TextChanged({
            & $refreshNumericValidation
        })

        $null = $TextBox.add_PreviewTextInput({
            param($sender, $event)

            try {
                $currentText = $sender.Text
                $start = $sender.SelectionStart
                $length = $sender.SelectionLength
                $prefix = if ($start -gt 0) { $currentText.Substring(0, $start) } else { '' }
                $suffixIndex = $start + $length
                $suffix = if ($suffixIndex -lt $currentText.Length) { $currentText.Substring($suffixIndex) } else { '' }
                $proposed = "$prefix$($event.Text)$suffix"
                $isAllowed = $proposed -match $inputPattern

                Write-Debug (
                    'Get-WPFTextInput preview input. CurrentLength={0}; InsertLength={1}; SelectionStart={2}; SelectionLength={3}; ProposedLength={4}; Allowed={5}' -f
                    $currentText.Length,
                    $event.Text.Length,
                    $start,
                    $length,
                    $proposed.Length,
                    $isAllowed
                )

                if (-not $isAllowed) {
                    $event.Handled = $true
                }
            } catch {
                Write-Debug (
                    'Get-WPFTextInput preview input handler error: {0}' -f $_.Exception.Message
                )
            }
        })

        [DataObject]::AddPastingHandler(
            $TextBox,
            [DataObjectPastingEventHandler] {
                param($sender, $event)

                if (-not $event.DataObject.GetDataPresent([DataFormats]::Text)) {
                    return
                }

                $pastedText = [string] $event.DataObject.GetData([DataFormats]::Text)
                $currentText = $sender.Text
                $start = $sender.SelectionStart
                $length = $sender.SelectionLength
                $prefix = if ($start -gt 0) { $currentText.Substring(0, $start) } else { '' }
                $suffixIndex = $start + $length
                $suffix = if ($suffixIndex -lt $currentText.Length) { $currentText.Substring($suffixIndex) } else { '' }
                $proposed = "$prefix$pastedText$suffix"
                $isAllowed = $proposed -match $inputPattern

                Write-Debug (
                    'Get-WPFTextInput paste input. CurrentLength={0}; PasteLength={1}; SelectionStart={2}; SelectionLength={3}; ProposedLength={4}; Allowed={5}' -f
                    $currentText.Length,
                    $pastedText.Length,
                    $start,
                    $length,
                    $proposed.Length,
                    $isAllowed
                )

                if (-not $isAllowed) {
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
