suppressMessages({devtools::load_all(quiet = TRUE); library(dplyr)})
out <- "dev/renderer-try"
cells <- read_images(list.files("demo_images", "\\.ome\\.tif$", full.names = TRUE)) |>
  mutate(mutant = if_else(grepl("I56A", filepath), "I56A", "L59A"))

crops <- tibble(mutant = c("I56A", "L59A"), x = c(0.47, 0.42), y = c(0.40, 0.55))
zooms <- tibble(mutant = c("I56A", "L59A"), x = c(0.50, 0.40), y = c(0.33, 0.55))

m <- cells |>
  tidymontage() |>
  add_merge(Cy3, `Alexa Fluor 488`, DAPI) |>
  adjust_crop(width = 60, center = crops) |>
  add_zoom(width = 15, center = zooms, box = "merge") |>
  layout_grid(x = c(view, mutant), y = channel)
cat(format(m), sep = "\n")
print(montage_panels(m) |> select(col, row, channel, view, mutant, px_xmin:px_ymax), n = 4)
t0 <- Sys.time(); save_montage(m, file.path(out, "crop_zoom.png"), width = 180); cat(format(Sys.time() - t0), "\n")

# zoom without crop, zoom row below
m2 <- cells |>
  tidymontage() |>
  add_merge(Cy3, `Alexa Fluor 488`, DAPI) |>
  add_zoom(width = 20, center = zooms) |>
  layout_grid(x = mutant, y = view, channel = "merge")
save_montage(m2, file.path(out, "zoom_rows.png"), width = 90)
