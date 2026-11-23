#' Add a merge of channels
#'
#' Adds a merged image of several channels as a new, virtual channel. It can
#' be placed in the layout like any other channel, e.g. a row
#' `GFP | Cy3 | merge` with `layout_grid(x = channel)`.
#'
#' A merge blends the coloured channels additively: each member channel is
#' shown with its own colour and display range, then the colours are added up.
#' Member channels don't need their own panels.
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
#'
#' @returns The montage with the merge step added.
#' @examples
#' \dontrun{
#' montage |>
#'   add_merge(GFP, Cy3, name = "merge") |>
#'   layout_grid(x = channel, y = condition)
#' }
#' @export
add_merge <- function(montage, ..., name = "merge") {
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
  add_step(montage, new_step("add_merge", list(channels = channels, name = name)))
}

#' @export
format.tidymontage_step_add_merge <- function(x, ...) {
  ch <- vapply(x$params$channels, function(c) {
    if (make.names(c) == c) c else paste0("`", c, "`")
  }, character(1))
  paste0("add_merge(", paste(ch, collapse = ", "), ", name = \"", x$params$name, "\")")
}
