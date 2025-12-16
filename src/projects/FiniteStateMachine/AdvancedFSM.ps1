$ErrorActionPreference = 'Stop'


# MARK: TRAN WINDOW
enum StateTransitionWindow {
    BEFORE_TRANSITION
    ON_TRANSITION
    AFTER_TRANSITION
    ON_EXIT
    ON_ENTER
}

# MARK: STATE MACHINE
class StateMachine {
    [object] $ActiveState
    [object] $PreviousState
    [hashtable] $Transitions
    [System.Diagnostics.Stopwatch] $Timer = [System.Diagnostics.Stopwatch]::new()
    # Hashtable of tuple, hashtable[] values corresponding the the StateTransitionWindow values
    [hashtable] $Handlers = @{}

    StateMachine(
        [object] $InitialState,
        [hashtable] $Transitions
    ) {
        $this.ActiveState = $InitialState
        $this.Transitions = $Transitions
        $this.Timer.Start()
    }
}

# MARK: TRAN EVENT
class StateTransitionEvent {
    [object] $Event
    [StateMachine] $StateMachine
    [StateTransitionWindow] $StateTransitionWindow = [StateTransitionWindow]::ON_TRANSITION

    StateTransitionEvent(
        [StateMachine] $StateMachine,
        [object] $Event
    ) {
        $this.Event = $Event
        $this.StateMachine = $StateMachine
    }

    StateTransitionEvent(
        [StateMachine] $StateMachine,
        [string] $Event,
        [StateTransitionWindow] $StateTransitionWindow
    ) {
        $this.Event = $Event
        $this.StateMachine = $StateMachine
        $this.StateTransitionWindow = $StateTransitionWindow
    }
}

# MARK: STATE MGMT
class StateManagement {
    # This should be reading from a queue or something
    static [void] ProcessEvent([StateTransitionEvent[]] $StateTransitionEvents) {
        foreach ($StateTransitionEvent in $StateTransitionEvents) {
            [StateManagement]::Transition($StateTransitionEvent.StateMachine, $StateTransitionEvent.Event)
        }
    }

	static [bool] CanTransition([StateMachine] $StateMachine, [object] $Event)
	{
        $Key = [System.Tuple]::Create($StateMachine.ActiveState, $Event)
        return $StateMachine.Transitions.ContainsKey($Key)
	}

    static [hashtable] GetTransition([StateMachine] $StateMachine, [object] $Event)
	{
        $Key = [System.Tuple]::Create($StateMachine.ActiveState, $Event)
        if ($StateMachine.Transitions.ContainsKey($Key)) {
            return $StateMachine.Transitions[$Key]
        }
        return @{}
	}

	static [void] Transition([StateMachine[]] $StateMachine, [object] $Event)
    {
        foreach($Machine in $StateMachine) {
            # Process StateTransitionWindow::BEFORE_TRANSITION handlers
            [StateManagement]::InvokeHandlers($Machine, [StateTransitionWindow]::BEFORE_TRANSITION, $Event)

            # Validate transition can occur
            $Key = [System.Tuple]::Create($Machine.ActiveState, $Event)
            if (-not $Machine.Transitions.ContainsKey($Key)) {
                Write-Warning "Invalid transition from '$($Machine.ActiveState)' on event '$Event'"
                return
            }

            $Machine.PreviousState = $Machine.ActiveState
            $Machine.ActiveState = $Machine.Transitions[$Key]
            $Machine.Timer.Restart()
            Write-Verbose "Transitioned to state: $($Machine.ActiveState)"

            # Process StateTransitionWindow::AFTER_TRANSITION handlers
            [StateManagement]::InvokeHandlers($Machine, [StateTransitionWindow]::AFTER_TRANSITION, $Event)

            # Process on_exit for the old state
            [StateManagement]::InvokeHandlers($Machine, [StateTransitionWindow]::ON_EXIT, $Event)

            # Process on_enter for the new state
            [StateManagement]::InvokeHandlers($Machine, [StateTransitionWindow]::ON_ENTER, $Event)
        }
    }

    static [void] InvokeHandlers(
        [StateMachine[]] $StateMachine,
        [StateTransitionWindow] $StateTransitionWindow,
        [object] $Event
    ) {
        $Key = [System.Tuple]::Create($StateTransitionWindow, $Event)

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
        [object] $From,
        [object] $Event,
        [object] $To
    ) {
        $Key = [System.Tuple]::Create($From, $Event)

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
        [object] $State,
        [object] $Event
    ) {
        $Key = [System.Tuple]::Create($State, $Event)

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

# MARK: NEW-SM
function New-FSMStateMachine {
    [CmdletBinding()]
    [OutputType([StateTransitionEvent])]
    param(
        [Parameter(Mandatory)]
        [object] $InitialState,

        [hashtable] $Transitions = @{}
    )

    return [StateMachine]::new($InitialState, $Transitions)
}

# MARK: NEW-SMT
function New-FSMTransitionEvent {
    [CmdletBinding()]
    [OutputType([StateTransitionEvent])]
    param (
        [Parameter(Mandatory)]
        [StateMachine] $StateMachine,

        [Parameter(Mandatory)]
        [object] $Event
    )

    return [StateTransitionEvent]::new($StateMachine, $Event)
}

# MARK: ADD-ST
function Add-FSMTransition {
    [CmdletBinding(SupportsShouldProcess,DefaultParameterSetName='ByProperty')]
    param(
        [Parameter(Mandatory,ParameterSetName='ByProperty',ValueFromPipeline)]
        [Parameter(Mandatory,ParameterSetName='ByHashtable',ValueFromPipeline)]
        [StateMachine] $StateMachine,

        [Parameter(Mandatory,ParameterSetName='ByProperty')]
        [object] $From,

        [Parameter(Mandatory,ParameterSetName='ByProperty')]
        [object] $OnEvent,

        [Parameter(Mandatory,ParameterSetName='ByProperty')]
        [object] $To,

        [Parameter(ParameterSetName='ByHashtable')]
        [hashtable] $Transitions
    )

    process {
        if ($PSCmdlet.ParameterSetName -eq 'ByHashtable') {
            # Parameter validation attributes are still in effect
            $From = $Transition.From
            $OnEvent = $Transition.Event
            $To = $Transitions.To
        }

        if ($PSCmdlet.ShouldProcess($StateMachine, "Adding transition '$From' -> '$To' on '$OnEvent'")) {
            [StateManagement]::AddTransition($StateMachine, $From, $OnEvent, $To)
        }
    }
}

# MARK: REM-ST
function Remove-FSMTransition {
    [CmdletBinding(SupportsShouldProcess,DefaultParameterSetName='ByProperty')]
    param(
        [Parameter(Mandatory,ParameterSetName='ByProperty',ValueFromPipeline)]
        [Parameter(Mandatory,ParameterSetName='ByHashtable',ValueFromPipeline)]
        [StateMachine] $StateMachine,

        [Parameter(Mandatory,ParameterSetName='ByProperty')]
        [ValidateScript({ -not [String]::IsNullOrEmpty($_.Trim()) })]
        [object] $From,

        [Parameter(Mandatory,ParameterSetName='ByProperty')]
        [ValidateScript({ -not [String]::IsNullOrEmpty($_.Trim()) })]
        [object] $Event,

        [Parameter(Mandatory,ParameterSetName='ByHashtable')]
        [hashtable] $Transitions
    )

    process {
        if ($PSCmdlet.ParameterSetName -eq 'ByHashtable') {
            # Parameter validation attributes are still in effect
            $From = $Transitions.From
            $Event = $Transitions.Event
        }

        if ($PSCmdlet.ShouldProcess($StateMachine, "Removing transition '$From' for event '$Event'")) {
            [StateManagement]::RemoveTransition($StateMachine, $From, $Event)
        }
    }
}

# MARK: SET-FSMSTATE
function Invoke-FSMTransition {
    [CmdletBinding(DefaultParameterSetName='ByStateMachine')]
    [OutputType([void])]
    param(
        [Parameter(Mandatory,ParameterSetName='ByStateMachine',ValueFromPipeline)]
        [StateMachine[]] $StateMachine,

        [Parameter(Mandatory,ParameterSetName='ByStateMachine',Position=0)]
        [ValidateNotNullOrEmpty()]
        [object] $Event,

        [Parameter(Mandatory,ParameterSetName='ByTransitionEvent')]
        [StateTransitionEvent[]] $TransitionEvent
    )

    process {
        if ($PScmdlet.ParameterSetName -eq 'ByTransitionEvent') {
            [StateManagement]::Transition($TransitionEvent.StateMachine, $TransitionEvent.Event)
        } else {
            [StateManagement]::Transition($StateMachine, $Event)
        }
    }
}


# MARK: NEW-TRANTABLE
function New-FSMTransitionTable {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param (
        [Parameter(Mandatory,ValueFromPipeline)]
        [Array[]] $Transitions
    )

    begin {
        $TransitionTable = @{}
        $ErrorsFound = $False
    }

    process {
        foreach($Transition in $Transitions) {
            if ($Transition.Count -lt 3 -or $Transition.Count -gt 3) {
                Write-Error "Transitions can only contain 3 elements."
                $ErrorsFound = $true
                return
            }
            $Key = [System.Tuple]::Create($Transition[0], $Transition[1])
            $TransitionTable.Add($Key, $Transition[2])
        }
    }

    end {
        if ($ErrorsFound) {
            return @{}
        }
        return $TransitionTable
    }
}

# MARK: NEW-TUPLE
function New-Tuple {
    [Alias('tuple')]
    [Alias('~')]
    param()

    $Tuple = [System.Tuple]::Create.Invoke($args)

    return $Tuple
}

# MARK: SCRATCHPAD
function Scratchpad {
    #=================
    # Example usage
    #=================

    $VerbosePreference = 'Continue'

    enum MoveState {
        IDLING
        RUNNING
        PAUSED
    }

    # Using a list of dictionaries, where each dictionary represents a transition rule.
    $TransitionTable = New-FSMTransitionTable @(
        @([MoveState]::IDLING, 'start', [MoveState]::RUNNING),
        @([MoveState]::RUNNING, 'stop', [MoveState]::IDLING),
        @([MoveState]::RUNNING,  'pause', [MoveState]::PAUSED),
        @([MoveState]::PAUSED, 'resume', [MoveState]::RUNNING),
        @([MoveState]::PAUSED, 'stop', [MoveState]::IDLING)
    )

    $MobilityFSM = New-FSMStateMachine -InitialState ([MoveState]::IDLING) -Transitions $TransitionTable
    $StanceFSM = New-FSMStateMachine 'standing'

    $MobilityFSM | Invoke-FSMTransition -Event 'start'  # Output: Transitioned to state: running
    $MobilityFSM | Invoke-FSMTransition -Event 'pause'  # Output: Transitioned to state: paused
    $MobilityFSM | Invoke-FSMTransition -Event 'resume' # Output: Transitioned to state: running
    $MobilityFSM | Invoke-FSMTransition -Event 'stop'   # Output: Transitioned to state: idle
    $MobilityFSM | Invoke-FSMTransition -Event 'invalid'  # Output: Invalid transition from idle with event invalid

    $StanceFSM | Add-FSMTransition -From 'standing' -OnEvent 'crouch' -To 'crouching'
    $StanceFSM | Add-FSMTransition -From 'crouching' -OnEvent 'crouch' -To 'standing'
}

# Boilerplate to detect if this script is being
# sourced or run.
$TopLevelScript = Get-PSCallStack | Where-Object { $_.ScriptName } | Select-Object -Last 1
$IsTopLevelScript = $TopLevelScript.Command -eq $MyInvocation.MyCommand.Name
$IsMain = $IsTopLevelScript -and $MyInvocation.InvocationName -ne '.'
$IsMainInVSCode = (
    $IsTopLevelScript -and
    $Host.Name -eq 'Visual Studio Code Host' -and
    $MyInvocation.CommandOrigin -eq 'Internal'
)
if ($IsMain -or $IsMainInVSCode) {
    Scratchpad
}
