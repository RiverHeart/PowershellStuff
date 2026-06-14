# Async Context Pinning in Timer Callbacks

## Problem

When you use `DispatcherTimer` or other async callbacks in the DSL, context resolution can drift to the wrong window.

### Why This Happens

DSL helpers like `Get-WPFWindow` and `Reference` use smart context resolution:
1. If a ContextId is provided explicitly, use it.
2. If called from an object ($this), resolve from that object's context.
3. If neither, resolve from the "current active DSL context" (the most recently created/focused window).

In synchronous code (event handlers, direct commands), this works well because $this is bound and the "active context" is the window you're in.

But in async callbacks (timer ticks, delayed operations), **there is no $this binding**, and "active context" may have changed. If another window was created or focused while the timer was waiting, the callback may resolve helpers against the wrong window.

```powershell
# Example: slideshow timer tick resolves to wrong window if another window became active
Invoke-ImageViewerNavigate -Direction Forward
# ^ Without ContextId, Get-WPFWindow inside this might resolve to a different window
```

## Solution: Capture Once, Reuse

When setting up an async callback, capture the window's ContextId once and pass it explicitly to all downstream calls:

```powershell
function Start-ImageViewerSlideshow {
    param(
        [double] $IntervalSeconds,
        [ValidateNotNullOrEmpty()]
        [string] $ContextId
    )

    $Window = Get-WPFWindow -ContextId $ContextId -ErrorAction Stop
    if (-not $ContextId) {
        $ContextId = Get-WPFContextId -InputObject $Window -ErrorAction Stop
    }

    # Capture ContextId ONCE before creating the timer
    $TimerContextId = $ContextId

    $Timer = [System.Windows.Threading.DispatcherTimer]::new()

    $null = $Timer.add_Tick({
        # Use captured ContextId in all async callback code
        Invoke-ImageViewerNavigate -Direction Forward -ContextId $TimerContextId
        Invoke-ImageViewerUpdateStatus -Window $TimerWindow  # or pass -ContextId
    }.GetNewClosure())

    # ... rest of setup ...
}
```

### Key Points

1. **Capture once**: Get the ContextId at setup time, before async code runs.
2. **Pass explicitly**: Always include `-ContextId $CapturedId` in downstream helper calls.
3. **Use GetNewClosure()**: Ensure captured variables are properly closed over in the script block.
4. **Fail fast**: Use `-ErrorAction Stop` during initial context resolution so errors surface immediately, not in a delayed callback.

## When This Matters

- **Always needed**: DispatcherTimer, any delayed async operations
- **Not needed**: Synchronous event handlers (Key, When Click, etc.) where $this is bound
- **Bonus safety**: Even synchronous code can pass ContextId for defensive clarity

## Example: Figure Drawing Mode

```powershell
# Setup: capture once
$Window = Get-WPFWindow -ErrorAction Stop
$TimerContextId = Get-WPFContextId -InputObject $Window -ErrorAction Stop

# Timer callback: reuse pinned context
$null = $Timer.add_Tick({
    Invoke-ImageViewerNavigate -Direction Forward -ContextId $TimerContextId
    Invoke-ImageViewerUpdateFigureDrawingCountdown -ContextId $TimerContextId
}.GetNewClosure())

# Countdown timer callback: same pattern
$null = $CountdownTimer.add_Tick({
    Invoke-ImageViewerUpdateFigureDrawingCountdown -ContextId $TimerContextId
}.GetNewClosure())
```

## See Also

- [Get-WPFWindow](KeywordReference.md#get-wpfwindow)
- [Get-WPFContextId](KeywordReference.md#get-wpfcontextid)
- [TimedEvent](KeywordReference.md#timedevent)
