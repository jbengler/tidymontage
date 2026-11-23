suppressMessages({devtools::load_all(quiet = TRUE); library(dplyr)})
source("dev/long-tibble-spike/img.R")
source("dev/long-tibble-spike/view.R")
out <- "dev/long-tibble-spike/out"

# A: two conditions, linked exposure, global crop + inset + scale bar ----------
cells <- read_images(list.files("demo_images", "\\.ome\\.tif$", full.names = TRUE)) |>
  as_long() |>
  mutate(mutant = if_else(grepl("I56A", filepath), "I56A", "L59A"))

t0 <- Sys.time()
p <- cells |>
  mutate(img = exposure(img, "p0.1", "p99.9"), .by = channel) |>
  view_montage(
    x = mutant,
    crop = list(x = c(400, 1399), y = c(300, 1299)),
    inset = list(x = c(800, 949), y = c(600, 749)),
    scale_bar = 10
  )
save_view(p, file.path(out, "A_conditions.png"))
cat("A rendered + saved:", format(Sys.time() - t0), " size mm:", attr(p, "size_mm"), "\n")

# B: z-stack, max projection via summarise, per-channel exposure ---------------
t0 <- Sys.time()
p <- read_images("demo_images/DIV14Actin-01-Airyscan Processing-02.tif") |>
  as_long() |>
  filter(t == 1) |>
  summarise(img = max(img), .by = c(filepath, channel, color, size_x, size_y, pixel_size)) |>
  mutate(img = exposure(img, "p0.1", "p99.8"), .by = channel) |>
  mutate(sample = "DIV14") |>
  view_montage(
    x = sample,
    crop = list(x = c(400, 1599), y = c(400, 1599)),
    inset = list(x = c(900, 1099), y = c(1100, 1299)),
    scale_bar = 20
  )
save_view(p, file.path(out, "B_zstack_projection.png"))
cat("B rendered + saved:", format(Sys.time() - t0), "\n")

# C: per-column crop positions (same size, different place per condition) ------
p <- cells |>
  mutate(img = exposure(img), .by = channel) |>
  view_montage(
    x = mutant,
    crop = list(x = c(1, 800), y = c(1, 800)),
    crops = data.frame(mutant = c("I56A", "L59A"), x0 = c(500, 300), y0 = c(400, 600)),
    merge = TRUE, scale_bar = 10
  )
save_view(p, file.path(out, "C_per_column_crops.png"))

# D: honest-default warnings ----------------------------------------------------
cat("\n-- no exposure at all:\n")
withCallingHandlers(invisible(view_montage(cells, x = mutant)), warning = function(w) { cat("WARNING:", conditionMessage(w), "\n"); invokeRestart("muffleWarning") })
cat("\n-- exposure without .by:\n")
withCallingHandlers(invisible(view_montage(mutate(cells, img = exposure(img)), x = mutant)), warning = function(w) { cat("WARNING:", conditionMessage(w), "\n"); invokeRestart("muffleWarning") })
cat("\n-- exposure .by = c(channel, mutant) (unlinked on purpose): no warning\n")
invisible(view_montage(mutate(cells, img = exposure(img), .by = c(channel, mutant)), x = mutant))
cat("done\n")
