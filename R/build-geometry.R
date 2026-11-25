# Geometry -------------------------------------------------------------------------

# Height of one header strip in mm, for text of `size` points.
strip_mm <- function(size) size * 0.3528 * 1.9

# Panel rectangles in mm, measured from the top-left corner (y points down),
# plus nested header strips. The panels and gaps fit into the box
# `size$width` x `size$height`; headers are added outside of it.
#
# Both layouts are a grid of cells: a cell is one panel (grid) or one block of
# hero plus side panels (hero). The size of a cell is linear in a free size
# `s` (a panel width, or the side panel width): w = cw * s + dw,
# h = ch * s + dh. The largest `s` that fits the box is used. In the grid,
# each column has its own width and each row its own height (see
# grid_tracks()); cw and ch are their means.
montage_geometry <- function(space, size = default_size(), gap = 1,
                             headers = list(x = TRUE, y = TRUE, size = 7),
                             extra = list(top = 0, bottom = 0, right = 0, left = 0),
                             call = rlang::caller_env()) {
  panels <- space$panels
  if (anyNA(panels$.aspect)) {
    cli::cli_abort("Can't determine the size of all images.", call = call)
  }
  check_aspect <- function(a, what) {
    if (diff(range(a)) > 0.01 * min(a)) {
      cli::cli_abort(
        c(
          "All {what} must have the same aspect ratio.",
          "i" = "Use the same width-to-height ratio for crops and zooms, and for images of different shapes, crop them."
        ),
        call = call
      )
    }
    a[1]
  }
  if (identical(space$type, "hero")) {
    a_hero <- check_aspect(panels$.aspect[panels$.role == "hero"], "hero panels")
    a_side <- check_aspect(panels$.aspect[panels$.role == "side"], "side panels")
    shape <- hero_shape(a_hero, a_side, space$n_side, gap, space$position, isTRUE(space$stack))
    cell_gap <- 3 * gap
  } else {
    # rows have one height and columns one width, in units of the free size
    tracks <- grid_tracks(panels, call)
    shape <- list(cw = mean(tracks$w), dw = 0, ch = mean(tracks$h), dh = 0)
    cell_gap <- gap
  }

  n_col <- max(panels$col)
  n_row <- max(panels$row)
  col_grid <- if (isTRUE(headers$x)) space$col_grid
  row_grid <- if (isTRUE(headers$y)) space$row_grid
  strip <- strip_mm(headers$size %||% 7)
  # space for a legend on top, then the header strips
  top <- extra$top + if (is.null(col_grid)) 0 else ncol(col_grid) * strip
  left0 <- extra$left %||% 0
  left <- left0 + if (is.null(row_grid)) 0 else ncol(row_grid) * strip

  fit <- function(box, n, c, d) {
    if (is.na(box)) Inf else (box - (n - 1) * cell_gap - n * d) / (n * c)
  }
  s_free <- min(fit(size$width, n_col, shape$cw, shape$dw), fit(size$height, n_row, shape$ch, shape$dh))
  if (s_free <= 0) {
    cli::cli_abort(
      "The montage is too small for its panels and {gap} mm gaps: increase its size with {.fn adjust_size}.",
      call = call
    )
  }
  # labels of hero side panels: added on top of the box, like headers
  lab_w <- 0
  lab_h <- 0
  wrapped <- NULL
  lab_at <- hero_label_side(space)
  if (identical(space$type, "hero") && isTRUE(space$labels)) {
    text_size <- headers$size %||% 7
    labs <- unique(panels$.label[panels$.role == "side"])
    line_h <- text_size * 0.3528 * 1.25
    # below the panels: as wide as a panel; beside them (rotated): as long as
    # a panel is high
    room <- if (lab_at == "bottom") s_free else s_free * shape$a_side
    # labels may reach into the gaps between side panels (half a gap each side)
    wrapped <- wrap_labels(labs, room + gap, text_size, call)
    n_lines <- max(lengths(strsplit(wrapped, "\n", fixed = TRUE)))
    if (lab_at == "bottom") {
      lab_h <- 0.8 + n_lines * line_h
    } else {
      lab_w <- 0.8 + n_lines * line_h
    }
    names(wrapped) <- labs
  }
  # Stacked strips line up across blocks, so their labels are shared: once on
  # the left of the first column (strips below the hero) or below the last
  # row (strips beside it). Otherwise each block has its own labels.
  shared <- isTRUE(space$stack)
  cell_lab_w <- if (shared) 0 else lab_w
  cell_lab_h <- if (shared) 0 else lab_h
  pre_w <- if (shared) lab_w else 0
  post_h <- if (shared) lab_h else 0
  if (identical(space$type, "hero")) {
    col_w <- rep(shape$cw * s_free + shape$dw + cell_lab_w, n_col)
    row_h <- rep(shape$ch * s_free + shape$dh + cell_lab_h, n_row)
  } else {
    col_w <- tracks$w * s_free
    row_h <- tracks$h * s_free
  }
  col_start <- left + pre_w + c(0, cumsum(col_w + cell_gap))[seq_len(n_col)]
  row_start <- top + c(0, cumsum(row_h + cell_gap))[seq_len(n_row)]
  width <- left + pre_w + sum(col_w) + (n_col - 1) * cell_gap + extra$right
  height <- top + sum(row_h) + (n_row - 1) * cell_gap + post_h + extra$bottom

  ox <- col_start[panels$col]
  oy <- row_start[panels$row]
  if (identical(space$type, "hero")) {
    r <- hero_rects(shape, s_free, gap, space$n_side, space$position, panels$.role, panels$.k, isTRUE(space$stack))
    # labels on the left come first
    if (lab_at == "left" && !shared) ox <- ox + lab_w
    panels$xmin <- ox + r$x
    panels$ymin <- oy + r$y
    panels$xmax <- panels$xmin + r$w
    panels$ymax <- panels$ymin + r$h
  } else {
    panels$xmin <- ox
    panels$ymin <- oy
    panels$xmax <- ox + col_w[panels$col]
    panels$ymax <- oy + row_h[panels$row]
  }

  side_labels <- NULL
  if (!is.null(wrapped)) {
    side <- panels[panels$.role == "side", , drop = FALSE]
    if (shared) {
      side <- side[if (lab_at == "left") side$col == 1 else side$row == n_row, , drop = FALSE]
    }
    pos <- lab_at
    # beside the panels, labels are rotated like ggplot2 facet strips: reading
    # top to bottom on the right, bottom to top on the left. All labels start
    # at the same distance from their panel; extra lines grow outwards.
    side_labels <- data.frame(
      label = unname(wrapped[side$.label]),
      x = switch(
        pos,
        bottom = (side$xmin + side$xmax) / 2,
        right = side$xmax + 0.8,
        left = side$xmin - 0.8
      ),
      y = if (pos == "bottom") side$ymax + 0.8 else (side$ymin + side$ymax) / 2,
      angle = switch(pos, bottom = 0, right = -90, left = 90),
      hjust = 0.5,
      # bottom: the text hangs from the anchor; rotated: its baseline side
      # (last line) faces the panel
      vjust = if (pos == "bottom") 1 else 0
    )
  }

  # headers span the panels, not the label space
  col_from <- col_start + (if (identical(lab_at, "left") && !shared) lab_w else 0)
  row_from <- row_start
  labels <- NULL
  lines <- NULL
  if (!is.null(col_grid)) {
    st <- header_strips(col_grid, col_from, col_from + col_w - cell_lab_w)
    labels <- rbind(labels, data.frame(
      label = st$label, x = (st$from + st$to) / 2, y = extra$top + (st$level - 0.5) * strip, angle = 0
    ))
    outer <- st[st$level < ncol(col_grid), , drop = FALSE]
    lines <- rbind(lines, data.frame(
      x = outer$from + 0.5, xend = outer$to - 0.5,
      y = extra$top + outer$level * strip - 0.3, yend = extra$top + outer$level * strip - 0.3
    ))
  }
  if (!is.null(row_grid)) {
    st <- header_strips(row_grid, row_from, row_from + row_h - cell_lab_h)
    labels <- rbind(labels, data.frame(
      label = st$label, x = left0 + (st$level - 0.5) * strip, y = (st$from + st$to) / 2, angle = 90
    ))
    outer <- st[st$level < ncol(row_grid), , drop = FALSE]
    lines <- rbind(lines, data.frame(
      x = left0 + outer$level * strip - 0.3, xend = left0 + outer$level * strip - 0.3,
      y = outer$from + 0.5, yend = outer$to - 0.5
    ))
  }
  list(
    panels = panels, labels = labels, lines = lines, side_labels = side_labels,
    width = width, height = height
  )
}

# Widths of the grid's columns and heights of its rows, relative to the first
# column of each connected part of the grid, so that every panel's shape
# (height / width) is its row's height over its column's width. Panels of one
# shape give equal tracks; a square crop row over a row of flat zoom strips
# gives two row heights. Shapes that can't be split this way are an error.
grid_tracks <- function(panels, call = rlang::caller_env()) {
  n_col <- max(panels$col)
  n_row <- max(panels$row)
  w <- rep(NA_real_, n_col)
  h <- rep(NA_real_, n_row)
  a <- panels$.aspect
  repeat {
    # start a connected part at its first column without a width
    todo <- setdiff(unique(panels$col), which(!is.na(w)))
    if (length(todo) == 0) break
    w[min(todo)] <- 1
    repeat {
      changed <- FALSE
      for (i in seq_len(nrow(panels))) {
        r <- panels$row[i]
        k <- panels$col[i]
        if (!is.na(w[k]) && is.na(h[r])) {
          h[r] <- a[i] * w[k]
          changed <- TRUE
        } else if (is.na(w[k]) && !is.na(h[r])) {
          w[k] <- h[r] / a[i]
          changed <- TRUE
        }
      }
      if (!changed) break
    }
  }
  # columns or rows without panels
  w[is.na(w)] <- 1
  h[is.na(h)] <- mean(h, na.rm = TRUE)
  bad <- abs(h[panels$row] / w[panels$col] - a) > 0.01 * a
  if (any(bad)) {
    what <- intersect(c("channel", "view"), names(panels))
    where <- unique(vapply(which(bad), function(i) {
      paste0(what, " = ", vapply(what, function(k) as.character(panels[[k]][i]), ""), collapse = ", ")
    }, character(1)))
    cli::cli_abort(
      c(
        "Panels of different shapes must line up: all panels in a row need the same height, and all panels in a column the same width.",
        "x" = "The shape of {.val {where[1]}} doesn't fit its row and column.",
        "i" = "Put views of different shapes on different rows (or columns), e.g. with {.code y = view}, use the same width-to-height ratio for crops and zooms, or crop images of different shapes."
      ),
      call = call
    )
  }
  list(w = w, h = h)
}

# Wrap labels that are wider than `width` (mm) onto two lines, at the space
# that balances the lines best. Warn if a label still doesn't fit.
wrap_labels <- function(labels, width, size, call = rlang::caller_env()) {
  too_wide <- character()
  out <- vapply(labels, function(l) {
    if (text_width_mm(l, size) <= width) {
      return(l)
    }
    words <- strsplit(l, " ", fixed = TRUE)[[1]]
    if (length(words) < 2) {
      too_wide <<- c(too_wide, l)
      return(l)
    }
    splits <- vapply(seq_len(length(words) - 1), function(i) {
      paste(paste(words[seq_len(i)], collapse = " "), paste(words[-seq_len(i)], collapse = " "), sep = "\n")
    }, character(1))
    widths <- vapply(splits, function(x) max(text_width_mm(strsplit(x, "\n", fixed = TRUE)[[1]], size)), numeric(1))
    if (min(widths) > width) too_wide <<- c(too_wide, l)
    splits[which.min(widths)]
  }, character(1))
  if (length(too_wide) > 0) {
    cli::cli_warn(
      c(
        "{cli::qty(too_wide)}Label{?s} {.val {too_wide}} {?is/are} longer than the side panels.",
        "i" = "Use shorter channel names, e.g. with {.code mutate(channel = ...)}, or label with {.fn add_color_legend} instead."
      ),
      call = call
    )
  }
  unname(out)
}

# Size of a hero block as a function of the side panel width s: the hero's
# edge equals n side panels plus their gaps.
hero_shape <- function(a_hero, a_side, n, gap, position, stack = FALSE) {
  # s is the width of a side panel
  if (stack && position == "bottom") {
    # side panels as wide as the hero, one under the other
    list(cw = 1, dw = 0, ch = a_hero + n * a_side, dh = n * gap, a_hero = a_hero, a_side = a_side)
  } else if (stack) {
    # side panels as high as the hero, side by side
    list(cw = a_side / a_hero + n, dw = n * gap, ch = a_side, dh = 0, a_hero = a_hero, a_side = a_side)
  } else if (position == "bottom") {
    # hero width = n * s + (n - 1) * gap
    list(cw = n, dw = (n - 1) * gap, ch = a_hero * n + a_side, dh = a_hero * (n - 1) * gap + gap,
         a_hero = a_hero, a_side = a_side)
  } else {
    # hero height = n * side height + (n - 1) * gap
    list(cw = n * a_side / a_hero + 1, dw = (n - 1) * gap / a_hero + gap, ch = n * a_side, dh = (n - 1) * gap,
         a_hero = a_hero, a_side = a_side)
  }
}

# Where the labels of hero side panels go: below them, or beside them on the
# left or right. Stacked strips below the hero are labelled on the left, like
# rows; stacked strips beside it are labelled below, like columns.
hero_label_side <- function(space) {
  if (!identical(space$type, "hero")) {
    return(NA_character_)
  }
  if (isTRUE(space$stack)) {
    if (space$position == "bottom") "left" else "bottom"
  } else {
    space$position
  }
}

hero_rects <- function(shape, s, gap, n, position, role, k, stack = FALSE) {
  side_w <- s
  side_h <- s * shape$a_side
  if (stack && position == "bottom") {
    hero_w <- s
    hero_h <- s * shape$a_hero
    side_x <- rep(0, length(k))
    side_y <- hero_h + gap + (k - 1) * (side_h + gap)
    hero_x <- 0
  } else if (stack) {
    hero_h <- side_h
    hero_w <- hero_h / shape$a_hero
    side_y <- rep(0, length(k))
    side_x <- if (position == "right") hero_w + gap + (k - 1) * (side_w + gap) else (k - 1) * (side_w + gap)
    hero_x <- if (position == "right") 0 else n * (side_w + gap)
  } else if (position == "bottom") {
    hero_w <- n * s + (n - 1) * gap
    hero_h <- hero_w * shape$a_hero
    side_x <- (k - 1) * (side_w + gap)
    side_y <- rep(hero_h + gap, length(k))
    hero_x <- 0
  } else {
    hero_h <- n * side_h + (n - 1) * gap
    hero_w <- hero_h / shape$a_hero
    side_y <- (k - 1) * (side_h + gap)
    side_x <- rep(if (position == "right") hero_w + gap else 0, length(k))
    hero_x <- if (position == "right") 0 else side_w + gap
  }
  is_hero <- role == "hero"
  list(
    x = ifelse(is_hero, hero_x, side_x),
    y = ifelse(is_hero, 0, side_y),
    w = ifelse(is_hero, hero_w, side_w),
    h = ifelse(is_hero, hero_h, side_h)
  )
}

# One header per run of equal values, for each level of nesting.
header_strips <- function(grid, from, to) {
  out <- lapply(seq_len(ncol(grid)), function(j) {
    key <- do.call(paste, c(lapply(grid[seq_len(j)], as.character), sep = "\r"))
    runs <- rle(key)
    ends <- cumsum(runs$lengths)
    starts <- ends - runs$lengths + 1
    data.frame(level = j, label = as.character(grid[[j]][starts]), from = from[starts], to = to[ends])
  })
  do.call(rbind, out)
}
