# Previews: montages that show options to choose from, to find the ballpark
# for exposure and positions before fine-tuning the arguments.

# Steps are coarse on purpose: neighbouring options should look different.
exposure_ladder <- list(
  min = c(0, 0.1, 1, 5, 10, 25),
  max = c(95, 98, 99, 99.9, 99.99, 100)
)

#' Preview exposure options
#'
#' Shows one image of a channel with 25 combinations of display ranges,
#' ordered by how the image looks: from left to right it gets brighter (the
#' upper end, `max`, decreases), from top to bottom the background gets darker
#' (the lower end, `min`, increases). The outlined panel is the current setting
#' of the montage (see [adjust_exposure()]), surrounded by up to two steps in
#' each direction; at the ends of the scale (e.g. `min = "p0"`) it moves off
#' the middle. Read off the percentiles of the panel you like and set them with
#' [adjust_exposure()].
#'
#' The percentiles are computed from all images of the channel, as in the
#' montage, so the preview looks like the final figure. Repeat the preview
#' after adjusting the exposure to refine it further.
#'
#' @param montage A [tidymontage()] object.
#' @param channel The channel to preview. Can be left out if the montage has
#'   one channel only.
#' @param ... Conditions that pick one image of the channel, as in
#'   `dplyr::filter()`, e.g. `mutant == "L59A"`. By default, the brightest
#'   image is shown.
#'
#' @returns A montage with the options. Print it to see them.
#' @examples
#' \dontrun{
#' montage |> preview_exposure("Cy3")
#' montage |> preview_exposure("Cy3", mutant == "L59A")
#' }
#' @export
preview_exposure <- function(montage, channel, ...) {
  check_tidymontage(montage)
  images <- montage$images
  spec <- montage_spec(montage)
  channels <- unique(as.character(images$channel))
  if (missing(channel)) {
    if (length(channels) > 1) {
      cli::cli_abort(c("Choose a {.arg channel} to preview.", "i" = "Channels: {.val {channels}}."))
    }
    channel <- channels
  }
  if (!rlang::is_string(channel) || !channel %in% channels) {
    cli::cli_abort(c("{.arg channel} must be one channel of the montage.", "i" = "Channels: {.val {channels}}."))
  }

  candidates <- images[as.character(images$channel) == channel, , drop = FALSE]
  pixels <- img_pixels(candidates$img)
  conditions <- rlang::enquos(...)
  if (length(conditions) > 0) {
    keep <- rep(TRUE, nrow(candidates))
    for (q in conditions) keep <- keep & (rlang::eval_tidy(q, candidates) %in% TRUE)
    selected <- which(keep)
    if (length(selected) != 1) {
      cli::cli_abort(c(
        "The conditions must pick exactly one image of {.val {channel}}, but they pick {length(selected)}.",
        "i" = "Add conditions on columns that tell the images apart, e.g. {.field filepath}."
      ))
    }
    how <- "chosen"
  } else {
    brightness <- vapply(pixels, function(m) stats::quantile(sample_pixels(m), 0.999, names = FALSE), numeric(1))
    selected <- which.max(brightness)
    how <- if (nrow(candidates) > 1) paste("the brightest of", nrow(candidates), "images") else "the only image"
  }

  # display ranges come from the images that share a range with the selected
  # one, as in the montage (linked per channel by default)
  exposure <- spec$exposure
  by <- setdiff(exposure$by, c("channel", "view"))
  same_group <- rep(TRUE, nrow(candidates))
  for (d in intersect(by, names(candidates))) {
    same_group <- same_group & as.character(candidates[[d]]) == as.character(candidates[[d]][selected])
  }
  pool <- unlist(lapply(pixels[same_group], sample_pixels))
  override <- exposure$overrides[[channel]]
  min_steps <- exposure_steps(override$min %||% exposure$min, exposure_ladder$min, pool)
  max_steps <- exposure_steps(override$max %||% exposure$max, exposure_ladder$max, pool)
  lo <- stats::quantile(pool, min_steps$steps / 100, names = FALSE)
  hi <- stats::quantile(pool, max_steps$steps / 100, names = FALSE)

  grid <- expand.grid(i = seq_along(min_steps$steps), j = seq_along(max_steps$steps))
  rows <- candidates[rep(selected, nrow(grid)), , drop = FALSE]
  min_labels <- paste("min", format_percentile(min_steps$steps))
  max_labels <- paste("max", format_percentile(max_steps$steps))
  # min increases downwards (darker background); max decreases to the right
  # (brighter image)
  rows$min_option <- factor(min_labels[grid$i], levels = min_labels)
  rows$max_option <- factor(max_labels[grid$j], levels = rev(max_labels))
  rows$display_min <- lo[grid$i]
  rows$display_max <- hi[grid$j]
  rows$.outline <- grid$i == min_steps$current & grid$j == max_steps$current

  preview <- tidymontage(rows, x = max_option, y = min_option)
  if (length(spec$colors) > 0) preview <- add_step(preview, new_step("adjust_colors", spec$colors))
  if (!is.null(spec$crop)) preview <- add_step(preview, new_step("add_crop", spec$crop))

  shown <- if ("filepath" %in% names(candidates)) basename(candidates$filepath[selected]) else paste("image", selected)
  cli::cli_inform(c(
    "i" = "{.val {channel}}: {.file {shown}} ({how}).",
    "i" = "Percentiles from {sum(same_group)} image{?s} sharing its display range."
  ))
  preview
}

# Five steps around the current setting on a ladder of percentiles. A setting
# that is an intensity value is placed at its percentile.
exposure_steps <- function(spec, ladder, pool) {
  current <- if (spec$type == "percentile") spec$value else 100 * mean(pool <= spec$value)
  values <- sort(unique(c(ladder, current)))
  at <- match(current, values)
  first <- min(max(1, at - 2), max(1, length(values) - 4))
  steps <- values[first:min(length(values), first + 4)]
  list(steps = steps, current = match(current, steps))
}

format_percentile <- function(x) {
  paste0("p", format(signif(x, 4), drop0trailing = TRUE, trim = TRUE, scientific = FALSE))
}

#' Preview positions for crops and zooms
#'
#' Shows the full images with relative coordinates: axes from 0 to 1 below and
#' to the right of each image, and faint grid lines in steps of 0.1. Read off
#' the center of the region you want and use it in [add_crop()] or
#' [add_zoom()]. If the montage has a crop or zoom already, its current region
#' is outlined and labelled, which also shows its size.
#'
#' One image is shown per block of the montage (the columns mapped to `x` and
#' `y`, e.g. one per condition), as positions are usually chosen per block.
#' The merge is shown if the montage has one, otherwise the first channel.
#'
#' @param montage A [tidymontage()] object.
#' @param ... Conditions that pick images, as in `dplyr::filter()`, e.g.
#'   `mutant == "I56A"`.
#'
#' @returns A montage with the coordinates. Print it to see them.
#' @examples
#' \dontrun{
#' montage |> preview_positions()
#' montage |> preview_positions(mutant == "I56A")
#' }
#' @export
preview_positions <- function(montage, ...) {
  check_tidymontage(montage)
  images <- montage$images
  spec <- montage_spec(montage)
  conditions <- rlang::enquos(...)
  if (length(conditions) > 0) {
    keep <- rep(TRUE, nrow(images))
    for (q in conditions) keep <- keep & (rlang::eval_tidy(q, images) %in% TRUE)
    images <- images[keep, , drop = FALSE]
    if (nrow(images) == 0) cli::cli_abort("The conditions pick no images.")
  }

  merges <- setdiff(names(spec$merges), names(spec$overlays))
  channel <- if (length(merges) > 0) merges[1] else unique(as.character(images$channel))[1]
  blocks <- setdiff(c(spec$mapping$x, spec$mapping$y), c("channel", "view"))
  if (length(blocks) == 0) {
    images$file <- basename(images$filepath)
    blocks <- "file"
  }

  preview <- rlang::inject(
    tidymontage(images, x = c(!!!rlang::syms(blocks)), channel = !!channel, gap = 7)
  )
  for (step in montage$steps) {
    if (step$type %in% c("add_merge", "add_overlay", "adjust_colors", "adjust_exposure")) {
      preview <- add_step(preview, step)
    }
  }
  add_step(preview, new_step("preview_positions", list(crop = spec$crop, zoom = spec$zooms[1][[1]])))
}

# Grid lines, axis labels and region outlines of a positions preview (mm).
preview_positions_overlay <- function(panels, data, images, pp, call) {
  lines <- list()
  ticks <- list()
  rects <- list()
  for (i in seq_len(nrow(panels))) {
    p <- panels[i, ]
    w <- p$xmax - p$xmin
    h <- p$ymax - p$ymin
    ink <- if (identical(p$.background, "white")) "black" else "white"
    at <- seq(0.1, 0.9, by = 0.1)
    lines[[i]] <- rbind(
      data.frame(x = p$xmin + at * w, xend = p$xmin + at * w, y = p$ymin, yend = p$ymax, color = ink),
      data.frame(x = p$xmin, xend = p$xmax, y = p$ymin + at * h, yend = p$ymin + at * h, color = ink)
    )
    labels_at <- seq(0, 1, by = 0.2)
    ticks[[i]] <- rbind(
      data.frame(label = as.character(labels_at), x = p$xmin + labels_at * w, y = p$ymax + 0.6, hjust = 0.5, vjust = 1),
      data.frame(label = as.character(labels_at), x = p$xmax + 0.6, y = p$ymin + labels_at * h, hjust = 0, vjust = 0.5)
    )
    row <- data[p$.row, , drop = FALSE]
    node <- vctrs::vec_data(images$img[p$.sources[[1]]])[[1]]$node
    for (what in c("crop", "zoom")) {
      view <- pp[[what]]
      if (is.null(view)) next
      r <- tryCatch(view_region(view, row, node, call), error = function(e) NULL)
      if (is.null(r)) next
      sx <- w / node$size_x
      sy <- h / node$size_y
      rects[[length(rects) + 1]] <- data.frame(
        xmin = p$xmin + (r[1] - 1) * sx, xmax = p$xmin + r[2] * sx,
        ymin = p$ymin + (r[3] - 1) * sy, ymax = p$ymin + r[4] * sy,
        label = what, color = ink
      )
    }
  }
  list(
    lines = do.call(rbind, lines),
    ticks = do.call(rbind, ticks),
    rects = if (length(rects) > 0) do.call(rbind, rects)
  )
}
