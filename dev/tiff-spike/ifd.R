# Minimal TIFF / BigTIFF IFD walker in pure R
type_size <- c(`1`=1,`2`=1,`3`=2,`4`=4,`5`=8,`6`=1,`7`=1,`8`=2,`9`=4,`10`=8,`11`=4,`12`=8,`16`=8,`17`=8,`18`=8)
read_ifds <- function(path, max_ifds = Inf) {
  con <- file(path, "rb"); on.exit(close(con))
  bo <- rawToChar(readBin(con, "raw", 2))
  endian <- if (bo == "II") "little" else "big"
  u16 <- function() readBin(con, "integer", 1, 2, signed = FALSE, endian = endian)
  u32 <- function() { v <- readBin(con, "integer", 1, 4, endian = endian); if (v < 0) v + 2^32 else v }
  u64 <- function() { lo <- u32(); hi <- u32(); if (endian == "little") hi * 2^32 + lo else lo * 2^32 + hi }
  magic <- u16(); big <- magic == 43
  if (big) { u16(); u16(); off <- u64() } else off <- u32()
  ifds <- list(); k <- 0
  while (off != 0 && k < max_ifds) {
    k <- k + 1
    seek(con, off)
    n <- if (big) u64() else u16()
    tags <- vector("list", n)
    for (i in seq_len(n)) {
      tag <- u16(); type <- u16(); cnt <- if (big) u64() else u32()
      pos <- seek(con)
      sz <- type_size[[as.character(type)]] * cnt
      inline <- sz <= (if (big) 8 else 4)
      voff <- if (inline) pos else if (big) u64() else u32()
      tags[[i]] <- data.frame(tag = tag, type = type, count = cnt, offset = voff)
      seek(con, pos + (if (big) 8 else 4))
    }
    off <- if (big) u64() else u32()
    ifds[[k]] <- do.call(rbind, tags)
  }
  list(endian = endian, bigtiff = big, ifds = ifds)
}
read_tag_raw <- function(path, row, endian) {
  con <- file(path, "rb"); on.exit(close(con))
  seek(con, row$offset)
  readBin(con, "raw", row$count * type_size[[as.character(row$type)]])
}
