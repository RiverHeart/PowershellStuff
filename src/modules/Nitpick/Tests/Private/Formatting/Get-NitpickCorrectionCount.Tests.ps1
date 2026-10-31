BeforeAll {
    Import-Module -Name "$PSScriptRoot\..\..\..\Nitpick.psd1" -Force
}

AfterAll {
    Remove-Module -Name Nitpick -Force -ErrorAction SilentlyContinue
}

Describe 'Get-NitpickCorrectionCount' {
    It 'counts each change set once and each ungrouped correction individually' {
        $Corrections = @(
            [pscustomobject]@{ ChangeSetId = 'PairA' }
            [pscustomobject]@{ ChangeSetId = 'PairA' }
            [pscustomobject]@{ ChangeSetId = 'PairB' }
            [pscustomobject]@{ ChangeSetId = $null }
            [pscustomobject]@{ ChangeSetId = '' }
        )
        $Count = InModuleScope Nitpick -Parameters @{ Corrections = $Corrections } {
            param ($Corrections)
            Get-NitpickCorrectionCount -Corrections $Corrections
        }

        $Count | Should -Be 4
    }

    It 'returns zero for an empty correction collection' {
        $Count = InModuleScope Nitpick {
            Get-NitpickCorrectionCount -Corrections @()
        }

        $Count | Should -Be 0
    }
}
