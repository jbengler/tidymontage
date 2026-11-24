#' Add a merge of channels
#'
#' Adds a merged image of several channels as a new, virtual channel. It can
#' be placed in the layout like any other channel, e.g. a row
#' `GFP | Cy3 | merge` with `layout_grid(x = channel)`.
#'
#' Merges are always drawn on a black background: each member channel is
#' shown with its own colour and display range, and the colours are added up
#' like light. Member channels don't need their own panels.
#'
#' A channel coloured black (`"#000000"`) is shown inverted in its own panels,
#' as dark signal on white. In a merge, it uses its original colour from the
#' image metadata (the `color` column) instead, unless `colors` sets one.
#'
#' A merge combines the images that would share a panel apart from their
#' channel, typically the channels of one file. Every panel of the merge needs
#' exactly one image of each member channel.
#'
#' @param montage A [tidymontage()] object.
#' @param ... Channels to merge, as bare names or strings. Use backticks or
#'   strings for names with spaces, e.g. `` `Alexa Fluor 488` ``.
#' @param name Name of the merged channel, as it appears in the layout and in
#'   labels.
#' @param colors Colours of member channels in this merge only, as a named
#'   vector, e.g. `c(GFP = "red")`. Members not named keep their channel colour
#'   (or, if that is black, their original colour).
#'
#' @returns The montage with the merge step added.
#' @examples
#' \dontrun{
#' montage |>
#'   add_merge(GFP, Cy3, name = "merge")
#'
#' # both channels inverted on their own; in the merge, Cy3 in its original
#' # colour and GFP in green
#' montage |>
#'   adjust_colors(Cy3 = "black", GFP = "black") |>
#'   add_merge(Cy3, GFP, colors = c(GFP = "green"))
#' }
#' @export
add_merge <- function(montage, ..., name = "merge", colors = NULL) {
  check_tidymontage(montage)
  call <- rlang::current_env()
  quos <- rlang::enquos(...)
  channels <- unique(unlist(lapply(quos, function(q) {
    expr <- rlang::quo_get_expr(q)
    if (rlang::is_symbol(expr)) {
      rlang::as_string(expr)
    } else if (is.character(expr)) {
      expr
    } else {
      cli::cli_abort("Channels in {.arg ...} must be names or strings, not {.code {rlang::expr_deparse(expr)}}.", call = call)
    }
  })))
  if (length(channels) < 2) {
    cli::cli_abort("A merge needs at least two channels.")
  }
  available <- unique(as.character(montage$images$channel))
  unknown <- setdiff(channels, available)
  if (length(unknown) > 0) {
    cli::cli_abort(c("Unknown channel{?s}: {.val {unknown}}.", "i" = "Available channels: {.val {available}}."))
  }
  if (!rlang::is_string(name) || !nzchar(name)) {
    cli::cli_abort("{.arg name} must be a single non-empty string.")
  }
  existing <- unlist(lapply(montage$steps, function(s) if (s$type == "add_merge") s$params$name))
  if (name %in% c(available, existing)) {
    cli::cli_abort("{.arg name} {.val {name}} is already used by a channel or another merge.")
  }
  if (!is.null(colors)) {
    colors <- as.list(colors)
    if (!rlang::is_named(colors)) {
      cli::cli_abort("{.arg colors} must be named by channel, e.g. {.code c(GFP = \"red\")}.")
    }
    not_members <- setdiff(names(colors), channels)
    if (length(not_members) > 0) {
      cli::cli_abort("{.arg colors} names {.val {not_members}}, which {?is/are} not in the merge.")
    }
    for (nm in names(colors)) {
      col <- colors[[nm]]
      ok <- rlang::is_string(col) && !inherits(try(grDevices::col2rgb(col), silent = TRUE), "try-error")
      if (!ok) {
        cli::cli_abort("The colour for {.val {nm}} in {.arg colors} must be a single valid colour.")
      }
    }
    colors <- lapply(colors, as.character)
  }
  add_step(montage, new_step("add_merge", list(
    channels = channels, name = name, colors = colors
  )))
}

#' @export
format.tidymontage_step_add_merge <- function(x, ...) {
  ch <- vapply(x$params$channels, function(c) {
    if (make.names(c) == c) c else paste0("`", c, "`")
  }, character(1))
  p <- x$params
  args <- c(ch, paste0("name = \"", p$name, "\""))
  if (length(p$colors) > 0) {
    cols <- vapply(names(p$colors), function(nm) {
      paste0(if (make.names(nm) == nm) nm else paste0("`", nm, "`"), " = \"", p$colors[[nm]], "\"")
    }, character(1))
    args <- c(args, paste0("colors = c(", paste(cols, collapse = ", "), ")"))
  }
  paste0("add_merge(", paste(args, collapse = ", "), ")")
}
