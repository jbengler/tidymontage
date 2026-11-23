# Minimal TIFF / BigTIFF structure parser in base R.
#
# `tiff` reads pixels well but only exposes the first ImageDescription and
# ignores private tags (ImageJ metadata) and per-page ColorMaps. This parser
# walks the IFD chain and decodes individual tags on demand.

tiff_type_size <- c(
  `1` = 1, `2` = 1, `3` = 2, `4` = 4, `5` = 8, `6` = 1, `7` = 1, `8` = 2,
  `9` = 4, `10` = 8, `11` = 4, `12` = 8, `13` = 4, `16` = 8, `17` = 8, `18` = 8
)

# Combine the byte columns of an integer matrix into unsigned integers (as double).
bytes_to_uint <- function(m, endian) {
  m <- matrix(as.integer(m), ncol = ncol(m))
  k <- ncol(m)
  weights <- 256^(if (endian == "little") 0:(k - 1) else (k - 1):0)
  drop(m %*% weights)
}

raw_uint <- function(x, size, endian) {
  bytes_to_uint(matrix(x, ncol = size, byrow = TRUE), endian)
}

# Open a TIFF and walk all IFDs. Returns a `tiff_file` list with one data
# frame of entries (tag, type, count, pos) per IFD, where `pos` is the file
# position of the tag's value (inline or at its offset).
tiff_open <- function(path, call = rlang::caller_env()) {
  size <- file.size(path)
  con <- file(path, "rb")
  on.exit(close(con))

  header <- readBin(con, "raw", 16)
  if (length(header) < 8) {
    cli::cli_abort("{.file {path}} is not a TIFF file.", call = call)
  }
  byte_order <- rawToChar(header[1:2])
  endian <- switch(byte_order, II = "little", MM = "big", NULL)
  if (is.null(endian)) {
    cli::cli_abort("{.file {path}} is not a TIFF file.", call = call)
  }
  magic <- raw_uint(header[3:4], 2, endian)
  if (!magic %in% c(42, 43)) {
    cli::cli_abort("{.file {path}} is not a TIFF file.", call = call)
  }
  bigtiff <- magic == 43
  offset <- if (bigtiff) raw_uint(header[9:16], 8, endian) else raw_uint(header[5:8], 4, endian)

  count_size <- if (bigtiff) 8 else 2
  entry_size <- if (bigtiff) 20 else 12
  field_size <- if (bigtiff) 8 else 4

  ifds <- list()
  seen <- numeric()
  while (offset > 0 && offset < size && !offset %in% seen) {
    seen <- c(seen, offset)
    seek(con, offset)
    n <- raw_uint(readBin(con, "raw", count_size), count_size, endian)
    block <- readBin(con, "raw", n * entry_size + field_size)
    if (length(block) < n * entry_size + field_size) {
      cli::cli_abort("{.file {path}} is truncated or corrupt.", call = call)
    }
    m <- matrix(block[seq_len(n * entry_size)], ncol = entry_size, byrow = TRUE)
    tag <- bytes_to_uint(m[, 1:2, drop = FALSE], endian)
    type <- bytes_to_uint(m[, 3:4, drop = FALSE], endian)
    count <- bytes_to_uint(m[, 5:(4 + field_size), drop = FALSE], endian)
    value_field <- m[, (5 + field_size):entry_size, drop = FALSE]
    type_size <- unname(tiff_type_size[as.character(type)])
    type_size[is.na(type_size)] <- 1
    inline <- type_size * count <= field_size
    entry_start <- offset + count_size + (seq_len(n) - 1) * entry_size
    pos <- ifelse(
      inline,
      entry_start + 4 + field_size,
      bytes_to_uint(value_field, endian)
    )
    ifds[[length(ifds) + 1]] <- data.frame(tag = tag, type = type, count = count, pos = pos)
    offset <- raw_uint(block[n * entry_size + seq_len(field_size)], field_size, endian)
  }
  if (length(ifds) == 0) {
    cli::cli_abort("{.file {path}} contains no images.", call = call)
  }

  structure(
    list(path = path, endian = endian, bigtiff = bigtiff, ifds = ifds),
    class = "tiff_file"
  )
}

# Decode one tag of one IFD (1-based). Returns NULL if the tag is absent.
# ASCII and UNDEFINED tags are returned as raw vectors.
tiff_tag <- function(tf, ifd, tag) {
  entries <- tf$ifds[[ifd]]
  e <- entries[entries$tag == tag, , drop = FALSE]
  if (nrow(e) == 0) {
    return(NULL)
  }
  e <- e[1, ]
  size <- tiff_type_size[as.character(e$type)]
  if (is.na(size)) {
    return(NULL)
  }
  n <- e$count
  con <- file(tf$path, "rb")
  on.exit(close(con))
  seek(con, e$pos)
  raw <- readBin(con, "raw", n * size)
  endian <- tf$endian
  switch(
    as.character(e$type),
    `1` = as.integer(raw),
    `2` = raw,
    `7` = raw,
    `3` = readBin(raw, "integer", n, 2, signed = FALSE, endian = endian),
    `4` = raw_uint(raw, 4, endian),
    `5` = {
      v <- raw_uint(raw, 4, endian)
      v[c(TRUE, FALSE)] / v[c(FALSE, TRUE)]
    },
    `6` = readBin(raw, "integer", n, 1, signed = TRUE),
    `8` = readBin(raw, "integer", n, 2, endian = endian),
    `9` = readBin(raw, "integer", n, 4, endian = endian),
    `10` = {
      v <- readBin(raw, "integer", 2 * n, 4, endian = endian)
      v[c(TRUE, FALSE)] / v[c(FALSE, TRUE)]
    },
    `11` = readBin(raw, "double", n, 4, endian = endian),
    `12` = readBin(raw, "double", n, 8, endian = endian),
    `13` = raw_uint(raw, 4, endian),
    `16` = raw_uint(raw, 8, endian),
    `18` = raw_uint(raw, 8, endian),
    raw
  )
}

# Basic properties of one page, with TIFF defaults filled in.
tiff_page_info <- function(tf, ifd) {
  get <- function(tag, default) {
    v <- tiff_tag(tf, ifd, tag)
    if (is.null(v)) default else v
  }
  bits <- get(258, 1)
  list(
    width = get(256, NA)[1],
    height = get(257, NA)[1],
    bits = bits[1],
    samples = get(277, 1)[1],
    sample_format = get(339, 1)[1],
    photometric = get(262, NA)[1],
    compression = get(259, 1)[1],
    x_resolution = get(282, NA)[1],
    resolution_unit = get(296, 2)[1]
  )
}

# Text of a tag stored as ASCII (raw bytes, trailing NULs removed), kept as
# raw so that callers can decide how to decode it.
tiff_tag_bytes <- function(tf, ifd, tag) {
  raw <- tiff_tag(tf, ifd, tag)
  if (is.null(raw) || !is.raw(raw)) {
    return(NULL)
  }
  raw[raw != as.raw(0)]
}

# Decode ASCII bytes as UTF-8 text, independent of the session locale.
bytes_to_utf8 <- function(raw) {
  if (is.null(raw)) {
    return(NULL)
  }
  txt <- rawToChar(raw)
  Encoding(txt) <- "UTF-8"
  txt
}
