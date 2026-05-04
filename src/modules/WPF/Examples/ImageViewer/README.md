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
* Supports fullscreen mode
* Supports Dark/Light modes

## TODO

* Add a copy/paste button. Reusable component?
* Create zoom slider
* Support "Save As"
* Support image cropping
* Support slideshow mode
* Support figure drawing mode
* Add click-and-drag panning for zoomed images
* Add Home/End keyboard navigation (optional: PageUp/PageDown)
* Show user-friendly dialogs for image load/open errors
* Persist last opened folder between runs
