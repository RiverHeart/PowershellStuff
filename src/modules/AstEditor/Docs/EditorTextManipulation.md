# Editor Text Manipulation

## Overview

[Like A Script Monkey in the Syntax Tree](https://youtu.be/NtdIyLHpYJ0?si=7m68NtuX96G01JRp) by Walter Legowski is an interesting example of editor manipulation with Powershell ISE or VSCode that I hadn't realized was possible. In his demo, he showcases the ability to manipulate text in the active file via methods exposed by `$psISE.CurrentFile.Editor` and `$PSEditor.GetEditorContext().CurrentFile`.

If you call `$PSEditor.GetEditorContext().CurrentFile.InsertText('foo')` on a PowerShell file it will append 'foo' to the file contents in the editor. From there, it's not difficult to imagine how you could use `$PSEditor.GetEditorContext().CurrentFile.Ast` to get the coordinates for more targeted edits. Fortunately or unfortunately, depending on your perspective, Copilot doesn't have access to `$PSEditor` so replacing patch edits with structured editing cmdlets isn't easily achieved.

`$PSEditor` exposes `RegisterCommand()` and `UnregisterCommand()` methods but cmdlet equivalents `Register-EditorCommand` and `Unregister-EditorCommand` are also available through the `PowerShellEditorServices.Commands` module. Sadly, there is no `Get-EditorCommand` just `GetCommands()`. Registered commands can be listed and invoked through the native command `PowerShell: Show Additional Commands from PowerSell Module`.

With Powershell Editor Services, you can create a command from a callable (scriptblock or function) which you can later invoke in the context of the Powershell Extension.

```powershell
Register-EditorCommand `
    -Name "Foo" `
    -DisplayName "Foo" `
    -ScriptBlock { Write-Host "Foo" }
```

Below is a more advanced example demonstrating text replacement. As an aside, if ever there was an argument against type safety it'd be the types in this example. I've never seen this comma delimited syntax before; quite odd. The type for `$EditorContext` isn't strictly necessary but the one for getting the `$SelectionBuffer` seems to be.

```powershell
$Macro = {
    param(
        [Microsoft.PowerShell.EditorServices.Extensions.EditorContext, Microsoft.PowerShell.EditorServices] $EditorContext
    )

    $CurrentFile = $EditorContext.CurrentFile
    $SelectedRange = $EditorContext.SelectedRange

    # A GetSelectedText() method doesn't seem to exist...
    $SelectionBuffer = [Microsoft.PowerShell.EditorServices.Extensions.FileRange, Microsoft.PowerShell.EditorServices]::new(
        $SelectedRange.Start,
        $SelectedRange.End
    )

    $SelectedText = $CurrentFile.GetText($SelectionBuffer)
    $ReplacementText = "New Text"

    if ($SelectedText) {
        $CurrentFile.InsertText($ReplacementText, $SelectedRange)
    }
}

Register-EditorCommand `
    -Name "ReplaceSelectedText" `
    -DisplayName "Replace Selected Text" `
    -ScriptBlock $Macro
```

Module authors can test for and register commands on module load by checking for the ambient variable `$PSEditor` and registering the command. Unsure whether this is desirable on the part of the user but module authors should at least unregister commands when their module is removed. 

```powershell
if ($PSEditor) {
    Register-EditorCommand `
        -Name "Foo" `
        -DisplayName "Foo" `
        -ScriptBlock { Write-Host "Foo" }

    $PSModule = $ExecutionContext.SessionState.Module
    $PSModule.OnRemove = {
        Unregister-EditorCommand -Name "Foo"
    }
}
```

Unfortunately, I don't know how I can make use of this yet. The blog listed in the `References` section shows that you can set a keybinding that can invoke your registered command to save you some effort but unless you actually need access to the in-memory file content you could probably create a VSCode task that calls a script against the active file. You also have snippets for basic text insertion tasks. So yeah, it's interesting that the mechanisms exist but unclear to me when you'd want to use them.

## References

https://jdhitsolutions.com/blog/powershell/5907/extending-vscode-with-powershell/
