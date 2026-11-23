suppressWarnings(library(tiff)); source("ifd.R")
dir <- "../../demo_images"
g <- list.files(dir, "12_23_13[.]tif$", full.names = TRUE)
f <- list.files(dir, "12_23_13[.]ome[.]tif$", full.names = TRUE)
h <- list.files(dir, "12_23_13_OME[.]tif$", full.names = TRUE)
a <- suppressWarnings(readTIFF(g, all = 1, as.is = TRUE))[[1]]
bi <- suppressWarnings(readTIFF(f, all = 1, indexed = TRUE))[[1]] - 1L
hi <- suppressWarnings(readTIFF(h, all = 1, indexed = TRUE))[[1]] - 1L
cat("ImageJ  a[1:3,1:4]:\n"); print(a[1:3, 1:4])
cat(".ome    [1:3,1:4]:\n"); print(bi[1:3, 1:4])
cat("_OME    [1:3,1:4]:\n"); print(hi[1:3, 1:4])
cat("ome vs ImageJ: n diff", sum(a != bi), " t(ome) identical:", identical(t(bi), a), " flip rows:", identical(bi[nrow(bi):1, ], a), "\n")
cat("ranges", range(a), "|", range(bi), "\n")
# raw strip read for page 1, bypassing libtiff
r <- read_ifds(f); t1 <- r$ifds[[1]]
off <- read_tag_raw(f, t1[t1$tag == 273, ], r$endian); cnt <- t1[t1$tag == 273, "count"]
offs <- readBin(off, "integer", cnt, 4, endian = r$endian)
con <- file(f, "rb"); seek(con, offs[1]); row1 <- readBin(con, "integer", 1796, 2, signed = FALSE, endian = r$endian); close(con)
cat("raw first row from file:", row1[1:6], "\n")
cat("matrix a first row     :", a[1, 1:6], "\n")
