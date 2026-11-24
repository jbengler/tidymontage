# Display ranges -------------------------------------------------------------------

# One display range (lo, hi) per panel, from full-resolution pixels.
montage_ranges <- function(panels, images, pixels, exposure, call = rlang::caller_env()) {
  data <- images[panels$.image, , drop = FALSE]
  data$view <- panels$view
  by <- exposure$by
  group <- if (length(by) == 0) rep("all", nrow(data)) else {
    do.call(paste, c(lapply(by, function(d) as.character(data[[d]])), sep = "\r"))
  }

  spans <- tapply(data$channel, group, function(ch) length(unique(ch)) > 1)
  if (any(spans)) {
    cli::cli_warn(
      c(
        "A display range is shared by several channels.",
        "i" = "Display ranges are usually linked per channel: include {.field channel} in {.arg .by} of {.fn adjust_exposure}."
      ),
      call = call
    )
  }

  lo <- hi <- numeric(nrow(data))
  for (g in unique(group)) {
    idx <- which(group == g)
    pool <- unlist(lapply(pixels[idx], sample_pixels))
    for (i in idx) {
      ov <- exposure$overrides[[as.character(data$channel[i])]]
      lo[i] <- resolve_range_spec(ov$min %||% exposure$min, pool)
      hi[i] <- resolve_range_spec(ov$max %||% exposure$max, pool)
    }
  }
  if ("display_min" %in% names(data)) {
    use <- !is.na(data$display_min)
    lo[use] <- data$display_min[use]
  }
  if ("display_max" %in% names(data)) {
    use <- !is.na(data$display_max)
    hi[use] <- data$display_max[use]
  }
  flat <- hi <= lo
  hi[flat] <- lo[flat] + 1
  data.frame(lo = lo, hi = hi, group = group)
}

sample_pixels <- function(m, n = 250000) {
  step <- max(1L, length(m) %/% n)
  as.vector(m)[seq(1, length(m), by = step)]
}

resolve_range_spec <- function(spec, pool) {
  if (spec$type == "value") spec$value else stats::quantile(pool, spec$value / 100, names = FALSE, type = 7)
}

# Colours ----------------------------------------------------------------------------

montage_colors <- function(panels, images, colors) {
  col <- if ("color" %in% names(images)) images$color[panels$.image] else rep(NA_character_, nrow(panels))
  ch <- panels$channel
  override <- ch %in% names(colors)
  col[override] <- vapply(colors[ch[override]], single_color, character(1))
  col[is.na(col)] <- "#FFFFFF"
  col
}

# Panel styles -----------------------------------------------------------------------

# Colours and background of each panel, without reading pixels. `.colors`
# holds one colour per source image; `.lut` the LUT of panels shown with a
# colormap (a single channel or an overlay), otherwise NULL. A single channel
# coloured black is drawn inverted on white, a LUT panel on the first colour
# of its map; everything else, and every merge, on black. In merges, black and
# LUT members use their original colour (the `color` column) unless the merge
# sets one.
panel_styles <- function(panels, images, spec, call = rlang::caller_env()) {
  invisible_in <- character()
  luts <- vector("list", nrow(panels))
  lut_channels <- names(Filter(is_lut, spec$colors))
  cols <- lapply(seq_len(nrow(panels)), function(i) {
    src <- panels$.sources[[i]]
    ch <- as.character(images$channel[src])
    col <- montage_colors(tibble::tibble(.image = src, channel = ch), images, spec$colors)
    if (panels$.is_overlay[i]) {
      col <- spec$overlays[[panels$channel[i]]]$color
      if (is_lut(col)) luts[[i]] <<- col
      return(single_color(col))
    }
    if (panels$.is_merge[i]) {
      original <- if ("color" %in% names(images)) images$color[src] else rep(NA_character_, length(src))
      original[is.na(original)] <- "#FFFFFF"
      fallback <- is_black(col) | ch %in% lut_channels
      col[fallback] <- original[fallback]
      ov <- spec$merge_style[[panels$channel[i]]]$colors
      hit <- ch %in% names(ov)
      col[hit] <- unlist(ov[ch[hit]])
      if (any(is_black(col))) invisible_in <<- c(invisible_in, panels$channel[i])
    } else if (ch[1] %in% lut_channels) {
      luts[[i]] <<- spec$colors[[ch[1]]]
    }
    col
  })
  if (length(invisible_in) > 0) {
    cli::cli_warn(
      c(
        "A channel in the merge {.val {unique(invisible_in)}} is black and invisible on the black background.",
        "i" = "Give it a colour with {.code add_merge(colors = )}."
      ),
      call = call
    )
  }
  background <- vapply(seq_len(nrow(panels)), function(i) {
    single_colour <- !panels$.is_merge[i] || panels$.is_overlay[i]
    if (!is.null(luts[[i]])) {
      lut_low(luts[[i]])
    } else if (single_colour && any(is_black(cols[[i]]))) {
      "white"
    } else {
      "black"
    }
  }, character(1))
  panels$.colors <- cols
  panels$.lut <- luts
  panels$.background <- background
  panels
}

is_black <- function(color) {
  colSums(grDevices::col2rgb(color)) == 0
}
