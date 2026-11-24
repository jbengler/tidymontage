# Building a montage: steps -> spec (build-spec.R) -> panel space
# (build-panels.R) -> regions (build-regions.R) -> geometry
# (build-geometry.R) -> styles, display ranges (build-colors.R) ->
# rasters (build-rasters.R). Pixels are only read in montage_build().

# Build everything needed to draw the montage.
montage_build <- function(montage, dpi = 150, call = rlang::caller_env()) {
  spec <- montage_spec(montage)
  images <- montage$images
  views <- montage_views(spec)
  space <- montage_layout_space(montage, spec, views, call)
  panels <- space$panels

  # Every image that is shown on its own or as part of a merge. Display ranges
  # are computed over all of them (full images), so merges and crops use the
  # linked ranges too.
  used <- unique(unlist(panels$.sources))
  sources <- tibble::tibble(.image = used, channel = as.character(images$channel[used]), view = "full")
  pixels <- img_pixels(images$img[used])
  ranges <- montage_ranges(sources, images, pixels, spec$exposure, call = call)
  sources$display_min <- ranges$lo
  sources$display_max <- ranges$hi

  rasters <- lapply(seq_len(nrow(panels)), function(i) {
    target_px <- (panels$xmax[i] - panels$xmin[i]) / 25.4 * dpi
    src <- panels$.sources[[i]]
    values <- lapply(src, function(s) {
      k <- match(s, used)
      m <- pixels[[k]][panels$.y0[i]:panels$.y1[i], panels$.x0[i]:panels$.x1[i], drop = FALSE]
      f <- max(1L, floor(ncol(m) / target_px))
      scale_intensity(bin_mean(m, f), sources$display_min[k], sources$display_max[k])
    })
    if (panels$.is_overlay[i]) {
      # overlays: as bright as the weakest member, on the members' 0-1 scale
      v <- Reduce(pmin, values)
      threshold <- spec$overlays[[panels$channel[i]]]$threshold
      if (!is.null(threshold)) v[v < threshold] <- 0
      values <- list(v)
    }
    lt <- panels$.lut[[i]]
    if (!is.null(lt)) {
      return(pack_raster(lut_rgb(values[[1]], lut_table(lt))))
    }
    pack_raster(compose_panel(values, panels$.colors[[i]], panels$.background[i]))
  })

  legend <- if (!is.null(space$legend)) legend_ranges(space$legend, sources, call = call)

  single <- !panels$.is_merge
  at <- match(panels$.image, used)
  panels$display_min <- ifelse(single, sources$display_min[at], NA_real_)
  panels$display_max <- ifelse(single, sources$display_max[at], NA_real_)
  panels$color <- ifelse(single, vapply(panels$.colors, `[`, character(1), 1), NA_character_)

  list(
    panels = panels, labels = space$labels, lines = space$lines, boxes = space$boxes,
    scale_bars = space$scale_bars, headers = space$headers, legend = legend, preview = space$preview,
    side_labels = space$side_labels,
    width = space$width, height = space$height, rasters = rasters
  )
}

# Panel space, regions, geometry and boxes: everything but pixels.
montage_layout_space <- function(montage, spec = montage_spec(montage), views = montage_views(spec),
                                 call = rlang::caller_env()) {
  images <- montage$images
  space <- montage_panel_space(images, spec, views, call = call)
  space <- montage_regions(space, images, views, call = call)
  legend <- spec$legend
  space$panels <- panel_styles(space$panels, images, spec, call = call)
  items <- if (!is.null(legend)) legend_items(space$panels, images, spec$colors)
  geom <- montage_geometry(space, spec$size, spec$gap, spec$headers, call = call)
  if (!is.null(legend)) {
    # the panels' width limits the rows of a legend on top or at the bottom
    p <- geom$panels
    extra <- legend_extent(items, legend, max(p$xmax) - min(p$xmin))
    # a legend wider than the panels (one long entry) widens the figure evenly
    if (legend$position != "right" && nrow(items) > 0) {
      overflow <- legend_dims(items, legend, max(p$xmax) - min(p$xmin))$width - (max(p$xmax) - min(p$xmin))
      if (overflow > 0) {
        extra$left <- overflow / 2
        extra$right <- extra$right + overflow / 2
      }
    }
    geom <- montage_geometry(space, spec$size, spec$gap, spec$headers, extra, call = call)
  } else {
    extra <- legend_extent(NULL, NULL)
  }
  if (!is.null(spec$preview_positions)) {
    # room for the axis labels below and to the right of the panels
    extra$bottom <- extra$bottom + 3.5
    extra$right <- extra$right + 5
    extra$left <- (extra$left %||% 0) + 1.5
    geom <- montage_geometry(space, spec$size, spec$gap, spec$headers, extra, call = call)
  }
  legend_df <- if (!is.null(legend) && nrow(items) > 0) {
    p <- geom$panels
    # the legend goes beyond everything else, e.g. side labels below or beside panels
    legend_layout(items, legend, list(
      xmin = min(p$xmin), xmax = max(p$xmax), ymin = min(p$ymin), ymax = max(p$ymax),
      top = extra$top, bottom = extra$bottom,
      right_edge = geom$width - extra$right, bottom_edge = geom$height - extra$bottom
    ))
  }
  panels <- geom$panels
  if (".outline" %in% names(space$data)) {
    panels$.outline <- space$data$.outline[panels$.row] %in% TRUE
  }
  overlay <- if (!is.null(spec$preview_positions)) {
    preview_positions_overlay(panels, space$data, images, spec$preview_positions, call)
  }
  list(
    legend = legend_df,
    panels = panels,
    preview = overlay,
    data = space$data,
    labels = geom$labels,
    lines = geom$lines,
    side_labels = geom$side_labels,
    boxes = montage_boxes(space, geom$panels, images, views, call = call),
    scale_bars = montage_scale_bars(geom$panels, images, spec$scale_bar, call = call),
    headers = spec$headers,
    width = geom$width,
    height = geom$height
  )
}
