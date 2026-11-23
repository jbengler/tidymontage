suppressWarnings(library(tiff)); source("ifd.R"); source("ij.R")
f <- "../../demo_images/DIV14Actin-01-Airyscan Processing-02.tif"
ij <- read_ij_meta(f)
C <- 4; Z <- 7; T <- 1
idx <- function(c, z, t = 1) (t - 1) * C * Z + (z - 1) * C + c
labs <- unlist(ij$labl)
expected <- unlist(lapply(1:Z, function(z) sprintf("c:%d/%d z:%d/%d", 1:C, C, z, Z)))
ok <- all(startsWith(labs[idx(rep(1:C, Z), rep(1:Z, each = C))], expected))
cat("CZT page formula matches all 28 slice labels:", ok, "\n")
tm <- function(label, expr) { gc(); t0 <- Sys.time(); v <- expr; cat(sprintf("%-38s %.2fs\n", label, as.numeric(Sys.time() - t0, units = "secs"))); v }
# streaming max projection: one page at a time
stream_max <- function(c) {
  acc <- NULL
  for (z in 1:Z) { p <- suppressWarnings(readTIFF(f, all = idx(c, z), as.is = TRUE))[[1]]; acc <- if (is.null(acc)) p else pmax(acc, p) }
  acc
}
m1 <- tm("stream max, channel 1 (7 pages)", stream_max(1))
m2 <- tm("batch max, channel 1 (one readTIFF)", do.call(pmax, suppressWarnings(readTIFF(f, all = idx(1, 1:Z), as.is = TRUE))))
cat("stream == batch:", identical(m1, m2), "\n")
all4 <- tm("stream max, all 4 channels", lapply(1:C, stream_max))
mean4 <- tm("mean projection, channel 4", Reduce(`+`, lapply(suppressWarnings(readTIFF(f, all = idx(4, 1:Z), as.is = TRUE)), as.numeric)) / Z)
cat("max-proj ranges per channel:\n"); print(t(sapply(all4, range)))
cat("per-plane 99.9th percentile, channel 1:", sapply(1:Z, function(z) quantile(suppressWarnings(readTIFF(f, all = idx(1, z), as.is = TRUE))[[1]], 0.999)), "\n")
cat("one plane MB:", format(object.size(m1), units = "MB"), "\n")
