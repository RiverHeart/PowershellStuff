<#
.NOTE
    This is going to be difficult to implement nicely so I'll likely need to come
    back to this later.

    Implementation difficulties:

    AllocConsole() fails with ERROR_ACCESS_DENIED (0x5) when called from the main
    process because it already has a console allocated (the Powershell console) and
    Windows does not allow multiple consoles for a single process.

    We could work around this by running the UI in a background runspace so the existing
    console is shared by the REPL and the UI (for logging) but logs will be
    interleaved with user input which is not ideal.

    Since our "logging" is just bog-standard Write-Foo calls we can't just flip
    a switch to log to a file and tail that in a separate console. Named pipes
    are an option but I don't like the idea. Writing logs to memory is just asking for
    trouble.

    We could potentially implement a custom console control in WPF and redirect output
    there but that is a non-trivial amount of work and we're not bringing in third party
    components.
#>

# Change to the script directory if we're not in it.
if (-not $PSScriptRoot -ne $PWD) {
    Set-Location $PSScriptRoot
}

$ErrorActionPreference = 'Stop'

Import-Module ../.. -Force

function New-WPFConsole {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $Window
    )

    # Determine the path to the WPF module for importing in the new runspace
    $WPFModulePath = Get-Module WPF | Select-Object -First 1 -ExpandProperty ModuleBase
    if ($WPFModulePath) {
        Write-Verbose "WPF module path: $WPFModulePath"
    } else {
        Write-Error "Could not determine WPF module path."
        return
    }

    $ConsoleCode = @"
using System;
using System.Runtime.InteropServices;

public class WPFConsole : IDisposable {
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool AllocConsole();

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool FreeConsole();

    // In Multi-Threaded architectures, both the UI thread (on window close)
    // and the Runspace (on loop exit) might attempt to clean up the resource
    // so we need to ensure that the console is only freed once.
    private bool _disposed = false;

    public WPFConsole() {
        if (AllocConsole() == false) {
            throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
        }
    }

    // Write to console from the UI thread
    public void WriteLine(string message) {
        if (_disposed) { throw new ObjectDisposedException("WPFConsole"); }
        Console.WriteLine(message);
    }

    public string ReadLine() {
        if (_disposed) { throw new ObjectDisposedException("WPFConsole"); }
        return Console.ReadLine();
    }

    public void Dispose() {
        Dispose(true);
        GC.SuppressFinalize(this);
    }

    protected virtual void Dispose(bool disposing) {
        if (!_disposed) {
            FreeConsole();
            _disposed = true;
        }
    }

    // Finalizer to ensure console is freed if Dispose is not called
    ~WPFConsole() {
        Dispose(false);
    }
}
"@

    if (-not ('WPFConsole' -as [type])) {
        try {
            Add-Type -TypeDefinition $ConsoleCode -Language CSharp
        } catch {
            Write-Error "Failed to compile WPFConsole: $_"
            return
        }
    }

    try {
        $console = [WPFConsole]::new()
        $console.WriteLine("Hello from the console!")
    } catch {
        Write-Error "Failed to allocate console: $_"
        return
    }

    # Start a background job to read console input and write it to the window.
    $Runspace = [runspacefactory]::CreateRunspace()
    $Runspace.Open()

    # CRITICAL: Pass shared reference table into the new runspace
    $Runspace.SessionStateProxy.SetVariable("WPFConsole", (Get-WPFControlRegistry))
    $Runspace.SessionStateProxy.SetVariable("__Window", $Window)

    $PowerShell = [powershell]::Create()
    $PowerShell.Runspace = $Runspace
    $PowerShell.AddScript({
        Import-Module $using:WPFModulePath -Force

        while ($true) {
            $console.WriteLine("WPF> ")
            $Input = $console.ReadLine()
            if ($Input -eq 'exit') { break }

            $console.WriteLine("You entered: $Input")
            # Marshal the input back to the UI thread safely
            $Window.Dispatcher.Invoke([action]{
                $ConsoleInputLabel.Content = "You entered: $Input"

                # Execute user's typed command in the background runspace and capture output
                # try {
                #     $Output = Invoke-Expression $Input 2>&1 | Out-String
                #     $console.WriteLine("Output: $Output")
                # } catch {
                #     $console.WriteLine("Error: $_")
                # }
            })
        }
    }).BeginInvoke()
}

Window 'Window' {
    $this.Title = 'Terminal GUI Communication Example'
    $this.Height = 100
    $this.Width = 250
    State @{
        WPFConsole = $null
    }

    On Loaded {
        $this.Tag.State.WPFConsole = New-WPFConsole -Window $this
    }

    On Closed {
        # Clean up the console when the window is closed
        try {
            $this.Tag.State.WPFConsole.Dispose()
        } catch {
            Write-Error "Failed to dispose WPFConsole: $_"
        }
    }

    StackPanel "Buttons" {
        Button "Button" {
            $this.Content = 'Click Me'
            $this.Width = 100

            On "Click" {
                Write-Host "Hello World!"
            }
        }
        Label "ConsoleInputLabel" {
            $this.Content = 'Waiting for console input...'
        }
    }
} | Show-WPFWindow

