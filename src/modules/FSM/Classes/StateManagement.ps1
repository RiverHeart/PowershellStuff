class StateManagement {
    # This should be reading from a queue or something
    static [void] ProcessEvent([StateTransitionEvent[]] $StateTransitionEvents) {
        foreach ($StateTransitionEvent in $StateTransitionEvents) {
            [StateManagement]::Transition($StateTransitionEvent.StateMachine, $StateTransitionEvent.EventType)
        }
    }

	static [bool] CanTransition([StateMachine] $StateMachine, [string] $EventType)
	{
        $Key = [System.Tuple]::Create($StateMachine.ActiveState, $EventType)
        return $StateMachine.Transitions.ContainsKey($Key)
	}

    static [hashtable] GetTransition([StateMachine] $StateMachine, [string] $EventType)
	{
        $Key = [System.Tuple]::Create($StateMachine.ActiveState, $EventType)
        if ($StateMachine.Transitions.ContainsKey($Key)) {
            return $StateMachine.Transitions[$Key]
        }
        return @{}
	}

	static [void] Transition([StateMachine[]] $StateMachine, [string] $EventType)
    {
        foreach($Machine in $StateMachine) {
            # Process StateTransitionWindow::BEFORE_TRANSITION handlers
            [StateManagement]::InvokeHandlers($Machine, [StateTransitionWindow]::BEFORE_TRANSITION, $EventType)

            # Validate transition can occur
            $Key = [System.Tuple]::Create($Machine.ActiveState, $EventType)
            if (-not $Machine.Transitions.ContainsKey($Key)) {
                Write-Warning "Invalid transition from '$($Machine.ActiveState)' with event '$EventType'"
                return
            }

            $Machine.PreviousState = $Machine.ActiveState
            $Machine.ActiveState = $Machine.Transitions[$Key]
            $Machine.Timer.Restart()
            Write-Verbose "Transitioned to state: $($Machine.ActiveState)"

            # Process StateTransitionWindow::AFTER_TRANSITION handlers
            [StateManagement]::InvokeHandlers($Machine, [StateTransitionWindow]::AFTER_TRANSITION, $EventType)

            # Process on_exit for the old state
            [StateManagement]::InvokeHandlers($Machine, [StateTransitionWindow]::ON_EXIT, $EventType)

            # Process on_enter for the new state
            [StateManagement]::InvokeHandlers($Machine, [StateTransitionWindow]::ON_ENTER, $EventType)
        }
    }

    static [void] InvokeHandlers(
        [StateMachine[]] $StateMachine,
        [StateTransitionWindow] $StateTransitionWindow,
        [string] $EventType
    ) {
        $Key = [System.Tuple]::Create($StateTransitionWindow, $EventType)

        foreach($Machine in $StateMachine) {
            if ($Machine.Handlers.ContainsKey($Key)) {
                Write-Verbose "Processing handlers for '$Key'"
                foreach($Handler in $Machine.Handlers[$Key]) {
                    try {
                        $Handler.Invoke()
                    } catch {
                        Write-Warning "Handler failed with error: $_"
                    }
                }
            }
        }
    }

    static [void] AddTransition(
        [StateMachine[]] $StateMachine,
        [hashtable[]] $Transitions
    ) {
        foreach($Machine in $StateMachine) {
            foreach($Transition in $Transitions) {
                [StateManagement]::AddTransition(
                    $Machine,
                    $Transition.From,
                    $Transition.Event,
                    $Transition.To
                )
            }
        }
    }

    static [void] AddTransition(
        [StateMachine[]] $StateMachine,
        [string] $From,
        [string] $EventType,
        [string] $To
    ) {
        $Key = [System.Tuple]::Create($From, $EventType)

        foreach($Machine in $StateMachine) {
            if ($Machine.Transitions.ContainsKey($Key)) {
                Write-Verbose "Transition '$Key' -> '$To' already exits."
            } else {
                Write-Verbose "Adding transition '$Key' -> '$To'"
                $Machine.Transitions.Add($Key, $To)
            }
        }
    }

    static [void] RemoveTransition(
        [StateMachine[]] $StateMachine,
        [hashtable[]] $Transitions
    ) {
        foreach($Machine in $StateMachine) {
            foreach($Transition in $Transitions) {
                [StateManagement]::RemoveTransition($Machine, $Transition.From, $Transition.Event)
            }
        }
    }

    static [void] RemoveTransition(
        [StateMachine[]] $StateMachine,
        [string] $State,
        [string] $EventType
    ) {
        $Key = [System.Tuple]::Create($State, $EventType)

        foreach($Machine in $StateMachine) {
            if ($Machine.Transitions.ContainsKey($Key)) {
                Write-Verbose "Removing transition '$Key'"
                $Machine.Transitions.Remove($Key)
            } else {
                Write-Verbose "Transition '$Key' not found"
            }
        }
    }
}
