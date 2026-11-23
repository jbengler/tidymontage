# Steps are the lazy building blocks of a montage recipe. Each user-facing verb
# (`select_planes()`, `adjust_exposure()`, `add_merge()`, ...) validates its
# arguments, creates one step and appends it with `add_step()`. Steps are only
# executed when the montage is rendered.

new_step <- function(type, params = list()) {
  if (!rlang::is_string(type)) {
    cli::cli_abort("{.arg type} must be a single string.", .internal = TRUE)
  }
  if (!is.list(params) || (length(params) > 0 && !rlang::is_named(params))) {
    cli::cli_abort("{.arg params} must be a named list.", .internal = TRUE)
  }
  structure(
    list(type = type, params = params),
    class = c(paste0("tidymontage_step_", type), "tidymontage_step")
  )
}

add_step <- function(montage, step, call = rlang::caller_env()) {
  check_tidymontage(montage, call = call)
  if (!inherits(step, "tidymontage_step")) {
    cli::cli_abort("{.arg step} must be a {.cls tidymontage_step}.", .internal = TRUE)
  }
  montage$steps <- c(montage$steps, list(step))
  montage
}

#' @export
format.tidymontage_step <- function(x, ...) {
  rlang::expr_deparse(rlang::call2(x$type, !!!x$params), width = Inf)
}

#' @export
print.tidymontage_step <- function(x, ...) {
  cat("<tidymontage_step> ", format(x), "\n", sep = "")
  invisible(x)
}

#' @export
format.tidymontage_step_adjust_exposure <- function(x, ...) {
  p <- x$params
  args <- c(
    paste0("min = ", format_range_spec(p$min)),
    paste0("max = ", format_range_spec(p$max)),
    vapply(names(p$overrides), function(nm) {
      o <- p$overrides[[nm]]
      paste0(nm, " = c(", format_range_spec(o$min), ", ", format_range_spec(o$max), ")")
    }, character(1)),
    paste0(".by = ", format_dims(p$by))
  )
  paste0("adjust_exposure(", paste(args, collapse = ", "), ")")
}

format_dims <- function(dims) {
  if (length(dims) == 1) dims else paste0("c(", paste(dims, collapse = ", "), ")")
}
