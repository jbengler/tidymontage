# Minimal viewer: one ggplot with a raster per panel.
#   columns = values of `x`, rows = values of `y` (channels) + an optional merge row
#   crop   = global region list(x = c(x0, x1), y = c(y0, y1)) in image pixels
#   crops  = per-column override: data frame with the x column plus x0, y0
#            (crop size taken from `crop`)
#   inset  = region list(x = , y = ) in image pixels, shown magnified in each panel
#   scale_bar = length in micrometres, drawn on the merge panels
# Colour and merging happen only here; the tibble holds greyscale images.

view_montage <- function(data, x, y = channel, crop = NULL, crops = NULL, inset = NULL,
                         scale_bar = NULL, merge = TRUE, panel_mm = 40, gap_mm = 1,
                         target_px = 600) {
  x_val <- as.character(rlang::eval_tidy(rlang::enquo(x), data))
  y_val <- as.character(rlang::eval_tidy(rlang::enquo(y), data))
  x_levels <- unique(x_val)
  y_levels <- unique(y_val)
  if (anyDuplicated(paste(x_val, y_val, sep = "\r"))) {
    stop("More than one image per panel: summarise z/t first.", call. = FALSE)
  }

  recs <- vctrs::vec_data(data$img)
  cache <- new.env()

  # --- display ranges: check linking, fill in missing ones -------------------
  envs <- lapply(recs, `[[`, "range")
  no_range <- vapply(envs, is.null, logical(1))
  if (any(no_range)) {
    warning(
      "No display range set for ", sum(no_range), " image(s): using p0.1-p99.9 per image ",
      "(unlinked). Use mutate(img = exposure(img), .by = channel) to link them.",
      call. = FALSE
    )
    for (i in which(no_range)) recs[[i]] <- vctrs::vec_data(exposure(new_img(recs[i])))[[1]]
    envs <- lapply(recs, `[[`, "range")
  }
  env_id <- vapply(envs, function(e) format(e), character(1))
  mixed <- tapply(data$channel, env_id, function(ch) length(unique(ch)) > 1)
  if (any(mixed)) {
    warning("A display range spans several channels. Did you forget `.by = channel`?", call. = FALSE)
  }

  # --- crop regions per column -----------------------------------------------
  first <- recs[[1]]$node
  size_x <- data$size_x[1]
  size_y <- data$size_y[1]
  crop <- crop %||% list(x = c(1, size_x), y = c(1, size_y))
  crop_w <- diff(crop$x) + 1
  crop_h <- diff(crop$y) + 1
  col_crop <- lapply(x_levels, function(xv) {
    if (!is.null(crops) && xv %in% as.character(crops[[1]])) {
      r <- crops[as.character(crops[[1]]) == xv, ]
      list(x = r$x0 + c(0, crop_w - 1), y = r$y0 + c(0, crop_h - 1))
    } else crop
  })
  names(col_crop) <- x_levels

  panel_w <- panel_mm
  panel_h <- panel_mm * crop_h / crop_w
  row_levels <- c(y_levels, if (merge) "merge")
  left <- 6
  top <- 6
  rect <- function(i, j) {
    xmin <- left + (i - 1) * (panel_w + gap_mm)
    ytop <- top + (j - 1) * (panel_h + gap_mm)
    c(xmin = xmin, xmax = xmin + panel_w, ymin = -(ytop + panel_h), ymax = -ytop)
  }

  # --- pixels -> tinted rgb arrays --------------------------------------------
  tinted <- function(k, region, stride) {
    m <- materialize(recs[[k]]$node, cache)
    rng <- range_value(recs[[k]]$range, cache)
    rows <- seq(region$y[1], region$y[2], by = stride)
    cols <- seq(region$x[1], region$x[2], by = stride)
    v <- (m[rows, cols] - rng[1]) / (rng[2] - rng[1])
    v[v < 0] <- 0
    v[v > 1] <- 1
    tint <- grDevices::col2rgb(data$color[k])[, 1] / 255
    array(c(v * tint[1], v * tint[2], v * tint[3]), c(length(rows), length(cols), 3))
  }
  to_raster <- function(a) {
    a[a > 1] <- 1
    as.raster(matrix(grDevices::rgb(a[, , 1], a[, , 2], a[, , 3]), nrow(a)))
  }

  stride <- max(1, floor(crop_w / target_px))
  layers <- list()
  for (i in seq_along(x_levels)) {
    region <- col_crop[[i]]
    merged <- 0
    merged_inset <- 0
    for (j in seq_along(row_levels)) {
      r <- rect(i, j)
      if (row_levels[j] == "merge") {
        a <- merged
        ai <- merged_inset
      } else {
        k <- which(x_val == x_levels[i] & y_val == row_levels[j])
        if (length(k) == 0) next
        a <- tinted(k, region, stride)
        merged <- merged + a
        if (!is.null(inset)) {
          ai <- tinted(k, inset, max(1, floor(diff(inset$x) / target_px)))
          merged_inset <- merged_inset + ai
        }
      }
      layers[[length(layers) + 1]] <- ggplot2::annotation_raster(
        to_raster(a), r["xmin"], r["xmax"], r["ymin"], r["ymax"], interpolate = FALSE
      )
      if (!is.null(inset)) {
        # zoom box on the main view, in panel coordinates
        sx <- panel_w / crop_w
        bx <- r["xmin"] + (inset$x - region$x[1]) * sx
        by <- r["ymax"] - (inset$y - region$y[1]) * sx
        layers[[length(layers) + 1]] <- ggplot2::annotate(
          "rect", xmin = bx[1], xmax = bx[2] + sx, ymin = by[2] - sx, ymax = by[1],
          fill = NA, colour = "white", linewidth = 0.25
        )
        # magnified inset in the bottom-left corner
        iw <- 0.42 * panel_w
        ih <- iw * diff(inset$y) / diff(inset$x)
        ix <- r["xmin"] + 1
        iy <- r["ymin"] + 1
        layers[[length(layers) + 1]] <- ggplot2::annotation_raster(
          to_raster(ai), ix, ix + iw, iy, iy + ih, interpolate = FALSE
        )
        layers[[length(layers) + 1]] <- ggplot2::annotate(
          "rect", xmin = ix, xmax = ix + iw, ymin = iy, ymax = iy + ih,
          fill = NA, colour = "white", linewidth = 0.4
        )
      }
      if (row_levels[j] == "merge" && !is.null(scale_bar)) {
        k <- which(x_val == x_levels[i])[1]
        len_mm <- scale_bar / data$pixel_size[k] * panel_w / crop_w
        x1 <- r["xmax"] - 1.5
        y1 <- r["ymin"] + 1.5
        layers[[length(layers) + 1]] <- ggplot2::annotate(
          "segment", x = x1 - len_mm, xend = x1, y = y1, yend = y1, colour = "white", linewidth = 0.8
        )
        layers[[length(layers) + 1]] <- ggplot2::annotate(
          "text", x = x1 - len_mm / 2, y = y1 + 1.2, label = paste0(scale_bar, "~mu*m"), parse = TRUE,
          colour = "white", size = 2
        )
      }
    }
    layers[[length(layers) + 1]] <- ggplot2::annotate(
      "text", x = rect(i, 1)["xmin"] + panel_w / 2, y = -top + 2.5, label = x_levels[i], size = 3
    )
  }
  for (j in seq_along(row_levels)) {
    r <- rect(1, j)
    layers[[length(layers) + 1]] <- ggplot2::annotate(
      "text", x = left - 2.5, y = (r["ymin"] + r["ymax"]) / 2, label = row_levels[j], angle = 90, size = 2.6
    )
  }

  width <- left + length(x_levels) * (panel_w + gap_mm)
  height <- top + length(row_levels) * (panel_h + gap_mm)
  p <- ggplot2::ggplot() + layers +
    ggplot2::coord_fixed(xlim = c(0, width), ylim = c(-height, 0), expand = FALSE) +
    ggplot2::theme_void() +
    ggplot2::theme(plot.background = ggplot2::element_rect(fill = "white", colour = NA))
  attr(p, "size_mm") <- c(width, height)
  p
}

save_view <- function(p, file, dpi = 300) {
  s <- attr(p, "size_mm")
  ggplot2::ggsave(file, p, width = s[1], height = s[2], units = "mm", dpi = dpi)
  invisible(file)
}
