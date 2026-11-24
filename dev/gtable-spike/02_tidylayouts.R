# Place montages in a tidylayouts figure. tidylayouts aligns "plot" leaves on
# their panel tracks; a plot leaf only needs a gtable, so the spike hands it
# one directly (no change to tidylayouts).
suppressMessages({
  devtools::load_all("../tidylayouts", quiet = TRUE)
  devtools::load_all(".", quiet = TRUE)
  library(dplyr)
})
source("dev/gtable-spike/gtable.R")
out <- "dev/gtable-spike/out"
montage_leaf <- function(m) new_node("plot", plot = NULL, gtable = montage_gtable(m, dpi = 200))

cells <- read_images(list.files("demo_images", "\\.ome\\.tif$", full.names = TRUE)) |>
  mutate(mutant = if_else(grepl("I56A", filepath), "I56A", "L59A"))
crops <- tibble(mutant = c("I56A", "L59A"), x = c(0.47, 0.42), y = c(0.40, 0.55))
zooms <- tibble(mutant = c("I56A", "L59A"), x = c(0.50, 0.40), y = c(0.40, 0.48))

# headers above and a legend below: the images, not the decoration, should align
m1 <- cells |> tidymontage(x = mutant, channel = c("Cy3", "merge"), width = 50, height = NA) |>
  add_merge(Cy3, `Alexa Fluor 488`, DAPI) |> add_color_legend()
m2 <- cells |> tidymontage(x = mutant, layout = layout_hero(position = "bottom"), width = 80, height = NA) |>
  add_merge(Cy3, `Alexa Fluor 488`, DAPI) |> add_crop(width = 60, center = crops) |>
  add_zoom(width = 15, center = zooms) |> add_scale_bar()

p1 <- dummy(name = "plot", color = "#0072B2")
p2 <- dummy(name = "plot", color = "#D55E00", height = 45)

fig <- new_row(p1, montage_leaf(m1)) |>
  new_row(montage_leaf(m2), p2) |>
  layout_tags("A")
grDevices::png(file.path(out, "tidylayouts.png"), width = 180, height = 150, units = "mm", res = 200)
print(fig)
invisible(grDevices::dev.off())

# check the alignment numerically: the montage's panel track is its image grid
gt <- montage_gtable(m1)
cat("montage tracks (mm): widths", round(grid::convertWidth(gt$widths, "mm", TRUE), 1),
    "| heights", round(grid::convertHeight(gt$heights, "mm", TRUE), 1), "\n")
leaf <- tidylayouts:::measure_leaf(montage_leaf(m1))
str(leaf$meas)
