# Crop and zoom regions in source pixels, and the boxes marking zooms.

# Regions ----------------------------------------------------------------------------

# The region of the source image shown in each panel, in 1-based pixels
# (x0, x1, y0, y1), and the panel aspect ratio. No pixels are read.
montage_regions <- function(space, images, views, call = rlang::caller_env()) {
  panels <- space$panels
  first_source <- vapply(panels$.sources, `[`, integer(1), 1)
  nodes <- lapply(vctrs::vec_data(images$img[first_source]), `[[`, "node")
  shifted <- character()
  regions <- lapply(seq_len(nrow(panels)), function(i) {
    view <- views[[panels$view[i]]]
    row <- space$data[panels$.row[i], , drop = FALSE]
    r <- view_region(view, row, nodes[[i]], call)
    if (isTRUE(attr(r, "shifted"))) shifted <<- c(shifted, panel_where(row))
    r
  })
  if (length(shifted) > 0) {
    cli::cli_warn(
      c(
        "Some regions reach beyond the image and were moved inside it.",
        "i" = "Affected: {unique(shifted)}."
      ),
      call = call
    )
  }
  m <- do.call(rbind, regions)
  panels$.x0 <- m[, 1]
  panels$.x1 <- m[, 2]
  panels$.y0 <- m[, 3]
  panels$.y1 <- m[, 4]
  panels$.aspect <- (m[, 4] - m[, 3] + 1) / (m[, 2] - m[, 1] + 1)
  # use the requested shape rather than rounded pixel counts
  for (v in names(views)) {
    if (!is.null(views[[v]]$width)) {
      panels$.aspect[panels$view == v] <- views[[v]]$height / views[[v]]$width
    }
  }
  space$panels <- panels
  space
}

view_region <- function(view, row, node, call) {
  sx <- node$size_x
  sy <- node$size_y
  if (is.null(view$width)) {
    return(c(1, sx, 1, sy))
  }
  if (view$units == "um") {
    if (is.na(node$pixel_size)) {
      cli::cli_abort(
        c(
          "The view {.val {view$name}} is sized in micrometres, but {panel_where(row)} has no known pixel size.",
          "i" = "Use {.code units = \"px\"}, or set a pixel size."
        ),
        call = call
      )
    }
    w <- round(view$width / node$pixel_size)
    h <- round(view$height / node$pixel_size)
  } else {
    w <- round(view$width)
    h <- round(view$height)
  }
  if (w > sx || h > sy) {
    cli::cli_abort(
      "The view {.val {view$name}} ({w} x {h} px) is larger than the image ({sx} x {sy} px) of {panel_where(row)}.",
      call = call
    )
  }
  center <- lookup_center(view, row, call)
  # relative 0-1 or 0-based pixel coordinates of the full image
  cx <- if (view$center_units == "rel") center[1] * sx else center[1]
  cy <- if (view$center_units == "rel") center[2] * sy else center[2]
  x0 <- round(cx - w / 2) + 1
  y0 <- round(cy - h / 2) + 1
  x0n <- min(max(x0, 1), sx - w + 1)
  y0n <- min(max(y0, 1), sy - h + 1)
  r <- c(x0n, x0n + w - 1, y0n, y0n + h - 1)
  attr(r, "shifted") <- x0n != x0 || y0n != y0
  r
}

lookup_center <- function(view, row, call) {
  center <- view$center
  if (is.numeric(center)) {
    return(center)
  }
  keys <- setdiff(intersect(names(center), names(row)), c("x", "y"))
  hit <- rep(TRUE, nrow(center))
  for (k in keys) {
    hit <- hit & as.character(center[[k]]) == as.character(row[[k]])
  }
  hit[is.na(hit)] <- FALSE
  if (sum(hit) != 1) {
    what <- paste0(keys, " = ", vapply(keys, function(k) as.character(row[[k]]), ""), collapse = ", ")
    problem <- if (sum(hit) == 0) "No" else "More than one"
    cli::cli_abort(
      "{problem} center for the view {.val {view$name}} matches {what}.",
      call = call
    )
  }
  c(center$x[hit], center$y[hit])
}

panel_where <- function(row) {
  cols <- intersect(c("filepath", "channel"), names(row))
  paste0(cols, " = ", vapply(cols, function(k) as.character(row[[k]]), ""), collapse = ", ")
}

# Boxes marking zoom regions on the main panels, in mm.
montage_boxes <- function(space, panels, images, views, call = rlang::caller_env()) {
  zooms <- Filter(function(v) !isTRUE(v$main), views)
  main <- views[[1]]$name
  boxes <- list()
  outside <- character()
  for (z in zooms) {
    if (identical(z$box, "none")) next
    on <- panels$view == main & (z$box == "all" | (panels$.is_merge & !panels$.is_overlay))
    for (i in which(on)) {
      row <- space$data[panels$.row[i], , drop = FALSE]
      node <- vctrs::vec_data(images$img[panels$.sources[[i]][1]])[[1]]$node
      zr <- view_region(z, row, node, call)
      sx <- (panels$xmax[i] - panels$xmin[i]) / (panels$.x1[i] - panels$.x0[i] + 1)
      sy <- (panels$ymax[i] - panels$ymin[i]) / (panels$.y1[i] - panels$.y0[i] + 1)
      b <- c(
        xmin = panels$xmin[i] + (zr[1] - panels$.x0[i]) * sx,
        xmax = panels$xmin[i] + (zr[2] - panels$.x0[i] + 1) * sx,
        ymin = panels$ymin[i] + (zr[3] - panels$.y0[i]) * sy,
        ymax = panels$ymin[i] + (zr[4] - panels$.y0[i] + 1) * sy
      )
      if (b["xmin"] < panels$xmin[i] - 1e-9 || b["xmax"] > panels$xmax[i] + 1e-9 ||
        b["ymin"] < panels$ymin[i] - 1e-9 || b["ymax"] > panels$ymax[i] + 1e-9) {
        outside <- c(outside, panel_where(row))
        next
      }
      b <- as.data.frame(as.list(b))
      # boxes contrast with the panel: black on white panels
      b$color <- if (identical(panels$.background[i], "white")) "black" else "white"
      boxes[[length(boxes) + 1]] <- b
    }
  }
  if (length(outside) > 0) {
    cli::cli_warn(
      "A zoom region lies outside the {.val {main}} view, so no box is drawn for {unique(outside)}.",
      call = call
    )
  }
  if (length(boxes) == 0) NULL else do.call(rbind, boxes)
}
