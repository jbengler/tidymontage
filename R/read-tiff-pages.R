# Read pages of a TIFF as integer matrices (rows = image y, columns = image x).
read_tiff_pages <- function(path, pages, palette = FALSE, sample = NA_integer_, bits = 16) {
  imgs <- quiet_tiff(tiff::readTIFF(path, all = pages, as.is = !palette, indexed = palette))
  lapply(imgs, function(x) {
    if (!is.na(sample)) {
      x <- x[, , sample]
    } else if (length(dim(x)) == 3) {
      x <- x[, , 1]
    }
    if (is.double(x)) {
      # `tiff` ignores `as.is` for RGB images and scales them to 0-1.
      x <- round(x * (2^bits - 1))
    }
    if (palette) {
      # Indexed reads return colour-table positions, which are 1-based.
      x <- x - 1L
    }
    attributes(x) <- list(dim = dim(x))
    storage.mode(x) <- "integer"
    x
  })
}

# libtiff warns about tags it does not know, such as ImageJ's private tags.
quiet_tiff <- function(expr) {
  withCallingHandlers(
    expr,
    warning = function(w) {
      if (grepl("Unknown field|TIFFReadDirectory|TIFFFetchNormalTag", conditionMessage(w))) {
        invokeRestart("muffleWarning")
      }
    }
  )
}
