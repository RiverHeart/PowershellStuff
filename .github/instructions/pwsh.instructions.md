---
name: PowerShell Coding Style
description: This file describes the PowerShell coding style for the project.
applyTo: "**/*.{ps1,psm1,psd1}"
---

# Function Help Comments
- Write comment-based help **above** the function definition, not inside it.

```powershell
# Correct
<#
.SYNOPSIS
    Does a thing.
#>
function Invoke-Thing { ... }

# Incorrect
function Invoke-Thing {
    <#
    .SYNOPSIS
        Does a thing.
    #>
}
```

# Param Block Formatting
- Use the following formatting for param blocks, with each parameter on its own line and attributes properly aligned for readability.
- If a `[Parameter()]` arg would take a boolean, include or exclude the name to indicate true and false. For example, instead of `[Parameter(Mandatory=$true)]`, use `[Parameter(Mandatory)]`.

```powershell
param (
    [Parameter(Mandatory,ValueFromPipeline)]
    [ValidateNotNullOrEmpty()]
    [string] $InputObject,

    [Parameter(Mandatory)]
    [ValidateSet('A', 'B')]
    [string] $Mode,

    [switch] $OptionalParam
)
```
