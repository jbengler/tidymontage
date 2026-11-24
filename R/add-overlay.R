#' Add an overlay of channels
#'
#' Adds a panel that shows where channels coincide: a single-colour image that
#' is bright only where all member channels are bright. It is computed as the
#' minimum of the members' display-scaled intensities (0 to 1 within their
#' display ranges), so it is "as bright as the weakest channel". Like a merge,
#' an overlay is a new, virtual channel that can be placed in the layout like
#' any other channel.
#'
#' The overlay keeps the 0-1 scale it inherits and is not stretched again, so
#' a faint overlap looks faint. Because it depends on the display ranges, keep
#' them linked (the default of [adjust_exposure()]) when comparing conditions.
#'
#' @inheritParams add_merge
#' @param name Name of the overlay, as it appears in the layout and in labels.
#' @param color Colour of the overlay. `"black"` shows it inverted, as dark
#'   signal on white. A colormap made with [lut()], such as `lut("inferno")`,
#'   colours the overlay by its strength.
#' @param threshold Optional threshold between 0 and 1 on the overlay
#'   intensity: pixels below it are shown as background. `NULL` (the default)
#'   shows the overlay as it is.
#'
#' @returns The montage with the overlay step added.
#' @examples
#' \dontrun{
#' montage |>
#'   add_overlay(GFP, Cy3, name = "overlap", color = "yellow")
#' }
#' @export
add_overlay <- function(montage, ..., name = "overlay", color = "white", threshold = NULL) {
  check_tidymontage(montage)
  call <- rlang::current_env()
  channels <- virtual_members(rlang::enquos(...), montage, name, "overlay", call)
  check_color_or_lut(color, cli::format_inline("{.arg color}"))
  if (!is.null(threshold) && (!is.numeric(threshold) || length(threshold) != 1 || is.na(threshold) ||
    threshold < 0 || threshold > 1)) {
    cli::cli_abort("{.arg threshold} must be a single number between 0 and 1, or {.code NULL}.")
  }
  add_step(montage, new_step("add_overlay", list(
    channels = channels, name = name, color = color, threshold = threshold
  )))
}

#' @export
format.tidymontage_step_add_overlay <- function(x, ...) {
  p <- x$params
  args <- c(
    format_channel_names(p$channels),
    paste0("name = \"", p$name, "\""),
    if (!identical(p$color, "white")) paste0("color = ", format_color(p$color)),
    if (!is.null(p$threshold)) paste0("threshold = ", p$threshold)
  )
  paste0("add_overlay(", paste(args, collapse = ", "), ")")
}
