# RelayCommand Syntax Proposal

## Goal

Add a command pattern that matches the existing DSL shape:

- keyword + initializer arguments + one trailing script block
- child keywords inside the block for behavior

This proposal keeps command wiring explicit in author code while still allowing backend implementation details (RelayCommand creation, event hookup, and CanExecute refresh) to stay internal.

## Proposed Syntax

Define named commands in the UI tree with one script block and two optional child blocks:

```powershell
RelayCommand 'SaveAs' {
    CanExecute {
        (Reference 'Window').Tag.IsFileLoaded
    }
    Execute {
        $BitmapSource = Reference 'Viewer' -Property Source
        Invoke-ImageViewerSaveFileAs -Image $BitmapSource
    }
}
```

Attach the command by name where needed:

```powershell
MenuItem '(F)ile/(S)ave As' {
    Shortcut 'SaveAs' 'Ctrl+Shift+S'
}

Button 'SaveButton' {
    Shortcut 'SaveAs'
}
```

## Behavior Contract

- RelayCommand Name:
  - Required and unique within the current window scope.
- Execute:
  - Required.
  - Runs in the current DSL execution context.
- CanExecute:
  - Optional.
  - Defaults to always true when omitted.
- Shortcut binding:
  - Uses the named command if present.
  - Keeps existing input gesture behavior.
- Enabled state:
  - Controls bound to the command should reflect CanExecute automatically.

## Why This Fits The DSL

- Preserves the one-scriptblock style used across the module.
- Avoids the awkward adjacent-scriptblock signature.
- Keeps command intent visible near UI definitions.
- Reuses a command across menu items, buttons, and key gestures without duplicating enablement checks.

## Minimal Implementation Shape

1. Keep New-WPFRelayCommand internal and backend-oriented.
2. Add RelayCommand DSL keyword that:
   - registers command name
   - captures Execute and optional CanExecute scriptblocks
   - materializes the underlying RelayCommand object
3. Update Shortcut and command-aware controls to resolve and attach a named command.
4. Ensure command invalidation hooks exist for state changes that affect CanExecute.

## Open Design Questions

- Scope rules for command lookup:
  - Window-global only, or support nested/local command scopes?
- CanExecute refresh strategy:
  - Explicit refresh API only, or also hook common state updates?
- Error behavior:
  - Fail fast on missing Execute or duplicate command name?

## Non-Goals For First Iteration

- Inline command sugar inside Shortcut.
- Advanced routing features beyond current DSL needs.
- Multiple CanExecute blocks or composition syntax.

## Suggested First Adoption Target

Use ImageViewer Save As as the pilot command:

```powershell
RelayCommand 'SaveAs' {
    CanExecute {
        (Reference 'Window').Tag.IsFileLoaded
    }
    Execute {
        $BitmapSource = Reference 'Viewer' -Property Source
        $CurrentFile = (Reference 'Window').Tag.FileNavigator.CurrentFile
        $SourcePath = if ($null -ne $CurrentFile) { $CurrentFile.FullName } else { $null }
        $InitialDirectory = if ($null -ne $CurrentFile) { $CurrentFile.DirectoryName } else { $null }

        Invoke-ImageViewerSaveFileAs `
            -Image $BitmapSource `
            -SourcePath $SourcePath `
            -InitialDirectory $InitialDirectory
    }
}

MenuItem '(F)ile/(S)ave As' {
    Shortcut 'SaveAs' 'Ctrl+Shift+S'
}
```

This provides a concrete can-execute scenario and keeps migration risk low.
