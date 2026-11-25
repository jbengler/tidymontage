# Add a colour legend

Adds a legend that names the channels and their colours, like a ggplot2
legend: a coloured swatch next to each channel name, outside the panels.
It lists the channels shown in the montage, including the members of
merges; merges themselves are not listed. Black channels (shown
inverted) are left out, since their swatches would all look the same;
their colours in merges are listed instead. The montage grows by the
space the legend needs, so the panels keep their size.

## Usage

``` r
add_color_legend(
  montage,
  position = c("bottom", "top", "right"),
  size = 7,
  color = "black",
  ranges = TRUE
)
```

## Arguments

- montage:

  A
  [`tidymontage()`](https://jbengler.github.io/tidymontage/reference/tidymontage.md)
  object.

- position:

  Where the legend goes: `"bottom"` (the default), `"top"` or `"right"`.

- size:

  Text size in points.

- color:

  Text colour.

- ranges:

  If `TRUE`, label colour bars with the display range.

## Value

The montage with the legend step added.

## Details

Channels and overlays coloured with a colormap
([`lut()`](https://jbengler.github.io/tidymontage/reference/lut.md)) are
shown with a colour bar instead of a swatch. With `ranges = TRUE`, the
ends of a channel's bar are labelled with its display range (see
[`adjust_exposure()`](https://jbengler.github.io/tidymontage/reference/adjust_exposure.md)).
This needs one range for all images of the channel, which is the
default; bars of channels with several ranges, and of overlays, are left
unlabelled.

## Examples

``` r
if (FALSE) { # \dontrun{
montage |> add_color_legend("bottom")
} # }
```
