# Overview

This project experiments with custom PSHosts.

The immediate use case for such a thing is output suppression from tests without having to configure that specifically though the need to run the code in a new runspace might make that a no-go.

## Reading Material

* https://learn.microsoft.com/en-us/powershell/scripting/developer/hosting/host06-sample?view=powershell-7.6#see-also
* https://www.youtube.com/watch?v=B-uvhmbnMx4
* https://github.com/PowerShell/PowerShellEditorServices/blob/ba8b42071c097536d240e857b2b1cf3dcd1e1fbc/src/PowerShellEditorServices/Services/PowerShell/Host/NullPSHostUI.cs
