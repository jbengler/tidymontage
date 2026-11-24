# Rasters ----------------------------------------------------------------------------

# Average blocks of f x f pixels.
bin_mean <- function(m, f) {
  if (f <= 1) {
    return(m)
  }
  h <- nrow(m) %/% f
  w <- ncol(m) %/% f
  a <- array(m[seq_len(h * f), seq_len(w * f)], c(f, h, f, w))
  matrix(colMeans(matrix(aperm(a, c(1, 3, 2, 4)), f * f)), h, w)
}

# Intensities -> red, green and blue matrices (0-255) for one colour.
tint_rgb <- function(m, lo, hi, color) {
  v <- (m - lo) / (hi - lo)
  v[v < 0] <- 0
  v[v > 1] <- 1
  rgb <- grDevices::col2rgb(color)[, 1]
  list(v * rgb[1], v * rgb[2], v * rgb[3])
}

# Red, green and blue matrices (0-255, clipped) -> nativeRaster.
pack_raster <- function(rgb) {
  ch <- lapply(rgb, function(x) round(pmin(x, 255)))
  packed <- ch[[1]] + 256 * ch[[2]] + 65536 * ch[[3]] - 16777216
  structure(as.integer(t(packed)), dim = dim(rgb[[1]]), class = "nativeRaster", channels = 4L)
}

tint_raster <- function(m, lo, hi, color) {
  pack_raster(tint_rgb(m, lo, hi, color))
}

# Intensities -> 0-1 within the display range.
scale_intensity <- function(m, lo, hi) {
  v <- (m - lo) / (hi - lo)
  v[v < 0] <- 0
  v[v > 1] <- 1
  v
}

# Red, green and blue matrices (0-255) of one panel. On black, colours add up
# like light; on white, they multiply like inks (a black channel shows dark
# signal on white).
compose_panel <- function(values, colors, background = "black") {
  rgb <- grDevices::col2rgb(colors) / 255
  if (background == "white") {
    lapply(1:3, function(ch) {
      out <- 255
      for (j in seq_along(values)) out <- out * (1 - values[[j]] * (1 - rgb[ch, j]))
      out
    })
  } else {
    lapply(1:3, function(ch) {
      out <- 0
      for (j in seq_along(values)) out <- out + values[[j]] * rgb[ch, j] * 255
      out
    })
  }
}

# Additive blend of several tinted images.
blend_rgb <- function(layers) {
  Reduce(function(a, b) Map(`+`, a, b), layers)
}
