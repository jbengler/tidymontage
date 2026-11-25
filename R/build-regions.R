# Crop and zoom regions in source pixels, and the boxes marking zooms.

# Regions ----------------------------------------------------------------------------

# The region of the source image shown in each panel, in 1-based pixels
# (x0, x1, y0, y1), and the panel aspect ratio. No pixels are read.
# Rotated regions also have their exact center (.cx, .cy, in 0-based pixel
# coordinates) and angle; their x0 ... y1 describe the region before rotation
# about its center, which gives its size in pixels.
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
  panels$.cx <- vapply(regions, attr, numeric(1), "cx")
  panels$.cy <- vapply(regions, attr, numeric(1), "cy")
  panels$.angle <- vapply(regions, attr, numeric(1), "angle")
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
    return(upright_region(1, sx, 1, sy))
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
  center <- lookup_center(view, row, call)
  angle <- view_angle(view, row, call)
  # relative 0-1 or 0-based pixel coordinates of the full image
  cx <- if (view$center_units == "rel") center[1] * sx else center[1]
  cy <- if (view$center_units == "rel") center[2] * sy else center[2]
  if (angle != 0) {
    # rotated regions are not moved inside the image: all corners must fit
    x0 <- round(cx - w / 2) + 1
    y0 <- round(cy - h / 2) + 1
    r <- c(x0, x0 + w - 1, y0, y0 + h - 1)
    attr(r, "cx") <- cx
    attr(r, "cy") <- cy
    attr(r, "angle") <- angle
    k <- region_corners(r)
    if (any(k$x < 0 | k$x > sx | k$y < 0 | k$y > sy)) {
      cli::cli_abort(
        c(
          "The view {.val {view$name}}, rotated by {angle} degrees, reaches beyond the image of {panel_where(row)}.",
          "i" = "Move its center or make it smaller."
        ),
        call = call
      )
    }
    return(r)
  }
  if (w > sx || h > sy) {
    cli::cli_abort(
      "The view {.val {view$name}} ({w} x {h} px) is larger than the image ({sx} x {sy} px) of {panel_where(row)}.",
      call = call
    )
  }
  x0 <- round(cx - w / 2) + 1
  y0 <- round(cy - h / 2) + 1
  x0n <- min(max(x0, 1), sx - w + 1)
  y0n <- min(max(y0, 1), sy - h + 1)
  upright_region(x0n, x0n + w - 1, y0n, y0n + h - 1, shifted = x0n != x0 || y0n != y0)
}

upright_region <- function(x0, x1, y0, y1, shifted = FALSE) {
  r <- c(x0, x1, y0, y1)
  attr(r, "cx") <- (x0 - 1 + x1) / 2
  attr(r, "cy") <- (y0 - 1 + y1) / 2
  attr(r, "angle") <- 0
  attr(r, "shifted") <- shifted
  r
}

# The angle of a view for an image: its `angle` argument, else the angle
# column of its centers, else that of the view it lies in (zooms inherit the
# crop's angle), else 0. Degrees, counterclockwise as in ImageJ / Fiji.
view_angle <- function(view, row, call) {
  if (!is.null(view$angle)) {
    a <- view$angle
  } else if (is.data.frame(view$center) && "angle" %in% names(view$center)) {
    a <- attr(lookup_center(view, row, call), "angle")
    if (is.na(a)) a <- 0
  } else if (!is.null(view$parent)) {
    a <- view_angle(view$parent, row, call)
  } else {
    a <- 0
  }
  a %% 360
}

# Corners of a region in 0-based image coordinates: top-left, top-right,
# bottom-right, bottom-left in the region's own frame.
region_corners <- function(r) {
  w <- r[2] - r[1] + 1
  h <- r[4] - r[3] + 1
  u <- c(-1, 1, 1, -1) * w / 2
  v <- c(-1, -1, 1, 1) * h / 2
  image_point(attr(r, "cx"), attr(r, "cy"), attr(r, "angle"), u, v)
}

# A point (u, v) in the frame of a region (x along the region, y down,
# centered) to image coordinates. The region's x axis points along `angle`
# counterclockwise; image y points down.
image_point <- function(cx, cy, angle, u, v) {
  a <- angle * pi / 180
  list(x = cx + u * cos(a) + v * sin(a), y = cy - u * sin(a) + v * cos(a))
}

# Image coordinates (0-based pixels, as in ImageJ) to mm on panel i.
panel_point <- function(panels, i, px, py) {
  a <- panels$.angle[i] * pi / 180
  dx <- px - panels$.cx[i]
  dy <- py - panels$.cy[i]
  u <- dx * cos(a) - dy * sin(a)
  v <- dx * sin(a) + dy * cos(a)
  w <- panels$.x1[i] - panels$.x0[i] + 1
  h <- panels$.y1[i] - panels$.y0[i] + 1
  list(
    x = (panels$xmin[i] + panels$xmax[i]) / 2 + u * (panels$xmax[i] - panels$xmin[i]) / w,
    y = (panels$ymin[i] + panels$ymax[i]) / 2 + v * (panels$ymax[i] - panels$ymin[i]) / h
  )
}

lookup_center <- function(view, row, call) {
  center <- view$center
  if (is.numeric(center)) {
    return(center)
  }
  keys <- setdiff(intersect(names(center), names(row)), c("x", "y", "angle"))
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
  angle <- if ("angle" %in% names(center)) center$angle[hit] else NA_real_
  structure(c(center$x[hit], center$y[hit]), angle = angle)
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
      k <- region_corners(zr)
      k <- panel_point(panels, i, k$x, k$y)
      tol <- 1e-6
      if (any(k$x < panels$xmin[i] - tol | k$x > panels$xmax[i] + tol |
        k$y < panels$ymin[i] - tol | k$y > panels$ymax[i] + tol)) {
        outside <- c(outside, panel_where(row))
        next
      }
      # corners 1-4 (top-left first, in the zoom's own frame) and the extent
      b <- c(
        x1 = k$x[1], x2 = k$x[2], x3 = k$x[3], x4 = k$x[4],
        y1 = k$y[1], y2 = k$y[2], y3 = k$y[3], y4 = k$y[4],
        xmin = min(k$x), xmax = max(k$x), ymin = min(k$y), ymax = max(k$y)
      )
      b <- as.data.frame(as.list(b))
      # boxes contrast with the panel: black on light panels
      b$color <- ink_on(panels$.background[i])
      b$label <- z$label %||% NA_character_
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

# Labels of numbered zooms in the top-left corner of their panels, in mm.
montage_zoom_labels <- function(panels, views) {
  labels <- vapply(views, function(v) v$label %||% NA_character_, character(1))
  labels <- labels[!is.na(labels)]
  on <- which(panels$view %in% names(labels))
  if (length(on) == 0) {
    return(NULL)
  }
  data.frame(
    x = panels$xmin[on],
    y = panels$ymin[on],
    label = unname(labels[panels$view[on]])
  )
}

# Zoom labels: white text, in the size of scale bar labels, on a black
# square in the top-left corner of the box or panel (side in mm).
zoom_label_style <- list(size = 7, color = "white", fill = "black", side = 3)
