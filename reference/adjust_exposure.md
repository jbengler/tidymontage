# Adjust the display range

Sets how image intensities map to brightness: intensities at or below
`min` are shown black, at or above `max` in full colour. Like in ImageJ,
this is a display property and does not change the image data.

## Usage

``` r
adjust_exposure(montage, min = "p0.1", max = "p99.9", ..., .by = channel)
```

## Arguments

- montage:

  A
  [`tidymontage()`](https://jbengler.github.io/tidymontage/reference/tidymontage.md)
  object.

- min, max:

  Lower and upper end of the display range: a percentile of the pixel
  intensities as a string such as `"p0.1"` or `"p99.9"`, or an intensity
  value such as `0` or `4000`.

- ...:

  Per-channel exceptions as name-value pairs, for example
  `DAPI = c(0, 2000)` or `DAPI = c("p1", "p99")`.

- .by:

  Columns that define which images share a display range, as a bare name
  or [`c()`](https://rdrr.io/r/base/c.html) of names. Default:
  `channel`.

## Value

The montage with the exposure step added.

## Details

By default, display ranges are **linked per channel**: all images of one
channel share the same range, computed from all of them together, so
that brightness can be compared across conditions. This is also what
happens without calling `adjust_exposure()`. To unlink on purpose, group
more finely, for example `.by = c(channel, condition)`.

A data column `display_min` and/or `display_max` in the images tibble
overrides the range for single images.

## Examples

``` r
if (FALSE) { # \dontrun{
montage |> adjust_exposure(min = "p0.1", max = "p99.9")
montage |> adjust_exposure(DAPI = c(0, 3000))
} # }
```
