$ErrorActionPreference = 'Stop'

# MARK: TRAN WINDOW
enum TransitionWindow {
    BEFORE_TRANSITION
    ON_TRANSITION
    AFTER_TRANSITION
    ON_EXIT
    ON_ENTER
}

# MARK: STATE MACHINE
class StateMachine {
    [string] $ActiveState
    [string] $PreviousState
    [hashtable] $TransitionTable
    [System.Diagnostics.Stopwatch] $Timer = [System.Diagnostics.Stopwatch]::new()
    # Hashtable of tuple, hashtable[] values corresponding the the TransitionWindow values
    [hashtable] $Handlers = @{}

    StateMachine(
        [string] $InitialState,
        [hashtable] $TransitionTable
    ) {
        $this.ActiveState = $InitialState
        $this.TransitionTable = $TransitionTable
        $this.Timer.Start()
    }
}

class TransitionEvent {
    [string] $EventType
    [StateMachine] $StateMachine
    [TransitionWindow] $TransitionWindow = [TransitionWindow]::ON_TRANSITION

    TransitionEvent(
        [string] $EventType,
        [StateMachine] $StateMachine
    ) {
        $this.EventType = $EventType
        $this.StateMachine = $StateMachine
    }

    TransitionEvent(
        [string] $EventType,
        [StateMachine] $StateMachine,
        [TransitionWindow] $TransitionWindow
    ) {
        $this.EventType = $EventType
        $this.StateMachine = $StateMachine
        $this.TransitionWindow = $TransitionWindow
    }
}

class StateManagement {
    # Process array of events
    static [void] ProcessEvents([TransitionEvent[]] $TransitionEvents) {
        foreach ($TransitionEvent in $TransitionEvents) {
            [StateManagement]::Transition($TransitionEvent.EventType, $TransitionEvent.StateMachine)
        }
    }

    # Process an individual event
    static [void] ProcessEvent([TransitionEvent] $TransitionEvent) {
        # Transition
        [StateManagement]::Transition($TransitionEvent.EventType, $TransitionEvent.StateMachine)
    }

    static [void] ProcessEvent([string] $EventType, [StateMachine] $StateMachine) {
        [StateManagement]::Transition($EventType, $StateMachine)
    }

	static [bool] CanTransition([string] $EventType, [StateMachine] $StateMachine)
	{
        $Key = [System.Tuple]::Create($StateMachine.ActiveState, $EventType)
        return $StateMachine.TransitionTable.ContainsKey($Key)
	}

    static [hashtable] GetTransition([string] $EventType, [StateMachine] $StateMachine)
	{
        $Key = [System.Tuple]::Create($StateMachine.ActiveState, $EventType)
        if ($StateMachine.TransitionTable.ContainsKey($Key)) {
            return $StateMachine.TransitionTable[$Key]
        }
        return @{}
	}
	
	static [StateMachine] Transition([string] $EventType, [StateMachine] $StateMachine)
    {
        # Process TransitionWindow::BEFORE_TRANSITION handlers
        [StateManagement]::InvokeHandlers([TransitionWindow]::BEFORE_TRANSITION, $EventType, $StateMachine)

        # Validate transition can occur
        $Key = [System.Tuple]::Create($StateMachine.ActiveState, $EventType)
        if (-not $StateMachine.TransitionTable.ContainsKey($Key)) {
            Write-Host "Invalid transition from '$($StateMachine.ActiveState)' with event '$EventType'"
            return $StateMachine
        }

        $StateMachine.PreviousState = $StateMachine.ActiveState
        $StateMachine.ActiveState = $StateMachine.TransitionTable[$Key]
        $StateMachine.Timer.Restart()
        Write-Host "Transitioned to state: $($StateMachine.ActiveState)"

        # Process TransitionWindow::AFTER_TRANSITION handlers
        [StateManagement]::InvokeHandlers([TransitionWindow]::AFTER_TRANSITION, $EventType, $StateMachine)

        # Process on_exit for the old state
        [StateManagement]::InvokeHandlers([TransitionWindow]::ON_EXIT, $EventType, $StateMachine)

        # Process on_enter for the new state
        [StateManagement]::InvokeHandlers([TransitionWindow]::ON_ENTER, $EventType, $StateMachine)

        return $StateMachine
    }

    static [void] InvokeHandlers(
        [TransitionWindow] $TransitionWindow,
        [string] $EventType,
        [StateMachine] $StateMachine
    ) {
        $Key = [System.Tuple]::Create($TransitionWindow, $EventType)
        if ($StateMachine.Handlers.ContainsKey($Key)) {
            Write-Host "Processing handlers for '$Key'"
            foreach($Handler in $StateMachine.Handlers[$Key]) {
                try {
                    $Handler.Invoke()
                } catch {
                    Write-Host "Handler failed with error: $_"
                }
            }
        }
    }

    static [void] AddTransitions([hashtable[]] $Transitions, [StateMachine] $StateMachine) {
        foreach($Transition in $Transitions) {
            [StateManagement]::AddTransition($Transition.ActiveState, $Transition.Event, $Transition.TargetState, $StateMachine)
        }
    }

    static [void] AddTransition([string] $ActiveState, [string] $EventType, [string] $TargetState, [StateMachine] $StateMachine)
    {
        $Key = [System.Tuple]::Create($ActiveState, $EventType)
        if ($StateMachine.TransitionTable.ContainsKey($Key)) {
            Write-Host "Transition '$Key' -> '$TargetState' already exits."
        } else {
            Write-Host "Adding transition '$Key' -> '$TargetState'"
            $StateMachine.TransitionTable.Add($Key, $TargetState)
        }
    }

    static [void] RemoveTransitions([hashtable[]] $Transitions, [StateMachine] $StateMachine) {
        foreach($Transition in $Transitions) {
            [StateManagement]::RemoveTransition($Transition.ActiveState, $Transition.Event, $StateMachine)
        }
    }

    static [void] RemoveTransition([string] $State, [string] $EventType, [StateMachine] $StateMachine)
    {
        $Key = [System.Tuple]::Create($State, $EventType)
        if ($StateMachine.TransitionTable.ContainsKey($Key)) {
            Write-Host "Removing transition '$Key'"
            $StateMachine.TransitionTable.Remove($Key)
        } else {
            Write-Host "Transition '$Key' not found"
        }
    }
}


# MARK: NEW TUPLE
function New-Tuple {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification='Does not alter system state.')]
    [Alias('tuple')]
    [Alias('~')]
    param()

    $Tuple = [System.Tuple]::Create.Invoke($args)

    return $Tuple
}


# MARK: SCRATCHPAD
function Scratchpad {

    # Using a dictionary where keys are (ActiveState, EventType) tuples
    # and values are the next_state.
    $TransitionTableDict = @{
        (tuple 'idle' 'start') = 'running'
        (tuple 'running' 'stop') = 'idle'
        (tuple 'running' 'pause') = 'paused'
        (tuple 'paused' 'resume') = 'running'
        (tuple 'paused' 'stop') = 'idle'
    }

    # Using a list of dictionaries, where each dictionary represents a transition rule.
    $TransitionTableList = @(
        @{ ActiveState = 'idle'; Event = 'start'; TargetState = 'running'},
        @{ ActiveState = 'running'; Event = 'stop'; TargetState = 'idle'},
        @{ ActiveState = 'running'; Event = 'pause'; TargetState = 'paused'},
        @{ ActiveState = 'paused'; Event = 'resume'; TargetState = 'running'},
        @{ ActiveState = 'paused'; Event = 'stop'; TargetState = 'idle'}
    )

    # Example usage
    $MobilityFSM = [StateMachine]::new('idle', $TransitionTableDict)
    $StanceFSM = [StateMachine]::new('standing', @{})

    [StateManagement]::ProcessEvent('start', $MobilityFSM)    # Output: Transitioned to state: running
    [StateManagement]::ProcessEvent('pause', $MobilityFSM)    # Output: Transitioned to state: paused
    [StateManagement]::ProcessEvent('resume', $MobilityFSM)   # Output: Transitioned to state: running
    [StateManagement]::ProcessEvent('stop', $MobilityFSM)     # Output: Transitioned to state: idle
    [StateManagement]::ProcessEvent('invalid', $MobilityFSM)  # Output: Invalid transition from idle with event invalid

    [StateManagement]::AddTransition('standing', 'crouch', 'crouching', $StanceFSM)
    [StateManagement]::AddTransition('crouching', 'stand', 'standing', $StanceFSM)
}

# Ignore scratchpad if sourcing
if ($MyInvocation.InvocationName -ne '.') {
    Scratchpad
}
