function New-FSMStateMachine {
    [CmdletBinding()]
    [OutputType([StateTransitionEvent])]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({ -not [String]::IsNullOrEmpty($_.Trim()) })]
        [string] $InitialState,

        [hashtable] $Transitions = @{}
    )

    return [StateMachine]::new($InitialState, $Transitions)
}
