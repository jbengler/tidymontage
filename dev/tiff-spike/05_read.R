suppressWarnings(library(tiff))
dir <- "/Users/janbroderengler/GoogleDrive/R/packages/tidymontage/demo_images"
f <- list.files(dir, pattern = "12_23_13\\.tif$", full.names = TRUE)
g <- list.files(dir, pattern = "12_23_13_OME\\.tif$", full.names = TRUE)
tm <- function(expr) { t0 <- Sys.time(); v <- expr; cat(sprintf("  %.3fs\n", as.numeric(Sys.time() - t0, units = "secs"))); v }
cat("all pages, as.is:\n"); a <- tm(suppressWarnings(readTIFF(f, all = TRUE, as.is = TRUE)))
cat("page 2 only (all = 2), as.is:\n"); p2 <- tm(suppressWarnings(readTIFF(f, all = 2, as.is = TRUE)))
cat("class:", class(p2), " len:", length(p2), "\n"); str(p2)
x <- if (is.list(p2)) p2[[1]] else p2
cat("identical to page 2 of full read:", identical(x, a[[2]]), "\n")
cat("storage:", storage.mode(x), " range:", range(x), " n distinct:", length(unique(as.vector(x))), "\n")
cat("as.is=FALSE range (scaled):", range(suppressWarnings(readTIFF(f, all = 2))[[1]]), "\n")
cat("pages c(3,1):\n"); p31 <- tm(suppressWarnings(readTIFF(f, all = c(3, 1), as.is = TRUE)))
cat("order kept (3 then 1):", identical(p31[[1]], a[[3]]), identical(p31[[2]], a[[1]]), "\n")
cat("palette file page 2, as.is:\n"); q <- tm(suppressWarnings(readTIFF(g, all = 2, as.is = TRUE)))
q <- if (is.list(q)) q[[1]] else q
cat("dims:", dim(q), " identical pixels to ImageJ tif:", identical(q, a[[2]]), "\n")
cat("palette file page 2, indexed = TRUE:\n"); qi <- suppressWarnings(readTIFF(g, all = 2, indexed = TRUE)); str(qi)
cat("memory of one page (MB):", format(object.size(x), units = "MB"), "\n")
