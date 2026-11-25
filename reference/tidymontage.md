# Start a montage

`tidymontage()` turns a tibble of images into a montage. Like
`tidyplot()` in tidyplots, it takes the mapping and the size; `add_*()`
and `adjust_*()` verbs then add merges, crops, zooms, scale bars and
more. Nothing is read from disk until the montage is printed or saved.

## Usage

``` r
tidymontage(
  images,
  x = NULL,
  y = NULL,
  ...,
  layout = "grid",
  gap = NULL,
  width = NULL,
  height = NULL,
  units = NULL
)
```

## Arguments

- images:

  A data frame of images, usually from
  [`read_images()`](https://jbengler.github.io/tidymontage/reference/read_images.md).
  Must contain the columns `filepath`, `channel` and `img`.

- x, y:

  Columns mapped to the columns (`x`) and rows (`y`) of the montage: a
  bare name such as `condition`, or several with
  [`c()`](https://rdrr.io/r/base/c.html) (the first one varies slowest).
  In the grid layout, `channel` and `view` can be mapped too.

- ...:

  Choose and order the levels of panel dimensions, for example
  `channel = c("GFP", "DAPI")` or `condition = "ctrl"`.

- layout:

  `"grid"` (the default) or `"hero"`, or a layout created with
  [`layout_grid()`](https://jbengler.github.io/tidymontage/reference/layouts.md)
  or
  [`layout_hero()`](https://jbengler.github.io/tidymontage/reference/layouts.md).

- gap:

  Gap between panels in mm. `NULL` (the default) uses
  [`tidymontage_options()`](https://jbengler.github.io/tidymontage/reference/tidymontage_options.md),
  or 1.

- width, height, units:

  Size of the box the panel grid fits into, see
  [`adjust_size()`](https://jbengler.github.io/tidymontage/reference/adjust_size.md).
  `NULL` (the default) uses
  [`tidymontage_options()`](https://jbengler.github.io/tidymontage/reference/tidymontage_options.md),
  or 90 x 90 mm.

## Value

A `tidymontage` object. Printing it draws the montage.

## Details

The images tibble decides *which* images are shown: select planes with
[`filter()`](https://dplyr.tidyverse.org/reference/filter.html) and
project z-stacks with `summarise(img = max(img))` before calling
`tidymontage()`. Everything visual is decided by the montage.

Columns mapped to `x` and `y` (such as `condition`) arrange blocks of
panels. Within each block, the layout arranges channels and views (see
[`layout_grid()`](https://jbengler.github.io/tidymontage/reference/layouts.md));
in the grid, map `channel` or `view` to `x` or `y` to place them
yourself. Merges and zooms added later become levels of `channel` and
`view`. Each panel must show exactly one image.

## Examples

``` r
if (FALSE) { # \dontrun{
read_images(c("ctrl.ome.tif", "ko.ome.tif")) |>
  dplyr::mutate(condition = ifelse(grepl("ctrl", filepath), "ctrl", "ko")) |>
  tidymontage(x = condition)
} # }
```
