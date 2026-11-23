suppressWarnings(library(tiff))
dir <- "/Users/janbroderengler/GoogleDrive/R/packages/tidymontage/demo_images"
files <- list.files(dir, pattern = "\\.tif$", full.names = TRUE)
for (f in files) {
  cat("\n=====", basename(f), "=====\n")
  t0 <- Sys.time()
  info <- suppressWarnings(readTIFF(f, payload = FALSE, all = TRUE))
  cat("info all pages:", format(Sys.time() - t0), " pages:", length(info), "\n")
  a <- attributes(info[[1]])
  str(a[setdiff(names(a), "description")])
  d <- a$description
  cat("description nchar:", if (is.null(d)) "NULL" else nchar(d), "\n")
  if (!is.null(d)) cat(substr(d, 1, 2500), "\n")
  cat("pages with description:", sum(vapply(info, function(x) !is.null(attr(x, "description")), logical(1))), "\n")
}
