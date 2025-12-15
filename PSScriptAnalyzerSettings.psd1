@{
    # Disable stupid rules
    ExcludeRules = @(
        # Dogmatic nonsense
        'PSUseApprovedVerbs'

        # Used to be an issue, not anymore
        'PSAvoidUsingWriteHost'

        # I'll use proxy functions if I want
        'PSAvoidOverwritingBuiltInCmdlets'

        # Not everything using 'New' changes state
        'PSUseShouldProcessForStateChangingFunctions'

        # Annoying and practically useless when working with
        # powershell classes in modules
        'TypeNotFound'
    )
}
