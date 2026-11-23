# Lazy greyscale image vectors -------------------------------------------------
#
# An `img` vector is the image column of the long image tibble. Each element is
# a recipe: a node describing where the pixels come from, either one plane
# (`source`) of a file or a reduction (`max`, `min`, `mean`) of other nodes.
# No pixels are read until the montage is rendered. Each node carries the
# image geometry, so it survives `summarise()`.

new_img <- function(x = list()) {
  vctrs::new_vctr(x, class = "tidymontage_img")
}

img_source <- function(file, page, sample = NA_integer_, palette = FALSE, bits = 16L,
                       size_x = NA_integer_, size_y = NA_integer_, pixel_size = NA_real_) {
  list(
    node = list(
      type = "source", file = file, page = as.integer(page), sample = as.integer(sample),
      palette = palette, bits = as.integer(bits), size_x = as.integer(size_x),
      size_y = as.integer(size_y), pixel_size = pixel_size
    )
  )
}

#' Test if an object is an image vector
#'
#' Image vectors are the `img` column of [read_images()]. Each element is a
#' lazy reference to a greyscale image: a plane in a file, or a projection of
#' several planes. Pixels are only read when a montage is rendered.
#'
#' @param x An object.
#' @returns `TRUE` if `x` is an image vector, otherwise `FALSE`.
#' @export
is_img <- function(x) {
  inherits(x, "tidymontage_img")
}

#' Project images
#'
#' Use `max()`, `min()` and `mean()` on an image vector to combine several
#' images into one, typically a z-projection inside `summarise()`. The result
#' is lazy: pixels are read and combined plane by plane when the montage is
#' rendered.
#'
#' @param x,... Image vectors.
#' @param na.rm Ignored.
#' @returns An image vector of length 1.
#' @examples
#' \dontrun{
#' read_images("stack.ome.tif") |>
#'   dplyr::summarise(img = max(img), .by = c(filepath, channel))
#' }
#' @name img-projection
NULL

#' @rdname img-projection
#' @export
Summary.tidymontage_img <- function(..., na.rm = FALSE) {
  generic <- .Generic
  if (!generic %in% c("max", "min")) {
    cli::cli_abort(
      c(
        "{.fn {generic}} is not supported for images.",
        "i" = "Use {.fn max}, {.fn min} or {.fn mean} to project images."
      ),
      call = NULL
    )
  }
  img_reduce(vctrs::vec_c(...), generic)
}

#' @rdname img-projection
#' @export
mean.tidymontage_img <- function(x, ...) {
  img_reduce(x, "mean")
}

img_reduce <- function(x, fun) {
  recs <- vctrs::vec_data(x)
  if (length(recs) == 0) {
    cli::cli_abort("Can't compute {.fn {fun}} of zero images.", call = NULL)
  }
  nodes <- lapply(recs, `[[`, "node")
  size_x <- unique(vapply(nodes, `[[`, integer(1), "size_x"))
  size_y <- unique(vapply(nodes, `[[`, integer(1), "size_y"))
  if (length(size_x) > 1 || length(size_y) > 1) {
    cli::cli_abort(
      "Can't compute {.fn {fun}} of images with different sizes.",
      call = NULL
    )
  }
  pixel_size <- unique(vapply(nodes, `[[`, numeric(1), "pixel_size"))
  if (length(pixel_size) > 1) {
    cli::cli_abort(
      "Can't compute {.fn {fun}} of images with different pixel sizes.",
      call = NULL
    )
  }
  new_img(list(list(
    node = list(
      type = "reduce", fun = fun, inputs = nodes,
      size_x = size_x, size_y = size_y, pixel_size = pixel_size
    )
  )))
}

# Printing ---------------------------------------------------------------------

#' @export
format.tidymontage_img <- function(x, ...) {
  vapply(vctrs::vec_data(x), function(r) node_label(r$node), character(1))
}

node_label <- function(node) {
  if (identical(node$type, "source")) {
    paste("page", node$page)
  } else {
    paste(node$fun, "of", node_n_sources(node))
  }
}

node_n_sources <- function(node) {
  if (identical(node$type, "source")) 1L else sum(vapply(node$inputs, node_n_sources, integer(1)))
}

#' @exportS3Method vctrs::vec_ptype_abbr
vec_ptype_abbr.tidymontage_img <- function(x, ...) "img"

#' @exportS3Method vctrs::vec_ptype_full
vec_ptype_full.tidymontage_img <- function(x, ...) "img"

# Images have no natural order.
#' @exportS3Method vctrs::vec_proxy_order
vec_proxy_order.tidymontage_img <- function(x, ...) {
  cli::cli_abort("Images can't be sorted.", call = NULL)
}

# Reading pixels -----------------------------------------------------------------

# Pixels of every element of an image vector, as a list of matrices
# (rows = image y, columns = image x).
img_pixels <- function(x) {
  cache <- new.env(parent = emptyenv())
  lapply(vctrs::vec_data(x), function(r) materialize_node(r$node, cache))
}

node_key <- function(node) {
  if (identical(node$type, "source")) {
    paste(node$file, node$page, node$sample, sep = "#")
  } else {
    paste0(node$fun, "(", paste(vapply(node$inputs, node_key, character(1)), collapse = ","), ")")
  }
}

# Reductions stream their inputs one plane at a time; only results that are
# requested directly are cached.
materialize_node <- function(node, cache, store = TRUE) {
  key <- node_key(node)
  if (!is.null(cache[[key]])) {
    return(cache[[key]])
  }
  value <- if (identical(node$type, "source")) {
    read_tiff_pages(node$file, node$page, palette = node$palette, sample = node$sample, bits = node$bits)[[1]]
  } else {
    acc <- NULL
    for (input in node$inputs) {
      m <- materialize_node(input, cache, store = FALSE)
      acc <- if (is.null(acc)) {
        if (node$fun == "mean") as.double(m) else m
      } else {
        switch(node$fun, max = pmax(acc, m), min = pmin(acc, m), mean = acc + m)
      }
    }
    if (node$fun == "mean") acc / length(node$inputs) else acc
  }
  if (store) {
    cache[[key]] <- value
  }
  value
}
