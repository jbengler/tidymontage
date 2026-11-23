#' Add a colour legend
#'
#' Adds a legend that names the channels and their colours, like a ggplot2
#' legend: a coloured swatch next to each channel name, outside the panels.
#' It lists the channels shown in the montage, including the members of
#' merges; merges themselves are not listed. The montage grows by the space
#' the legend needs, so the panels keep their size.
#'
#' @param montage A [tidymontage()] object.
#' @param position Where the legend goes: `"top"`, `"bottom"` or `"right"`.
#' @param size Text size in points.
#' @param color Text colour.
#'
#' @returns The montage with the legend step added.
#' @examples
#' \dontrun{
#' montage |> add_color_legend("bottom")
#' }
#' @export
add_color_legend <- function(montage, position = c("top", "bottom", "right"), size = 7, color = "black") {
  check_tidymontage(montage)
  check_number(size, "size")
  check_color(color, "color")
  add_step(montage, new_step("add_color_legend", list(
    position = rlang::arg_match(position), size = size, color = color
  )))
}

#' @export
format.tidymontage_step_add_color_legend <- function(x, ...) {
  defaults <- list(position = "top", size = 7, color = "black")
  paste0("add_color_legend(", paste(format_args(x$params, defaults), collapse = ", "), ")")
}

# Text width in mm, measured with the font metrics of a (file-less) PDF
# device, so no plot device needs to be open.
text_width_mm <- function(label, size) {
  old <- grDevices::dev.cur()
  grDevices::pdf(NULL)
  on.exit({
    grDevices::dev.off()
    if (old > 1) grDevices::dev.set(old)
  }, add = TRUE)
  unname(vapply(label, function(l) {
    grob <- grid::textGrob(l, gp = grid::gpar(fontsize = size))
    grid::convertWidth(grid::grobWidth(grob), "mm", valueOnly = TRUE)
  }, numeric(1)))
}

# Channels and colours of the legend, in the order they appear in the panels.
legend_items <- function(panels, images, colors) {
  src <- unique(unlist(panels$.sources))
  channel <- as.character(images$channel[src])
  keep <- !duplicated(channel)
  items <- tibble::tibble(.image = src[keep], channel = channel[keep])
  items$color <- montage_colors(items, images, colors)
  items[, c("channel", "color")]
}

# Space the legend needs (mm) on each side of the panels.
legend_extent <- function(items, lg) {
  if (is.null(lg)) {
    return(list(top = 0, bottom = 0, right = 0))
  }
  dims <- legend_dims(items, lg)
  list(
    top = if (lg$position == "top") dims$height else 0,
    bottom = if (lg$position == "bottom") dims$height else 0,
    right = if (lg$position == "right") dims$width else 0
  )
}

legend_dims <- function(items, lg) {
  swatch <- lg$size * 0.3528 * 1.1
  item_w <- swatch + 1 + text_width_mm(items$channel, lg$size)
  margin <- 2
  if (lg$position == "right") {
    list(
      swatch = swatch, item_w = item_w,
      width = margin + max(item_w), height = length(item_w) * swatch * 1.6
    )
  } else {
    list(
      swatch = swatch, item_w = item_w,
      width = sum(item_w) + (length(item_w) - 1) * 3, height = swatch + 2 * margin
    )
  }
}

# Swatches and labels, placed around the panel area (mm, y down).
legend_layout <- function(items, lg, area) {
  d <- legend_dims(items, lg)
  n <- nrow(items)
  if (lg$position == "right") {
    x0 <- rep(area$xmax + 2, n)
    y_center <- (area$ymin + area$ymax) / 2 - d$height / 2 + (seq_len(n) - 0.5) * d$swatch * 1.6
  } else {
    start <- (area$xmin + area$xmax) / 2 - d$width / 2
    x0 <- start + c(0, cumsum(d$item_w + 3))[seq_len(n)]
    y_center <- rep(if (lg$position == "top") area$top / 2 else area$ymax + area$bottom / 2, n)
  }
  out <- data.frame(
    label = items$channel, color = items$color,
    xmin = x0, xmax = x0 + d$swatch,
    ymin = y_center - d$swatch / 2, ymax = y_center + d$swatch / 2,
    text_x = x0 + d$swatch + 1, text_y = y_center
  )
  attr(out, "style") <- lg
  out
}
