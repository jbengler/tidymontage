#' Add a colour legend
#'
#' Adds a legend that names the channels and their colours, like a ggplot2
#' legend: a coloured swatch next to each channel name, outside the panels.
#' It lists the channels shown in the montage, including the members of
#' merges; merges themselves are not listed. Black channels (shown inverted)
#' are left out, since their swatches would all look the same; their colours
#' in merges are listed instead. The montage grows by the space the legend
#' needs, so the panels keep their size.
#'
#' @param montage A [tidymontage()] object.
#' @param position Where the legend goes: `"bottom"` (the default), `"top"` or
#'   `"right"`.
#' @param size Text size in points.
#' @param color Text colour.
#'
#' @returns The montage with the legend step added.
#' @examples
#' \dontrun{
#' montage |> add_color_legend("bottom")
#' }
#' @export
add_color_legend <- function(montage, position = c("bottom", "top", "right"), size = 7, color = "black") {
  check_tidymontage(montage)
  check_number(size, "size")
  check_color(color, "color")
  add_step(montage, new_step("add_color_legend", list(
    position = rlang::arg_match(position), size = size, color = color
  )))
}

#' @export
format.tidymontage_step_add_color_legend <- function(x, ...) {
  defaults <- list(position = "bottom", size = 7, color = "black")
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
# Black channels are left out. Merges that colour a member differently get an
# extra entry: just the channel name if that is unambiguous, otherwise
# "merge: GFP".
legend_items <- function(panels, images, colors) {
  src <- unique(unlist(panels$.sources))
  channel <- as.character(images$channel[src])
  keep <- !duplicated(channel)
  items <- tibble::tibble(.image = src[keep], channel = channel[keep])
  items$color <- montage_colors(items, images, colors)
  items <- items[, c("channel", "color")]
  extra <- NULL
  if (".colors" %in% names(panels)) {
    merges <- panels[panels$.is_merge & !panels$.is_overlay & !duplicated(panels$channel), , drop = FALSE]
    for (i in seq_len(nrow(merges))) {
      members <- as.character(images$channel[merges$.sources[[i]]])
      differ <- to_hex(merges$.colors[[i]]) != to_hex(items$color[match(members, items$channel)])
      if (any(differ)) {
        extra <- rbind(extra, tibble::tibble(
          merge = merges$channel[i], channel = members[differ], color = merges$.colors[[i]][differ]
        ))
      }
    }
  }
  # overlays get one entry each: "overlay (GFP, Cy3)"
  if (".is_overlay" %in% names(panels)) {
    ov <- panels[panels$.is_overlay & !duplicated(panels$channel), , drop = FALSE]
    for (i in seq_len(nrow(ov))) {
      members <- as.character(images$channel[ov$.sources[[i]]])
      items <- rbind(items, tibble::tibble(
        channel = paste0(ov$channel[i], " (", paste(members, collapse = ", "), ")"),
        color = ov$.colors[[i]][1]
      ))
    }
  }
  items <- items[!is_black(items$color), , drop = FALSE]
  if (!is.null(extra)) {
    # compare colours by value: "magenta" is "#FF00FF"
    extra$color <- to_hex(extra$color)
    # one colour per channel across merges, and no entry of its own: plain name
    plain <- !extra$channel %in% items$channel &
      vapply(extra$channel, function(ch) length(unique(extra$color[extra$channel == ch])) == 1,
        logical(1), USE.NAMES = FALSE)
    extra$label <- unname(ifelse(plain, extra$channel, paste0(extra$merge, ": ", extra$channel)))
    extra <- extra[!duplicated(extra$label), , drop = FALSE]
    items <- rbind(items, tibble::tibble(channel = extra$label, color = extra$color))
  }
  items
}

# Space the legend needs (mm) on each side of the panels. Legends on top or
# at the bottom wrap into rows no wider than the panels (`max_width`).
legend_extent <- function(items, lg, max_width = Inf) {
  if (is.null(lg) || is.null(items) || nrow(items) == 0) {
    return(list(top = 0, bottom = 0, right = 0, left = 0))
  }
  dims <- legend_dims(items, lg, max_width)
  list(
    top = if (lg$position == "top") dims$height else 0,
    bottom = if (lg$position == "bottom") dims$height else 0,
    right = if (lg$position == "right") dims$width else 0,
    left = 0
  )
}

legend_dims <- function(items, lg, max_width = Inf) {
  swatch <- lg$size * 0.3528 * 1.1
  item_w <- swatch + 1 + text_width_mm(items$channel, lg$size)
  margin <- 2
  spacing <- 3
  line <- swatch * 1.6
  if (lg$position == "right") {
    return(list(
      swatch = swatch, item_w = item_w, row = seq_along(item_w), line = line,
      width = margin + max(item_w), height = length(item_w) * line
    ))
  }
  # fill rows from left to right
  row <- integer(length(item_w))
  r <- 1L
  used <- 0
  for (i in seq_along(item_w)) {
    needed <- if (used == 0) item_w[i] else used + spacing + item_w[i]
    if (used > 0 && needed > max_width) {
      r <- r + 1L
      used <- item_w[i]
    } else {
      used <- needed
    }
    row[i] <- r
  }
  row_w <- tapply(item_w, row, function(w) sum(w) + (length(w) - 1) * spacing)
  list(
    swatch = swatch, item_w = item_w, row = row, line = line, spacing = spacing,
    row_w = as.vector(row_w), width = max(row_w), height = 2 * margin + swatch + (max(row) - 1) * line
  )
}

# Swatches and labels, placed around the panel area (mm, y down).
legend_layout <- function(items, lg, area) {
  d <- legend_dims(items, lg, area$xmax - area$xmin)
  n <- nrow(items)
  if (lg$position == "right") {
    x0 <- rep(area$xmax + 2, n)
    y_center <- (area$ymin + area$ymax) / 2 - d$height / 2 + (seq_len(n) - 0.5) * d$line
  } else {
    # each row is centred over the panels
    x0 <- numeric(n)
    for (r in unique(d$row)) {
      idx <- which(d$row == r)
      start <- (area$xmin + area$xmax) / 2 - d$row_w[r] / 2
      x0[idx] <- start + c(0, cumsum(d$item_w[idx] + d$spacing))[seq_along(idx)]
    }
    first <- if (lg$position == "top") 2 + d$swatch / 2 else area$ymax + 2 + d$swatch / 2
    y_center <- first + (d$row - 1) * d$line
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

to_hex <- function(color) {
  rgb <- grDevices::col2rgb(color)
  grDevices::rgb(rgb[1, ], rgb[2, ], rgb[3, ], maxColorValue = 255)
}
