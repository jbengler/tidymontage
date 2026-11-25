# Drawing ---------------------------------------------------------------------------
#
# A montage renders to a gtable with 3 x 3 tracks. The middle track in both
# directions is the image grid (from the first to the last image edge), named
# "panel"; the outer tracks hold the decoration: headers and a top legend
# before, side labels, scale bar labels and a bottom legend after. Layout
# tools such as tidylayouts align figures on the "panel" track. One grob
# spans all tracks; pixels are only read when it is drawn.

montage_gtable <- function(montage, dpi = 150, call = rlang::caller_env()) {
  space <- montage_layout_space(montage, call = call)
  p <- space$panels
  W <- space$width
  H <- space$height
  x0 <- min(p$xmin)
  x1 <- max(p$xmax)
  y0 <- min(p$ymin)
  y1 <- max(p$ymax)
  gt <- gtable::gtable(
    widths = grid::unit(c(x0, x1 - x0, W - x1), "mm"),
    heights = grid::unit(c(y0, y1 - y0, H - y1), "mm"),
    name = "tidymontage"
  )
  content <- grid::gTree(montage = montage, dpi = dpi, name = "montage", cl = "tidymontage_grob")
  gt <- gtable::gtable_add_grob(gt, content, t = 1, l = 1, b = 3, r = 3, name = "montage", clip = "off")
  gtable::gtable_add_grob(gt, grid::nullGrob(), t = 2, l = 2, name = "panel")
}

#' @exportS3Method grid::makeContent
makeContent.tidymontage_grob <- function(x) {
  # warnings (e.g. about display ranges) are reported without a call: they
  # arise while drawing, inside grid
  grid::setChildren(x, grid::gList(montage_grob(montage_build(x$montage, dpi = x$dpi, call = NULL))))
}

# All elements of a built montage, in a viewport with figure coordinates in
# mm. Positions in the build are measured from the top-left corner (y down);
# grid counts y from the bottom, so y becomes height - y.
montage_grob <- function(b) {
  H <- b$height
  n <- function(v) grid::unit(v, "native")
  lwd <- function(mm) mm * 72.27 / 25.4
  out <- list()
  add <- function(g) out[[length(out) + 1]] <<- g
  rect <- function(name, xmin, xmax, ymin, ymax, ...) {
    grid::rectGrob(
      x = n(xmin), y = n(H - ymax), width = n(xmax - xmin), height = n(ymax - ymin),
      just = c("left", "bottom"), gp = grid::gpar(...), name = name
    )
  }
  text <- function(name, label, x, y, hjust = 0.5, vjust = 0.5, rot = 0, ...) {
    grid::textGrob(
      label, x = n(x), y = n(H - y), hjust = hjust, vjust = vjust, rot = rot,
      gp = grid::gpar(...), name = name
    )
  }
  # four-cornered outlines (possibly rotated): columns x1-x4, y1-y4
  quads <- function(name, d, ...) {
    grid::polygonGrob(
      x = n(as.vector(t(as.matrix(d[c("x1", "x2", "x3", "x4")])))),
      y = n(H - as.vector(t(as.matrix(d[c("y1", "y2", "y3", "y4")])))),
      id = rep(seq_len(nrow(d)), each = 4), gp = grid::gpar(...), name = name
    )
  }
  # text grobs take one angle and justification each
  texts <- function(name, d, label, size, col, lineheight = 0.9) {
    for (k in seq_len(nrow(d))) {
      add(text(
        paste0(name, "-", k), label[k], d$x[k], d$y[k],
        hjust = d$hjust[k] %||% 0.5, vjust = d$vjust[k] %||% 0.5, rot = d$angle[k] %||% 0,
        fontsize = size, col = col, lineheight = lineheight
      ))
    }
  }

  # Text with a halo: drawn in the outline colour around its position, then
  # on top. Used by scale bar labels and zoom numbers, so they look the same.
  halo_text <- function(name, label, x, y, hjust, vjust, size, col, outline) {
    if (!is.na(outline)) {
      angles <- seq(0, 2 * pi, length.out = 13)[-13]
      for (j in seq_along(angles)) {
        add(text(paste0(name, "-halo-", j), label, x + 0.12 * cos(angles[j]), y - 0.12 * sin(angles[j]),
                 hjust = hjust, vjust = vjust, fontsize = size, col = outline))
      }
    }
    add(text(name, label, x, y, hjust = hjust, vjust = vjust, fontsize = size, col = col))
  }

  # Zoom numbers: white text on a black square whose top-left corner is at
  # (x, y); the square widens for longer labels.
  tag <- function(name, label, x, y) {
    st <- zoom_label_style
    gp <- grid::gpar(fontsize = st$size)
    w <- max(grid::unit(st$side, "mm"), grid::grobWidth(grid::textGrob(label, gp = gp)) + grid::unit(st$side * 0.5, "mm"))
    h <- grid::unit(st$side, "mm")
    add(grid::rectGrob(
      x = n(x), y = n(H - y), width = w, height = h, just = c("left", "top"),
      gp = grid::gpar(fill = st$fill, col = NA), name = paste0(name, "-square")
    ))
    add(grid::textGrob(
      label, x = n(x) + w * 0.5, y = n(H - y) - h * 0.5,
      gp = grid::gpar(fontsize = st$size, col = st$color), name = name
    ))
  }

  p <- b$panels
  for (i in seq_len(nrow(p))) {
    add(grid::rasterGrob(
      b$rasters[[i]], x = n(p$xmin[i]), y = n(H - p$ymax[i]),
      width = n(p$xmax[i] - p$xmin[i]), height = n(p$ymax[i] - p$ymin[i]),
      just = c("left", "bottom"), interpolate = FALSE, name = paste0("image-", i)
    ))
  }
  # light panels get a thin black frame, so they stand out from the page
  white <- p[is_light(p$.background), , drop = FALSE]
  if (nrow(white) > 0) {
    add(rect("frames", white$xmin, white$xmax, white$ymin, white$ymax, col = "black", fill = NA, lwd = lwd(0.25)))
  }
  # previews: the current option is outlined
  if (".outline" %in% names(p) && any(p$.outline)) {
    o <- p[p$.outline, , drop = FALSE]
    add(rect("outline", o$xmin - 0.4, o$xmax + 0.4, o$ymin - 0.4, o$ymax + 0.4,
             col = "#E69F00", fill = NA, lwd = lwd(0.8)))
  }
  if (!is.null(b$preview)) {
    pv <- b$preview
    ln <- pv$lines
    add(grid::segmentsGrob(
      n(ln$x), n(H - ln$y), n(ln$xend), n(H - ln$yend),
      gp = grid::gpar(col = ln$color, alpha = 0.3, lwd = lwd(0.15)), name = "preview-grid"
    ))
    tk <- pv$ticks
    texts("preview-ticks", tk, tk$label, 5, "grey30")
    if (!is.null(pv$rects)) {
      r <- pv$rects
      add(quads("preview-regions", r, col = r$color, fill = NA, lwd = lwd(0.3)))
      d <- data.frame(x = r$x1, y = r$y1 - 0.3, hjust = 0, vjust = 0)
      for (k in seq_len(nrow(r))) {
        add(text(paste0("preview-region-label-", k), r$label[k], d$x[k], d$y[k], hjust = 0, vjust = 0,
                 fontsize = 5, col = r$color[k]))
      }
    }
  }
  if (!is.null(b$boxes) && nrow(b$boxes) > 0) {
    bx <- b$boxes
    # numbers first, so the box line runs over the edge of their squares
    bl <- bx[!is.na(bx$label %||% NA), , drop = FALSE]
    for (k in seq_len(nrow(bl))) tag(paste0("zoom-box-label-", k), bl$label[k], bl$x1[k], bl$y1[k])
    add(quads("zoom-boxes", bx, col = bx$color, fill = NA, lwd = lwd(0.25)))
  }
  if (!is.null(b$zoom_labels)) {
    zl <- b$zoom_labels
    for (k in seq_len(nrow(zl))) tag(paste0("zoom-label-", k), zl$label[k], zl$x[k], zl$y[k])
  }
  if (!is.null(b$arrows)) {
    # each panel's arrowheads are clipped to the panel
    ar <- b$arrows
    for (i in unique(ar$panel)) {
      a <- ar[ar$panel == i, , drop = FALSE]
      heads <- lapply(seq_len(nrow(a)), function(k) arrowhead_polygon(a$x[k], a$y[k], a$size[k]))
      add(grid::polygonGrob(
        x = n(unlist(lapply(heads, `[[`, "x"))), y = n(H - unlist(lapply(heads, `[[`, "y"))),
        id = rep(seq_len(nrow(a)), each = 3), gp = grid::gpar(fill = a$color, col = NA),
        vp = grid::viewport(
          x = n(p$xmin[i]), y = n(H - p$ymax[i]), width = n(p$xmax[i] - p$xmin[i]),
          height = n(p$ymax[i] - p$ymin[i]), just = c("left", "bottom"), clip = "on",
          xscale = c(p$xmin[i], p$xmax[i]), yscale = c(H - p$ymax[i], H - p$ymin[i])
        ),
        name = paste0("arrows-", i)
      ))
    }
  }
  if (!is.null(b$scale_bars)) {
    sb <- b$scale_bars
    st <- attr(sb, "style")
    outline <- st$outline %||% NA
    add(rect("scale-bars", sb$xmin, sb$xmax, sb$ymin, sb$ymax,
             fill = st$color, col = if (is.na(outline)) NA else outline, lwd = lwd(0.15)))
    if (isTRUE(st$label)) {
      for (k in seq_len(nrow(sb))) {
        halo_text(paste0("scale-bar-label-", k), parse(text = sb$label[k]), sb$label_x[k], sb$label_y[k],
                  sb$label_hjust[k], sb$label_vjust[k], st$size, st$color, outline)
      }
    }
  }
  if (!is.null(b$legend)) {
    lg <- b$legend
    st <- attr(lg, "style")
    bar <- !vapply(lg$lut %||% vector("list", nrow(lg)), is.null, logical(1))
    for (k in which(bar)) {
      add(grid::rasterGrob(
        matrix(lut_table(lg$lut[[k]]), nrow = 1), x = n(lg$xmin[k]), y = n(H - lg$ymax[k]),
        width = n(lg$xmax[k] - lg$xmin[k]), height = n(lg$ymax[k] - lg$ymin[k]),
        just = c("left", "bottom"), interpolate = FALSE, name = paste0("legend-bar-", k)
      ))
    }
    add(rect("legend-keys", lg$xmin, lg$xmax, lg$ymin, lg$ymax,
             fill = ifelse(bar, NA, lg$color), col = "grey40", lwd = lwd(0.15)))
    if (!is.null(lg$range_lo)) {
      for (k in which(!is.na(lg$range_lo))) {
        add(text(paste0("legend-range-lo-", k), lg$range_lo[k], lg$xmin[k], lg$ymax[k] + 0.4, hjust = 0, vjust = 1,
                 fontsize = range_label_size(st), col = st$color))
        add(text(paste0("legend-range-hi-", k), lg$range_hi[k], lg$xmax[k], lg$ymax[k] + 0.4, hjust = 1, vjust = 1,
                 fontsize = range_label_size(st), col = st$color))
      }
    }
    texts("legend-label", data.frame(x = lg$text_x, y = lg$text_y, hjust = 0), lg$label, st$size, st$color)
  }
  hd <- b$headers %||% list(size = 7, color = "black")
  if (!is.null(b$labels) && nrow(b$labels) > 0) {
    texts("header", b$labels, b$labels$label, hd$size, hd$color)
  }
  if (!is.null(b$side_labels) && nrow(b$side_labels) > 0) {
    texts("side-label", b$side_labels, b$side_labels$label, hd$size, hd$color)
  }
  if (!is.null(b$lines) && nrow(b$lines) > 0) {
    ln <- b$lines
    add(grid::segmentsGrob(n(ln$x), n(H - ln$y), n(ln$xend), n(H - ln$yend),
                           gp = grid::gpar(col = hd$color, lwd = lwd(0.25)), name = "header-lines"))
  }
  grid::gTree(
    children = do.call(grid::gList, out),
    vp = grid::viewport(xscale = c(0, b$width), yscale = c(0, b$height)),
    name = "montage-elements"
  )
}

# The tracks are all in mm, so no unit conversion (which would open a
# graphics device) is needed.
gtable_size_mm <- function(gt) {
  c(width = sum(as.numeric(gt$widths)), height = sum(as.numeric(gt$heights)))
}

#' Save a montage at its exact physical size
#'
#' Renders the montage and saves it at its fixed physical size, set with
#' [adjust_size()] (by default, the panel grid fits into 90 x 90 mm). The file
#' format is taken from the file extension: `.pdf`, `.png`, `.tif`/`.tiff`,
#' `.jpg`/`.jpeg` or `.svg`. Bitmaps are written with the ragg package if it
#' is installed, for consistent output on all systems.
#'
#' @param montage A [tidymontage()] object.
#' @param filename File to write.
#' @param dpi Resolution of the image panels, and of bitmap files. Panels are
#'   binned down to this resolution at the printed size.
#' @param ... Passed to the graphics device.
#'
#' @returns The montage, invisibly.
#' @examples
#' \dontrun{
#' montage |> save_montage("figure.pdf")
#' montage |> adjust_size(width = 180, height = NA) |> save_montage("figure.pdf")
#' }
#' @export
save_montage <- function(montage, filename, dpi = 300, ...) {
  check_tidymontage(montage)
  gt <- montage_gtable(montage, dpi = dpi)
  size <- gtable_size_mm(gt)
  open_device(filename, size[["width"]], size[["height"]], dpi, ...)
  on.exit(grDevices::dev.off(), add = TRUE)
  grid::grid.newpage()
  grid::grid.draw(gt)
  cli::cli_inform("Saved {.file {filename}} ({round(size[['width']], 1)} x {round(size[['height']], 1)} mm).")
  invisible(montage)
}

open_device <- function(filename, width, height, dpi, ..., call = rlang::caller_env()) {
  ext <- tolower(tools::file_ext(filename))
  inch <- c(width, height) / 25.4
  has_ragg <- requireNamespace("ragg", quietly = TRUE)
  switch(
    ext,
    pdf = if (capabilities("cairo")) {
      grDevices::cairo_pdf(filename, width = inch[1], height = inch[2], ...)
    } else {
      grDevices::pdf(filename, width = inch[1], height = inch[2], useDingbats = FALSE, ...)
    },
    svg = grDevices::svg(filename, width = inch[1], height = inch[2], ...),
    png = if (has_ragg) {
      ragg::agg_png(filename, width = width, height = height, units = "mm", res = dpi, background = "white", ...)
    } else {
      grDevices::png(filename, width = width, height = height, units = "mm", res = dpi, bg = "white", ...)
    },
    tif = ,
    tiff = if (has_ragg) {
      ragg::agg_tiff(filename, width = width, height = height, units = "mm", res = dpi, background = "white", ...)
    } else {
      grDevices::tiff(filename, width = width, height = height, units = "mm", res = dpi, bg = "white", ...)
    },
    jpg = ,
    jpeg = if (has_ragg) {
      ragg::agg_jpeg(filename, width = width, height = height, units = "mm", res = dpi, background = "white", ...)
    } else {
      grDevices::jpeg(filename, width = width, height = height, units = "mm", res = dpi, bg = "white", ...)
    },
    cli::cli_abort(
      "Can't save {.file {filename}}: use {.file .pdf}, {.file .png}, {.file .tif}, {.file .jpg} or {.file .svg}.",
      call = call
    )
  )
}

#' Panels of a montage
#'
#' Returns the panels of a montage as a tibble: their panel dimensions, grid
#' position, rectangle in mm (measured from the top-left corner of the
#' figure) and the region of the source image they show. No pixels are read,
#' so this is a quick way to check a layout.
#'
#' The region is given in pixels (`px_xmin` ... `px_ymax`, 1-based) and as
#' `angle`. For rotated regions (`angle` not 0), the pixel columns describe
#' the region before it is rotated about its center.
#'
#' @param montage A [tidymontage()] object.
#' @returns A tibble with one row per panel.
#' @export
get_panels <- function(montage) {
  check_tidymontage(montage)
  space <- montage_layout_space(montage, call = rlang::current_env())
  p <- space$panels
  p$merge <- p$.is_merge & !p$.is_overlay
  p$overlay <- p$.is_overlay
  p$background <- p$.background
  if (".role" %in% names(p)) p$role <- p$.role
  p$px_xmin <- p$.x0
  p$px_xmax <- p$.x1
  p$px_ymin <- p$.y0
  p$px_ymax <- p$.y1
  p$angle <- p$.angle
  p[, !startsWith(names(p), ".")]
}

#' @export
print.tidymontage <- function(x, ...) {
  gt <- montage_gtable(x, dpi = 150)
  size <- gtable_size_mm(gt)
  grid::grid.newpage()
  # draw at the montage's physical size, centred on the device
  grid::pushViewport(grid::viewport(
    width = grid::unit(size[["width"]], "mm"), height = grid::unit(size[["height"]], "mm")
  ))
  grid::grid.draw(gt)
  grid::popViewport()
  invisible(x)
}
