#' Set global defaults for montages
#'
#' Like `tidyplots_options()` in tidyplots, `tidymontage_options()` sets
#' defaults for the rest of the session, for example the size of all montages
#' in a report. Arguments given to [tidymontage()] or [adjust_size()] still
#' take precedence.
#'
#' Each call sets all options at once, as in tidyplots: options not given are
#' reset to the package defaults. Calling `tidymontage_options()` without
#' arguments resets all of them.
#'
#' @param width,height Size of the box the panel grid fits into, see
#'   [adjust_size()]. One of them can be `NA`. Package default: 90 x 90 mm.
#' @param units Units of `width` and `height`: `"mm"`, `"cm"` or `"in"`.
#'   Package default: `"mm"`.
#' @param gap Gap between panels in mm. Package default: 1.
#'
#' @returns The previous options, invisibly, as a list that can be passed to
#'   [options()] to restore them.
#' @examples
#' old <- tidymontage_options(width = 140, height = 140)
#' # ... montages are now fitted into 140 x 140 mm ...
#' options(old)
#'
#' # back to the package defaults
#' tidymontage_options()
#' @export
tidymontage_options <- function(width = NULL, height = NULL, units = NULL, gap = NULL) {
  if (!is.null(units)) units <- rlang::arg_match(units, c("mm", "cm", "in"))
  if (!is.null(width) || !is.null(height)) {
    # validate together, as the montage will
    size_spec(width %||% 90, height %||% 90, units %||% "mm")
  }
  if (!is.null(gap)) check_gap(gap)
  invisible(options(
    tidymontage.width = width, tidymontage.height = height,
    tidymontage.units = units, tidymontage.gap = gap
  ))
}

option_size <- function(which) getOption(paste0("tidymontage.", which), 90)
option_units <- function() getOption("tidymontage.units", "mm")
option_gap <- function() getOption("tidymontage.gap", 1)
