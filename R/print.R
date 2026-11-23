#' @export
format.tidymontage <- function(x, ...) {
  images <- x$images
  n_files <- length(unique(images$filepath))
  n_channels <- length(unique(images$channel))

  mapping <- vapply(
    x$mapping,
    function(quo) if (rlang::quo_is_null(quo)) "<none>" else rlang::as_label(quo),
    character(1)
  )

  steps <- if (length(x$steps) == 0) {
    "  (none)"
  } else {
    paste0("  ", seq_along(x$steps), ". ", vapply(x$steps, format, character(1)))
  }

  c(
    paste0(
      "<tidymontage> ", nrow(images), " ", plural(nrow(images), "image"), " from ",
      n_files, " ", plural(n_files, "file"), ", ",
      n_channels, " ", plural(n_channels, "channel")
    ),
    paste0("x: ", mapping[["x"]], "  y: ", mapping[["y"]]),
    paste0("layout: ", if (is.null(x$layout)) "<default>" else class(x$layout)[1]),
    "steps:",
    steps
  )
}

#' @export
print.tidymontage <- function(x, ...) {
  # Rendering is not implemented yet: print a summary of the recipe instead.
  cat(format(x, ...), sep = "\n")
  invisible(x)
}

plural <- function(n, word) {
  if (n == 1) word else paste0(word, "s")
}
