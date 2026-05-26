# Image Viewer

## Overview

Simple image viewer. It sports a menu bar and when you choose `File->Open`, you can select an image to load into the viewer. Using the directory of the image, a [FileNavigator](../../Private/Classes/FileNavigator.ps1) is created and forward/back buttons at the bottom of the window can be used to switch to the previous or next image. The FileNavigator loops around from front to back and vice versa when it passes the start or end of a file list.

Free SVG icons sourced from [FontAwesome](https://fontawesome.com/search?ip=classic&s=solid&ic=free-collection).

![Without XAML](./ImageViewer.png)

## Features

* Displays an image and its name, resolution, and folder index
* Navigation between images in the active file's directory
* Image rotation
* Image zoom with "Actual Fit"/"Fit to Window" actions.
* Copy image button
* SaveAs with automatic format conversion
* Fullscreen mode with mouse auto-hide on idle
* Supports Dark/Light modes
* Slideshow mode with configurable interval, fullscreen playback, and Escape-to-stop

## CLI Automation Flags

`ImageViewer.DSL.ps1` supports optional script parameters for automation:

* `-FilePath <string>`: Opens a file on startup.
* `-SlideshowIntervalSeconds <double>`: Starts slideshow automatically at the specified interval.
* `-AutoCloseSeconds <double>`: Closes the window automatically after first render, then the specified delay. Use `0` to close immediately after first render.
* `-StartFullscreen`: Enters fullscreen mode on startup.

Example runs:

```powershell
# Open file, start slideshow at 2.5s, close after 10s
.\ImageViewer.DSL.ps1 `
    -FilePath 'C:\Images\sample.jpg' `
    -SlideshowIntervalSeconds 2.5 `
    -AutoCloseSeconds 10

# Quick unattended auto-close run
.\ImageViewer.DSL.ps1 -AutoCloseSeconds 0

# Environment-driven auto-close run
$env:WPF_AUTO_CLOSE_SECONDS = '0'
.\ImageViewer.DSL.ps1
Remove-Item Env:WPF_AUTO_CLOSE_SECONDS -ErrorAction SilentlyContinue
```

For repeatable automation, use the wrapper script:

```powershell
# Open a file, run slideshow at 2s, auto-close after 10s
.\Invoke-ImageViewerSmoke.ps1 `
    -FilePath 'C:\Images\sample.jpg' `
    -SlideshowIntervalSeconds 2 `
    -AutoCloseSeconds 10
```

## TODO

* Create zoom slider
* Support image cropping
* Support figure drawing mode
* Picture-in-picture?
* Add click-and-drag panning for zoomed images
* Add Home/End keyboard navigation (optional: PageUp/PageDown)
* Show user-friendly dialogs for image load/open errors
* Persist last opened folder between runs
* Sometimes when an image is loaded, it seems like something is stealing focus from the window because the keyboard events for forward/back don't work.
