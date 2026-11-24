suppressMessages({devtools::load_all(quiet = TRUE); library(dplyr)})
out <- "dev/renderer-try"
cells <- read_images(list.files("demo_images", "\\.ome\\.tif$", full.names = TRUE)) |>
  mutate(mutant = if_else(grepl("I56A", filepath), "I56A", "L59A"))
crops <- tibble(mutant = c("I56A", "L59A"), x = c(0.47, 0.42), y = c(0.40, 0.55))
zooms <- tibble(mutant = c("I56A", "L59A"), x = c(0.50, 0.40), y = c(0.33, 0.55))

m <- cells |>
  tidymontage() |>
  add_merge(Cy3, `Alexa Fluor 488`, DAPI) |>
  add_crop(width = 60, center = crops) |>
  add_zoom(width = 15, center = zooms, box = "merge") |>
  layout_grid(x = c(view, mutant), y = channel) |>
  add_scale_bar()
cat(format(m), sep = "\n")
save_montage(m, file.path(out, "annotations.png"), width = 180)

stack <- read_images("demo_images/DIV14Actin-01-Airyscan Processing-02.tif") |>
  summarise(img = max(img), .by = c(filepath, channel, color))
tidymontage(stack) |>
  add_merge(`Alexa Fluor 647`, `Alexa Fluor 488`, `Hoechst 33258`, name = "merge") |>
  layout_row() |>
  adjust_headers(x = FALSE) |>
  add_scale_bar(20, where = "merge") |>
  save_montage(file.path(out, "annotations_row.png"), width = 180)
