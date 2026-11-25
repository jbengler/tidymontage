# Panel space --------------------------------------------------------------------

# One row per panel: its source images (indices into `images`; several for
# merges), its position (grid cell, or block and role for the hero layout) and
# the values of the panel dimensions.
montage_panel_space <- function(images, spec, views = list(full = list(name = "full")),
                                call = rlang::caller_env()) {
  mapping <- spec$mapping
  data <- images
  data$.image <- seq_len(nrow(data))
  data <- expand_merges(data, spec$merges, mapping, call = call, overlays = names(spec$overlays))
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
    .is_overlay = data$.is_overlay,
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
  merges <- setdiff(names(spec$merges), names(spec$overlays))
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
    n_side = n, position = spec$layout$position, labels = isTRUE(spec$layout$labels %||% TRUE),
    stack = isTRUE(spec$layout$stack)
  )
}

# Add one virtual row per merge and panel cell. Its `.sources` are the member
# images. The cell is defined by the layout's dimensions, apart from channel
# and columns that are determined by the channel (such as a `target` column).
expand_merges <- function(data, merges, layout, call, overlays = character()) {
  data$.sources <- as.list(data$.image)
  data$.is_merge <- FALSE
  data$.is_overlay <- FALSE
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
      row$.is_overlay <- nm %in% overlays
      rows[[length(rows) + 1]] <- row
    }
  }
  vctrs::vec_rbind(data, !!!rows)
}

dim_levels <- function(x, chosen = NULL) {
  present <- if (is.factor(x)) levels(droplevels(x)) else unique(as.character(x))
  if (!is.null(chosen)) chosen[chosen %in% present] else present
}
