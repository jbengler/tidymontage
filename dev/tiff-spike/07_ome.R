suppressWarnings(library(tiff)); source("ifd.R")
dir <- "/Users/janbroderengler/GoogleDrive/R/packages/tidymontage/demo_images"
f <- list.files(dir, pattern = "12_23_13\\.ome\\.tif$", full.names = TRUE)
r <- read_ifds(f)
cat("endian:", r$endian, " bigtiff:", r$bigtiff, " IFDs:", length(r$ifds), "\n")
for (i in seq_along(r$ifds)) cat("IFD", i, "tags:", paste(r$ifds[[i]]$tag, collapse = " "), "\n")
t1 <- r$ifds[[1]]
d <- read_tag_raw(f, t1[t1$tag == 270, ], r$endian)
xml_raw <- d[d != as.raw(0)]
cat("ImageDescription bytes:", length(d), "\n")
x <- xml2::read_xml(xml_raw); xml2::xml_ns_strip(x)
img <- xml2::xml_find_all(x, "//Image")
cat("Images (series):", length(img), "\n")
px <- xml2::xml_find_first(x, "//Pixels")
print(unlist(xml2::xml_attrs(px)))
ch <- xml2::xml_find_all(px, "Channel")
print(do.call(rbind, lapply(ch, function(n) as.data.frame(as.list(xml2::xml_attrs(n))))))
td <- xml2::xml_find_all(px, "TiffData")
cat("TiffData entries:", length(td), "\n"); print(do.call(rbind, lapply(td, function(n) as.data.frame(as.list(xml2::xml_attrs(n))))))
cat("Planes:", length(xml2::xml_find_all(px, "Plane")), "\n")
cat("StructuredAnnotations children:", length(xml2::xml_children(xml2::xml_find_first(x, "//StructuredAnnotations"))), "\n")
obj <- xml2::xml_find_all(x, "//Objective"); if (length(obj)) print(unlist(xml2::xml_attrs(obj[[1]])))
# pixels vs ImageJ tif
g <- list.files(dir, pattern = "12_23_13\\.tif$", full.names = TRUE)
info <- suppressWarnings(readTIFF(f, payload = FALSE, info = TRUE, all = TRUE))
print(info[, intersect(names(info), c("width","length","bits.per.sample","sample.format","compression","color.space","software"))])
a <- suppressWarnings(readTIFF(g, all = TRUE, as.is = TRUE))
b <- suppressWarnings(readTIFF(f, all = TRUE, as.is = TRUE))
cat("pixels identical to ImageJ tif, per page:", mapply(identical, a, b), "\n")
bi <- suppressWarnings(readTIFF(f, all = TRUE, indexed = TRUE))
cat("indexed - 1 identical to ImageJ tif, per page:", mapply(function(p, q) identical(p, q - 1L), a, bi), "\n")
# OME Color is a signed 32-bit RGBA integer
ome_color <- function(v) { v <- as.numeric(v); v[v < 0] <- v[v < 0] + 2^32
  sprintf("#%02X%02X%02X", (v %/% 2^24) %% 256, (v %/% 2^16) %% 256, (v %/% 2^8) %% 256) }
cat("channel colours:", ome_color(xml2::xml_attr(ch, "Color")), "\n")
cat("unit bytes:", as.character(charToRaw(enc2utf8(xml2::xml_attr(px, "PhysicalSizeXUnit")))), "\n")
