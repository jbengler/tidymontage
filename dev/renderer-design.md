# Renderer design (agreed 2026-11-23)

## Split between data and display

- The image tibble (dplyr) decides **which intensities**: `filter()` planes,
  `summarise(img = max(img))` projections, descriptive columns (condition, ...).
- The viewer decides **everything visual**: colour, display range (exposure),
  merges, crops, zooms, layout, labels, scale bars.
- Escape hatches from the data: `color` column (default colour),
  optional `display_min` / `display_max` columns (per-image display range).

## Panel space

Every panel is a combination of three dimensions:

| Dimension | Levels come from |
|---|---|
| groups (any data columns, e.g. `condition`) | the tibble |
| `channel` | the tibble, plus virtual merge channels |
| `view` | the viewer: full image or crop, plus zooms |

Rule (as for facets): every dimension is either mapped to x/y or fixed to one
level, otherwise an informative error.

Each panel cell (all dimensions incl. channel) must match exactly one image
row; otherwise error ("summarise z first or map another variable").

## Verbs

```r
tidymontage(images, x = condition, y = NULL, ...,   # ... chooses levels
            layout = "grid", gap = 1, width = 90, height = 90) |>
  add_merge(GFP, Cy3, name = "merge") |>       # virtual channel level
  adjust_colors(DAPI = "#0072B2") |>           # overrides the color column
  adjust_exposure(min = "p0.1", max = "p99.9") |>   # .by = channel by default (linked)
  add_crop(width = 40, center = crop_centers) |> # redefines the default view
  add_zoom(width = 8, center = zoom_centers, name = "zoom") |>  # adds view level
  add_scale_bar() |>                           # one per view, outlined
  adjust_headers() |> adjust_layout() |> adjust_size() |>       # change setup later
  save_montage("fig.pdf")                      # exact physical size
```

- **Mapping in the constructor**, like `tidyplot(x, y)`. It only stores names
  of dimensions; merges and zooms added later become levels of `channel` and
  `view` when the montage is built (lazily), so the order of verbs doesn't
  matter.
- **Overlay** = virtual channel like a merge (`add_overlay(GFP, Cy3, name,
  color = "white", threshold = NULL)`): the minimum of the members'
  display-scaled (0-1) intensities, in one colour, not stretched again;
  optional threshold on the 0-1 scale. Black -> inverted. Legend entry
  "name (GFP, Cy3)". Not counted as a merge for hero defaults, boxes or
  scale bars (`"merge"`).
- **Merge** = virtual channel. Merges combine the rows sharing a panel cell
  (all dimensions except channel). Member channels need not be shown.
- **Exposure** is a display property, linked per channel by default.
- **Black channels**: a single channel coloured black (`"#000000"`) is drawn
  inverted, dark signal on white, with a thin black frame; zoom boxes on it
  are black. **Merges are always on black** (colours add up like light);
  black members use their original colour (the `color` column) unless
  `add_merge(colors = c(GFP = "red"))` sets one; still black -> warning. The
  legend adds "merge: GFP" entries where merge colours differ.
- **Crop**: size given once (um by default), so magnification is equal by
  construction; only the position varies.
- **Zoom** = additional `view` level, shown as its own panel (no insets). Box
  on the parent view (`box = "all" | "merge" | "none"`). No connector lines.
- **Positions**: tibble joined on shared columns, centers relative 0-1 by
  default, `center_units = "px"` for Fiji pixels.

## Layouts are like themes

Two kinds of dimensions:

- **Block dimensions**: columns mapped to `x` / `y` (condition, mutant, ...).
  They arrange blocks in every layout.
- **Within-block dimensions**: `channel` and `view`. The layout arranges them.

Switching the layout keeps the mapping.

- `layout_grid(channel = "auto", view = "auto")` (default, `"grid"`): channel
  and view go onto an axis, innermost, only if they still vary within a cell.
  `"auto"`: channel on a free axis (no block dimensions; `x` first), view on
  the other one. Mapping `channel` or `view` in `x` / `y` overrides this.
- `layout_hero(hero = panel(...), side = panel(...), position = "right" |
  "bottom" | "left")` (`"hero"`): one big panel plus a strip of side panels
  per block. Defaults: hero = the merge (or first channel) of the main view;
  side = the single channels of the zoom (or of the main view). Hero edge =
  n * side + (n - 1) * gap; blocks are 3 * gap apart. channel/view in x/y are
  ignored (with a message). Warn above 4 side panels.
  `labels = TRUE` (default): side panels labelled with what distinguishes them
  (channel, else view), in the header font, outside the images: below
  (bottom) or beside, rotated like ggplot2 facet strips (right: -90,
  left: 90). Long labels wrap to two lines (may reach into the gaps), with a
  warning if still too long. Label space is added on top of the box.
- `add_color_legend("bottom" | "top" | "right")` (default bottom): swatch + channel name for
  the channels shown (merge members, not merges), outside the panels.
- Geometry: both are grids of cells whose size is linear in one free size;
  the largest that fits the box is used.
- `get_panels(m)`: panel rectangles (mm), roles, source regions.

## Naming decisions

- `view` for the crop/zoom dimension.
- `panel()` helper for picking panels in `layout_hero()`.
- Themes in the tidyplots sense (pure style: background, fonts, gaps, scale
  bar style, palette) are still to come, separate from layouts.

## Rendering (since 2026-11-24)

A montage renders to its own gtable (grid only, no ggplot2): 3 x 3 tracks,
the middle ones are the image grid ("panel"), the outer ones decoration.
`print()` and `save_montage()` draw it at exact size (bitmaps via ragg if
installed); pixels are read lazily in `makeContent()`. tidylayouts can align
montages on their image grid. See `dev/gtable-spike/`.
