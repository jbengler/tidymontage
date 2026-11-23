# ImageJ metadata: the `ImageDescription` header ("ImageJ=1.54p\nchannels=3...")
# and the private tags 50838 (byte counts) / 50839 (data) holding info text,
# slice labels, display ranges and LUTs.

is_imagej_description <- function(txt) {
  !is.null(txt) && startsWith(txt, "ImageJ=")
}

ij_parse_description <- function(txt) {
  lines <- strsplit(txt, "\n", fixed = TRUE)[[1]]
  lines <- lines[grepl("=", lines, fixed = TRUE)]
  keys <- trimws(sub("=.*$", "", lines))
  values <- trimws(sub("^[^=]*=", "", lines))
  stats::setNames(as.list(values), keys)
}

ij_int <- function(desc, key, default = NA_integer_) {
  v <- suppressWarnings(as.integer(desc[[key]]))
  if (length(v) == 0 || is.na(v)) default else v
}

ij_num <- function(desc, key) {
  v <- suppressWarnings(as.numeric(desc[[key]]))
  if (length(v) == 0) NA_real_ else v
}

ij_private <- function(tf) {
  counts <- tiff_tag(tf, 1, 50838)
  data <- tiff_tag(tf, 1, 50839)
  if (is.null(counts) || is.null(data) || length(counts) < 1) {
    return(NULL)
  }
  # Tag 50839 is usually BYTE (decoded as integers), sometimes UNDEFINED (raw).
  if (!is.raw(data)) {
    data <- as.raw(data)
  }
  endian <- tf$endian
  header_size <- counts[1]
  if (header_size < 4 || length(data) < sum(counts) ||
    !identical(rawToChar(data[1:4]), "IJIJ")) {
    return(NULL)
  }
  utf16 <- function(b) {
    intToUtf8(readBin(b, "integer", length(b) / 2, 2, signed = FALSE, endian = endian))
  }
  out <- list()
  n_types <- (header_size - 4) %/% 8
  pos <- header_size
  k <- 2
  for (i in seq_len(n_types)) {
    h <- data[(5 + (i - 1) * 8):(4 + i * 8)]
    type <- rawToChar(h[1:4])
    n <- raw_uint(h[5:8], 4, endian)
    values <- vector("list", n)
    for (j in seq_len(n)) {
      b <- data[(pos + 1):(pos + counts[k])]
      pos <- pos + counts[k]
      k <- k + 1
      values[[j]] <- switch(
        type,
        info = ,
        labl = ,
        prop = utf16(b),
        rang = readBin(b, "double", length(b) / 8, 8, endian = endian),
        luts = matrix(as.integer(b), ncol = 3),
        b
      )
    }
    out[[type]] <- values
  }
  list(
    info = if (!is.null(out$info)) out$info[[1]],
    labels = if (!is.null(out$labl)) unlist(out$labl),
    ranges = if (!is.null(out$rang)) unlist(out$rang),
    luts = out$luts
  )
}

# Colour at the top of a LUT (256 x 3 matrix).
lut_color <- function(m) {
  if (!is.matrix(m) || ncol(m) != 3 || nrow(m) < 1) {
    return(NA_character_)
  }
  top <- m[nrow(m), ]
  sprintf("#%02X%02X%02X", top[1], top[2], top[3])
}

# Per-channel values from ZEN metadata that Bio-Formats stores in the ImageJ
# info text, e.g. "Information|Image|Channel|Fluor #2 = Alexa Fluor 488".
zen_channel_values <- function(info, field, n) {
  if (is.null(info) || n < 1) {
    return(rep(NA_character_, n))
  }
  lines <- strsplit(info, "\n", fixed = TRUE)[[1]]
  prefix <- paste0("Information|Image|Channel|", field)
  value_of <- function(key) {
    hit <- lines[startsWith(lines, paste0(key, " = "))]
    if (length(hit) == 0) NA_character_ else trimws(sub("^[^=]*= ", "", hit[1]))
  }
  values <- vapply(seq_len(n), function(k) value_of(paste0(prefix, " #", k)), character(1))
  if (n == 1 && is.na(values)) {
    values <- value_of(prefix)
  }
  values
}
