# gtable spike (2026-11-24)

Question: can a montage render to its own gtable (grid only, no ggplot), with
the image grid as the "panel" that tidylayouts aligns on?

- `gtable.R` – `montage_gtable()`, a lazy `makeContent()` grob and grid
  drawing of all montage elements.
- `01_compare.R` – current ggplot renderer vs. gtable on three README-like
  montages (grid with crop/zoom, hero with legend, black channel).
- `02_tidylayouts.R` – montages in a tidylayouts figure.

## Answer: yes

- **Structure**: a 3 x 3 gtable. Middle track in both directions = the image
  grid (first to last image edge, in mm); outer tracks = decoration (headers
  and top legend before, side labels, scale bar labels, bottom legend after).
  One grob spans all tracks and draws in figure mm; an empty grob named
  `panel` marks the image grid.
- **Lazy**: pixels are read in `makeContent()`, i.e. only when drawn. Creating
  the gtable takes 0.01-0.2 s (layout only).
- **Same figure**: dimensions identical to the ggplot renderer. Pixels differ
  in 22-36 % with the default png device, but in 6 % with ragg (the device
  ggsave uses); the remaining differences are thin lines at raster-pixel
  boundaries, i.e. resampling of the image rasters, not geometry. Visually
  identical (`out/*_ggplot.png` vs `out/*_gtable.png`).
- **Faster**: drawing 0.35-0.5 s vs. 0.5-0.9 s through ggplot.
- **tidylayouts**: a "plot" leaf only needs a gtable. `measure_leaf()` reads
  lead / span / trail from the montage tracks, e.g. widths 4.7 | 50 | 0 and
  heights 4.7 | 50 | 6.7 mm (row headers; column headers; legend). In
  `out/tidylayouts.png` the montages' image grids align with the plots'
  panels; headers, side labels and legends sit outside. Tags work.

## Found and fixed along the way

- Legends at the bottom or right overlapped hero side labels (also in the
  ggplot renderer): the legend now goes beyond all other decoration
  (`legend_layout()` gets the outer edge; test in `test-legend.R`).

## Next steps

1. Package: replace the ggplot renderer by the gtable (`print()`,
   `save_montage()` via ragg or base devices), drop `autoplot()` and possibly
   ggplot2 from Imports; regenerate visual snapshots (vdiffr works on grid).
2. tidylayouts: accept non-ggplot objects that provide a gtable, e.g. a
   generic `as_layout_gtable()` with a ggplot method; tidymontage registers
   its method when tidylayouts is installed (no hard dependency either way).
3. Later: flexible spans (`auto_width()` / `auto_height()`) by refitting the
   montage geometry to the assigned span at draw time.
