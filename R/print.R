#' @export
format.tidymontage <- function(x, ...) {
  images <- x$images
  n_files <- length(unique(images$filepath))
  n_channels <- length(unique(images$channel))
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
    format_setup(x$setup %||% default_setup()),
    "steps:",
    steps
  )
}

plural <- function(n, word) {
  if (n == 1) word else paste0(word, "s")
}

format_setup <- function(setup) {
  args <- format_setup_args(setup)
  g <- setup$size$given
  if (!(identical(g$width, 90) && identical(g$height, 90) && g$units == "mm")) {
    args <- c(args, paste0("width = ", format(g$width)), paste0("height = ", format(g$height)))
    if (g$units != "mm") args <- c(args, paste0("units = \"", g$units, "\""))
  }
  paste0("tidymontage(", paste(c("images", args), collapse = ", "), ")")
}
