<#
.SYNOPSIS
    Creates a [FileNavigator] object which allows programmatic
    navigation of files within a directory with filtering.

.DESCRIPTION
    Creates a [FileNavigator] object which allows programmatic
    navigation of files within a directory with filtering.

    This function is just a wrapper around the class to expose
    it to module users without them having to explicitly import
    class modules.

.EXAMPLE
    Most basic use of a file navigator. Uses the current directory for
    context by default. Gets the current file being tracked.

    $FileNavigator = New-WPFFileNavigator
    $FileNavigator.CurrentFile

.EXAMPLE
    Create a file navigator in directory 'foo/bar/baz' and filter on
    all 'exe' and 'Image' file types. Weird combination but this is an example.
    Move to the next available file, display it, then change to the 'baz/baz/foo'
    directory and display the file there.

    $FileNavigator = New-WPFFileNavigator `
        -Directory 'foo/bar/baz' `
        -Extensions 'exe' `
        -Categories 'Image'

    $FileNavigator.MoveNext()
    $FileNavigator.CurrentFile
    $FileNavigator.SetDirectory('baz/bar/foo')
    $FileNavigator.CurrentFile
#>
function New-WPFFileNavigator {
    [CmdletBinding()]
    #[OutputType([FileNavigator])]
    param(
        [System.IO.DirectoryInfo] $Directory,
        [string[]] $Extensions,
        [string[]] $Types,
        [string[]] $Categories
    )

    if (-not $Directory) {
        $Directory = [System.IO.Directory]::GetCurrentDirectory()
    }

    return [FileNavigator]::new($Directory, $Extensions, $Types, $Categories)
}
