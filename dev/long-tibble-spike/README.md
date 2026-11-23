# Long image tibble spike (2026-11-23)

Question: can the image tibble be long (one row per file x channel x z x t)
with a lazy greyscale `img` column, so that processing is plain dplyr and
colour, merge, crop and zoom live in the viewer?

Run from the package root:

- `01_dplyr.R` – the `img` column through dplyr verbs.
- `02_montage.R` – three montages (`out/`) and the exposure warnings.
- `img.R` – `tm_img` vctrs class (lazy recipes), `exposure()`, materialisation.
- `view.R` – minimal ggplot viewer: colour, merge, crop, per-column crops,
  inset with zoom box, scale bar.

## Answer: yes, it works

- A list-backed `vctrs::new_vctr()` class survives `filter()`, `arrange()`,
  `slice()`, `mutate(.by)`, `summarise(.by)`, `bind_rows()` and `count()`.
- `max()`, `min()` (Summary group generic) and `mean()` dispatch inside
  `summarise(.by)` and return one lazy recipe ("max of 7"). Unsupported ones
  (`sum()`) fail with dplyr's usual group context.
- `exposure()` called in `mutate(.by = channel)` attaches one shared
  environment per group, so linked exposure is literally `.by = channel`.
  The range is computed once, at render time, from all members.
- The viewer detects the two honest-default problems and warns:
  no display range (falls back to per-image, unlinked) and one range
  spanning several channels (forgot `.by`). Deliberate unlinking
  (`.by = c(channel, condition)`) is silent.
- Colour and additive merge only in the viewer works naturally: the tibble
  stays greyscale, merge rows are built per x cell.
- Speed: max projection of 7 planes (2024²) 0.3 s; full 4x2 montage with
  insets rendered and saved at 300 dpi in ~2 s.

## Learned

1. **Per-image metadata must travel with `img`.** `summarise(.by)` drops every
   column not listed in `.by`; the spike had to list `size_x`, `size_y`,
   `pixel_size` and `color` in `.by` so the viewer could find them. Image
   geometry (size, pixel size, z step) should live inside the recipe, so a
   projection keeps it automatically. Display properties chosen by the user
   (`color`) can stay columns.
2. **Insets need per-column positions, like crops.** A global inset region
   lands on background in the second condition (`out/A_conditions.png`,
   right column). Crops and insets share the same "global or per x cell"
   mechanism. The inset corner should avoid overlapping its own zoom box.
3. **Projecting drops display ranges** (with a warning): exposure belongs
   after projection, which is also the scientifically right order.
4. **Ranges are cached in the shared environment.** Fine within a session;
   a stale cache after files change on disk is possible. Environments also
   give reference semantics inside an otherwise copy-on-modify tibble, which
   is what makes linking work but is worth keeping internal.
5. **Text in plots:** "µ" breaks in a C locale with the default font; plotmath
   (`10~mu*m`) works.
6. **Colours:** pure blue (`#0000FF`) Hoechst is very dark on black; supports
   the plan's colour-blind-safe defaults.

## Proposed package structure

- `read_images()` returns the long tibble: metadata columns + `z`, `t`, `img`.
  The `planes` list-column disappears.
- Data layer (dplyr): `filter()` planes, `summarise(img = max(img), .by = ...)`,
  `mutate(img = exposure(img, ...), .by = channel)`. Optional sugar verbs.
- Viewer: `tidymontage(x =, y =)` + layout, merge, crop (global or per x),
  zoom insets, labels, scale bars; rendering as a ggplot at exact size.
