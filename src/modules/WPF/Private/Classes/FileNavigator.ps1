using namespace System
using namespace System.IO
using namespace System.Collections.Generic

<#
.SYNOPSIS
    Allow programmatic navigation of files within a directory with filtering

.SYNOPSIS
    Allow programmatic navigation of files within a directory with filtering

    Uses the given or current directory to construct a list of files that are
    allowed by file extensions filters. Filters are all extensions but for
    for user convenience this class supports file types and categories to
    reduce the boilerplate.

.NOTES
    Over-engineered you say? Hah... yeah... **sobbing noises**

    I just wanted to be Enterprise grade for once in my life Dad!

.EXAMPLE
    Most basic use of a file navigator. Uses the current directory for
    context by default. Gets the current file being tracked.

    $FileNavigator = [FileNavigator]::new()
    $FileNavigator.CurrentFile

.EXAMPLE
    Create a file navigator in directory 'foo/bar/baz' and filter on
    all 'exe' and 'Image' file types. Weird combination but this is an example.
    Move to the next available file, display it, then change to the 'baz/baz/foo'
    directory and display the file there.

    $FileNavigator = [FileNavigator]::new('foo/bar/baz', 'exe', $null, 'Image')
    $FileNavigator.MoveNext()
    $FileNavigator.CurrentFile
    $FileNavigator.SetDirectory('baz/bar/foo')
    $FileNavigator.CurrentFile
#>
class FileNavigator {

    # MARK: PROPERTIES
    #==================

    [int] $Index = -1  # -1 indicates an empty directory or no matching files
    [DirectoryInfo] $Directory
    [FileInfo[]] $Files
    [string[]] $ValidExtensions
    [string[]] $ValidTypes
    [string[]] $ValidCategories


    # MARK: EVENTS
    #==============

    [HashSet[Action]] $OnDirectoryChanged = [HashSet[Action]]::new()
    [HashSet[Action]] $OnFiltersChanged = [HashSet[Action]]::new()


    # MARK: MEMBER DEFS
    #===================

    [hashtable[]] $MemberDefinitions = @(
        @{
            MemberType = 'ScriptProperty'
            Name = 'CurrentFile'
            Value = {
                if ($this.Index -ge 0 -and $this.Index -lt $this.Files.Count) {
                    return $this.Files[$this.Index]
                }
                return $null
            }
        }
    )


    # MARK: METHODS
    #===============

    # Initialize with all defaults
    FileNavigator() {
        $this.Init([Directory]::GetCurrentDirectory(), $null, $null, $null)
    }

    # Initialize with filters and working directory
    FileNavigator(
        [string[]] $Extensions,
        [string[]] $Types,
        [string[]] $Categories
    ) {
        $this.Init([Directory]::GetCurrentDirectory(), $Extensions, $Types, $Categories)
    }

    FileNavigator(
        [DirectoryInfo] $Directory,
        [string[]] $Extensions,
        [string[]] $Types,
        [string[]] $Categories
    ) {
        $this.Init($Directory, $Extensions, $Types, $Categories)
    }

    hidden [void] Init(
        [DirectoryInfo] $Directory,
        [string[]] $Extensions,
        [string[]] $Types,
        [string[]] $Categories
    ) {
        if (-not $Directory -or -not $Directory.Exists) {
            throw [DirectoryNotFoundException]::new("Directory not found: '$Directory'")
        }

        $this.SetDirectory($Directory)
        $this.SetFilters($Extensions, $Types, $Categories)  # Implicitly reloads files.

        # Add dynamic properties
        foreach($MemberDefinition in $this.MemberDefinitions) {
            $this | Add-Member @MemberDefinition
        }

        # Setup event handlers after SetDirectory/SetExtensions
        # have been called to avoid unnecessary file loading
        $this.AddEvent('OnDirectoryChanged', $this.Refresh)
        $this.AddEvent('OnFiltersChanged', $this.Refresh)

        # Populate $this.Files
        $this.Refresh()
    }

    [void] AddEvent(
        [string] $Name,
        [object] $Callable
    ) {
        if ([string]::IsNullOrEmpty($Name) -or -not $Callable) {
            throw [InvalidDataException]::new("Name and Callable cannot be null or empty.")
        }
        if (-not $this.PSObject.Properties[$Name]) {
            throw [InvalidOperationException]::new("Event '$Name' not found")
        }
        $this.$Name.Add($Callable)
    }

    [void] RemoveEvent(
        [string] $Name,
        [object] $Callable
    ) {
        if ([string]::IsNullOrEmpty($Name) -or -not $Callable) {
            throw [InvalidDataException]::new("Name and Callable cannot be null or empty.")
        }
        if (-not $this.PSObject.Properties[$Name]) {
            return
        }
        $this.$Name.Remove($Callable)
    }

    [void] SetFilters(
        [string[]] $Extensions,
        [string[]] $Types,
        [string[]] $Categories
    ) {
        $this.ValidTypes = $Types
        $this.ValidCategories = $Categories

        if ($Extensions) {
            $this.ValidExtensions = $Extensions
        }
        if ($Types -or $Categories) {
            $this.ValidExtensions += Get-WPFFileInfo `
                -Type $Types 1
                -Category $Categories |
                ForEach-Object { $_.Extensions }
        }

        # Trigger file reload
        if ($this.OnFiltersChanged) {
            $this.OnFiltersChanged | ForEach-Object { $_.Invoke() }
        }
    }

    [FileInfo[]] GetFiles() {
        # Get all files or all files with valid extensions if defined
        return $this.Directory.GetFiles() | Where-Object {
            -not $this.ValidExtensions -or $_.Extension.TrimStart('.') -in $this.ValidExtensions
        }
    }

    [void] SetDirectory([DirectoryInfo] $Directory) {
        if (-not $Directory.Exists) {
            throw [InvalidOperationException]::new("Directory '$Directory' does not exist.")
        }
        $this.Directory = $Directory

        # Trigger file reload
        if ($this.OnDirectoryChanged) {
            $this.OnDirectoryChanged | ForEach-Object { $_.Invoke() }
        }
    }

    [void] Refresh() {
        # Ensure directory object is up to date
        $this.Directory.Refresh()

        # Get the files
        $this.Files = $this.GetFiles()

        # Initialize index to first position if files were found
        # and an index wasn't already assigned
        if ($this.Files.Count -gt 0 -and $this.Index -eq -1) {
            $this.Index = 0
        }
        # Reset index to -1 to indicate empty.
        elseif (-not $this.Files -and $this.Index -ne -1) {
            $this.Index = -1
        }
    }

    [void] MoveTo([int] $Index) {
        if ($this.Files -and $Index -ge 0 -and $Index -le $this.Files.Count) {
            $this.Index = $Index
        } else {
            throw [IndexOutOfRangeException]::new("Index '$Index' out of range 0..$($this.Files.Count)")
        }
    }

    [void] MoveTo([string] $FileName) {
        $this.MoveTo($this.GetIndexByName($FileName))
    }

    [int] GetIndexByName([string] $FileName) {
        for ($i = 0; $i -lt $this.Files.Count; $i++) {
            if ($this.Files[$i].Name -eq $FileName) {
                return $i
            }
        }
        return -1
    }

    [void] MovePrevious() {
        # Nowhere else to go
        if ($this.Index -eq $this.Files.Count) {
            return
        }

        $this.Index -= 1
        # Loop from start to end if we've passed the first element
        if ($this.Index -lt 0 -and $this.Files.Count -ge 0) {
            $this.Index = $this.Files.Count - 1
        }
    }

    [void] MoveNext() {
        # Nowhere else to go
        if ($this.Index -eq $this.Files.Count) {
            return
        }

        # Loop from end to start if we've passed the last element
        $this.Index += 1
        if ($this.Index -ge $this.Files.Count) {
            $this.Index = 0
        }
    }
}
