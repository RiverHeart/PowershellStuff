Describe 'Registry Context' -Tag 'RegistryContext' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../WPF.psd1" -Force
    }

    BeforeEach {
        InModuleScope WPF {
            Clear-WPFControlRegistry
        }
    }

    It 'Should allow duplicate names across different window contexts' {
        $FirstWindow = Window 'Window' {
            Button 'SharedButton' {}
        }

        $SecondWindow = Window 'Window' {
            Button 'SharedButton' {}
        }

        $FirstContextId = [string] $FirstWindow.PSObject.Properties['_WPFContextId'].Value
        $SecondContextId = [string] $SecondWindow.PSObject.Properties['_WPFContextId'].Value

        $FirstButton = Reference 'SharedButton' -ContextId $FirstContextId
        $SecondButton = Reference 'SharedButton' -ContextId $SecondContextId

        $FirstWindow | Should -Not -Be -ExpectedValue $SecondWindow
        $FirstContextId | Should -Not -Be -ExpectedValue $SecondContextId
        $FirstButton | Should -Not -Be -ExpectedValue $SecondButton
    }

    It 'Should resolve Reference from the current object context' {
        $FirstWindow = Window 'Window' {
            Button 'SharedButton' {}
        }

        $SecondWindow = Window 'Window' {
            Button 'SharedButton' {}
        }

        $FirstButton = Reference 'SharedButton' -ContextId ([string] $FirstWindow.PSObject.Properties['_WPFContextId'].Value)
        $SecondButton = Reference 'SharedButton' -ContextId ([string] $SecondWindow.PSObject.Properties['_WPFContextId'].Value)

        $FirstVars = New-WPFVariableList -InputObject $FirstButton
        $SecondVars = New-WPFVariableList -InputObject $SecondButton

        $ResolvedFirstWindow = { Reference 'Window' }.InvokeWithContext($null, $FirstVars)
        $ResolvedSecondWindow = { Reference 'Window' }.InvokeWithContext($null, $SecondVars)

        $ResolvedFirstWindow | Should -BeExactly -ExpectedValue $FirstWindow
        $ResolvedSecondWindow | Should -BeExactly -ExpectedValue $SecondWindow
    }

    It 'Should throw when lookup is ambiguous and there is no active context' {
        $null = Window 'Window' {
            Button 'SharedButton' {}
        }

        $null = Window 'Window' {
            Button 'SharedButton' {}
        }

        InModuleScope WPF {
            (Get-WPFControlRegistry).ActiveContextId = $null
        }

        { Reference 'Window' -ErrorAction Stop } | Should -Throw '*ambiguous*'
    }

    It 'Should clear one context without affecting other contexts' {
        $FirstWindow = Window 'Window' {
            Button 'FirstButton' {}
        }

        $SecondWindow = Window 'Window' {
            Button 'SecondButton' {}
        }

        $FirstContextId = [string] $FirstWindow.PSObject.Properties['_WPFContextId'].Value
        $SecondContextId = [string] $SecondWindow.PSObject.Properties['_WPFContextId'].Value

        Unregister-WPFObject -ContextId $FirstContextId

        { Reference 'FirstButton' -ContextId $FirstContextId -ErrorAction Stop } | Should -Throw
        (Reference 'SecondButton' -ContextId $SecondContextId) | Should -Not -BeNullOrEmpty
    }

    It 'Should resolve using the fallback context rules when ContextId is omitted' {
        InModuleScope WPF {
            $Window = Window 'Window' {}
            $ExpectedContextId = [string] $Window.PSObject.Properties['_WPFContextId'].Value
            (Get-WPFControlRegistry).ActiveContextId = $null
            $ResolvedContextId = Resolve-WPFControlContextId

            $ResolvedContextId | Should -BeExactly -ExpectedValue $ExpectedContextId
        }
    }

    It 'Should reject an explicit null InputObject' {
        { Resolve-WPFControlContextId -InputObject $null -ErrorAction Stop } | Should -Throw
    }

    It 'Should return true when a context exists' {
        InModuleScope WPF {
            $Window = Window 'Window' {}
            $ContextId = [string] $Window.PSObject.Properties['_WPFContextId'].Value

            (Test-WPFControlContextId -ContextId $ContextId) | Should -BeTrue
        }
    }

    It 'Should return false when a context does not exist' {
        InModuleScope WPF {
            (Test-WPFControlContextId -ContextId 'missing-context') | Should -BeFalse
        }
    }

    It 'Should error when ErrorIfMissing is used and context does not exist' {
        InModuleScope WPF {
            { Test-WPFControlContextId -ContextId 'missing-context' -ErrorIfMissing -ErrorAction Stop } | Should -Throw '*No WPF control context exists*'
        }
    }

    It 'Should error when an explicit InputObject does not resolve' {
        InModuleScope WPF {
            $InputObject = [pscustomobject] @{
                Name = 'MissingContextObject'
            }

            { Resolve-WPFControlContextId -InputObject $InputObject -ErrorAction Stop } | Should -Throw '*not associated with a WPF control context*'
        }
    }
}
