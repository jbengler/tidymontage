# Preview positions for crops and zooms

Shows the full images with relative coordinates: axes from 0 to 1 below
and to the right of each image, and faint grid lines in steps of 0.1.
Read off the center of the region you want and use it in
[`add_crop()`](https://jbengler.github.io/tidymontage/reference/add_crop.md)
or
[`add_zoom()`](https://jbengler.github.io/tidymontage/reference/add_zoom.md).
If the montage has a crop or zoom already, its current region is
outlined and labelled, which also shows its size.

## Usage

``` r
preview_positions(montage, ...)
```

## Arguments

- montage:

  A
  [`tidymontage()`](https://jbengler.github.io/tidymontage/reference/tidymontage.md)
  object.

- ...:

  Conditions that pick images, as in
  [`dplyr::filter()`](https://dplyr.tidyverse.org/reference/filter.html),
  e.g. `mutant == "I56A"`.

## Value

A montage with the coordinates. Print it to see them.

## Details

One image is shown per block of the montage (the columns mapped to `x`
and `y`, e.g. one per condition), as positions are usually chosen per
block. The merge is shown if the montage has one, otherwise the first
channel.

## Examples

``` r
if (FALSE) { # \dontrun{
montage |> preview_positions()
montage |> preview_positions(mutant == "I56A")
} # }
```
