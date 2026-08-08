Import-Module "$PSScriptRoot/../../PleaseWork.psd1" -Force

InModuleScope PleaseWork {
    Describe 'Git changesets' {
        It 'returns repository-relative files and applies Git pathspecs' {
            $Repository = Join-Path $TestDrive 'repository'
            $TaskRoot = Join-Path $Repository 'Module'
            $Public = Join-Path $TaskRoot 'Public'
            $null = New-Item -ItemType Directory -Path $Public -Force
            $File = Join-Path $Public 'One.ps1'
            $WorkingFile = Join-Path $Public 'Working.ps1'

            $null = git -C $Repository init --quiet
            $null = git -C $Repository config user.email 'pleasework@example.invalid'
            $null = git -C $Repository config user.name 'PleaseWork Tests'
            '*.ignored.ps1' | Set-Content -LiteralPath (Join-Path $Repository '.gitignore')
            'first' | Set-Content -LiteralPath $File
            'first' | Set-Content -LiteralPath $WorkingFile
            $null = git -C $Repository add .
            $null = git -C $Repository commit --quiet -m 'base'
            $BaseRef = git -C $Repository rev-parse HEAD

            'second' | Set-Content -LiteralPath $File
            'docs' | Set-Content -LiteralPath (Join-Path $Repository 'README.md')
            $null = git -C $Repository add .
            $null = git -C $Repository commit --quiet -m 'head'
            $HeadRef = git -C $Repository rev-parse HEAD

            'third' | Set-Content -LiteralPath $File
            'second' | Set-Content -LiteralPath $WorkingFile
            'staged' | Set-Content -LiteralPath (Join-Path $Public 'Staged.ps1')
            $null = git -C $Repository add Module/Public/Staged.ps1
            'untracked' | Set-Content -LiteralPath (Join-Path $Public 'Untracked.ps1')
            'ignored' | Set-Content -LiteralPath (Join-Path $Public 'Generated.ignored.ps1')

            $Changeset = Get-GitChangeset `
                -WorkingDirectory $TaskRoot `
                -BaseRef $BaseRef `
                -HeadRef $HeadRef
            $MatchingFiles = @(Get-GitChangedPath `
                -Changeset $Changeset `
                -PathSpec './Public')

            $Changeset.Available | Should -BeTrue
            $Changeset.Provider | Should -Be 'Git'
            (Resolve-Path -LiteralPath $Changeset.Root).ProviderPath | Should -Be $Repository
            $Changeset.WorkingRoot | Should -Be $TaskRoot
            $Changeset.Files | Should -Be @(
                'Module/Public/One.ps1'
                'README.md'
                'Module/Public/Staged.ps1'
                'Module/Public/Working.ps1'
                'Module/Public/Untracked.ps1'
            )
            $MatchingFiles | Should -Be @(
                'Module/Public/One.ps1'
                'Module/Public/Staged.ps1'
                'Module/Public/Working.ps1'
                'Module/Public/Untracked.ps1'
            )
            $Changeset.Files | Should -Not -Contain 'Module/Public/Generated.ignored.ps1'
            @($Changeset.Files | Where-Object { $_ -eq 'Module/Public/One.ps1' }).Count | Should -Be 1
        }
    }
}
