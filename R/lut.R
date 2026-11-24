#' Colour lookup tables (colormaps)
#'
#' Creates a lookup table (LUT) that colours a channel with a colormap such as
#' magma or viridis instead of a single colour. Use it in [adjust_colors()] or
#' as the colour of [add_overlay()]. Intensities at or below the lower end of
#' the display range (see [adjust_exposure()]) get the first colour of the
#' map, at or above the upper end its last colour.
#'
#' Colormaps work best for single-channel panels with quantitative content,
#' such as calcium imaging, ratio images or intensity heatmaps: perceptually
#' uniform maps like magma and viridis show differences in intensity more
#' faithfully than a single colour does.
#'
#' Merges need single colours, since colours add up like light. In a merge, a
#' channel coloured with a LUT uses its original colour from the image
#' metadata (the `color` column) instead, unless [add_merge()] sets one. In
#' its own panels, a LUT channel is drawn on the first colour of its map, and
#' [add_color_legend()] shows it as a colour bar.
#'
#' @param colors The name of a colormap, or a vector of two or more colours.
#'   Colormaps are the perceptually uniform maps of the viridisLite package:
#'   `"magma"`, `"inferno"`, `"plasma"`, `"viridis"`, `"cividis"`, `"rocket"`,
#'   `"mako"` and `"turbo"`. Colours are spread evenly from the lower to the
#'   upper end of the display range, for example `c("black", "red", "yellow")`.
#' @param reverse If `TRUE`, the map runs the other way round.
#'
#' @returns A `tidymontage_lut` object.
#' @examples
#' lut("magma")
#' lut("viridis", reverse = TRUE)
#' lut(c("black", "darkred", "orange", "white"))
#'
#' \dontrun{
#' montage |> adjust_colors(GCaMP = lut("magma"))
#' }
#' @export
lut <- function(colors, reverse = FALSE) {
  if (!is.character(colors) || length(colors) == 0 || anyNA(colors)) {
    cli::cli_abort("{.arg colors} must be a colormap name or a vector of colours, not {.obj_type_friendly {colors}}.")
  }
  if (!rlang::is_bool(reverse)) {
    cli::cli_abort("{.arg reverse} must be {.code TRUE} or {.code FALSE}.")
  }
  if (length(colors) == 1) {
    name <- tolower(colors)
    if (!name %in% lut_names) {
      if (is_valid_color(colors)) {
        cli::cli_abort(c(
          "A LUT needs a colormap name or at least two colours.",
          "i" = "For a single colour, use it directly, e.g. {.code GFP = {.str {colors}}}."
        ))
      }
      cli::cli_abort(c(
        "Unknown colormap {.val {colors}}.",
        "i" = "Available colormaps: {.val {lut_names}}."
      ))
    }
    colors <- name
  } else {
    bad <- colors[!vapply(colors, is_valid_color, logical(1))]
    if (length(bad) > 0) {
      cli::cli_abort("{.arg colors} contains invalid colour{?s}: {.val {bad}}.")
    }
  }
  structure(list(colors = colors, reverse = reverse), class = "tidymontage_lut")
}

lut_names <- c("magma", "inferno", "plasma", "viridis", "cividis", "rocket", "mako", "turbo")

is_lut <- function(x) inherits(x, "tidymontage_lut")

is_valid_color <- function(x) {
  rlang::is_string(x) && !inherits(try(grDevices::col2rgb(x), silent = TRUE), "try-error")
}

#' @export
format.tidymontage_lut <- function(x, ...) {
  cols <- if (length(x$colors) == 1) {
    paste0("\"", x$colors, "\"")
  } else {
    paste0("c(", paste0("\"", x$colors, "\"", collapse = ", "), ")")
  }
  paste0("lut(", cols, if (x$reverse) ", reverse = TRUE", ")")
}

#' @export
print.tidymontage_lut <- function(x, ...) {
  cat("<tidymontage_lut> ", format(x), "\n", sep = "")
  invisible(x)
}

# The 256 colours of a LUT, as hex strings.
lut_table <- function(x) {
  table <- if (length(x$colors) == 1) {
    substr(viridisLite::viridis(256, option = x$colors), 1, 7)
  } else {
    grDevices::colorRampPalette(x$colors)(256)
  }
  if (x$reverse) rev(table) else table
}

lut_low <- function(x) lut_table(x)[1]
lut_high <- function(x) lut_table(x)[256]

# A colour or LUT as it is shown where only a single colour fits (merges,
# swatches): a LUT's top colour.
single_color <- function(x) if (is_lut(x)) lut_high(x) else x

# Intensities (0-1) -> red, green and blue matrices (0-255) through a LUT.
lut_rgb <- function(v, table) {
  idx <- round(v * (length(table) - 1)) + 1
  rgb <- grDevices::col2rgb(table)
  lapply(1:3, function(ch) matrix(rgb[ch, idx], nrow(v), ncol(v)))
}

# A colour or a LUT, as given to adjust_colors() or add_overlay().
check_color_or_lut <- function(x, what, call = rlang::caller_env()) {
  if (is_lut(x) || is_valid_color(x)) {
    return(invisible())
  }
  if (rlang::is_string(x) && tolower(x) %in% lut_names) {
    cli::cli_abort(c(
      "{what} must be a single valid colour or a LUT.",
      "i" = "For a colormap, use {.code lut({.str {x}})}."
    ), call = call)
  }
  cli::cli_abort("{what} must be a single valid colour or a LUT, not {.obj_type_friendly {x}}.", call = call)
}

format_color <- function(x) if (is_lut(x)) format(x) else paste0("\"", x, "\"")

# Text and frames on a panel: black on light backgrounds, white on dark ones.
is_light <- function(color) {
  rgb <- grDevices::col2rgb(color) / 255
  as.vector(c(0.2126, 0.7152, 0.0722) %*% rgb) > 0.5
}

ink_on <- function(background) if (is_light(background)) "black" else "white"
