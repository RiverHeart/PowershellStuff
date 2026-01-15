# Image Viewer

## Overview

Simple image viewer. It sports a menu bar and when you choose `File->Open`, you can select an image to load into the viewer. Using the directory of the image, a [FileNavigator](../../Private/Classes/FileNavigator.ps1) is created and forward/back buttons at the bottom of the window can be used to switch to the previous or next image. The FileNavigator loops around from front to back and vice versa when it passes the start or end of a file list.

Free SVG icons sourced from [FontAwesome](https://fontawesome.com).

![Without XAML](./ImageViewer.png)


## TODO

* Add Fit and Actual size buttons
* Add rotate button
* Implement export to different format
* Implement slideshow
* Implement rotate button
