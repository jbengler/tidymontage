#' Add arrowheads that point at locations
#'
#' Adds arrowheads that mark locations in the images, such as a vesicle or a
#' contact site. An arrowhead belongs to an image, not to a channel: it is
#' drawn at the same place in every panel of that image, in each channel and
#' in merges and overlays. Crops and zooms show it wherever its tip falls
#' inside their region.
#'
#' Each arrowhead is a filled triangle whose tip is at the given position. All
#' arrowheads point in the same direction, from the lower right to the upper
#' left at 45 degrees, and have the same size in every panel. By default they
#' contrast with the panel: white on dark panels, black on light ones.
#'
#' Positions are given like the centers of [add_crop()]: relative to the full
#' image by default (`0` = left or top edge, `1` = right or bottom edge), or
#' with `units = "px"` as pixel coordinates of the full image, counted from 0
#' as in ImageJ / Fiji. Calling `add_arrows()` again adds more arrowheads.
#'
#' @param montage A [tidymontage()] object.
#' @param at Positions of the arrow tips: a numeric vector `c(x, y)` for one
#'   arrowhead on every image, or a data frame with columns `x` and `y` and
#'   columns of the images tibble to match on, e.g. `condition` or
#'   `filepath`. A data frame can have several rows per image; images without
#'   a matching row get no arrowheads.
#' @param size Length of an arrowhead in mm.
#' @param units Units of `at`: `"rel"` (relative, 0-1) or `"px"`.
#' @param color Colour of the arrowheads. `NULL` (the default) picks white or
#'   black, whichever contrasts with the panel.
#'
#' @returns The montage with the arrow step added.
#' @examples
#' \dontrun{
#' arrows <- tibble::tribble(
#'   ~condition, ~x,   ~y,
#'   "ctrl",     0.48, 0.42,
#'   "ctrl",     0.55, 0.38,
#'   "ko",       0.41, 0.50
#' )
#' montage |> add_arrows(arrows)
#' }
#' @export
add_arrows <- function(montage, at, size = 2, units = c("rel", "px"), color = NULL) {
  check_tidymontage(montage)
  units <- rlang::arg_match(units)
  check_center(at, units, montage$images, call = rlang::current_env(), arg = "at", several = TRUE)
  check_number(size, "size")
  if (!is.null(color)) check_color(color, "color")
  add_step(montage, new_step("add_arrows", list(at = at, size = size, units = units, color = color)))
}

#' @export
format.tidymontage_step_add_arrows <- function(x, ...) {
  p <- x$params
  at <- if (is.numeric(p$at)) {
    paste0("c(", paste(p$at, collapse = ", "), ")")
  } else {
    keys <- setdiff(names(p$at), c("x", "y"))
    paste0(
      "<", nrow(p$at), " ", plural(nrow(p$at), "position"),
      if (length(keys) > 0) paste0(" by ", paste(keys, collapse = ", ")), ">"
    )
  }
  args <- c(
    paste0("at = ", at),
    if (p$size != 2) paste0("size = ", p$size),
    if (p$units != "rel") paste0("units = \"", p$units, "\""),
    if (!is.null(p$color)) paste0("color = \"", p$color, "\"")
  )
  paste0("add_arrows(", paste(args, collapse = ", "), ")")
}

# Arrow tips on the panels, in mm, with the panel each one is clipped to.
# Tips outside the region a panel shows are left out. In rotated regions the
# tips move with the image, but arrowheads keep pointing up-left on the page.
montage_arrows <- function(space, panels, images, arrows) {
  if (length(arrows) == 0) {
    return(NULL)
  }
  out <- list()
  for (i in seq_len(nrow(panels))) {
    row <- space$data[panels$.row[i], , drop = FALSE]
    node <- vctrs::vec_data(images$img[panels$.sources[[i]][1]])[[1]]$node
    for (a in arrows) {
      at <- arrow_positions(a$at, row)
      if (nrow(at) == 0) next
      # 0-based pixel coordinates of the full image; pixel k spans [k, k + 1]
      px <- if (a$units == "rel") at$x * node$size_x else at$x
      py <- if (a$units == "rel") at$y * node$size_y else at$y
      pt <- panel_point(panels, i, px, py)
      x <- pt$x
      y <- pt$y
      inside <- x >= panels$xmin[i] & x <= panels$xmax[i] & y >= panels$ymin[i] & y <= panels$ymax[i]
      if (!any(inside)) next
      out[[length(out) + 1]] <- data.frame(
        panel = i, x = x[inside], y = y[inside], size = a$size,
        color = a$color %||% ink_on(panels$.background[i])
      )
    }
  }
  if (length(out) == 0) {
    return(NULL)
  }
  do.call(rbind, out)
}

# The rows of `at` that apply to an image (a row of the panel data).
arrow_positions <- function(at, row) {
  if (is.numeric(at)) {
    return(data.frame(x = at[1], y = at[2]))
  }
  keys <- setdiff(intersect(names(at), names(row)), c("x", "y"))
  hit <- rep(TRUE, nrow(at))
  for (k in keys) {
    hit <- hit & as.character(at[[k]]) == as.character(row[[k]])
  }
  hit[is.na(hit)] <- FALSE
  data.frame(x = at$x[hit], y = at$y[hit])
}

# Corners of an arrowhead (mm, y down): the tip, then the two corners of its
# base, which lies down and to the right of the tip.
arrowhead_polygon <- function(x, y, size) {
  d <- c(1, 1) / sqrt(2) # from the tip into the arrowhead
  n <- c(1, -1) / sqrt(2) # across it
  half <- size * 0.3
  list(
    x = c(x, x + size * d[1] + half * n[1], x + size * d[1] - half * n[1]),
    y = c(y, y + size * d[2] + half * n[2], y + size * d[2] - half * n[2])
  )
}
