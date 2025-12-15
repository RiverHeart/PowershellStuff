@{
    # Disable stupid rules
    ExcludeRules = @(
        'PSUseApprovedVerbs',
        'PSAvoidUsingWriteHost',
        'PSAvoidOverwritingBuiltInCmdlets'
        'PSUseShouldProcessForStateChangingFunctions'
    )
}
