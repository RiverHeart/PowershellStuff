# TabCentral

TabCentral provides a central hook registry for PowerShell tab completion.
It exposes a `TabExpansion2` wrapper that can run registered completer and
modifier hooks when explicitly enabled.

## Design

- WPF-agnostic core module.
- Explicit opt-in behavior via `Enable-TabCentral` and `Disable-TabCentral`.
- Module-scoped hook registry accessed through public hook cmdlets.

## Quick Start

```powershell
Import-Module TabCentral

# Explicitly enable TabCentral hook processing for this session.
Enable-TabCentral

# Confirm active hooks.
Get-TabCentralHook
```

Disable at any time:

```powershell
Disable-TabCentral
```

## Session Behavior

On import, TabCentral initializes `$Global:TabCentralEnabled` to `$false` only
if the variable is not already defined. This lets callers set defaults in their
profile while preserving explicit session control.

## Profile Default

Add this to your PowerShell profile if you want TabCentral enabled by default:

```powershell
Import-Module TabCentral
$Global:TabCentralEnabled = $true
```

If you want the module loaded but disabled by default:

```powershell
Import-Module TabCentral
$Global:TabCentralEnabled = $false
```

## Hook Registration

TabCentral supports two registration styles:

- Direct registration with `-Name`, `-Type`, and `-ScriptBlock`.
- Descriptor pipeline registration, for example:
	`Get-WPFTabCentralHook | Register-TabCentralHook`.

### Descriptor Contract

When using pipeline registration, each object should include:

- `Name` (string, required)
- `Type` (`Completer` or `Modifier`, required)
- `Callable` (script block, function, or cmdlet, preferred) or `ScriptBlock` (script block, supported for compatibility)
- `Source` (string, optional)

Register a completer hook:

```powershell
Register-TabCentralHook -Name 'Complete-Example' -Type Completer -ScriptBlock {
	param(
		[string] $inputScript,
		[int] $cursorColumn,
		[System.Management.Automation.Language.Ast] $ast,
		[System.Management.Automation.Language.Token[]] $tokens,
		[System.Management.Automation.Language.IScriptPosition] $positionOfCursor,
		[hashtable] $options
	)

	# Return $null when your hook does not apply.
	return $null
}
```

Register a modifier hook:

```powershell
Register-TabCentralHook -Name 'Modify-Example' -Type Modifier -ScriptBlock {
	param([System.Management.Automation.CommandCompletion] $CommandCompletion)

	# Return a single CommandCompletion instance.
	return $CommandCompletion
}
```

List and remove hooks:

```powershell
Get-TabCentralHook
Unregister-TabCentralHook -Name 'Complete-Example' -Type Completer
```

Register from descriptors returned by another module:

```powershell
Get-WPFTabCentralHook | Register-TabCentralHook -Force
```

Validate descriptors before registration:

```powershell
Get-WPFTabCentralHook | Test-TabCentralHookDescriptor
Get-WPFTabCentralHook | Test-TabCentralHookDescriptor -PassThru | Register-TabCentralHook -Force
```

## Cross-Module Integration Example

A module can import TabCentral and register hooks only when TabCentral is
available, without taking a hard dependency on WPF or any specific DSL.

```powershell
if (Get-Module -ListAvailable -Name TabCentral) {
	Import-Module TabCentral -ErrorAction Stop

	Register-TabCentralHook -Name 'Complete-MyModule' -Type Completer -ScriptBlock {
		param(
			[string] $inputScript,
			[int] $cursorColumn,
			[System.Management.Automation.Language.Ast] $ast,
			[System.Management.Automation.Language.Token[]] $tokens,
			[System.Management.Automation.Language.IScriptPosition] $positionOfCursor,
			[hashtable] $options
		)

		# Return a CommandCompletion when matched, else $null.
		return $null
	}
}
```

## Troubleshooting

- If completion behavior looks unchanged, run `Enable-TabCentral`.
- If a hook throws, TabCentral catches and logs debug output, then falls back to
  standard completion behavior.
- To clear all hooks, run `Reset-TabExpansion2`.
