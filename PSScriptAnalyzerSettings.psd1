@{
    IncludeDefaultRules = $true
    Rules = @{
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

    # Disable stupid rules
    ExcludeRules = @(
        # Dogmatic nonsense
        'PSUseApprovedVerbs'

        # Used to be an issue in earlier versions of PowerShell, but is no longer a problem in modern versions.
        'PSAvoidUsingWriteHost'

        # Proxy functions are a legitimate use case this rule fails to account for.
        'PSAvoidOverwritingBuiltInCmdlets'

        # Not everything using 'New' changes state
        'PSUseShouldProcessForStateChangingFunctions'

        # $Sender and $Event are the expected parameters for event handlers.
        'PSAvoidAssignmentToAutomaticVariable'

        # Explicit parameters may be required or provide clarity on availability
        # despite not being used in the function body
        'PSReviewUnusedParameter'

        # Useless when working with powershell classes in modules
        'TypeNotFound',

        # Produces false positive for the 'Command' DSL keyword
        'PSAvoidUsingCmdletAliases'
    )
}
