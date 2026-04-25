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

        # This is just annoying when working with events and callbacks
        'PSAvoidAssignmentToAutomaticVariable'

        # Parameters may be required or available despite not being used in the function body
        'PSReviewUnusedParameter'

        # Annoying and practically useless when working with
        # powershell classes in modules
        'TypeNotFound'
    )
}
