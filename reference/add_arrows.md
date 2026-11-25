# Add arrowheads that point at locations

Adds arrowheads that mark locations in the images, such as a vesicle or
a contact site. An arrowhead belongs to an image, not to a channel: it
is drawn at the same place in every panel of that image, in each channel
and in merges and overlays. Crops and zooms show it wherever its tip
falls inside their region.

## Usage

``` r
add_arrows(montage, at, size = 2, units = c("rel", "px"), color = NULL)
```

## Arguments

- montage:

  A
  [`tidymontage()`](https://jbengler.github.io/tidymontage/reference/tidymontage.md)
  object.

- at:

  Positions of the arrow tips: a numeric vector `c(x, y)` for one
  arrowhead on every image, or a data frame with columns `x` and `y` and
  columns of the images tibble to match on, e.g. `condition` or
  `filepath`. A data frame can have several rows per image; images
  without a matching row get no arrowheads.

- size:

  Length of an arrowhead in mm.

- units:

  Units of `at`: `"rel"` (relative, 0-1) or `"px"`.

- color:

  Colour of the arrowheads. `NULL` (the default) picks white or black,
  whichever contrasts with the panel.

## Value

The montage with the arrow step added.

## Details

Each arrowhead is a filled triangle whose tip is at the given position.
All arrowheads point in the same direction, from the lower right to the
upper left at 45 degrees, and have the same size in every panel. By
default they contrast with the panel: white on dark panels, black on
light ones.

Positions are given like the centers of
[`add_crop()`](https://jbengler.github.io/tidymontage/reference/add_crop.md):
relative to the full image by default (`0` = left or top edge, `1` =
right or bottom edge), or with `units = "px"` as pixel coordinates of
the full image, counted from 0 as in ImageJ / Fiji. Calling
`add_arrows()` again adds more arrowheads.

## Examples

``` r
if (FALSE) { # \dontrun{
arrows <- tibble::tribble(
  ~condition, ~x,   ~y,
  "ctrl",     0.48, 0.42,
  "ctrl",     0.55, 0.38,
  "ko",       0.41, 0.50
)
montage |> add_arrows(arrows)
} # }
```
