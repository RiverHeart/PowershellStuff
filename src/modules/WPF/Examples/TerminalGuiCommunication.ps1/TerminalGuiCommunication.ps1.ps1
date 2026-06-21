# Change to the script directory if we're not in it.
if (-not $PSScriptRoot -ne $PWD) {
    Set-Location $PSScriptRoot
}

$ErrorActionPreference = 'Stop'

Import-Module ../.. -Force

function New-WPFConsole {
    [CmdletBinding()]
    [OutputType([WPFConsole])]
    param(
        [Parameter(Mandatory)]
        [object] $Window
    )

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
        if (AllocConsole() == 0) {
            throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
        }
    }

    // Write to console from the UI thread
    public static void WriteLine(string message) {
        if (_disposed) { throw new ObjectDisposedException("WPFConsole"); }
        Console.WriteLine(message);
    }

    public static string ReadLine() {
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
        Add-Type -TypeDefinition $ConsoleCode -Language CSharp
    }

    try {
        [WPFConsole]::AllocConsole()
        [WPFConsole]::WriteLine("Hello from the console!")
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
        while ($true) {
            [WPFConsole]::WriteLine("WPF> ")
            $Input = [WPFConsole]::ReadLine()
            if ($Input -eq 'exit') { break }

            [WPFConsole]::WriteLine("You entered: $Input")
            # Marshal the input back to the UI thread safely
            $Window.Dispatcher.Invoke([action]{
                $ConsoleInputLabel.Content = "You entered: $Input"

                # Execute user's typed command in the background runspace and capture output
                # try {
                #     $Output = Invoke-Expression $Input 2>&1 | Out-String
                #     [WPFConsole]::WriteLine("Output: $Output")
                # } catch {
                #     [WPFConsole]::WriteLine("Error: $_")
                # }
            })
        }
    }).BeginInvoke()
    # $Pipeline = $Runspace.CreatePipeline()
    # $Pipeline.Commands.AddScript({
    #     while ($true) {
    #         $Input = Read-Host "Enter some text (or 'exit' to quit)"
    #         if ($Input -eq 'exit') {
    #             break
    #         }
    #         [WPFConsole]::WriteLine("You entered: $Input")
    #         # Marshal the input back to the UI thread safely
    #         $Window.Dispatcher.Invoke([action]{
    #             $ConsoleInputLabel.Content = "You entered: $Input"
    #         })
    #     }
    # })
    # $Pipeline.InvokeAsync()
}

Window 'Window' {
    $this.Title = 'Terminal GUI Communication Example'
    $this.Height = 100
    $this.Width = 250

    On Loaded {
        New-WPFConsole
    }

    On Closed {
        # Clean up the console when the window is closed
        try {
            [WPFConsole]::Dispose()
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

