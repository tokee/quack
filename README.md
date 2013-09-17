# Quack

## Purpose

To create QA (Quality Assurance) oriented views for collections of scans, typically from books or newspapers, with corresponding [http://www.loc.gov/standards/alto/](ALTO)-files.

## Features

 * Smooth zoom & pan of large images thanks to [http://openseadragon.github.io/](OpenSeadragon)
 * Marking of blown highlights & lowlights by colored overlays (toggable)
 * TextBlock marking by boxes (toggable)
 * Interactive inspection of OCR (hover the mouse over a TextBlock)
 * Grid lines for checking skewing and rotation (toggable)
 * Folder overview with thumbnails
 * Histogram, optionally not analyzing the edges of the image

## Requirements

 * A minimum of 2GB free RAM for processing of 30MP scans
 * bash
 * GraphicsMagic
 * ImageMagick (as GraphicsMagic cannot create histograms)
 * openeadragon.min.js
 * A suitable beefy browser-equipped machine for display, depending on image sizes and ALTO complexity

## Status

 * The script is not very flexible as it was developed for internal use at the State and University Library, Denmark.
 * There are no sample files due to copyright (a slow clearing process is underway)

## Verbiage

This is basically a simple bash script that grew to 600+ lines. It creates a HTML page for each image and uses the relevant parts of the ALTO files for creation of TextBlock boxes and OCS display. No webserver is required as the pages can be used directly from the file system.

Currently the display of the scans is not tile based and thus requires the browser to handle the full images directly. This can be quite taxing. It has been tested with Firefox & Chrome. Chrome was markedly faster as of 2013-09-17.

The choice of PNG was due to the QA-focus - no JPEG artifacts, thanks! This should probably be more flexible as the input can be JPEG and because some people do not require pixel perfectness for their QA.

## Development

Developed by Toke Eskildsen, partly as a personal project, partly as an employee at the State and University Library, Denmark.
