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

# The pixels a panel shows: a block of the image, or for rotated regions the
# image sampled on the rotated grid, with bilinear interpolation (as ImageJ
# rotates). One output pixel per source pixel, so the magnification stays.
panel_pixels <- function(m, panels, i) {
  if (panels$.angle[i] == 0) {
    return(m[panels$.y0[i]:panels$.y1[i], panels$.x0[i]:panels$.x1[i], drop = FALSE])
  }
  w <- panels$.x1[i] - panels$.x0[i] + 1
  h <- panels$.y1[i] - panels$.y0[i] + 1
  # pixel centers of the output, in the region's frame; rows vary fastest
  u <- rep((seq_len(w) - 0.5) - w / 2, each = h)
  v <- rep((seq_len(h) - 0.5) - h / 2, times = w)
  p <- image_point(panels$.cx[i], panels$.cy[i], panels$.angle[i], u, v)
  matrix(bilinear(m, p$x, p$y), h, w)
}

# Values of image m at 0-based image coordinates (pixel k spans [k, k + 1],
# its value sits at k + 0.5). Edges are extended.
bilinear <- function(m, x, y) {
  nx <- ncol(m)
  ny <- nrow(m)
  fx <- x - 0.5
  fy <- y - 0.5
  x0 <- pmin(pmax(floor(fx), 0), nx - 1)
  y0 <- pmin(pmax(floor(fy), 0), ny - 1)
  tx <- pmin(pmax(fx - x0, 0), 1)
  ty <- pmin(pmax(fy - y0, 0), 1)
  x1 <- pmin(x0 + 1, nx - 1)
  y1 <- pmin(y0 + 1, ny - 1)
  at <- function(yy, xx) m[yy + 1 + xx * ny]
  at(y0, x0) * (1 - tx) * (1 - ty) + at(y0, x1) * tx * (1 - ty) +
    at(y1, x0) * (1 - tx) * ty + at(y1, x1) * tx * ty
}
