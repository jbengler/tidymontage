# Decode ImageJ private metadata (tags 50838/50839) into a list
read_ij_meta <- function(path, r = read_ifds(path, max_ifds = 1)) {
  t1 <- r$ifds[[1]]; be <- r$endian
  if (!all(c(50838, 50839) %in% t1$tag)) return(NULL)
  cr <- read_tag_raw(path, t1[t1$tag == 50838, ], be)
  counts <- readBin(cr, "integer", length(cr) / 4, 4, endian = be)
  data <- read_tag_raw(path, t1[t1$tag == 50839, ], be)
  hdr <- data[1:counts[1]]
  ntypes <- (counts[1] - 4) / 8
  utf16 <- function(b) intToUtf8(readBin(b, "integer", length(b) / 2, 2, signed = FALSE, endian = be))
  out <- list(); pos <- counts[1]; k <- 2
  for (i in seq_len(ntypes)) {
    b <- hdr[(5 + (i - 1) * 8):(4 + i * 8)]
    type <- rawToChar(b[1:4]); n <- readBin(b[5:8], "integer", 1, 4, endian = be)
    vals <- vector("list", n)
    for (j in seq_len(n)) {
      x <- data[(pos + 1):(pos + counts[k])]; pos <- pos + counts[k]; k <- k + 1
      vals[[j]] <- switch(type,
        info = , labl = , prop = utf16(x),
        rang = readBin(x, "double", length(x) / 8, 8, endian = be),
        luts = matrix(as.integer(x), ncol = 3),
        x)
    }
    out[[type]] <- vals
  }
  out
}
read_description <- function(path, r = read_ifds(path, max_ifds = 1)) {
  t1 <- r$ifds[[1]]
  if (!270 %in% t1$tag) return(NULL)
  d <- read_tag_raw(path, t1[t1$tag == 270, ], r$endian)
  d[d != as.raw(0)]
}
