source("ifd.R")
dir <- "/Users/janbroderengler/GoogleDrive/R/packages/tidymontage/demo_images"
for (f in list.files(dir, pattern = "12_23_13.*\\.tif$", full.names = TRUE)) {
  cat("\n=====", basename(f), "=====\n")
  r <- read_ifds(f)
  cat("endian:", r$endian, " bigtiff:", r$bigtiff, " IFDs:", length(r$ifds), "\n")
  print(r$ifds[[1]])
  big <- subset(r$ifds[[1]], type %in% c(1, 2, 7) & count > 100)
  for (i in seq_len(nrow(big))) {
    raw <- read_tag_raw(f, big[i, ], r$endian)
    txt <- rawToChar(raw[raw != as.raw(0)][1:min(800, sum(raw != as.raw(0)))])
    cat("\n--- tag", big$tag[i], "type", big$type[i], "bytes", big$count[i], "\n", txt, "\n")
  }
}
