# tidymontage (development version)

* Several zooms per image: call `add_zoom()` again for each. With two or
  more, zooms are numbered in the order they were added: the number is shown
  in the top-left corner of each box and each zoom panel, and the views are
  named `"zoom 1"`, `"zoom 2"`, ... A new `label` argument sets your own
  label or turns it off. `preview_positions()` outlines all zooms.

* New `tidymontage_options()` sets session-wide defaults for the size box,
  its units and the gap, like `tidyplots_options()`.

* New `add_arrows()` marks locations with arrowheads. They belong to an image
  and are drawn in all of its panels: each channel, merges, overlays, crops
  and zooms.

* New `lut()` colours channels and overlays with a colormap such as magma or
  viridis, in `adjust_colors()` and `add_overlay(color = )`. In merges, such
  channels use their original colour. `add_color_legend()` shows them as
  colour bars labelled with the display range (`ranges = TRUE`).

* Initial CRAN submission.
