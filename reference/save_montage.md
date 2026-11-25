# Save a montage at its exact physical size

Renders the montage and saves it at its fixed physical size, set with
[`adjust_size()`](https://jbengler.github.io/tidymontage/reference/adjust_size.md)
(by default, the panel grid fits into 90 x 90 mm). The file format is
taken from the file extension: `.pdf`, `.png`, `.tif`/`.tiff`,
`.jpg`/`.jpeg` or `.svg`. Bitmaps are written with the ragg package if
it is installed, for consistent output on all systems. PDF and SVG files
are written with Cairo graphics where it is available. Without it (e.g.
on macOS without XQuartz), PDF falls back to R's standard PDF device and
SVG to the svglite package.

## Usage

``` r
save_montage(montage, filename, dpi = 300, ...)
```

## Arguments

- montage:

  A
  [`tidymontage()`](https://jbengler.github.io/tidymontage/reference/tidymontage.md)
  object.

- filename:

  File to write.

- dpi:

  Resolution of the image panels, and of bitmap files. Panels are binned
  down to this resolution at the printed size.

- ...:

  Passed to the graphics device.

## Value

The montage, invisibly.

## Examples

``` r
if (FALSE) { # \dontrun{
montage |> save_montage("figure.pdf")
montage |> adjust_size(width = 180, height = NA) |> save_montage("figure.pdf")
} # }
```
