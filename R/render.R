# Drawing and saving ---------------------------------------------------------------

montage_ggplot <- function(build) {
  p <- build$panels
  layers <- lapply(seq_len(nrow(p)), function(i) {
    ggplot2::annotation_raster(
      build$rasters[[i]],
      xmin = p$xmin[i], xmax = p$xmax[i], ymin = -p$ymax[i], ymax = -p$ymin[i],
      interpolate = FALSE
    )
  })
  if (!is.null(build$boxes) && nrow(build$boxes) > 0) {
    b <- build$boxes
    layers <- c(layers, list(ggplot2::annotate(
      "rect", xmin = b$xmin, xmax = b$xmax, ymin = -b$ymax, ymax = -b$ymin,
      fill = NA, colour = "white", linewidth = 0.25
    )))
  }
  if (!is.null(build$scale_bars)) {
    sb <- build$scale_bars
    st <- attr(sb, "style")
    outline <- st$outline %||% NA
    has_outline <- !is.na(outline)
    layers <- c(layers, list(ggplot2::annotate(
      "rect", xmin = sb$xmin, xmax = sb$xmax, ymin = -sb$ymax, ymax = -sb$ymin,
      fill = st$color, colour = if (has_outline) outline else NA, linewidth = 0.15
    )))
    if (isTRUE(st$label)) {
      text_layer <- function(dx, dy, colour) {
        ggplot2::annotate(
          "text", x = sb$label_x + dx, y = -sb$label_y + dy, label = sb$label, parse = TRUE,
          hjust = sb$label_hjust, vjust = sb$label_vjust, size = st$size / ggplot2::.pt, colour = colour
        )
      }
      if (has_outline) {
        # a halo: the label drawn in the outline colour around its position
        r <- 0.12
        angles <- seq(0, 2 * pi, length.out = 13)[-13]
        layers <- c(layers, Map(function(a) text_layer(r * cos(a), r * sin(a), outline), angles))
      }
      layers <- c(layers, list(text_layer(0, 0, st$color)))
    }
  }
  if (!is.null(build$legend)) {
    lg <- build$legend
    st <- attr(lg, "style")
    layers <- c(layers, list(
      ggplot2::annotate(
        "rect", xmin = lg$xmin, xmax = lg$xmax, ymin = -lg$ymax, ymax = -lg$ymin,
        fill = lg$color, colour = "grey40", linewidth = 0.15
      ),
      ggplot2::annotate(
        "text", x = lg$text_x, y = -lg$text_y, label = lg$label, hjust = 0,
        size = st$size / ggplot2::.pt, colour = st$color
      )
    ))
  }
  hd <- build$headers %||% list(size = 7, color = "black")
  if (!is.null(build$labels) && nrow(build$labels) > 0) {
    l <- build$labels
    layers <- c(layers, list(ggplot2::annotate(
      "text", x = l$x, y = -l$y, label = l$label, angle = l$angle,
      size = hd$size / ggplot2::.pt, colour = hd$color
    )))
  }
  if (!is.null(build$side_labels) && nrow(build$side_labels) > 0) {
    sl <- build$side_labels
    layers <- c(layers, list(ggplot2::annotate(
      "text", x = sl$x, y = -sl$y, label = sl$label, hjust = sl$hjust, vjust = sl$vjust,
      angle = sl$angle, size = hd$size / ggplot2::.pt, colour = hd$color, lineheight = 0.9
    )))
  }
  if (!is.null(build$lines) && nrow(build$lines) > 0) {
    ln <- build$lines
    layers <- c(layers, list(ggplot2::annotate(
      "segment", x = ln$x, xend = ln$xend, y = -ln$y, yend = -ln$yend,
      colour = hd$color, linewidth = 0.25
    )))
  }
  ggplot2::ggplot() +
    layers +
    ggplot2::coord_fixed(xlim = c(0, build$width), ylim = c(-build$height, 0), expand = FALSE) +
    ggplot2::theme_void() +
    ggplot2::theme(
      plot.background = ggplot2::element_rect(fill = "white", colour = NA),
      plot.margin = ggplot2::margin(0, 0, 0, 0)
    )
}

#' Save a montage at its exact physical size
#'
#' Renders the montage and saves it at its fixed physical size, set with
#' [adjust_size()] (by default, the panel grid fits into 90 x 90 mm). The file
#' format is taken from the file extension (`.pdf`, `.png`, `.svg`, `.tiff`,
#' ...).
#'
#' @param montage A [tidymontage()] object.
#' @param filename File to write.
#' @param dpi Resolution of the image panels. Panels are binned down to this
#'   resolution at the printed size.
#' @param ... Passed to [ggplot2::ggsave()].
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
  build <- montage_build(montage, dpi = dpi)
  ggplot2::ggsave(
    filename, montage_ggplot(build),
    width = build$width, height = build$height, units = "mm", dpi = dpi, bg = "white", ...
  )
  cli::cli_inform("Saved {.file {filename}} ({round(build$width, 1)} x {round(build$height, 1)} mm).")
  invisible(montage)
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
  p$merge <- p$.is_merge
  if (".role" %in% names(p)) p$role <- p$.role
  p$px_xmin <- p$.x0
  p$px_xmax <- p$.x1
  p$px_ymin <- p$.y0
  p$px_ymax <- p$.y1
  p[, !startsWith(names(p), ".")]
}

#' @export
print.tidymontage <- function(x, ...) {
  build <- montage_build(x, dpi = 150)
  # draw at the montage's physical size, centred on the device
  vp <- grid::viewport(width = grid::unit(build$width, "mm"), height = grid::unit(build$height, "mm"))
  print(montage_ggplot(build), newpage = TRUE, vp = vp)
  invisible(x)
}

#' @importFrom ggplot2 autoplot
#' @export
ggplot2::autoplot

#' Convert a montage to a ggplot
#'
#' The ggplot is laid out in mm at the montage's size (see [adjust_size()]);
#' the size is stored in the attribute `"size_mm"`.
#'
#' @param object A [tidymontage()] object.
#' @param dpi Resolution of the image panels.
#' @param ... Unused.
#' @returns A ggplot object.
#' @export
autoplot.tidymontage <- function(object, dpi = 150, ...) {
  build <- montage_build(object, dpi = dpi)
  p <- montage_ggplot(build)
  attr(p, "size_mm") <- c(width = build$width, height = build$height)
  p
}
