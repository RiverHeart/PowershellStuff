# TaskManager

Generated with New-WPFProject.

## Run

`powershell
./TaskManager.DSL.ps1
`

The generated scaffold creates an empty functions folder and a starter style file.
Both are safe to leave empty while you build out the app.

## Memory Header Nuance

The Memory column displays per-process working set values in MB.
The Memory header total shows overall physical memory usage percent based on OS-level values (`TotalVisibleMemorySize` and `FreePhysicalMemory`).
This avoids overcounting shared pages that can happen when summing process `WorkingSet64` values across all processes.
