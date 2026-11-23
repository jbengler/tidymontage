suppressWarnings(library(tiff)); source("ifd.R"); source("ij.R")
f <- "../../demo_images/DIV14Actin-01-Airyscan Processing-02.tif"
t0 <- Sys.time(); r <- read_ifds(f); cat("walk all IFDs:", format(Sys.time() - t0), "\n")
cat("endian:", r$endian, " bigtiff:", r$bigtiff, " IFDs:", length(r$ifds), "\n")
cat("IFD 1 tags:", r$ifds[[1]]$tag, "\nIFD 2 tags:", r$ifds[[2]]$tag, "\n")
desc <- rawToChar(read_description(f)); cat("--- description\n", desc, "\n")
info <- suppressWarnings(readTIFF(f, payload = FALSE, info = TRUE, all = 1))
print(info[, setdiff(names(info), "description")])
ij <- read_ij_meta(f, r)
cat("--- IJ blocks:", paste(names(ij), lengths(ij)), "\n")
if (!is.null(ij$labl)) cat("labels (first 6):", head(unlist(ij$labl)), sep = "\n  ")
if (!is.null(ij$rang)) cat("ranges:", ij$rang[[1]], "\n")
if (!is.null(ij$luts)) cat("LUT tops:", vapply(ij$luts, function(m) paste(m[256, ], collapse = ","), ""), "\n")
if (!is.null(ij$info)) {
  lines <- strsplit(ij$info[[1]], "\n")[[1]]
  cat("info lines:", length(lines), "\n")
  cat(grep("SizeZ|SizeC|SizeT|DimensionOrder|Scaling\\|Distance\\|(Id|Value)|Channel\\|(Name|Fluor|Color) |Information\\|Image\\|Channel\\|(Name|Fluor)|ZoomX|Objective.*(Model|Name) ", lines, value = TRUE), sep = "\n")
}
