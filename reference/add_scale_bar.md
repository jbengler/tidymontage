# Add scale bars

Adds a scale bar to the panels of a montage. Panels of one view share
the same magnification (see
[`add_crop()`](https://jbengler.github.io/tidymontage/reference/add_crop.md)),
so by default one bar per view is drawn, in the bottom-right panel of
that view.

## Usage

``` r
add_scale_bar(
  montage,
  length = NULL,
  where = c("last", "all", "merge"),
  position = c("bottomright", "bottomleft", "topright", "topleft"),
  color = "white",
  outline = "black",
  label = TRUE,
  size = 7,
  thickness = 0.6,
  inset = 1.5
)
```

## Arguments

- montage:

  A
  [`tidymontage()`](https://jbengler.github.io/tidymontage/reference/tidymontage.md)
  object.

- length:

  Length of the bar in micrometres: a single number for all views, a
  named vector per view (e.g. `c(crop = 10, zoom = 2)`), or `NULL` to
  choose a round length of about a fifth of the panel width.

- where:

  Which panels get a bar: `"last"` (one per view), `"all"`, or `"merge"`
  (all merge panels).

- position:

  Corner of the panel.

- color:

  Colour of the bar and its label.

- outline:

  Colour of a thin border around the bar and a halo around the label,
  which keeps them visible on bright image content. `NA` for none.

- label:

  Show the length above the bar?

- size:

  Text size in points.

- thickness:

  Thickness of the bar in mm.

- inset:

  Distance from the panel edges in mm.

## Value

The montage with the scale bar step added.

## Details

Scale bars need a known pixel size. If the images of a view have
different magnifications, for example uncropped images with different
pixel sizes, every panel of that view gets its own bar.

## Examples

``` r
if (FALSE) { # \dontrun{
montage |> add_scale_bar(10)
montage |> add_scale_bar(c(crop = 10, zoom = 2), where = "all")
} # }
```
