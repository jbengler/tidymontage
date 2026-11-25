# Layouts

A layout arranges the panels of a montage. The columns of the images
tibble that you map to `x` and `y` in
[`tidymontage()`](https://jbengler.github.io/tidymontage/reference/tidymontage.md)
(such as `condition`) arrange blocks of panels; the layout decides how
the channels and views of each block are arranged:

## Usage

``` r
layout_grid(channel = c("auto", "x", "y"), view = c("auto", "x", "y"))

layout_hero(
  hero = NULL,
  side = NULL,
  position = c("right", "bottom", "left"),
  labels = TRUE,
  stack = FALSE
)
```

## Arguments

- channel, view:

  For the grid: the axis (`"x"` or `"y"`) for channels and views.
  `"auto"` uses an axis that no other column is mapped to.

- hero, side:

  For the hero layout: the big panel and the small panels of each block,
  chosen with
  [`panel()`](https://jbengler.github.io/tidymontage/reference/panel.md).
  By default, the hero is the merge (or the first channel) of the main
  view (full image or crop), and the side panels are the single channels
  of the zoom (or of the main view).

- position:

  For the hero layout: where the small panels go.

- labels:

  For the hero layout: label the small panels with what distinguishes
  them (usually the channel), in the header font, outside the images:
  below them for `position = "bottom"`, beside them otherwise, rotated
  like ggplot2 facet strips. Long labels wrap onto two lines. Stacked
  side panels line up across blocks, so they are labelled once: on the
  left of the first column when below the hero, and below the last row
  when beside it.

- stack:

  For the hero layout: stack the small panels so that each is as long as
  the hero's edge, for strips such as a 15 x 4 um zoom. Below the hero,
  the strips are as wide as the hero and placed one under the other;
  beside it, they are as high as the hero and placed side by side. The
  side panels can have another aspect ratio than the hero, but all side
  panels share one.

## Value

A layout specification for
[`tidymontage()`](https://jbengler.github.io/tidymontage/reference/tidymontage.md)
or
[`adjust_layout()`](https://jbengler.github.io/tidymontage/reference/adjust_layout.md).

## Details

- `layout_grid()`, the default, puts channels and views on the rows and
  columns of a grid. Each channel and view is placed automatically on a
  free axis, unless you map `channel` or `view` to `x` or `y` yourself.

- `layout_hero()` shows one big panel per block, for example the merge
  of a crop, next to a strip of small panels, for example the single
  channels of a zoom.

Layouts are like themes: switch between them with the `layout` argument
of
[`tidymontage()`](https://jbengler.github.io/tidymontage/reference/tidymontage.md)
or with
[`adjust_layout()`](https://jbengler.github.io/tidymontage/reference/adjust_layout.md),
without changing the mapping.

## Examples

``` r
if (FALSE) { # \dontrun{
tidymontage(images, x = condition, layout = layout_grid(channel = "x"))
tidymontage(images, x = condition, layout = "hero")
tidymontage(images, layout = layout_hero(side = panel(view = "crop"), position = "bottom"))

# a big merge with zoom strips of each channel below it
tidymontage(images, layout = layout_hero(position = "bottom", stack = TRUE)) |>
  add_zoom(width = 15, height = 4)
} # }
```
