# Read images

`read_images()` reads the metadata of microscopy image files and returns
a long tibble with one row per image: one per file, channel, z-slice and
time point. The `img` column holds lazy references to the greyscale
images. Pixels are not read here; this happens when a montage is
rendered, and only for the images it shows.

## Usage

``` r
read_images(paths)
```

## Arguments

- paths:

  A character vector of paths to TIFF files (`.tif`, `.tiff`,
  `.ome.tif`) or to directories containing them.

## Value

A tibble with one row per image and the columns:

- `filepath`, `series`: file and image series (always 1 for non-OME
  files).

- `channel_index`, `channel`: position and label of the channel. The
  label is the fluorophore if known, otherwise the channel name,
  otherwise `"C1"`, `"C2"`, ...

- `z`, `t`: z-slice and time point of the image.

- `img`: the image, a lazy greyscale image vector (see
  [`is_img()`](https://jbengler.github.io/tidymontage/reference/is_img.md)).

- `color`: channel colour as a hex string, or `NA` if unknown.

- `channel_name`, `fluor`: channel name and fluorophore from the
  metadata.

- `size_x`, `size_y`, `size_z`, `size_t`: dimensions of the source file
  in pixels, z-slices and time points.

- `bit_depth`: bits per sample (8 or 16).

- `pixel_size`, `pixel_unit`: pixel size, always in micrometres.

- `z_step`: distance between z-slices in micrometres.

- `meta_source`, `pixel_size_source`: where the metadata came from.

## Details

Because the result is a tibble, you select and process images with
dplyr: [`filter()`](https://dplyr.tidyverse.org/reference/filter.html)
z-slices or time points, project a z-stack with
`summarise(img = max(img), .by = c(filepath, channel))`.

Metadata are taken from the richest source available, recorded in
`meta_source`:

- `"ome-xml"`: OME-TIFF (`.ome.tif`).

- `"imagej"`: TIFF saved by ImageJ / Fiji, including channel colours
  (LUTs) and channel names from microscope metadata carried over by
  Bio-Formats.

- `"tiff"`: plain TIFF. All pages are treated as z-slices of one
  channel.

The pixel size has its own source column, `pixel_size_source`, because
scale bars need a pixel size you can trust. A pixel size from plain TIFF
resolution tags (`"tiff"`) is only used if the unit is centimetres.

## Examples

``` r
if (FALSE) { # \dontrun{
read_images("path/to/images")
read_images(c("ctrl.ome.tif", "ko.ome.tif"))
} # }
```
