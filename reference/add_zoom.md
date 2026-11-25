# Add a blow-up of a region

`add_zoom()` adds a new view to the montage: an enlarged region of each
image, shown as panels of their own. Map `view` to `x` or `y` in the
layout to show them next to the main panels, or choose them with
`layout_grid(view = "zoom")`. A box marks the region on the main panels.

## Usage

``` r
add_zoom(
  montage,
  width,
  height = width,
  center = c(0.5, 0.5),
  units = c("um", "px"),
  center_units = c("rel", "px"),
  name = NULL,
  box = c("all", "merge", "none"),
  label = NULL,
  angle = NULL
)
```

## Arguments

- montage:

  A
  [`tidymontage()`](https://jbengler.github.io/tidymontage/reference/tidymontage.md)
  object.

- width, height:

  Size of the region. In micrometres by default, which keeps the
  magnification equal even if images have different pixel sizes.

- center:

  Position of the region's center: a numeric vector `c(x, y)` used for
  all images, or a data frame with columns `x`, `y` and one or more
  columns of the images tibble to match on, e.g. `condition` or
  `filepath`. The data frame can also have an `angle` column, for a
  different angle per image.

- units:

  Units of `width` and `height`: `"um"` (micrometres, needs a known
  pixel size) or `"px"` (pixels).

- center_units:

  Units of `center`: `"rel"` (relative, 0-1) or `"px"`.

- name:

  Name of the view in the layout. By default `"zoom"`, or `"zoom 1"`,
  `"zoom 2"`, ... if the montage has several zooms.

- box:

  Where to draw the box that marks the region on the main panels: on
  `"all"` panels, only on `"merge"` panels, or `"none"`.

- label:

  Label shown in the box and in the zoom panels. By default the number
  of the zoom if the montage has several, otherwise none. A string sets
  your own label; `NA` shows none.

- angle:

  Rotation of the region in degrees, counterclockwise, see
  [`add_crop()`](https://jbengler.github.io/tidymontage/reference/add_crop.md).
  `NULL` (the default) takes the angle of the crop, so the zoom box sits
  square in a rotated crop; `0` keeps the zoom upright.

## Value

The montage with the zoom step added.

## Details

As for
[`add_crop()`](https://jbengler.github.io/tidymontage/reference/add_crop.md),
the size is the same for all images, so all blow-ups share one
magnification, and positions are centers relative to the full image by
default.

Call `add_zoom()` again for more zooms. With two or more, they are
numbered in the order they were added: the number is shown in the
top-left corner of each box and of each panel of that zoom, and the
views are named `"zoom 1"`, `"zoom 2"`, ... unless `name` is given.

## Examples

``` r
if (FALSE) { # \dontrun{
montage |>
  add_crop(width = 40) |>
  add_zoom(width = 8, center = c(0.45, 0.6)) |>
  layout_grid(x = channel, y = view)

# two numbered zooms
montage |>
  add_zoom(width = 8, center = c(0.45, 0.6)) |>
  add_zoom(width = 8, center = c(0.7, 0.3))
} # }
```
