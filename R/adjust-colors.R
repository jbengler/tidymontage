#' Adjust channel colours
#'
#' Set the colour of channels by name. Colours are a display property: by
#' default, each image is shown in the colour of its `color` column, which
#' [read_images()] fills from the microscope metadata. `adjust_colors()`
#' overrides it for the channels you name.
#'
#' @param montage A [tidymontage()] object.
#' @param ... Name-value pairs of channel names and colours, for example
#'   `DAPI = "#0072B2"`. Colours can be any colour R understands, such as hex
#'   strings or names like `"white"`.
#'
#' @returns The montage with the colour step added.
#' @examples
#' \dontrun{
#' montage |> adjust_colors(DAPI = "#0072B2", GFP = "#009E73")
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
    col <- colors[[nm]]
    ok <- rlang::is_string(col) && !inherits(try(grDevices::col2rgb(col), silent = TRUE), "try-error")
    if (!ok) {
      cli::cli_abort("The colour for {.val {nm}} must be a single valid colour, not {.obj_type_friendly {col}}.")
    }
  }
  add_step(montage, new_step("adjust_colors", lapply(colors, as.character)))
}
