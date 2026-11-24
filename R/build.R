# Building a montage: steps -> spec -> panels -> geometry -> display ranges ->
# rasters. Pixels are only read in montage_rasters().

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

# Panel space --------------------------------------------------------------------

# One row per panel: its source images (indices into `images`; several for
# merges), its position (grid cell, or block and role for the hero layout) and
# the values of the panel dimensions.
montage_panel_space <- function(images, spec, views = list(full = list(name = "full")),
                                call = rlang::caller_env()) {
  mapping <- spec$mapping
  data <- images
  data$.image <- seq_len(nrow(data))
  data <- expand_merges(data, spec$merges, mapping, call = call)
  # every image (and merge) appears once per view
  data <- vctrs::vec_rbind(!!!lapply(names(views), function(v) {
    d <- data
    d$view <- v
    d
  }))
  for (d in names(mapping$levels)) {
    data <- data[as.character(data[[d]]) %in% mapping$levels[[d]], , drop = FALSE]
  }
  if (nrow(data) == 0) {
    cli::cli_abort("No images left after choosing levels.", call = call)
  }
  if (spec$layout$type == "hero") {
    hero_panel_space(data, spec, views, call)
  } else {
    grid_panel_space(data, spec, call)
  }
}

dims_key <- function(data, dims) {
  if (length(dims) == 0) rep("", nrow(data)) else {
    do.call(paste, c(lapply(dims, function(d) as.character(data[[d]])), sep = "\r"))
  }
}

# Does `d` vary between rows that share the same values of `dims`?
varies_within <- function(data, d, dims) {
  any(tapply(as.character(data[[d]]), dims_key(data, dims), function(v) length(unique(v)) > 1))
}

# Grid: add channel and view to an axis if they still vary within cells.
grid_axes <- function(data, mapping, layout) {
  x <- mapping$x
  y <- mapping$y
  within <- c("channel", "view")
  free <- c(x = length(setdiff(x, within)) == 0, y = length(setdiff(y, within)) == 0)
  # axes already holding channel or view (mapped by the user)
  placed <- c(if (any(within %in% x)) "x", if (any(within %in% y)) "y")
  for (d in within) {
    if (d %in% c(x, y) || !varies_within(data, d, c(x, y))) next
    axis <- layout[[d]]
    if (axis == "auto") {
      other <- if (length(placed) > 0) setdiff(c("x", "y"), placed[1]) else NULL
      axis <- if (!is.null(other)) other else if (free[["x"]]) "x" else "y"
    }
    placed <- c(placed, axis)
    # within-block dimensions vary fastest (innermost)
    if (axis == "x") x <- c(x, d) else y <- c(y, d)
  }
  list(x = x, y = y)
}

axis_index <- function(data, dims, levels) {
  if (length(dims) == 0) {
    return(list(index = rep(1L, nrow(data)), grid = NULL))
  }
  lv <- lapply(dims, function(d) dim_levels(data[[d]], levels[[d]]))
  # first dimension varies slowest
  grid <- rev(expand.grid(rev(lv), stringsAsFactors = FALSE))
  names(grid) <- dims
  index <- match(dims_key(data, dims), do.call(paste, c(grid, sep = "\r")))
  used <- sort(unique(index))
  list(index = match(index, used), grid = grid[used, , drop = FALSE])
}

check_one_image_per_panel <- function(data, dims, call) {
  key <- dims_key(data, dims)
  dup <- duplicated(key) | duplicated(key, fromLast = TRUE)
  if (any(dup)) {
    first <- data[dup, , drop = FALSE][1, ]
    n <- sum(key == key[dup][1])
    where_dims <- union(dims, "channel")
    where <- paste0(where_dims, " = ", vapply(where_dims, function(d) as.character(first[[d]]), ""), collapse = ", ")
    cli::cli_abort(
      c(
        "{n} images would share one panel ({where}).",
        "i" = "Each panel shows one image. Summarise z-slices or time points first, e.g. {.code summarise(img = max(img), .by = ...)}, or map another column such as {.field filepath} to {.arg x} or {.arg y}."
      ),
      call = call
    )
  }
}

grid_panel_space <- function(data, spec, call) {
  axes <- grid_axes(data, spec$mapping, spec$layout)
  mapped <- c(axes$x, axes$y)
  check_one_image_per_panel(data, mapped, call)
  ax <- axis_index(data, axes$x, spec$mapping$levels)
  ay <- axis_index(data, axes$y, spec$mapping$levels)
  panels <- panel_tibble(data, col = ax$index, row = ay$index, dims = mapped)
  panels <- panels[order(panels$row, panels$col), , drop = FALSE]
  list(type = "grid", panels = panels, data = data, col_grid = ax$grid, row_grid = ay$grid)
}

panel_tibble <- function(data, col, row, dims) {
  panels <- tibble::tibble(
    .row = seq_len(nrow(data)),
    .image = data$.image,
    .sources = data$.sources,
    .is_merge = data$.is_merge,
    col = col,
    row = row,
    channel = as.character(data$channel),
    view = data$view
  )
  for (d in setdiff(dims, c("channel", "view"))) {
    panels[[d]] <- data[[d]]
  }
  panels
}

# Hero: one big panel and a strip of small panels per block. Blocks are
# arranged by the mapped columns; channel and view are arranged by the layout.
hero_panel_space <- function(data, spec, views, call) {
  mapping <- spec$mapping
  within <- c("channel", "view")
  ignored <- intersect(c(mapping$x, mapping$y), within)
  if (length(ignored) > 0) {
    cli::cli_inform(
      "The hero layout arranges {.field {ignored}} itself, so {cli::qty(ignored)}{?it is/they are} ignored in {.arg x} and {.arg y}.",
      call = call
    )
  }
  bx <- setdiff(mapping$x, within)
  by <- setdiff(mapping$y, within)
  main <- names(views)[1]
  zooms <- names(views)[-1]
  merges <- names(spec$merges)
  channels <- unique(as.character(data$channel[!data$.is_merge]))

  hero <- spec$layout$hero
  if (is.null(hero)) {
    present_merges <- intersect(merges, unique(as.character(data$channel)))
    if (length(present_merges) > 1) {
      cli::cli_abort(
        c(
          "The hero layout can't choose between the merges {.val {present_merges}}.",
          "i" = "Choose one with {.code layout_hero(hero = panel(channel = \"{present_merges[1]}\"))}."
        ),
        call = call
      )
    }
    hero <- panel(channel = if (length(present_merges) == 1) present_merges else channels[1], view = main)
  }
  side <- spec$layout$side
  if (is.null(side)) {
    present_zooms <- intersect(zooms, unique(data$view))
    if (length(present_zooms) > 1) {
      cli::cli_abort(
        c(
          "The hero layout can't choose between the zooms {.val {present_zooms}}.",
          "i" = "Choose one with {.code layout_hero(side = panel(view = \"{present_zooms[1]}\"))}."
        ),
        call = call
      )
    }
    side <- panel(channel = channels, view = if (length(present_zooms) == 1) present_zooms else main)
  }

  data$.rowid <- seq_len(nrow(data))
  pick <- function(sel) {
    keep <- rep(TRUE, nrow(data))
    for (d in names(sel)) {
      if (!d %in% names(data)) {
        cli::cli_abort("{.fn panel} refers to {.field {d}}, which is not a panel dimension.", call = call)
      }
      keep <- keep & as.character(data[[d]]) %in% sel[[d]]
    }
    d <- data[keep, , drop = FALSE]
    # order by the levels given in panel(), then by channel and view
    ord <- do.call(order, lapply(names(sel), function(nm) match(as.character(d[[nm]]), sel[[nm]])))
    d[ord, , drop = FALSE]
  }
  hero_rows <- pick(hero)
  side_rows <- pick(side)

  blocks_x <- axis_index(data, bx, mapping$levels)
  blocks_y <- axis_index(data, by, mapping$levels)
  block_key <- dims_key(data, c(bx, by))
  all_blocks <- unique(block_key)

  hero_key <- dims_key(hero_rows, c(bx, by))
  n_hero <- as.vector(table(factor(hero_key, levels = all_blocks)))
  if (any(n_hero != 1)) {
    count <- n_hero[n_hero != 1][1]
    cli::cli_abort(
      c(
        "Each block needs exactly one hero panel, but {.val {format(hero)}} matches {count} panel{?s} in a block.",
        "i" = "Map the columns that distinguish blocks to {.arg x} or {.arg y}, or choose the hero with {.fn panel}."
      ),
      call = call
    )
  }
  side_key <- dims_key(side_rows, c(bx, by))
  n_side <- as.vector(table(factor(side_key, levels = all_blocks)))
  if (any(n_side == 0)) {
    cli::cli_abort("Some blocks have no side panels matching {.val {format(side)}}.", call = call)
  }
  if (length(unique(n_side)) > 1) {
    cli::cli_abort("All blocks need the same number of side panels, but they have {unique(n_side)}.", call = call)
  }
  n <- n_side[[1]]
  if (n > 4) {
    cli::cli_warn("The hero layout has {n} side panels per block; more than 4 get small. Consider a grid.", call = call)
  }

  rows <- c(hero_rows$.rowid, side_rows$.rowid)
  role <- c(rep("hero", nrow(hero_rows)), rep("side", nrow(side_rows)))
  k <- c(rep(0L, nrow(hero_rows)), stats::ave(seq_len(nrow(side_rows)), side_key, FUN = seq_along))
  d <- data[rows, , drop = FALSE]
  check_one_image_per_panel(
    tibble::tibble(key = paste(dims_key(d, c(bx, by)), role, k), channel = d$channel),
    "key", call
  )
  panels <- panel_tibble(d, col = blocks_x$index[rows], row = blocks_y$index[rows], dims = c(bx, by))
  panels$.row <- rows
  panels$.role <- role
  panels$.k <- k
  # side panels are labelled with what distinguishes them: usually the channel
  first_block <- side_key == side_key[1]
  side_dim <- if (length(unique(as.character(side_rows$channel[first_block]))) > 1) {
    "channel"
  } else if (length(unique(side_rows$view[first_block])) > 1) {
    "view"
  } else {
    "channel"
  }
  panels$.label <- c(rep(NA_character_, nrow(hero_rows)), as.character(side_rows[[side_dim]]))
  panels <- panels[order(panels$row, panels$col, panels$.role, panels$.k), , drop = FALSE]
  list(
    type = "hero", panels = panels, data = data, col_grid = blocks_x$grid, row_grid = blocks_y$grid,
    n_side = n, position = spec$layout$position, labels = isTRUE(spec$layout$labels %||% TRUE)
  )
}

# Add one virtual row per merge and panel cell. Its `.sources` are the member
# images. The cell is defined by the layout's dimensions, apart from channel
# and columns that are determined by the channel (such as a `target` column).
expand_merges <- function(data, merges, layout, call) {
  data$.sources <- as.list(data$.image)
  data$.is_merge <- FALSE
  if (length(merges) == 0) {
    return(data)
  }
  candidate <- setdiff(union(c(layout$x, layout$y), names(layout$levels)), c("channel", "view"))
  rows <- list()
  for (nm in names(merges)) {
    members <- merges[[nm]]
    md <- data[as.character(data$channel) %in% members, , drop = FALSE]
    by_channel <- vapply(candidate, function(d) {
      per_channel <- tapply(as.character(md[[d]]), as.character(md$channel), function(v) length(unique(v)))
      all(per_channel == 1) && length(unique(as.character(md[[d]]))) > 1
    }, logical(1))
    channel_cols <- candidate[by_channel]
    group_dims <- setdiff(candidate, channel_cols)
    key <- if (length(group_dims) == 0) rep("", nrow(md)) else {
      do.call(paste, c(lapply(group_dims, function(d) as.character(md[[d]])), sep = "\r"))
    }
    for (k in unique(key)) {
      g <- md[key == k, , drop = FALSE]
      where <- if (length(group_dims) == 0) "" else {
        paste0(" (", paste0(group_dims, " = ", vapply(group_dims, function(d) as.character(g[[d]][1]), ""), collapse = ", "), ")")
      }
      missing <- setdiff(members, as.character(g$channel))
      if (length(missing) > 0) {
        cli::cli_abort(
          "Merge {.val {nm}} needs {.val {members}}, but {.val {missing}} {?is/are} missing{where}.",
          call = call
        )
      }
      dup <- unique(as.character(g$channel)[duplicated(as.character(g$channel))])
      if (length(dup) > 0) {
        cli::cli_abort(
          c(
            "Merge {.val {nm}} would combine several {.val {dup}} images{where}.",
            "i" = "Map another column, such as {.field filepath}, to {.arg x} or {.arg y}, or summarise z-slices first."
          ),
          call = call
        )
      }
      g <- g[match(members, as.character(g$channel)), , drop = FALSE]
      row <- g[1, ]
      for (d in c("channel", channel_cols)) {
        row[[d]] <- if (is.factor(row[[d]])) factor(nm, levels = c(levels(row[[d]]), nm)) else nm
      }
      if ("color" %in% names(row)) row$color <- NA_character_
      row$.image <- NA_integer_
      row$.sources <- list(g$.image)
      row$.is_merge <- TRUE
      rows[[length(rows) + 1]] <- row
    }
  }
  vctrs::vec_rbind(data, !!!rows)
}

dim_levels <- function(x, chosen = NULL) {
  present <- if (is.factor(x)) levels(droplevels(x)) else unique(as.character(x))
  if (!is.null(chosen)) chosen[chosen %in% present] else present
}

# Geometry -------------------------------------------------------------------------

# Height of one header strip in mm, for text of `size` points.
strip_mm <- function(size) size * 0.3528 * 1.9

# Panel rectangles in mm, measured from the top-left corner (y points down),
# plus nested header strips. The panels and gaps fit into the box
# `size$width` x `size$height`; headers are added outside of it.
#
# Both layouts are a grid of cells: a cell is one panel (grid) or one block of
# hero plus side panels (hero). The size of a cell is linear in a free size
# `s` (the panel width, or the side panel width): w = cw * s + dw,
# h = ch * s + dh. The largest `s` that fits the box is used.
montage_geometry <- function(space, size = default_size(), gap = 1,
                             headers = list(x = TRUE, y = TRUE, size = 7),
                             extra = list(top = 0, bottom = 0, right = 0),
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
    shape <- hero_shape(a_hero, a_side, space$n_side, gap, space$position)
    cell_gap <- 3 * gap
  } else {
    a <- check_aspect(panels$.aspect, "panels")
    shape <- list(cw = 1, dw = 0, ch = a, dh = 0)
    cell_gap <- gap
  }

  n_col <- max(panels$col)
  n_row <- max(panels$row)
  col_grid <- if (isTRUE(headers$x)) space$col_grid
  row_grid <- if (isTRUE(headers$y)) space$row_grid
  strip <- strip_mm(headers$size %||% 7)
  # space for a legend on top, then the header strips
  top <- extra$top + if (is.null(col_grid)) 0 else ncol(col_grid) * strip
  left <- if (is.null(row_grid)) 0 else ncol(row_grid) * strip

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
  if (identical(space$type, "hero") && isTRUE(space$labels)) {
    text_size <- headers$size %||% 7
    labs <- unique(panels$.label[panels$.role == "side"])
    line_h <- text_size * 0.3528 * 1.25
    # below the panels: as wide as a panel; beside them (rotated): as long as
    # a panel is high
    room <- if (space$position == "bottom") s_free else s_free * shape$a_side
    # labels may reach into the gaps between side panels (half a gap each side)
    wrapped <- wrap_labels(labs, room + gap, text_size, call)
    n_lines <- max(lengths(strsplit(wrapped, "\n", fixed = TRUE)))
    if (space$position == "bottom") {
      lab_h <- 0.8 + n_lines * line_h
    } else {
      lab_w <- 0.8 + n_lines * line_h
    }
    names(wrapped) <- labs
  }
  cell_w <- shape$cw * s_free + shape$dw + lab_w
  cell_h <- shape$ch * s_free + shape$dh + lab_h
  width <- left + n_col * cell_w + (n_col - 1) * cell_gap + extra$right
  height <- top + n_row * cell_h + (n_row - 1) * cell_gap + extra$bottom

  ox <- left + (panels$col - 1) * (cell_w + cell_gap)
  oy <- top + (panels$row - 1) * (cell_h + cell_gap)
  if (identical(space$type, "hero")) {
    r <- hero_rects(shape, s_free, gap, space$n_side, space$position, panels$.role, panels$.k)
    # labels on the left come first
    if (space$position == "left") ox <- ox + lab_w
    panels$xmin <- ox + r$x
    panels$ymin <- oy + r$y
    panels$xmax <- panels$xmin + r$w
    panels$ymax <- panels$ymin + r$h
  } else {
    panels$xmin <- ox
    panels$ymin <- oy
    panels$xmax <- ox + s_free
    panels$ymax <- oy + s_free * shape$ch
  }

  side_labels <- NULL
  if (!is.null(wrapped)) {
    side <- panels[panels$.role == "side", , drop = FALSE]
    pos <- space$position
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
  col_from <- left + (seq_len(n_col) - 1) * (cell_w + cell_gap) +
    (if (identical(space$position, "left")) lab_w else 0)
  row_from <- top + (seq_len(n_row) - 1) * (cell_h + cell_gap)
  labels <- NULL
  lines <- NULL
  if (!is.null(col_grid)) {
    st <- header_strips(col_grid, col_from, col_from + cell_w - lab_w)
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
    st <- header_strips(row_grid, row_from, row_from + cell_h - lab_h)
    labels <- rbind(labels, data.frame(
      label = st$label, x = (st$level - 0.5) * strip, y = (st$from + st$to) / 2, angle = 90
    ))
    outer <- st[st$level < ncol(row_grid), , drop = FALSE]
    lines <- rbind(lines, data.frame(
      x = outer$level * strip - 0.3, xend = outer$level * strip - 0.3,
      y = outer$from + 0.5, yend = outer$to - 0.5
    ))
  }
  list(
    panels = panels, labels = labels, lines = lines, side_labels = side_labels,
    width = width, height = height
  )
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
hero_shape <- function(a_hero, a_side, n, gap, position) {
  if (position == "bottom") {
    # hero width = n * s + (n - 1) * gap
    list(cw = n, dw = (n - 1) * gap, ch = a_hero * n + a_side, dh = a_hero * (n - 1) * gap + gap,
         a_hero = a_hero, a_side = a_side)
  } else {
    # hero height = n * side height + (n - 1) * gap
    list(cw = n * a_side / a_hero + 1, dw = (n - 1) * gap / a_hero + gap, ch = n * a_side, dh = (n - 1) * gap,
         a_hero = a_hero, a_side = a_side)
  }
}

# Offsets and sizes of hero and side panels within their block.
hero_rects <- function(shape, s, gap, n, position, role, k) {
  side_w <- s
  side_h <- s * shape$a_side
  if (position == "bottom") {
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
    on <- panels$view == main & (z$box == "all" | panels$.is_merge)
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

# Scale bars -------------------------------------------------------

# Micrometres per mm of each panel (NA without a pixel size).
panel_um_per_mm <- function(panels, images) {
  first_source <- vapply(panels$.sources, `[`, integer(1), 1)
  ps <- vapply(vctrs::vec_data(images$img[first_source]), function(r) r$node$pixel_size, numeric(1))
  (panels$.x1 - panels$.x0 + 1) * ps / (panels$xmax - panels$xmin)
}

montage_scale_bars <- function(panels, images, sb, call = rlang::caller_env()) {
  if (is.null(sb)) {
    return(NULL)
  }
  scale <- panel_um_per_mm(panels, images)
  pick <- switch(
    sb$where,
    all = seq_len(nrow(panels)),
    merge = which(panels$.is_merge),
    last = unlist(lapply(unique(panels$view), function(v) {
      idx <- which(panels$view == v)
      s_v <- scale[idx]
      if (all(is.na(s_v)) || diff(range(s_v, na.rm = TRUE)) <= 1e-3 * min(s_v, na.rm = TRUE)) {
        idx[order(-panels$ymax[idx], -panels$xmax[idx])][1]
      } else {
        cli::cli_inform(
          "Panels of the view {.val {v}} have different magnifications, so each gets its own scale bar.",
          call = call
        )
        idx
      }
    }))
  )
  if (length(pick) == 0) {
    cli::cli_warn("No panels match {.code where = \"{sb$where}\"}, so no scale bars are drawn.", call = call)
    return(NULL)
  }
  if (anyNA(scale[pick])) {
    cli::cli_abort(
      c(
        "Scale bars need a known pixel size.",
        "i" = "Some images have no pixel size ({.field pixel_size_source} is {.val NA})."
      ),
      call = call
    )
  }
  bars <- lapply(pick, function(i) {
    view <- panels$view[i]
    len <- if (is.null(sb$length)) {
      nice_length((panels$xmax[i] - panels$xmin[i]) * scale[i])
    } else if (length(sb$length) == 1 && is.null(names(sb$length))) {
      sb$length
    } else {
      if (!view %in% names(sb$length)) {
        cli::cli_abort("{.arg length} has no value for the view {.val {view}}.", call = call)
      }
      sb$length[[view]]
    }
    w <- len / scale[i]
    if (w > panels$xmax[i] - panels$xmin[i] - 2 * sb$inset) {
      cli::cli_abort("A {len} \u00b5m scale bar doesn't fit into the panels of the view {.val {view}}.", call = call)
    }
    right <- endsWith(sb$position, "right")
    bottom <- startsWith(sb$position, "bottom")
    x0 <- if (right) panels$xmax[i] - sb$inset - w else panels$xmin[i] + sb$inset
    y0 <- if (bottom) panels$ymax[i] - sb$inset - sb$thickness else panels$ymin[i] + sb$inset
    data.frame(
      xmin = x0, xmax = x0 + w, ymin = y0, ymax = y0 + sb$thickness,
      label = paste0(format(len, drop0trailing = TRUE, trim = TRUE), "~mu*m"),
      # align the label with the bar's outer end, so it stays inside the panel
      label_x = if (right) x0 + w else x0,
      label_hjust = if (right) 1 else 0,
      label_y = if (bottom) y0 - 0.4 else y0 + sb$thickness + 0.4,
      label_vjust = if (bottom) 0 else 1
    )
  })
  out <- do.call(rbind, bars)
  attr(out, "style") <- sb
  out
}

# Display ranges -------------------------------------------------------------------

# One display range (lo, hi) per panel, from full-resolution pixels.
montage_ranges <- function(panels, images, pixels, exposure, call = rlang::caller_env()) {
  data <- images[panels$.image, , drop = FALSE]
  data$view <- panels$view
  by <- exposure$by
  group <- if (length(by) == 0) rep("all", nrow(data)) else {
    do.call(paste, c(lapply(by, function(d) as.character(data[[d]])), sep = "\r"))
  }

  spans <- tapply(data$channel, group, function(ch) length(unique(ch)) > 1)
  if (any(spans)) {
    cli::cli_warn(
      c(
        "A display range is shared by several channels.",
        "i" = "Display ranges are usually linked per channel: include {.field channel} in {.arg .by} of {.fn adjust_exposure}."
      ),
      call = call
    )
  }

  lo <- hi <- numeric(nrow(data))
  for (g in unique(group)) {
    idx <- which(group == g)
    pool <- unlist(lapply(pixels[idx], sample_pixels))
    for (i in idx) {
      ov <- exposure$overrides[[as.character(data$channel[i])]]
      lo[i] <- resolve_range_spec(ov$min %||% exposure$min, pool)
      hi[i] <- resolve_range_spec(ov$max %||% exposure$max, pool)
    }
  }
  if ("display_min" %in% names(data)) {
    use <- !is.na(data$display_min)
    lo[use] <- data$display_min[use]
  }
  if ("display_max" %in% names(data)) {
    use <- !is.na(data$display_max)
    hi[use] <- data$display_max[use]
  }
  flat <- hi <= lo
  hi[flat] <- lo[flat] + 1
  data.frame(lo = lo, hi = hi, group = group)
}

sample_pixels <- function(m, n = 250000) {
  step <- max(1L, length(m) %/% n)
  as.vector(m)[seq(1, length(m), by = step)]
}

resolve_range_spec <- function(spec, pool) {
  if (spec$type == "value") spec$value else stats::quantile(pool, spec$value / 100, names = FALSE, type = 7)
}

# Colours ----------------------------------------------------------------------------

montage_colors <- function(panels, images, colors) {
  col <- if ("color" %in% names(images)) images$color[panels$.image] else rep(NA_character_, nrow(panels))
  ch <- panels$channel
  override <- ch %in% names(colors)
  col[override] <- unlist(colors[ch[override]])
  col[is.na(col)] <- "#FFFFFF"
  col
}

# Rasters ----------------------------------------------------------------------------

# Average blocks of f x f pixels.
bin_mean <- function(m, f) {
  if (f <= 1) {
    return(m)
  }
  h <- nrow(m) %/% f
  w <- ncol(m) %/% f
  a <- array(m[seq_len(h * f), seq_len(w * f)], c(f, h, f, w))
  matrix(colMeans(matrix(aperm(a, c(1, 3, 2, 4)), f * f)), h, w)
}

# Intensities -> red, green and blue matrices (0-255) for one colour.
tint_rgb <- function(m, lo, hi, color) {
  v <- (m - lo) / (hi - lo)
  v[v < 0] <- 0
  v[v > 1] <- 1
  rgb <- grDevices::col2rgb(color)[, 1]
  list(v * rgb[1], v * rgb[2], v * rgb[3])
}

# Red, green and blue matrices (0-255, clipped) -> nativeRaster.
pack_raster <- function(rgb) {
  ch <- lapply(rgb, function(x) round(pmin(x, 255)))
  packed <- ch[[1]] + 256 * ch[[2]] + 65536 * ch[[3]] - 16777216
  structure(as.integer(t(packed)), dim = dim(rgb[[1]]), class = "nativeRaster", channels = 4L)
}

tint_raster <- function(m, lo, hi, color) {
  pack_raster(tint_rgb(m, lo, hi, color))
}

# Intensities -> 0-1 within the display range.
scale_intensity <- function(m, lo, hi) {
  v <- (m - lo) / (hi - lo)
  v[v < 0] <- 0
  v[v > 1] <- 1
  v
}

# Red, green and blue matrices (0-255) of one panel. On black, colours add up
# like light; on white, they multiply like inks (a black channel shows dark
# signal on white).
compose_panel <- function(values, colors, background = "black") {
  rgb <- grDevices::col2rgb(colors) / 255
  if (background == "white") {
    lapply(1:3, function(ch) {
      out <- 255
      for (j in seq_along(values)) out <- out * (1 - values[[j]] * (1 - rgb[ch, j]))
      out
    })
  } else {
    lapply(1:3, function(ch) {
      out <- 0
      for (j in seq_along(values)) out <- out + values[[j]] * rgb[ch, j] * 255
      out
    })
  }
}

# Additive blend of several tinted images.
blend_rgb <- function(layers) {
  Reduce(function(a, b) Map(`+`, a, b), layers)
}

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
    pack_raster(compose_panel(values, panels$.colors[[i]], panels$.background[i]))
  })

  single <- !panels$.is_merge
  at <- match(panels$.image, used)
  panels$display_min <- ifelse(single, sources$display_min[at], NA_real_)
  panels$display_max <- ifelse(single, sources$display_max[at], NA_real_)
  panels$color <- ifelse(single, vapply(panels$.colors, `[`, character(1), 1), NA_character_)

  list(
    panels = panels, labels = space$labels, lines = space$lines, boxes = space$boxes,
    scale_bars = space$scale_bars, headers = space$headers, legend = space$legend,
    side_labels = space$side_labels,
    width = space$width, height = space$height, rasters = rasters
  )
}

# Colours and background of each panel, without reading pixels. `.colors`
# holds one colour per source image. A single channel coloured black is drawn
# inverted on white; everything else, and every merge, on black. In merges,
# black members use their original colour (the `color` column) unless the
# merge sets one.
panel_styles <- function(panels, images, spec, call = rlang::caller_env()) {
  invisible_in <- character()
  cols <- lapply(seq_len(nrow(panels)), function(i) {
    src <- panels$.sources[[i]]
    ch <- as.character(images$channel[src])
    col <- montage_colors(tibble::tibble(.image = src, channel = ch), images, spec$colors)
    if (panels$.is_merge[i]) {
      original <- if ("color" %in% names(images)) images$color[src] else rep(NA_character_, length(src))
      original[is.na(original)] <- "#FFFFFF"
      black <- is_black(col)
      col[black] <- original[black]
      ov <- spec$merge_style[[panels$channel[i]]]$colors
      hit <- ch %in% names(ov)
      col[hit] <- unlist(ov[ch[hit]])
      if (any(is_black(col))) invisible_in <<- c(invisible_in, panels$channel[i])
    }
    col
  })
  if (length(invisible_in) > 0) {
    cli::cli_warn(
      c(
        "A channel in the merge {.val {unique(invisible_in)}} is black and invisible on the black background.",
        "i" = "Give it a colour with {.code add_merge(colors = )}."
      ),
      call = call
    )
  }
  background <- vapply(seq_len(nrow(panels)), function(i) {
    if (!panels$.is_merge[i] && any(is_black(cols[[i]]))) "white" else "black"
  }, character(1))
  panels$.colors <- cols
  panels$.background <- background
  panels
}

is_black <- function(color) {
  colSums(grDevices::col2rgb(color)) == 0
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
    geom <- montage_geometry(space, spec$size, spec$gap, spec$headers, extra, call = call)
  } else {
    extra <- legend_extent(NULL, NULL)
  }
  legend_df <- if (!is.null(legend) && nrow(items) > 0) {
    p <- geom$panels
    legend_layout(items, legend, list(
      xmin = min(p$xmin), xmax = max(p$xmax), ymin = min(p$ymin), ymax = max(p$ymax),
      top = extra$top, bottom = extra$bottom
    ))
  }
  list(
    legend = legend_df,
    panels = geom$panels,
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
