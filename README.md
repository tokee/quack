# Quack

An enhanced [ALTO](http://www.loc.gov/standards/alto/)-viewer for Quality Assurance oriented display of a collections of scans, typically from books or newspapers.

Please visit  [http://tokee.github.io/quack/](http://tokee.github.io/quack/) for the project homepage, featuring a live demo.


![Quack screenshot 20131127](docs/quack_20131127_8bit.png)

## Requirements

 * bash (only tested under Linux but might work under MacOS)
 * A minimum of 2GB free RAM for processing of 30MP scans
 * [GraphicsMagic](http://www.graphicsmagick.org/)
 * [ImageMagick](http://www.imagemagick.org) (as GraphicsMagic cannot create histograms)
 * [opj_decompress](https://manpages.debian.org/unstable/libopenjp2-tools/opj_decompress.1.en.html) if GraphicsMagic does not have JPEG 2000 support
 * [openseadragon.min.js](http://openseadragon.github.io/)
 * A suitable beefy browser equipped machine for display, depending on image sizes and ALTO complexity
 * [deepzoom](http://search.cpan.org/~drrho/Graphics-DZI-0.05/script/deepzoom) (only if tile based display is enabled. Install with 'sudo cpan -f install Graphics::DZI')
  * Perl (required by deepzoom)

## What does Quack do?

The State and University Library in Denmark scanned 30 million newspaper pages from microfilm. Quack was created as a proof of concept for a visual oriented quality assurance tool. Somehow it ended up in production.

Quack takes a folder with bitmaps and corresponding [ALTO](https://en.wikipedia.org/wiki/ALTO_(XML)) files (see the `samples` folder for an example). The bitmaps used during the project were greyscale JPEG 2000 and while other bitmap formats should be fine, it is untested how well it works for color images.

Each bitmap/ALTO pair in the folder results in the following

 * **Visual histogram**: Used for locating suspicious spikes that indicates overly high contrast
 * **Black/white overlay**: Shows where the scan is under- or over-exposed
 * **Statistics**
   * *Dark*: How many percent of the image that is under-exposed (see `BLOWN_BLACK_WT` and `BLOWN_BLACK_BT` below)
   * *S-Pos and Spike*: The greyscale value with the highest spike in the histogram and the percentage of the image that has this value
   * *Light*: How many percent of the image that is over-exposed (see `BLOWN_WHITE_WT` and `BLOWN_WHITE_BT` below)
   * *Unique*: The number of unique greyscale values in the image (ideally 256 if the image is a raw scan)
   * *Holes*: The number of holes in the histogram (ideally 0 if the image is a raw scan)
   * *OCR*: The overall OCR quality according to the ALTO
   * *Strings*: The number of unique strings in the ALTO
   * *KB*: The size of the bitmap in kilobytes
   * *MP*: The size of the bitmap in megapixels
 * **Segment overview**: An overview of the `TextBlock`s in the ALTO on a separate page for eact bitmap/ALOT pair. `TextBlock`s connected with the `IDNEXT` attribute share the same color

## Configuration

TODO: Add this section

## Usage

To get started, execute the following in a terminal (Tested under Linux, should work under OS-X and Cygwin):

```
  ./quack.sh samples samples_out
```
