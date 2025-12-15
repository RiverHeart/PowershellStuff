class StateMachine {
    [string] $ActiveState
    [string] $PreviousState
    [hashtable] $Transitions
    [System.Diagnostics.Stopwatch] $Timer = [System.Diagnostics.Stopwatch]::new()
    # Hashtable of tuple, hashtable[] values corresponding the the StateTransitionWindow values
    [hashtable] $Handlers = @{}

    StateMachine(
        [string] $InitialState,
        [hashtable] $Transitions
    ) {
        $this.ActiveState = $InitialState
        $this.Transitions = $Transitions
        $this.Timer.Start()
    }
}
