suppressWarnings(library(tiff))
dir <- "/Users/janbroderengler/GoogleDrive/R/packages/tidymontage/demo_images"
for (f in list.files(dir, pattern = "12_23_13.*\\.tif$", full.names = TRUE)) {
  cat("\n=====", basename(f), "=====\n")
  x <- suppressWarnings(readTIFF(f, payload = FALSE, info = TRUE, all = TRUE))
  print(x[, setdiff(names(x), "description")])
  for (i in seq_len(nrow(x))) {
    d <- x$description[i]
    cat("--- page", i, "description nchar:", nchar(d), "\n")
    if (!is.na(d) && nchar(d)) cat(substr(d, 1, 4000), "\n")
  }
}
