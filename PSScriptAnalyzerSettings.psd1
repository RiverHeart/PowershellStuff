@{
    IncludeDefaultRules = $true

    # Note: These rules are geared towards the WPF module and should probably be removed
    # if/when that module is migrated to a separate repository.
    Rules = @{
        # WARNING: This only applies to advanced cmdlets but it's better than nothing.
        PSProvideCommentHelp = @{
            Enable = $true
            ExportedOnly = $false
            BlockComment = $true
            VSCodeSnippetCorrection = $false
            Placement = 'before'
        }
        PSUseCorrectCasing = @{
            Enable        = $true
            CheckCommands = $true
            CheckKeyword  = $true
            CheckOperator = $true
        }
        PSUseCompatibleSyntax = @{
            Enable = $true
            TargetVersions = @('PowerShellCore', 'PowerShellDesktop')
        }
        PSUseCompatibleCmdlets = @{
            compatibility = 'desktop-5.1.14393.206-windows'
        }
        PSUseCompatibleCommands = @{
            compatibility = 'win-48_x64_10.0.17763.0_5.1.17763.316_x64_4.0.30319.42000_framework'
        }
        PSUseCompatibleTypes = @{
            compatibility = 'win-48_x64_10.0.17763.0_5.1.17763.316_x64_4.0.30319.42000_framework'
        }
    }

    ExcludeRules = @(
        # Well meaning but antiquated and dogmatic to a fault.
        #
        # Verb conventions are good and should be followed when applicable, but modern-day
        # cmdlet discovery is driven by internet searches rather than `Get-Command`, so strict
        # adherence to this rule is more posturing than practical.
        #
        # The lack of an exhaustive list of approved verbs also contributes to hacks such as
        # using 'Invoke' for everything or using the semantic meaning of a verb over its
        # official meaning.
        'PSUseApprovedVerbs'

        # Used to be an issue in earlier versions of PowerShell, but is no longer a problem in modern versions.
        'PSAvoidUsingWriteHost'

        # Proxy functions are a legitimate use case.
        'PSAvoidOverwritingBuiltInCmdlets'

        # Not everything using 'New' changes state, sometimes it's just a factory method.
        'PSUseShouldProcessForStateChangingFunctions'

        # $Sender and $Event are the expected parameter names for event handlers.
        #
        # In the context of the WPF module, using conventional parameter names for
        # event handlers is more beneficial than not.
        'PSAvoidAssignmentToAutomaticVariable'

        # Explicit parameters may be required or provide clarity on availability
        # despite not being used in the function body.
        #
        # In the context of the WPF module, showing the available parameters for
        # event handlers is more beneficial than hiding them.
        'PSReviewUnusedParameter'

        # Basically useless when working with PowerShell classes in modules as class definitions
        # defined in separate files are not analyzed and will never be found.
        'TypeNotFound',

        # Produces false positive for the 'Command' DSL keyword.
        'PSAvoidUsingCmdletAliases'
    )
}
