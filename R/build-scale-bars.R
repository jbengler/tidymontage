# Scale bars -------------------------------------------------------

# Micrometres per mm of each panel (NA without a pixel size).
panel_um_per_mm <- function(panels, images) {
  first_source <- vapply(panels$.sources, `[`, integer(1), 1)
  ps <- vapply(vctrs::vec_data(images$img[first_source]), function(r) r$node$pixel_size, numeric(1))
  (panels$.x1 - panels$.x0 + 1) * ps / (panels$xmax - panels$xmin)
}

montage_scale_bars <- function(panels, images, sb, call = rlang::caller_env()) {
  if (is.null(sb)) {
    return(NULL)
  }
  scale <- panel_um_per_mm(panels, images)
  pick <- switch(
    sb$where,
    all = seq_len(nrow(panels)),
    merge = which(panels$.is_merge & !panels$.is_overlay),
    last = unlist(lapply(unique(panels$view), function(v) {
      idx <- which(panels$view == v)
      s_v <- scale[idx]
      if (all(is.na(s_v)) || diff(range(s_v, na.rm = TRUE)) <= 1e-3 * min(s_v, na.rm = TRUE)) {
        idx[order(-panels$ymax[idx], -panels$xmax[idx])][1]
      } else {
        cli::cli_inform(
          "Panels of the view {.val {v}} have different magnifications, so each gets its own scale bar.",
          call = call
        )
        idx
      }
    }))
  )
  if (length(pick) == 0) {
    cli::cli_warn("No panels match {.code where = \"{sb$where}\"}, so no scale bars are drawn.", call = call)
    return(NULL)
  }
  if (anyNA(scale[pick])) {
    cli::cli_abort(
      c(
        "Scale bars need a known pixel size.",
        "i" = "Some images have no pixel size ({.field pixel_size_source} is {.val NA})."
      ),
      call = call
    )
  }
  bars <- lapply(pick, function(i) {
    view <- panels$view[i]
    len <- if (is.null(sb$length)) {
      nice_length((panels$xmax[i] - panels$xmin[i]) * scale[i])
    } else if (length(sb$length) == 1 && is.null(names(sb$length))) {
      sb$length
    } else {
      if (!view %in% names(sb$length)) {
        cli::cli_abort("{.arg length} has no value for the view {.val {view}}.", call = call)
      }
      sb$length[[view]]
    }
    w <- len / scale[i]
    if (w > panels$xmax[i] - panels$xmin[i] - 2 * sb$inset) {
      cli::cli_abort("A {len} \u00b5m scale bar doesn't fit into the panels of the view {.val {view}}.", call = call)
    }
    right <- endsWith(sb$position, "right")
    bottom <- startsWith(sb$position, "bottom")
    x0 <- if (right) panels$xmax[i] - sb$inset - w else panels$xmin[i] + sb$inset
    y0 <- if (bottom) panels$ymax[i] - sb$inset - sb$thickness else panels$ymin[i] + sb$inset
    data.frame(
      xmin = x0, xmax = x0 + w, ymin = y0, ymax = y0 + sb$thickness,
      label = paste0(format(len, drop0trailing = TRUE, trim = TRUE), "~mu*m"),
      # align the label with the bar's outer end, so it stays inside the panel
      label_x = if (right) x0 + w else x0,
      label_hjust = if (right) 1 else 0,
      label_y = if (bottom) y0 - 0.4 else y0 + sb$thickness + 0.4,
      label_vjust = if (bottom) 0 else 1
    )
  })
  out <- do.call(rbind, bars)
  attr(out, "style") <- sb
  out
}
