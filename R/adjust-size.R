#' Adjust the size of a montage
#'
#' Like plots in tidyplots, montages have a fixed physical size, so that they
#' look the same on screen and in every saved file. The size refers to the
#' grid of panels (panels and the gaps between them); headers are added
#' outside of it.
#'
#' The panel grid is scaled to fit into a box of `width` x `height`, keeping
#' the shape of the panels: depending on the layout, one side of the grid will
#' be shorter than the box. Use `NA` for one of them to constrain only the
#' other side. The default is a box of 90 x 90 mm; change it for all
#' montages with [tidymontage_options()].
#'
#' @param montage A [tidymontage()] object.
#' @param width,height Size of the box the panel grid has to fit into. One of
#'   them can be `NA`. `NULL` uses [tidymontage_options()], or 90 mm.
#' @param units Units of `width` and `height`: `"mm"`, `"cm"` or `"in"`.
#'   `NULL` uses [tidymontage_options()], or `"mm"`.
#'
#' @returns The montage with the size step added.
#' @examples
#' \dontrun{
#' montage |> adjust_size(width = 180, height = NA)
#' }
#' @export
adjust_size <- function(montage, width = NULL, height = NULL, units = NULL) {
  check_tidymontage(montage)
  units <- units %||% option_units()
  units <- rlang::arg_match(units, c("mm", "cm", "in"))
  add_step(montage, new_step("adjust_size", size_spec(
    width %||% option_size("width"), height %||% option_size("height"), units
  )))
}

size_spec <- function(width, height, units, call = rlang::caller_env()) {
  for (arg in c("width", "height")) {
    v <- get(arg)
    ok <- length(v) == 1 && (is.na(v) || (is.numeric(v) && v > 0))
    if (!ok) {
      cli::cli_abort("{.arg {arg}} must be a single positive number or {.code NA}.", call = call)
    }
  }
  if (is.na(width) && is.na(height)) {
    cli::cli_abort("At least one of {.arg width} and {.arg height} must be given.", call = call)
  }
  factor <- c(mm = 1, cm = 10, `in` = 25.4)[[units]]
  list(
    width = as.numeric(width) * factor, height = as.numeric(height) * factor,
    given = list(width = width, height = height, units = units)
  )
}

default_size <- function() {
  list(width = 90, height = 90)
}

#' @export
format.tidymontage_step_adjust_size <- function(x, ...) {
  g <- x$params$given
  args <- c(
    paste0("width = ", format(g$width)),
    paste0("height = ", format(g$height)),
    if (g$units != "mm") paste0("units = \"", g$units, "\"")
  )
  paste0("adjust_size(", paste(args, collapse = ", "), ")")
}
