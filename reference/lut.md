# Colour lookup tables (colormaps)

Creates a lookup table (LUT) that colours a channel with a colormap such
as magma or viridis instead of a single colour. Use it in
[`adjust_colors()`](https://jbengler.github.io/tidymontage/reference/adjust_colors.md)
or as the colour of
[`add_overlay()`](https://jbengler.github.io/tidymontage/reference/add_overlay.md).
Intensities at or below the lower end of the display range (see
[`adjust_exposure()`](https://jbengler.github.io/tidymontage/reference/adjust_exposure.md))
get the first colour of the map, at or above the upper end its last
colour.

## Usage

``` r
lut(colors, reverse = FALSE)
```

## Arguments

- colors:

  The name of a colormap, or a vector of two or more colours. Colormaps
  are the perceptually uniform maps of the viridisLite package:
  `"magma"`, `"inferno"`, `"plasma"`, `"viridis"`, `"cividis"`,
  `"rocket"`, `"mako"` and `"turbo"`. Colours are spread evenly from the
  lower to the upper end of the display range, for example
  `c("black", "red", "yellow")`.

- reverse:

  If `TRUE`, the map runs the other way round.

## Value

A `tidymontage_lut` object.

## Details

Colormaps work best for single-channel panels with quantitative content,
such as calcium imaging, ratio images or intensity heatmaps:
perceptually uniform maps like magma and viridis show differences in
intensity more faithfully than a single colour does.

Merges need single colours, since colours add up like light. In a merge,
a channel coloured with a LUT uses its original colour from the image
metadata (the `color` column) instead, unless
[`add_merge()`](https://jbengler.github.io/tidymontage/reference/add_merge.md)
sets one. In its own panels, a LUT channel is drawn on the first colour
of its map, and
[`add_color_legend()`](https://jbengler.github.io/tidymontage/reference/add_color_legend.md)
shows it as a colour bar.

## Examples

``` r
lut("magma")
#> <tidymontage_lut> lut("magma")
lut("viridis", reverse = TRUE)
#> <tidymontage_lut> lut("viridis", reverse = TRUE)
lut(c("black", "darkred", "orange", "white"))
#> <tidymontage_lut> lut(c("black", "darkred", "orange", "white"))

if (FALSE) { # \dontrun{
montage |> adjust_colors(GCaMP = lut("magma"))
} # }
```
