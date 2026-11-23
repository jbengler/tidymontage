suppressWarnings(library(tiff)); source("writer.R"); source("ifd.R")
C <- 2; Z <- 3; T <- 2
planes <- list(); for (t in 1:T) for (z in 1:Z) for (c in 1:C)
  planes[[length(planes) + 1]] <- matrix(as.integer(c * 1000 + z * 100 + t * 10), 4, 5)
desc <- sprintf("ImageJ=1.54p\nimages=%d\nchannels=%d\nslices=%d\nframes=%d\nhyperstack=true\nmode=composite\nunit=micron\nspacing=0.5\n", C*Z*T, C, Z, T)
for (big in c(FALSE, TRUE)) {
  p <- if (big) "hyper_big.tif" else "hyper.tif"
  write_tiff_min(p, planes, desc, bigtiff = big)
  cat("\n==", p, "size", file.size(p), "bytes; own parser bigtiff:", read_ifds(p)$bigtiff, " IFDs:", length(read_ifds(p)$ifds), "\n")
  res <- tryCatch({
    info <- readTIFF(p, payload = FALSE, info = TRUE, all = TRUE)
    cat("tiff info rows:", nrow(info), " desc ok:", grepl("slices=3", info$description[1]), "\n")
    # page index for (c, z, t) in CZT order
    idx <- function(c, z, t) (t - 1) * C * Z + (z - 1) * C + c
    pg <- readTIFF(p, all = idx(2, 3, 1), as.is = TRUE)[[1]]
    cat("c=2,z=3,t=1 -> page", idx(2, 3, 1), "value", pg[1, 1], "(expect 2310)\n")
    # z max projection for c=1, t=2 reading only those pages
    zs <- readTIFF(p, all = idx(1, 1:Z, 2), as.is = TRUE)
    cat("max-proj c=1,t=2:", max(sapply(zs, max)), "(expect 1320); dims", dim(zs[[1]]), "\n")
  }, error = function(e) cat("tiff ERROR:", conditionMessage(e), "\n"))
}
