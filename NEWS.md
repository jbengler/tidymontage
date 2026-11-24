# tidymontage (development version)

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
