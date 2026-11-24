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

  p <- b$panels
  for (i in seq_len(nrow(p))) {
    add(grid::rasterGrob(
      b$rasters[[i]], x = n(p$xmin[i]), y = n(H - p$ymax[i]),
      width = n(p$xmax[i] - p$xmin[i]), height = n(p$ymax[i] - p$ymin[i]),
      just = c("left", "bottom"), interpolate = FALSE, name = paste0("image-", i)
    ))
  }
  # white panels get a thin black frame, so they stand out from the page
  white <- p[p$.background %in% "white", , drop = FALSE]
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
      add(rect("preview-regions", r$xmin, r$xmax, r$ymin, r$ymax, col = r$color, fill = NA, lwd = lwd(0.3)))
      d <- data.frame(x = r$xmin, y = r$ymin - 0.3, hjust = 0, vjust = 0)
      for (k in seq_len(nrow(r))) {
        add(text(paste0("preview-region-label-", k), r$label[k], d$x[k], d$y[k], hjust = 0, vjust = 0,
                 fontsize = 5, col = r$color[k]))
      }
    }
  }
  if (!is.null(b$boxes) && nrow(b$boxes) > 0) {
    bx <- b$boxes
    add(rect("zoom-boxes", bx$xmin, bx$xmax, bx$ymin, bx$ymax, col = bx$color %||% "white", fill = NA, lwd = lwd(0.25)))
  }
  if (!is.null(b$scale_bars)) {
    sb <- b$scale_bars
    st <- attr(sb, "style")
    outline <- st$outline %||% NA
    add(rect("scale-bars", sb$xmin, sb$xmax, sb$ymin, sb$ymax,
             fill = st$color, col = if (is.na(outline)) NA else outline, lwd = lwd(0.15)))
    if (isTRUE(st$label)) {
      for (k in seq_len(nrow(sb))) {
        label <- parse(text = sb$label[k])
        if (!is.na(outline)) {
          # a halo: the label drawn in the outline colour around its position
          angles <- seq(0, 2 * pi, length.out = 13)[-13]
          for (j in seq_along(angles)) {
            add(text(
              paste0("scale-bar-halo-", k, "-", j), label,
              sb$label_x[k] + 0.12 * cos(angles[j]), sb$label_y[k] - 0.12 * sin(angles[j]),
              hjust = sb$label_hjust[k], vjust = sb$label_vjust[k], fontsize = st$size, col = outline
            ))
          }
        }
        add(text(paste0("scale-bar-label-", k), label, sb$label_x[k], sb$label_y[k],
                 hjust = sb$label_hjust[k], vjust = sb$label_vjust[k], fontsize = st$size, col = st$color))
      }
    }
  }
  if (!is.null(b$legend)) {
    lg <- b$legend
    st <- attr(lg, "style")
    add(rect("legend-keys", lg$xmin, lg$xmax, lg$ymin, lg$ymax, fill = lg$color, col = "grey40", lwd = lwd(0.15)))
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
#' @param montage A [tidymontage()] object.
#' @returns A tibble with one row per panel.
#' @export
montage_panels <- function(montage) {
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
