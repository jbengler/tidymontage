source("ifd.R")
dir <- "/Users/janbroderengler/GoogleDrive/R/packages/tidymontage/demo_images"
f <- list.files(dir, pattern = "12_23_13\\.tif$", full.names = TRUE)
r <- read_ifds(f); t1 <- r$ifds[[1]]
be <- r$endian
counts_raw <- read_tag_raw(f, t1[t1$tag == 50838, ], be)
counts <- readBin(counts_raw, "integer", length(counts_raw) / 4, 4, endian = be)
data <- read_tag_raw(f, t1[t1$tag == 50839, ], be)
cat("byte counts:", counts, "\n")
hdr <- data[1:counts[1]]
magic <- rawToChar(hdr[1:4])
ntypes <- (counts[1] - 4) / 8
types <- lapply(seq_len(ntypes), function(i) {
  b <- hdr[(5 + (i - 1) * 8):(4 + i * 8)]
  list(type = rawToChar(b[1:4]), n = readBin(b[5:8], "integer", 1, 4, endian = be))
})
str(types)
pos <- counts[1]; k <- 2
utf16 <- function(b) { v <- readBin(b, "integer", length(b) / 2, 2, signed = FALSE, endian = be); intToUtf8(v) }
for (ty in types) for (j in seq_len(ty$n)) {
  b <- data[(pos + 1):(pos + counts[k])]; pos <- pos + counts[k]; k <- k + 1
  if (ty$type %in% c("info", "labl")) {
    s <- utf16(b)
    cat("\n[", ty$type, j, "] nchar", nchar(s), "\n")
    if (ty$type == "labl") cat(s, "\n") else {
      lines <- strsplit(s, "\n")[[1]]
      cat(length(lines), "lines. Matching channel/scaling/display:\n")
      hits <- grep("Channel.*\\|(Name|Color|DyeName|Fluor)|Scaling\\|Distance\\|Value|DisplaySetting.*(Low|High|Color)|Objective.*Name|Emission|Excitation", lines, value = TRUE)
      cat(head(hits, 60), sep = "\n")
    }
  } else if (ty$type == "rang") {
    cat("\n[rang]", readBin(b, "double", length(b) / 8, 8, endian = be), "\n")
  } else if (ty$type == "luts") {
    m <- matrix(as.integer(b), ncol = 3)  # 256 R, then G, then B
    cat("\n[luts", j, "] last entry RGB:", m[256, ], "\n")
  } else cat("\n[", ty$type, "] bytes", length(b), "\n")
}
# ColorMap from the bio-formats tif
g <- list.files(dir, pattern = "12_23_13_OME\\.tif$", full.names = TRUE)
rg <- read_ifds(g)
for (i in seq_along(rg$ifds)) {
  row <- rg$ifds[[i]][rg$ifds[[i]]$tag == 320, ]
  cm <- readBin(read_tag_raw(g, row, rg$endian), "integer", row$count, 2, signed = FALSE, endian = rg$endian)
  m <- matrix(cm, ncol = 3)
  cat("OME.tif page", i, "ColorMap last RGB (16-bit):", m[65536, ], "\n")
}
