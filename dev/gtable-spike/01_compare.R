# Render README-like montages with the current ggplot renderer and with the
# gtable spike, and compare the PNGs pixel by pixel.
suppressMessages({devtools::load_all(quiet = TRUE); library(dplyr)})
source("dev/gtable-spike/gtable.R")
out <- "dev/gtable-spike/out"
dir.create(out, showWarnings = FALSE)
cells <- read_images(list.files("demo_images", "\\.ome\\.tif$", full.names = TRUE)) |>
  mutate(mutant = if_else(grepl("I56A", filepath), "I56A", "L59A"))
crops <- tibble(mutant = c("I56A", "L59A"), x = c(0.47, 0.42), y = c(0.40, 0.55))
zooms <- tibble(mutant = c("I56A", "L59A"), x = c(0.50, 0.40), y = c(0.40, 0.48))
montages <- list(
  grid = cells |> tidymontage(x = mutant) |> add_merge(Cy3, `Alexa Fluor 488`, DAPI) |>
    add_crop(width = 60, center = crops) |> add_zoom(width = 15, center = zooms, box = "merge") |> add_scale_bar(),
  hero = cells |> tidymontage(x = mutant, layout = layout_hero(position = "bottom")) |>
    add_merge(Cy3, `Alexa Fluor 488`, DAPI) |> add_crop(width = 60, center = crops) |>
    add_zoom(width = 15, center = zooms) |> add_scale_bar() |> add_color_legend(),
  ink = cells |> tidymontage(x = mutant, channel = c("Cy3", "merge")) |> adjust_colors(Cy3 = "black") |>
    add_merge(Cy3, `Alexa Fluor 488`) |> add_color_legend()
)
for (nm in names(montages)) {
  m <- montages[[nm]]
  t0 <- Sys.time(); suppressMessages(save_montage(m, file.path(out, paste0(nm, "_ggplot.png")), dpi = 200)); t_gg <- Sys.time() - t0
  t0 <- Sys.time(); gt <- montage_gtable(m, dpi = 200); t_build <- Sys.time() - t0
  t0 <- Sys.time(); size <- save_gtable(gt, file.path(out, paste0(nm, "_gtable.png")), dpi = 200); t_gt <- Sys.time() - t0
  a <- png::readPNG(file.path(out, paste0(nm, "_ggplot.png")))
  b <- png::readPNG(file.path(out, paste0(nm, "_gtable.png")))
  same_dim <- identical(dim(a)[1:2], dim(b)[1:2])
  diff <- if (same_dim) mean(abs(a[, , 1:3] - b[, , 1:3]) > 0.02) else NA
  cat(sprintf("%-5s size %s mm | dims equal: %s | pixels differing > 2%%: %s | ggplot %.2fs, gtable object %.3fs, gtable draw %.2fs\n",
              nm, paste(round(size, 1), collapse = " x "), same_dim, if (is.na(diff)) "NA" else sprintf("%.2f%%", 100 * diff),
              as.numeric(t_gg, units = "secs"), as.numeric(t_build, units = "secs"), as.numeric(t_gt, units = "secs")))
}
