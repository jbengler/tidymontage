# Spike: render a montage to a gtable (grid only, no ggplot).
#
# The gtable has 3 x 3 tracks. The middle track in both directions is the
# image grid ("panel"): from the first image's edge to the last one's. The
# outer tracks hold the decoration: headers and top legend before (lead),
# bottom legend, axis labels and right-hand labels after (trail). One grob,
# drawn in figure coordinates (mm, y down), spans all tracks; pixels are only
# read when it is drawn (makeContent).

montage_gtable <- function(montage, dpi = 150) {
  space <- montage_layout_space(montage)
  p <- space$panels
  W <- space$width
  H <- space$height
  x0 <- min(p$xmin); x1 <- max(p$xmax)
  y0 <- min(p$ymin); y1 <- max(p$ymax)
  gt <- gtable::gtable(
    widths = grid::unit(c(x0, x1 - x0, W - x1), "mm"),
    heights = grid::unit(c(y0, y1 - y0, H - y1), "mm")
  )
  content <- grid::gTree(
    montage = montage, dpi = dpi, width = W, height = H,
    name = "montage", cl = "tidymontage_grob"
  )
  gt <- gtable::gtable_add_grob(gt, content, t = 1, l = 1, b = 3, r = 3, name = "montage", clip = "off")
  # an empty marker for the image grid, which layout tools align on
  gtable::gtable_add_grob(gt, grid::nullGrob(), t = 2, l = 2, name = "panel")
}

# Draw time: build the montage (reads pixels) and draw it in a viewport with
# figure coordinates in mm.
makeContent.tidymontage_grob <- function(x) {
  build <- montage_build(x$montage, dpi = x$dpi)
  vp <- grid::viewport(xscale = c(0, x$width), yscale = c(0, x$height))
  grid::setChildren(x, grid::gList(grid::gTree(children = montage_grobs(build), vp = vp)))
}

lwd <- function(mm) mm * 72.27 / 25.4 # line width in mm -> lwd

# All positions in the build are mm from the top-left corner (y down); grid
# counts y from the bottom, so y becomes H - y.
montage_grobs <- function(b) {
  H <- b$height
  n <- function(v) grid::unit(v, "native")
  out <- list()
  add <- function(g) out[[length(out) + 1]] <<- g
  rect <- function(xmin, xmax, ymin, ymax, gp) {
    grid::rectGrob(x = n(xmin), y = n(H - ymax), width = n(xmax - xmin), height = n(ymax - ymin),
                   just = c("left", "bottom"), gp = gp)
  }
  text <- function(label, x, y, hjust = 0.5, vjust = 0.5, rot = 0, size = 7, col = "black") {
    grid::textGrob(label, x = n(x), y = n(H - y), hjust = hjust, vjust = vjust, rot = rot,
                   gp = grid::gpar(fontsize = size, col = col, lineheight = 0.9))
  }
  thin <- lwd(0.25 * 0.75)

  p <- b$panels
  for (i in seq_len(nrow(p))) {
    add(grid::rasterGrob(b$rasters[[i]], x = n(p$xmin[i]), y = n(H - p$ymax[i]),
                         width = n(p$xmax[i] - p$xmin[i]), height = n(p$ymax[i] - p$ymin[i]),
                         just = c("left", "bottom"), interpolate = FALSE))
  }
  white <- p[p$.background %in% "white", , drop = FALSE]
  if (nrow(white) > 0) add(rect(white$xmin, white$xmax, white$ymin, white$ymax, grid::gpar(col = "black", fill = NA, lwd = thin)))
  if (!is.null(b$boxes)) {
    bx <- b$boxes
    add(rect(bx$xmin, bx$xmax, bx$ymin, bx$ymax, grid::gpar(col = bx$color %||% "white", fill = NA, lwd = thin)))
  }
  if (!is.null(b$scale_bars)) {
    sb <- b$scale_bars
    st <- attr(sb, "style")
    outline <- st$outline %||% NA
    add(rect(sb$xmin, sb$xmax, sb$ymin, sb$ymax, grid::gpar(fill = st$color, col = if (is.na(outline)) NA else outline, lwd = lwd(0.15 * 0.75))))
    if (isTRUE(st$label)) {
      for (k in seq_len(nrow(sb))) {
        label <- parse(text = sb$label[k])
        if (!is.na(outline)) {
          for (a in seq(0, 2 * pi, length.out = 13)[-13]) {
            add(text(label, sb$label_x[k] + 0.12 * cos(a), sb$label_y[k] + 0.12 * sin(a),
                     hjust = sb$label_hjust[k], vjust = sb$label_vjust[k], size = st$size, col = outline))
          }
        }
        add(text(label, sb$label_x[k], sb$label_y[k], hjust = sb$label_hjust[k],
                 vjust = sb$label_vjust[k], size = st$size, col = st$color))
      }
    }
  }
  if (!is.null(b$legend)) {
    lg <- b$legend
    st <- attr(lg, "style")
    add(rect(lg$xmin, lg$xmax, lg$ymin, lg$ymax, grid::gpar(fill = lg$color, col = "grey40", lwd = lwd(0.15 * 0.75))))
    add(text(lg$label, lg$text_x, lg$text_y, hjust = 0, size = st$size, col = st$color))
  }
  hd <- b$headers %||% list(size = 7, color = "black")
  for (d in list(b$side_labels, b$labels)) {
    if (is.null(d) || nrow(d) == 0) next
    for (k in seq_len(nrow(d))) {
      add(text(d$label[k], d$x[k], d$y[k], hjust = d$hjust[k] %||% 0.5, vjust = d$vjust[k] %||% 0.5,
               rot = d$angle[k], size = hd$size, col = hd$color))
    }
  }
  if (!is.null(b$lines) && nrow(b$lines) > 0) {
    ln <- b$lines
    add(grid::segmentsGrob(n(ln$x), n(H - ln$y), n(ln$xend), n(H - ln$yend), gp = grid::gpar(col = hd$color, lwd = thin)))
  }
  do.call(grid::gList, out)
}

save_gtable <- function(gt, file, dpi = 300) {
  w <- sum(grid::convertWidth(gt$widths, "mm", valueOnly = TRUE))
  h <- sum(grid::convertHeight(gt$heights, "mm", valueOnly = TRUE))
  grDevices::png(file, width = w, height = h, units = "mm", res = dpi, bg = "white")
  on.exit(grDevices::dev.off())
  grid::grid.newpage()
  grid::grid.draw(gt)
  invisible(c(width = w, height = h))
}
