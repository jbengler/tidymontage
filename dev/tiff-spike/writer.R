# Minimal uncompressed 16-bit greyscale TIFF / BigTIFF writer (little endian), one strip per page
write_tiff_min <- function(path, planes, description = NULL, bigtiff = FALSE) {
  con <- file(path, "wb"); on.exit(close(con))
  w16 <- function(x) writeBin(as.integer(x), con, size = 2, endian = "little")
  w32 <- function(x) writeBin(as.integer(x), con, size = 4, endian = "little")
  w64 <- function(x) { w32(x %% 2^32); w32(x %/% 2^32) }
  wo <- if (bigtiff) w64 else w32
  writeBin(charToRaw("II"), con)
  if (bigtiff) { w16(43); w16(8); w16(0); hdr <- 16 } else { w16(42); hdr <- 8 }
  first_ifd_pos <- seek(con); wo(0)
  desc <- if (!is.null(description)) c(charToRaw(description), as.raw(0))
  prev_next_pos <- first_ifd_pos
  for (k in seq_along(planes)) {
    m <- planes[[k]]; h <- nrow(m); w <- ncol(m)
    # pixel data (row-major)
    data_pos <- seek(con); writeBin(as.integer(t(m)), con, size = 2, endian = "little")
    desc_pos <- seek(con); if (k == 1 && !is.null(desc)) writeBin(desc, con)
    if (seek(con) %% 2) writeBin(as.raw(0), con)
    ifd_pos <- seek(con)
    # patch previous "next IFD" pointer
    seek(con, prev_next_pos, rw = "write"); wo(ifd_pos); seek(con, ifd_pos, rw = "write")
    tags <- list(c(256, 4, 1, w), c(257, 4, 1, h), c(258, 3, 1, 16), c(259, 3, 1, 1), c(262, 3, 1, 1))
    if (k == 1 && !is.null(desc)) tags <- c(tags, list(c(270, 2, length(desc), desc_pos)))
    tags <- c(tags, list(c(273, if (bigtiff) 16 else 4, 1, data_pos), c(277, 3, 1, 1), c(278, 4, 1, h),
                         c(279, if (bigtiff) 16 else 4, 1, 2 * w * h)))
    if (bigtiff) w64(length(tags)) else w16(length(tags))
    for (tg in tags) {
      w16(tg[1]); w16(tg[2]); wo(tg[3])
      inl <- tg[2] == 3 && tg[3] == 1
      if (bigtiff) { if (inl) { w16(tg[4]); w16(0); w32(0) } else w64(tg[4]) }
      else { if (inl) { w16(tg[4]); w16(0) } else w32(tg[4]) }
    }
    prev_next_pos <- seek(con); wo(0)
  }
}
