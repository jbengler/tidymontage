#' Layouts
#'
#' A layout arranges the panels of a montage. The columns of the images
#' tibble that you map to `x` and `y` in [tidymontage()] (such as `condition`)
#' arrange blocks of panels; the layout decides how the channels and views of
#' each block are arranged:
#'
#' * `layout_grid()`, the default, puts channels and views on the rows and
#'   columns of a grid. Each channel and view is placed automatically on a free
#'   axis, unless you map `channel` or `view` to `x` or `y` yourself.
#' * `layout_hero()` shows one big panel per block, for example the merge of a
#'   crop, next to a strip of small panels, for example the single channels of
#'   a zoom.
#'
#' Layouts are like themes: switch between them with the `layout` argument of
#' [tidymontage()] or with [adjust_layout()], without changing the mapping.
#'
#' @param channel,view For the grid: the axis (`"x"` or `"y"`) for channels and
#'   views. `"auto"` uses an axis that no other column is mapped to.
#' @param hero,side For the hero layout: the big panel and the small panels of
#'   each block, chosen with [panel()]. By default, the hero is the merge (or
#'   the first channel) of the main view (full image or crop), and the side
#'   panels are the single channels of the zoom (or of the main view).
#' @param position For the hero layout: where the small panels go.
#' @param labels For the hero layout: label the small panels with what
#'   distinguishes them (usually the channel), in the header font, outside the
#'   images: below them for `position = "bottom"`, beside them otherwise,
#'   rotated like ggplot2 facet strips. Long labels wrap onto two lines.
#'   Stacked side panels line up across blocks, so they are labelled once:
#'   on the left of the first column when below the hero, and below the last
#'   row when beside it.
#' @param stack For the hero layout: stack the small panels so that each is as
#'   long as the hero's edge, for strips such as a 15 x 4 um zoom. Below the
#'   hero, the strips are as wide as the hero and placed one under the other;
#'   beside it, they are as high as the hero and placed side by side. The side
#'   panels can have another aspect ratio than the hero, but all side panels
#'   share one.
#'
#' @returns A layout specification for [tidymontage()] or [adjust_layout()].
#' @examples
#' \dontrun{
#' tidymontage(images, x = condition, layout = layout_grid(channel = "x"))
#' tidymontage(images, x = condition, layout = "hero")
#' tidymontage(images, layout = layout_hero(side = panel(view = "crop"), position = "bottom"))
#'
#' # a big merge with zoom strips of each channel below it
#' tidymontage(images, layout = layout_hero(position = "bottom", stack = TRUE)) |>
#'   add_zoom(width = 15, height = 4)
#' }
#' @name layouts
NULL

#' @rdname layouts
#' @export
layout_grid <- function(channel = c("auto", "x", "y"), view = c("auto", "x", "y")) {
  structure(
    list(type = "grid", channel = rlang::arg_match(channel), view = rlang::arg_match(view)),
    class = "tidymontage_layout"
  )
}

#' @rdname layouts
#' @export
layout_hero <- function(hero = NULL, side = NULL, position = c("right", "bottom", "left"), labels = TRUE,
                        stack = FALSE) {
  for (arg in c("hero", "side")) {
    v <- get(arg)
    if (!is.null(v) && !inherits(v, "tidymontage_panel")) {
      cli::cli_abort("{.arg {arg}} must be created with {.fn panel}.")
    }
  }
  structure(
    list(
      type = "hero", hero = hero, side = side, position = rlang::arg_match(position), labels = isTRUE(labels),
      stack = isTRUE(stack)
    ),
    class = "tidymontage_layout"
  )
}

#' Choose panels for a layout
#'
#' `panel()` picks panels by the levels of panel dimensions, for the `hero` and
#' `side` arguments of [layout_hero()].
#'
#' @param ... Name-value pairs of panel dimensions and levels, e.g.
#'   `channel = "merge"`, `view = "crop"` or `channel = c("GFP", "DAPI")`.
#'   The order of the levels sets the order of the panels.
#' @returns A panel specification.
#' @examples
#' panel(channel = "merge", view = "crop")
#' @export
panel <- function(...) {
  sel <- rlang::list2(...)
  if (length(sel) == 0 || !rlang::is_named(sel)) {
    cli::cli_abort("All arguments of {.fn panel} must be named with a panel dimension, e.g. {.code channel = \"merge\"}.")
  }
  structure(lapply(sel, as.character), class = "tidymontage_panel")
}

#' @export
format.tidymontage_panel <- function(x, ...) {
  args <- vapply(names(x), function(nm) paste0(nm, " = ", paste(deparse(unclass(x)[[nm]]), collapse = "")), "")
  paste0("panel(", paste(args, collapse = ", "), ")")
}

#' @export
format.tidymontage_layout <- function(x, ...) {
  if (x$type == "grid") {
    args <- c(
      if (x$channel != "auto") paste0("channel = \"", x$channel, "\""),
      if (x$view != "auto") paste0("view = \"", x$view, "\"")
    )
    if (length(args) == 0) return("\"grid\"")
    paste0("layout_grid(", paste(args, collapse = ", "), ")")
  } else {
    args <- c(
      if (!is.null(x$hero)) paste0("hero = ", format(x$hero)),
      if (!is.null(x$side)) paste0("side = ", format(x$side)),
      if (x$position != "right") paste0("position = \"", x$position, "\""),
      if (!isTRUE(x$labels %||% TRUE)) "labels = FALSE",
      if (isTRUE(x$stack)) "stack = TRUE"
    )
    if (length(args) == 0) return("\"hero\"")
    paste0("layout_hero(", paste(args, collapse = ", "), ")")
  }
}

#' @export
print.tidymontage_layout <- function(x, ...) {
  cat("<tidymontage_layout> ", format(x), "\n", sep = "")
  invisible(x)
}

as_layout <- function(layout, call = rlang::caller_env()) {
  if (inherits(layout, "tidymontage_layout")) {
    return(layout)
  }
  if (rlang::is_string(layout) && layout %in% c("grid", "hero")) {
    return(if (layout == "grid") layout_grid() else layout_hero())
  }
  cli::cli_abort(
    "{.arg layout} must be {.val grid}, {.val hero}, or created with {.fn layout_grid} or {.fn layout_hero}.",
    call = call
  )
}

#' Adjust the layout of a montage
#'
#' Changes the mapping, the level choices, the layout or the gap of a montage
#' after [tidymontage()]. Only the arguments you give are changed.
#'
#' @inheritParams tidymontage
#' @param montage A [tidymontage()] object.
#' @returns The montage with the layout step added.
#' @examples
#' \dontrun{
#' montage |> adjust_layout(layout = "hero")
#' montage |> adjust_layout(x = channel, y = condition)
#' }
#' @export
adjust_layout <- function(montage, x, y, ..., layout, gap) {
  check_tidymontage(montage)
  params <- list()
  if (!missing(x)) params$x <- dims_from_quo(rlang::enquo(x), montage$images, arg = "x")
  if (!missing(y)) params$y <- dims_from_quo(rlang::enquo(y), montage$images, arg = "y")
  levels <- check_levels(rlang::list2(...), montage$images)
  if (length(levels) > 0) params$levels <- levels
  if (!missing(layout)) params$layout <- as_layout(layout)
  if (!missing(gap)) params$gap <- check_gap(gap)
  if (!is.null(params$x) || !is.null(params$y)) {
    check_xy(params$x %||% character(), params$y %||% character())
  }
  add_step(montage, new_step("adjust_layout", params))
}

#' @export
format.tidymontage_step_adjust_layout <- function(x, ...) {
  paste0("adjust_layout(", paste(format_setup_args(x$params), collapse = ", "), ")")
}

format_setup_args <- function(p) {
  c(
    if (length(p$x) > 0) paste0("x = ", format_dims(p$x)),
    if (length(p$y) > 0) paste0("y = ", format_dims(p$y)),
    vapply(names(p$levels), function(nm) paste0(nm, " = ", paste(deparse(p$levels[[nm]]), collapse = "")), character(1)),
    if (!is.null(p$layout) && format(p$layout) != "\"grid\"") paste0("layout = ", format(p$layout)),
    if (!is.null(p$gap) && p$gap != 1) paste0("gap = ", p$gap)
  )
}

check_levels <- function(levels, images, call = rlang::caller_env()) {
  if (length(levels) == 0) {
    return(list())
  }
  if (!rlang::is_named(levels)) {
    cli::cli_abort(
      "Arguments in {.arg ...} must be named with a panel dimension, e.g. {.code channel = c(\"GFP\", \"DAPI\")}.",
      call = call
    )
  }
  unknown <- setdiff(names(levels), c(names(images), "view"))
  if (length(unknown) > 0) {
    cli::cli_abort(
      c(
        "Unknown argument or panel dimension{?s}: {.field {unknown}}.",
        "i" = "Arguments in {.arg ...} choose levels of columns of the images tibble, {.field channel} or {.field view}."
      ),
      call = call
    )
  }
  lapply(levels, as.character)
}

check_gap <- function(gap, call = rlang::caller_env()) {
  if (!is.numeric(gap) || length(gap) != 1 || is.na(gap) || gap < 0) {
    cli::cli_abort("{.arg gap} must be a single non-negative number (mm).", call = call)
  }
  gap
}

check_xy <- function(x, y, call = rlang::caller_env()) {
  both <- intersect(x, y)
  if (length(both) > 0) {
    cli::cli_abort("{.field {both}} can't be mapped to both {.arg x} and {.arg y}.", call = call)
  }
}

# Column names from a bare name, a string or c() of them.
dims_from_quo <- function(quo, data, arg, call = rlang::caller_env()) {
  expr <- rlang::quo_get_expr(quo)
  dims <- expr_names(expr, arg, call)
  allowed <- c(names(data), "view")
  unknown <- setdiff(dims, allowed)
  if (length(unknown) > 0) {
    cli::cli_abort(
      c(
        "Can't find {.field {unknown}} for {.arg {arg}}.",
        "i" = "Use columns of the images tibble or {.field view}."
      ),
      call = call
    )
  }
  dims
}

expr_names <- function(expr, arg, call) {
  if (is.null(expr)) {
    return(character())
  }
  if (rlang::is_symbol(expr)) {
    return(rlang::as_string(expr))
  }
  if (rlang::is_string(expr)) {
    return(expr)
  }
  if (rlang::is_call(expr, "c")) {
    return(unique(unlist(lapply(as.list(expr)[-1], expr_names, arg = arg, call = call))))
  }
  cli::cli_abort(
    "{.arg {arg}} must be a column name or {.code c()} of column names, not {.code {rlang::expr_deparse(expr)}}.",
    call = call
  )
}
