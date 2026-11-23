#' Read images
#'
#' `read_images()` reads the metadata of microscopy image files and returns a
#' long tibble with one row per image: one per file, channel, z-slice and time
#' point. The `img` column holds lazy references to the greyscale images.
#' Pixels are not read here; this happens when a montage is rendered, and only
#' for the images it shows.
#'
#' Because the result is a tibble, you select and process images with dplyr:
#' `filter()` z-slices or time points, project a z-stack with
#' `summarise(img = max(img), .by = c(filepath, channel))`.
#'
#' Metadata are taken from the richest source available, recorded in
#' `meta_source`:
#' * `"ome-xml"`: OME-TIFF (`.ome.tif`).
#' * `"imagej"`: TIFF saved by ImageJ / Fiji, including channel colours (LUTs)
#'   and channel names from microscope metadata carried over by Bio-Formats.
#' * `"tiff"`: plain TIFF. All pages are treated as z-slices of one channel.
#'
#' The pixel size has its own source column, `pixel_size_source`, because
#' scale bars need a pixel size you can trust. A pixel size from plain TIFF
#' resolution tags (`"tiff"`) is only used if the unit is centimetres.
#'
#' @param paths A character vector of paths to TIFF files (`.tif`, `.tiff`,
#'   `.ome.tif`) or to directories containing them.
#'
#' @returns A tibble with one row per image and the columns:
#'   * `filepath`, `series`: file and image series (always 1 for non-OME files).
#'   * `channel_index`, `channel`: position and label of the channel. The label
#'     is the fluorophore if known, otherwise the channel name, otherwise
#'     `"C1"`, `"C2"`, ...
#'   * `z`, `t`: z-slice and time point of the image.
#'   * `img`: the image, a lazy greyscale image vector (see [is_img()]).
#'   * `color`: channel colour as a hex string, or `NA` if unknown.
#'   * `channel_name`, `fluor`: channel name and fluorophore from the metadata.
#'   * `size_x`, `size_y`, `size_z`, `size_t`: dimensions of the source file in
#'     pixels, z-slices and time points.
#'   * `bit_depth`: bits per sample (8 or 16).
#'   * `pixel_size`, `pixel_unit`: pixel size, always in micrometres.
#'   * `z_step`: distance between z-slices in micrometres.
#'   * `meta_source`, `pixel_size_source`: where the metadata came from.
#'
#' @examples
#' \dontrun{
#' read_images("path/to/images")
#' read_images(c("ctrl.ome.tif", "ko.ome.tif"))
#' }
#'
#' @export
read_images <- function(paths) {
  paths <- expand_image_paths(paths)
  rows <- lapply(paths, read_meta)
  vctrs::vec_rbind(!!!rows)
}

expand_image_paths <- function(paths, call = rlang::caller_env()) {
  if (!is.character(paths) || length(paths) == 0 || anyNA(paths)) {
    cli::cli_abort(
      "{.arg paths} must be a character vector of file or directory paths, not {.obj_type_friendly {paths}}.",
      call = call
    )
  }
  missing <- paths[!file.exists(paths)]
  if (length(missing) > 0) {
    cli::cli_abort("Can't find {cli::qty(missing)}file{?s} {.file {missing}}.", call = call)
  }
  is_dir <- dir.exists(paths)
  expanded <- lapply(seq_along(paths), function(i) {
    if (!is_dir[i]) {
      return(paths[i])
    }
    found <- sort(list.files(paths[i], pattern = "\\.tiff?$", ignore.case = TRUE, full.names = TRUE))
    if (length(found) == 0) {
      cli::cli_warn("Directory {.file {paths[i]}} contains no TIFF files.", call = call)
    }
    found
  })
  paths <- unlist(expanded)
  if (length(paths) == 0) {
    cli::cli_abort("No image files found.", call = call)
  }
  unsupported <- paths[!grepl("\\.tiff?$", paths, ignore.case = TRUE)]
  if (length(unsupported) > 0) {
    cli::cli_abort(
      c(
        "Only TIFF files ({.file .tif}, {.file .tiff}, {.file .ome.tif}) are supported.",
        "x" = "Unsupported: {.file {unsupported}}."
      ),
      call = call
    )
  }
  paths
}

# Read the metadata of one file. Currently TIFF only; other formats (CZI)
# will get their own reader with the same output.
read_meta <- function(path, call = rlang::caller_env()) {
  read_meta_tiff(path, call = call)
}

read_meta_tiff <- function(path, call = rlang::caller_env()) {
  tf <- tiff_open(path, call = call)
  n_pages <- length(tf$ifds)
  info <- tiff_page_info(tf, 1)
  check_tiff_pixels(info, path, call)
  palette <- isTRUE(info$photometric == 3)
  desc_raw <- tiff_tag_bytes(tf, 1, 270)

  series <- if (is_ome_xml(desc_raw)) {
    meta_tiff_ome(tf, desc_raw, info, n_pages, call)
  } else if (is_imagej_description(bytes_to_utf8(desc_raw))) {
    list(meta_tiff_imagej(tf, bytes_to_utf8(desc_raw), info, n_pages, path, call))
  } else {
    list(meta_tiff_plain(tf, info, n_pages))
  }

  rows <- lapply(seq_along(series), function(s) {
    meta_rows(path, s, series[[s]], info, palette, tf)
  })
  vctrs::vec_rbind(!!!rows)
}

check_tiff_pixels <- function(info, path, call) {
  if (!info$bits %in% c(8, 16) || !info$sample_format %in% 1) {
    format <- if (info$sample_format == 3) "floating point" else if (info$sample_format == 2) "signed integer" else "unsigned integer"
    cli::cli_abort(
      c(
        "Only 8- and 16-bit unsigned integer images are supported.",
        "x" = "{.file {path}} has {info$bits}-bit {format} pixels."
      ),
      call = call
    )
  }
  if (!info$samples %in% c(1, 3)) {
    cli::cli_abort(
      "{.file {path}} has {info$samples} samples per pixel; only 1 (greyscale) or 3 (RGB) are supported.",
      call = call
    )
  }
}

meta_tiff_ome <- function(tf, desc_raw, info, n_pages, call) {
  series <- ome_parse(desc_raw, tf$path, n_pages, call = call)
  lapply(series, function(s) {
    s$meta_source <- "ome-xml"
    s$pixel_size_source <- if (is.na(s$pixel_size)) NA_character_ else "ome-xml"
    s
  })
}

meta_tiff_imagej <- function(tf, desc_txt, info, n_pages, path, call) {
  desc <- ij_parse_description(desc_txt)
  images <- ij_int(desc, "images", n_pages)
  size_c <- ij_int(desc, "channels", 1L)
  size_t <- ij_int(desc, "frames", 1L)
  size_z <- ij_int(desc, "slices", max(1L, images %/% (size_c * size_t)))

  if (size_c * size_z * size_t != n_pages) {
    if (n_pages == 1 && images > 1) {
      cli::cli_abort(
        c(
          "{.file {path}} stores {images} images in a single page.",
          "i" = "ImageJ writes files larger than 4 GB this way, which is not supported. Save as OME-TIFF instead."
        ),
        call = call
      )
    }
    cli::cli_abort(
      "ImageJ metadata of {.file {path}} describe {size_c * size_z * size_t} planes, but the file has {n_pages} pages.",
      call = call
    )
  }

  # ImageJ hyperstacks are stored in CZT order.
  grid <- expand.grid(c = seq_len(size_c), z = seq_len(size_z), t = seq_len(size_t))
  planes <- data.frame(c = grid$c, z = grid$z, t = grid$t, page = seq_len(nrow(grid)))

  private <- ij_private(tf)
  colors <- rep(NA_character_, size_c)
  if (!is.null(private$luts) && length(private$luts) == size_c) {
    colors <- vapply(private$luts, lut_color, character(1))
  }

  unit <- desc$unit
  pixel_size <- NA_real_
  z_step <- NA_real_
  if (!is.null(unit)) {
    if (!is.na(info$x_resolution) && info$x_resolution > 0) {
      pixel_size <- to_micron(1 / info$x_resolution, unit)
    }
    z_step <- to_micron(ij_num(desc, "spacing"), unit)
  }

  list(
    size_x = info$width,
    size_y = info$height,
    size_z = size_z,
    size_t = size_t,
    samples = info$samples,
    pixel_size = pixel_size,
    z_step = z_step,
    channels = data.frame(
      name = zen_channel_values(private$info, "Name", size_c),
      fluor = zen_channel_values(private$info, "Fluor", size_c),
      color = colors
    ),
    planes = planes,
    meta_source = "imagej",
    pixel_size_source = if (is.na(pixel_size)) NA_character_ else "imagej"
  )
}

meta_tiff_plain <- function(tf, info, n_pages) {
  list(
    size_x = info$width,
    size_y = info$height,
    size_z = n_pages,
    size_t = 1L,
    samples = info$samples,
    pixel_size = NA_real_,
    z_step = NA_real_,
    channels = data.frame(name = NA_character_, fluor = NA_character_, color = NA_character_),
    planes = data.frame(c = 1L, z = seq_len(n_pages), t = 1L, page = seq_len(n_pages)),
    meta_source = "tiff",
    pixel_size_source = NA_character_
  )
}

# Build the output rows (one per channel and plane) for one image series.
meta_rows <- function(path, series_index, s, info, palette, tf) {
  ch <- s$channels
  n_c <- nrow(ch)

  # Fall back to TIFF resolution tags, but only if they are in centimetres:
  # inch-based resolutions are almost always screen/print dpi, not pixel size.
  if (is.na(s$pixel_size) && isTRUE(info$resolution_unit == 3) &&
    !is.na(info$x_resolution) && info$x_resolution > 0) {
    s$pixel_size <- 1e4 / info$x_resolution
    s$pixel_size_source <- "tiff"
  }

  # Palette images without other colour information: use the ColorMap.
  if (palette) {
    for (k in which(is.na(ch$color))) {
      first_page <- s$planes$page[s$planes$c == k][1]
      ch$color[k] <- colormap_color(tiff_tag(tf, first_page, 320))
    }
  }

  sample <- NA_integer_
  if (s$samples == 3) {
    # RGB: each colour sample becomes its own channel.
    ch <- data.frame(
      name = c("red", "green", "blue"),
      fluor = NA_character_,
      color = c("#FF0000", "#00FF00", "#0000FF"),
      source_c = 1L,
      sample = 1:3
    )
  } else {
    ch$source_c <- seq_len(n_c)
    ch$sample <- NA_integer_
  }

  labels <- if (s$samples == 3) ch$name else channel_labels(ch$name, ch$fluor)

  # Long format: one row per channel x plane.
  path_abs <- normalizePath(path, mustWork = TRUE)
  rows <- lapply(seq_len(nrow(ch)), function(k) {
    p <- s$planes[s$planes$c == ch$source_c[k], , drop = FALSE]
    p <- p[order(p$t, p$z), , drop = FALSE]
    img <- new_img(lapply(p$page, function(page) {
      img_source(
        file = path_abs, page = page, sample = ch$sample[k], palette = palette,
        bits = info$bits, size_x = s$size_x, size_y = s$size_y, pixel_size = s$pixel_size
      )
    }))
    tibble::tibble(
      filepath = path,
      series = as.integer(series_index),
      channel_index = k,
      channel = labels[k],
      z = as.integer(p$z),
      t = as.integer(p$t),
      img = img,
      color = ch$color[k],
      channel_name = ch$name[k],
      fluor = ch$fluor[k],
      size_x = as.integer(s$size_x),
      size_y = as.integer(s$size_y),
      size_z = as.integer(s$size_z),
      size_t = as.integer(s$size_t),
      bit_depth = as.integer(info$bits),
      pixel_size = s$pixel_size,
      pixel_unit = if (is.na(s$pixel_size)) NA_character_ else "\u00b5m",
      z_step = s$z_step,
      meta_source = s$meta_source,
      pixel_size_source = s$pixel_size_source
    )
  })
  vctrs::vec_rbind(!!!rows)
}

channel_labels <- function(name, fluor) {
  usable <- function(x) !anyNA(x) && all(nzchar(x)) && !anyDuplicated(x)
  if (usable(fluor)) {
    fluor
  } else if (usable(name)) {
    name
  } else {
    paste0("C", seq_along(name))
  }
}

# Top colour of a TIFF ColorMap (16-bit values, all red then green then blue).
colormap_color <- function(cm) {
  if (is.null(cm) || length(cm) < 3 || length(cm) %% 3 != 0) {
    return(NA_character_)
  }
  n <- length(cm) / 3
  top <- cm[c(n, 2 * n, 3 * n)] %/% 257
  sprintf("#%02X%02X%02X", top[1], top[2], top[3])
}

# Convert a length to micrometres. Returns NA for unknown units.
to_micron <- function(value, unit) {
  if (length(value) == 0 || is.na(value) || is.null(unit) || is.na(unit)) {
    return(NA_real_)
  }
  # Work on code points: regular expressions with the micro sign fail in non-UTF-8 locales.
  # enc2utf8() would mangle UTF-8 strings in a C locale, so only use it for
  # strings that are not UTF-8 already (e.g. latin1).
  cp <- utf8ToInt(if (validUTF8(unit)) unit else enc2utf8(unit))
  if (anyNA(cp)) {
    return(NA_real_)
  }
  cp[cp %in% c(0xB5, 0x3BC)] <- utf8ToInt("u") # micro sign, Greek mu
  cp[cp %in% c(0xC5, 0xE5, 0x212B)] <- utf8ToInt("A") # angstrom
  unit <- tolower(trimws(intToUtf8(cp)))
  unit <- sub("\\u00b5", "u", unit, fixed = TRUE) # ImageJ writes the escape "\\u00B5m" literally
  factor <- switch(
    unit,
    um = ,
    micron = ,
    microns = ,
    micrometer = ,
    micrometre = 1,
    nm = 1e-3,
    pm = 1e-6,
    a = ,
    angstrom = 1e-4,
    mm = 1e3,
    cm = 1e4,
    m = 1e6,
    NA_real_
  )
  value * factor
}
