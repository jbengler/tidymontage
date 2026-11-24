suppressMessages({devtools::load_all(quiet = TRUE); library(dplyr)})
out <- "dev/renderer-try"
cells <- read_images(list.files("demo_images", "\\.ome\\.tif$", full.names = TRUE)) |>
  mutate(mutant = if_else(grepl("I56A", filepath), "I56A", "L59A"))

m <- tidymontage(cells) |> layout_grid(x = mutant, y = channel)
print(format(m))
print(get_panels(m), width = 120)
t0 <- Sys.time(); save_montage(m, file.path(out, "grid.png"), width = 90); cat("grid:", format(Sys.time() - t0), "\n")

stack <- read_images("demo_images/DIV14Actin-01-Airyscan Processing-02.tif") |>
  summarise(img = max(img), .by = c(filepath, channel, color))
t0 <- Sys.time()
tidymontage(stack) |>
  adjust_colors(`Hoechst 33258` = "#56B4E9") |>
  adjust_exposure(max = "p99.8") |>
  layout_row() |>
  save_montage(file.path(out, "row.png"), width = 180)
cat("row:", format(Sys.time() - t0), "\n")
save_montage(tidymontage(stack) |> layout_row(), file.path(out, "row.pdf"), width = 180)
cat("pdf size:", file.size(file.path(out, "row.pdf")), "bytes\n")

cat("\n-- errors and warnings:\n")
try(print(tidymontage(cells) |> layout_grid(x = mutant)))
try(print(tidymontage(cells) |> layout_grid(x = channel)))
withCallingHandlers(
  invisible(montage_build(tidymontage(cells) |> adjust_exposure(.by = mutant) |> layout_grid(x = mutant, y = channel))),
  warning = function(w) { cat("WARNING:", conditionMessage(w), "\n"); invokeRestart("muffleWarning") }
)
