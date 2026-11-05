BeforeDiscovery {
    $WrapperCases = @(
        @{ Module = 'Nitpick'; WrapperPath = "$PSScriptRoot\..\..\Private\Helpers\Should-Process.ps1" }
        @{ Module = 'AstEditor'; WrapperPath = "$PSScriptRoot\..\..\..\AstEditor\Private\Should-Process.ps1" }
    )
}

Describe '<Module> Should-Process confirmation behavior' -ForEach $WrapperCases {
    BeforeEach {
        $PreviousQuietWhatIf = $env:WHATIF__QUIET
        $Runspace = [powershell]::Create()
    }

    AfterEach {
        $Runspace.Dispose()
        $env:WHATIF__QUIET = $PreviousQuietWhatIf
    }

    It 'honors <Decision> with quiet mode <Quiet>' -ForEach @(
        @{ Quiet = 'True'; Decision = 'explicit confirmation'; Confirm = $true; Preference = 'High'; Prompts = $true }
        @{ Quiet = 'False'; Decision = 'explicit confirmation'; Confirm = $true; Preference = 'High'; Prompts = $true }
        @{ Quiet = 'True'; Decision = 'disabled confirmation'; Confirm = $false; Preference = 'Low'; Prompts = $false }
        @{ Quiet = 'False'; Decision = 'disabled confirmation'; Confirm = $false; Preference = 'Low'; Prompts = $false }
        @{ Quiet = 'True'; Decision = 'inherited preference'; Confirm = $null; Preference = 'Low'; Prompts = $true }
        @{ Quiet = 'False'; Decision = 'inherited preference'; Confirm = $null; Preference = 'Low'; Prompts = $true }
    ) {
        $env:WHATIF__QUIET = $Quiet
        [void] $Runspace.AddScript({
            param ($Path, $Confirmation, $Preference)
            . $Path
            $ConfirmPreference = $Preference
            $Parameters = @{}
            if ($null -ne $Confirmation) {
                $Parameters.Confirm = $Confirmation
            }
            Should-Process -Target 'Test target' -Action 'Test action' @Parameters
        }).AddArgument($WrapperPath).AddArgument($Confirm).AddArgument($Preference)

        $Result = @($Runspace.Invoke())

        if ($Prompts) {
            # A hostless runspace rejects prompts rather than waiting for interactive input.
            $Result | Should -HaveCount 0
            $Runspace.Streams.Error | Should -HaveCount 1
            $Runspace.Streams.Error[0].FullyQualifiedErrorId | Should -Be 'HostException'
            $Runspace.Streams.Error[0].Exception.Message | Should -Match 'ShouldProcess'
        } else {
            $Runspace.Streams.Error | Should -HaveCount 0
            $Result | Should -HaveCount 1
            $Result[0] | Should -BeTrue
        }
    }

    It 'returns false for quiet WhatIf even when confirmation is requested' {
        $env:WHATIF__QUIET = 'True'
        [void] $Runspace.AddScript({
            param ($Path)
            . $Path
            Should-Process -Target 'Test target' -Action 'Test action' -WhatIf -Confirm
        }).AddArgument($WrapperPath)

        $Result = @($Runspace.Invoke())

        $Runspace.Streams.Error | Should -HaveCount 0
        $Result | Should -HaveCount 1
        $Result[0] | Should -BeFalse
    }
}
