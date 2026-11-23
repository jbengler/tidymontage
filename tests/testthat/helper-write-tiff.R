# Minimal TIFF / BigTIFF writer for tiny synthetic test fixtures.
# Uncompressed, one strip per page, 8 or 16 bit, greyscale or RGB.

uint_bytes <- function(x, size, endian) {
  unlist(lapply(x, function(v) {
    b <- as.raw((v %/% 256^(0:(size - 1))) %% 256)
    if (endian == "big") rev(b) else b
  }))
}

encode_tag <- function(type, values, endian) {
  switch(
    as.character(type),
    `1` = ,
    `7` = if (is.raw(values)) values else as.raw(values),
    `2` = if (is.raw(values)) c(values, as.raw(0)) else c(charToRaw(values), as.raw(0)),
    `3` = uint_bytes(values, 2, endian),
    `4` = uint_bytes(values, 4, endian),
    `5` = uint_bytes(as.vector(rbind(round(values * 1e4), 1e4)), 4, endian),
    `12` = writeBin(as.double(values), raw(), size = 8, endian = endian),
    `16` = uint_bytes(values, 8, endian),
    stop("unsupported type")
  )
}

tag_count <- function(type, values, bytes) {
  if (type %in% c(1, 2, 7)) length(bytes) else length(values)
}

# planes: list of integer matrices (h x w) or arrays (h x w x 3, RGB).
# tags: extra tags for the first page; page_tags: list of extra tags per page.
# Each tag is list(tag, type, values).
write_test_tiff <- function(path, planes, bits = 16, endian = "little", bigtiff = FALSE,
                            tags = list(), page_tags = list(), photometric = NULL) {
  u <- function(x, size) uint_bytes(x, size, endian)
  off_size <- if (bigtiff) 8 else 4
  buf <- charToRaw(if (endian == "little") "II" else "MM")
  buf <- if (bigtiff) c(buf, u(43, 2), u(8, 2), u(0, 2)) else c(buf, u(42, 2))
  next_ptr <- length(buf)
  buf <- c(buf, raw(off_size))
  pad <- function() if (length(buf) %% 2) buf <<- c(buf, as.raw(0))

  for (k in seq_along(planes)) {
    img <- planes[[k]]
    rgb <- length(dim(img)) == 3
    h <- dim(img)[1]
    w <- dim(img)[2]
    spp <- if (rgb) 3 else 1
    px <- if (rgb) as.vector(aperm(img, c(3, 2, 1))) else as.vector(t(img))
    data <- if (bits == 8) as.raw(px) else writeBin(as.integer(px), raw(), size = 2, endian = endian)
    data_pos <- length(buf)
    buf <- c(buf, data)
    pad()

    phot <- if (!is.null(photometric)) photometric else if (rgb) 2 else 1
    offset_type <- if (bigtiff) 16 else 4
    all <- list(
      list(256, 4, w), list(257, 4, h), list(258, 3, rep(bits, spp)), list(259, 3, 1),
      list(262, 3, phot), list(273, offset_type, data_pos), list(277, 3, spp),
      list(278, 4, h), list(279, offset_type, length(data))
    )
    if (rgb) all <- c(all, list(list(284, 3, 1)))
    if (k == 1) all <- c(all, tags)
    if (length(page_tags) >= k) all <- c(all, page_tags[[k]])
    all <- all[order(vapply(all, function(t) t[[1]], numeric(1)))]

    entries <- list()
    for (tg in all) {
      vb <- encode_tag(tg[[2]], tg[[3]], endian)
      cnt <- tag_count(tg[[2]], tg[[3]], vb)
      if (length(vb) <= off_size) {
        field <- c(vb, raw(off_size - length(vb)))
      } else {
        pad()
        field <- u(length(buf), off_size)
        buf <- c(buf, vb)
      }
      entries[[length(entries) + 1]] <- c(u(tg[[1]], 2), u(tg[[2]], 2), u(cnt, off_size), field)
    }
    pad()
    ifd_pos <- length(buf)
    buf[next_ptr + seq_len(off_size)] <- u(ifd_pos, off_size)
    buf <- c(buf, u(length(all), if (bigtiff) 8 else 2), unlist(entries))
    next_ptr <- length(buf)
    buf <- c(buf, raw(off_size))
  }
  writeBin(buf, path)
  invisible(path)
}

# ImageJ private metadata tags (50838 byte counts, 50839 data).
ij_private_tags <- function(info = NULL, labels = NULL, ranges = NULL, luts = NULL, endian = "big") {
  utf16 <- function(s) uint_bytes(utf8ToInt(s), 2, endian)
  types <- list()
  blocks <- list()
  if (!is.null(info)) {
    types$info <- 1
    blocks <- c(blocks, list(utf16(info)))
  }
  if (!is.null(labels)) {
    types$labl <- length(labels)
    blocks <- c(blocks, lapply(labels, utf16))
  }
  if (!is.null(ranges)) {
    types$rang <- 1
    blocks <- c(blocks, list(writeBin(as.double(ranges), raw(), size = 8, endian = endian)))
  }
  if (!is.null(luts)) {
    types$luts <- length(luts)
    blocks <- c(blocks, lapply(luts, function(m) as.raw(as.vector(m))))
  }
  header <- c(
    charToRaw("IJIJ"),
    unlist(lapply(names(types), function(t) c(charToRaw(t), uint_bytes(types[[t]], 4, endian))))
  )
  list(
    list(50838, 4, c(length(header), lengths(blocks))),
    list(50839, 1, c(header, unlist(blocks)))
  )
}

# A 256 x 3 LUT ramping from black to `rgb` (0-255 each).
test_lut <- function(rgb) {
  ramp <- 0:255 / 255
  cbind(round(ramp * rgb[1]), round(ramp * rgb[2]), round(ramp * rgb[3]))
}

# Plane values encode channel, z and t: c * 10000 + z * 1000 + t * 100 + pixel (0-19).
test_plane <- function(c = 1, z = 1, t = 1, h = 4, w = 5) {
  matrix(as.integer(c * 10000 + z * 1000 + t * 100 + (seq_len(h * w) - 1)), h, w, byrow = TRUE)
}

local_tiff <- function(..., name = "test.tif", env = parent.frame()) {
  dir <- withr::local_tempdir(.local_envir = env)
  path <- file.path(dir, name)
  write_test_tiff(path, ...)
  path
}

# Pixels of the image at channel c, z-slice z and time point t.
pixels <- function(x, c = 1, z = 1, t = 1) {
  row <- x[x$channel_index == c & x$z == z & x$t == t, ]
  stopifnot(nrow(row) == 1)
  img_pixels(row$img)[[1]]
}
