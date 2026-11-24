#' Adjust channel colours
#'
#' Set the colour of channels by name. Colours are a display property: by
#' default, each image is shown in the colour of its `color` column, which
#' [read_images()] fills from the microscope metadata. `adjust_colors()`
#' overrides it for the channels you name.
#'
#' Instead of a single colour, a channel can get a colormap such as magma or
#' viridis with [lut()]. In merges, such a channel uses its original colour
#' (see [add_merge()]).
#'
#' @param montage A [tidymontage()] object.
#' @param ... Name-value pairs of channel names and colours, for example
#'   `DAPI = "#0072B2"`. Colours can be any colour R understands, such as hex
#'   strings or names like `"white"`, or colormaps made with [lut()], for
#'   example `GCaMP = lut("magma")`.
#'
#' @returns The montage with the colour step added.
#' @examples
#' \dontrun{
#' montage |> adjust_colors(DAPI = "#0072B2", GFP = "#009E73")
#' montage |> adjust_colors(GCaMP = lut("magma"))
#' }
#' @export
adjust_colors <- function(montage, ...) {
  check_tidymontage(montage)
  colors <- rlang::list2(...)
  if (length(colors) == 0 || !rlang::is_named(colors)) {
    cli::cli_abort("All arguments in {.arg ...} must be named with a channel, e.g. {.code DAPI = \"blue\"}.")
  }
  channels <- unique(as.character(montage$images$channel))
  unknown <- setdiff(names(colors), channels)
  if (length(unknown) > 0) {
    cli::cli_abort(
      c(
        "Unknown channel{?s}: {.val {unknown}}.",
        "i" = "Available channels: {.val {channels}}."
      )
    )
  }
  for (nm in names(colors)) {
    check_color_or_lut(colors[[nm]], cli::format_inline("The colour for {.val {nm}}"))
  }
  add_step(montage, new_step("adjust_colors", lapply(colors, function(x) if (is_lut(x)) x else as.character(x))))
}

#' @export
format.tidymontage_step_adjust_colors <- function(x, ...) {
  args <- vapply(names(x$params), function(nm) {
    paste0(format_channel_names(nm), " = ", format_color(x$params[[nm]]))
  }, character(1))
  paste0("adjust_colors(", paste(args, collapse = ", "), ")")
}
