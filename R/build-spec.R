# Steps -> specification, and the views of a montage.

default_exposure <- function() {
  list(
    min = list(type = "percentile", value = 0.1),
    max = list(type = "percentile", value = 99.9),
    by = "channel",
    overrides = list()
  )
}

# Collapse the setup and the steps into one specification. Later steps of the
# same kind override earlier ones; colours accumulate.
montage_spec <- function(montage) {
  setup <- montage$setup %||% default_setup()
  spec <- list(
    mapping = list(x = setup$x, y = setup$y, levels = setup$levels),
    layout = setup$layout, gap = setup$gap, size = setup$size,
    colors = list(), exposure = default_exposure(), merges = list(), merge_style = list(),
    overlays = list(),
    crop = NULL, zooms = list(), scale_bar = NULL, legend = NULL,
    headers = list(x = TRUE, y = TRUE, size = 7, color = "black")
  )
  for (step in montage$steps) {
    p <- step$params
    if (step$type == "adjust_colors") {
      spec$colors[names(p)] <- p
    } else if (step$type == "adjust_exposure") {
      spec$exposure <- p
    } else if (step$type == "adjust_layout") {
      for (nm in intersect(names(p), c("x", "y", "levels"))) spec$mapping[[nm]] <- p[[nm]]
      if (!is.null(p$layout)) spec$layout <- p$layout
      if (!is.null(p$gap)) spec$gap <- p$gap
    } else if (step$type == "add_merge") {
      spec$merges[[p$name]] <- p$channels
      spec$merge_style[[p$name]] <- list(colors = p$colors)
    } else if (step$type == "add_overlay") {
      # overlays are expanded like merges, but rendered differently
      spec$merges[[p$name]] <- p$channels
      spec$overlays[[p$name]] <- list(color = p$color, threshold = p$threshold)
    } else if (step$type == "add_crop") {
      spec$crop <- p
    } else if (step$type == "add_zoom") {
      spec$zooms[[p$name]] <- p
    } else if (step$type == "add_scale_bar") {
      spec$scale_bar <- p
    } else if (step$type == "add_color_legend") {
      spec$legend <- p
    } else if (step$type == "adjust_headers") {
      spec$headers <- p
    } else if (step$type == "adjust_size") {
      spec$size <- p
    }
  }
  check_xy(spec$mapping$x, spec$mapping$y, call = NULL)
  spec
}

# Views: the main view (full image or crop) first, then the zooms.
montage_views <- function(spec) {
  main <- spec$crop %||% list(name = "full", width = NULL)
  main$main <- TRUE
  zooms <- lapply(spec$zooms, function(z) {
    z$main <- FALSE
    z
  })
  views <- c(list(main), unname(zooms))
  names(views) <- vapply(views, `[[`, character(1), "name")
  views
}
