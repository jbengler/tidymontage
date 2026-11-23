# Lazy greyscale image column ("img") for a long image tibble.
#
# Each element is a recipe: a node (a source plane in a file, or a reduction
# of several nodes) plus an optional display range. Nothing is read until the
# viewer materialises a node. Display ranges are shared environments, so a
# range computed for a group (mutate(.by = channel)) is computed once and
# shared by all members.

new_img <- function(x = list()) vctrs::new_vctr(x, class = "tm_img")

img_source <- function(file, page, sample, palette, bits) {
  list(
    node = list(type = "source", file = file, page = page, sample = sample, palette = palette, bits = bits),
    range = NULL
  )
}

node_label <- function(node) {
  if (node$type == "source") sprintf("plane p%d", node$page)
  else sprintf("%s of %d", node$fun, length(node$inputs))
}

#' @export
format.tm_img <- function(x, ...) {
  vapply(vctrs::vec_data(x), function(r) {
    s <- node_label(r$node)
    if (!is.null(r$range)) s <- paste0(s, " [", r$range$label, "]")
    s
  }, character(1))
}

vec_ptype_abbr.tm_img <- function(x, ...) "img"
registerS3method("vec_ptype_abbr", "tm_img", vec_ptype_abbr.tm_img, envir = asNamespace("vctrs"))
registerS3method("format", "tm_img", format.tm_img)

reduce_img <- function(x, fun) {
  recs <- vctrs::vec_data(x)
  if (any(vapply(recs, function(r) !is.null(r$range), logical(1)))) {
    warning("Display ranges are dropped when images are combined; set them after projecting.", call. = FALSE)
  }
  new_img(list(list(
    node = list(type = "reduce", fun = fun, inputs = lapply(recs, `[[`, "node")),
    range = NULL
  )))
}

Summary.tm_img <- function(..., na.rm = FALSE) {
  if (!.Generic %in% c("max", "min")) stop("`", .Generic, "()` is not supported for images.", call. = FALSE)
  reduce_img(vctrs::vec_c(...), .Generic)
}
registerS3method("Summary", "tm_img", Summary.tm_img)

mean.tm_img <- function(x, ...) reduce_img(x, "mean")
registerS3method("mean", "tm_img", mean.tm_img)

# Display range shared by all images in `img` (one call per group with .by).
exposure <- function(img, min = "p0.1", max = "p99.9") {
  recs <- vctrs::vec_data(img)
  env <- new.env(parent = emptyenv())
  env$nodes <- lapply(recs, `[[`, "node")
  env$min <- min
  env$max <- max
  env$label <- paste(min, max, sep = "-")
  env$value <- NULL
  new_img(lapply(recs, function(r) {
    r$range <- env
    r
  }))
}

# --- materialisation ---------------------------------------------------------

node_key <- function(node) {
  if (node$type == "source") paste(node$file, node$page, node$sample, sep = "#")
  else paste0(node$fun, "(", paste(vapply(node$inputs, node_key, ""), collapse = ","), ")")
}

# Pixels of a node as an integer/double matrix. Reductions stream their
# inputs one plane at a time and only the result is cached.
materialize <- function(node, cache, store = TRUE) {
  key <- node_key(node)
  if (!is.null(cache[[key]])) return(cache[[key]])
  val <- if (node$type == "source") {
    read_tiff_pages(node$file, node$page, palette = node$palette, sample = node$sample, bits = node$bits)[[1]]
  } else {
    acc <- NULL
    for (inp in node$inputs) {
      m <- materialize(inp, cache, store = FALSE)
      acc <- if (is.null(acc)) {
        if (node$fun == "mean") as.double(m) else m
      } else switch(node$fun, max = pmax(acc, m), min = pmin(acc, m), mean = acc + m)
    }
    if (node$fun == "mean") acc <- acc / length(node$inputs)
    acc
  }
  if (store) cache[[key]] <- val
  val
}

range_value <- function(env, cache) {
  if (is.null(env$value)) {
    px <- unlist(lapply(env$nodes, function(n) {
      m <- materialize(n, cache)
      m[seq(1, length(m), by = 7)]
    }))
    q <- function(spec) {
      if (is.character(spec)) stats::quantile(px, as.numeric(sub("^p", "", spec)) / 100, names = FALSE) else spec
    }
    env$value <- c(q(env$min), q(env$max))
  }
  env$value
}

# --- long tibble from the current read_images() output -----------------------

as_long <- function(images) {
  rows <- lapply(seq_len(nrow(images)), function(i) {
    im <- images[i, ]
    p <- im$planes[[1]]
    meta <- im[rep(1, nrow(p)), setdiff(names(im), "planes")]
    meta$z <- p$z
    meta$t <- p$t
    meta$img <- new_img(lapply(seq_len(nrow(p)), function(k) {
      img_source(im$filepath, p$page[k], p$sample[k], p$palette[k], im$bit_depth)
    }))
    meta
  })
  vctrs::vec_rbind(!!!rows)
}
