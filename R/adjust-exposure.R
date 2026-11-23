#' Adjust the display range
#'
#' Sets how image intensities map to brightness: intensities at or below `min`
#' are shown black, at or above `max` in full colour. Like in ImageJ, this is a
#' display property and does not change the image data.
#'
#' By default, display ranges are **linked per channel**: all images of one
#' channel share the same range, computed from all of them together, so that
#' brightness can be compared across conditions. This is also what happens
#' without calling `adjust_exposure()`. To unlink on purpose, group more
#' finely, for example `.by = c(channel, condition)`.
#'
#' A data column `display_min` and/or `display_max` in the images tibble
#' overrides the range for single images.
#'
#' @param montage A [tidymontage()] object.
#' @param min,max Lower and upper end of the display range: a percentile of
#'   the pixel intensities as a string such as `"p0.1"` or `"p99.9"`, or an
#'   intensity value such as `0` or `4000`.
#' @param ... Per-channel exceptions as name-value pairs, for example
#'   `DAPI = c(0, 2000)` or `DAPI = c("p1", "p99")`.
#' @param .by Columns that define which images share a display range, as a
#'   bare name or `c()` of names. Default: `channel`.
#'
#' @returns The montage with the exposure step added.
#' @examples
#' \dontrun{
#' montage |> adjust_exposure(min = "p0.1", max = "p99.9")
#' montage |> adjust_exposure(DAPI = c(0, 3000))
#' }
#' @export
adjust_exposure <- function(montage, min = "p0.1", max = "p99.9", ..., .by = channel) {
  check_tidymontage(montage)
  min <- parse_range_spec(min, "min")
  max <- parse_range_spec(max, "max")
  overrides <- rlang::list2(...)
  if (length(overrides) > 0 && !rlang::is_named(overrides)) {
    cli::cli_abort("Per-channel exceptions in {.arg ...} must be named with a channel.")
  }
  channels <- unique(as.character(montage$images$channel))
  unknown <- setdiff(names(overrides), channels)
  if (length(unknown) > 0) {
    cli::cli_abort(c("Unknown channel{?s}: {.val {unknown}}.", "i" = "Available channels: {.val {channels}}."))
  }
  overrides <- lapply(names(overrides), function(nm) {
    v <- overrides[[nm]]
    if (length(v) != 2) {
      cli::cli_abort("The range for {.val {nm}} must have two values: {.code c(min, max)}.")
    }
    list(min = parse_range_spec(v[[1]], nm), max = parse_range_spec(v[[2]], nm))
  })
  names(overrides) <- names(rlang::list2(...))
  by <- dims_from_quo(rlang::enquo(.by), montage$images, arg = ".by")
  add_step(montage, new_step("adjust_exposure", list(min = min, max = max, by = by, overrides = overrides)))
}

# A range end is a percentile ("p99.9") or an intensity value.
parse_range_spec <- function(x, arg, call = rlang::caller_env()) {
  if (is.numeric(x) && length(x) == 1 && !is.na(x)) {
    return(list(type = "value", value = as.numeric(x)))
  }
  # c("p1", 4000) arrives as c("p1", "4000"): accept numbers as strings
  if (rlang::is_string(x) && !is.na(suppressWarnings(as.numeric(x)))) {
    return(list(type = "value", value = as.numeric(x)))
  }
  if (rlang::is_string(x) && grepl("^p[0-9.]+$", x)) {
    p <- suppressWarnings(as.numeric(substring(x, 2)))
    if (!is.na(p) && p >= 0 && p <= 100) {
      return(list(type = "percentile", value = p))
    }
  }
  cli::cli_abort(
    "{.arg {arg}} must be a percentile like {.val p99.9} or an intensity value, not {.obj_type_friendly {x}}.",
    call = call
  )
}

format_range_spec <- function(spec) {
  if (spec$type == "percentile") paste0("\"p", spec$value, "\"") else format(spec$value)
}
