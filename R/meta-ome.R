# OME-XML metadata, as written into the first ImageDescription of OME-TIFFs.

is_ome_xml <- function(raw) {
  if (is.null(raw)) {
    return(FALSE)
  }
  head <- rawToChar(raw[seq_len(min(length(raw), 2000))])
  grepl("<OME", head, fixed = TRUE)
}

# Parse OME-XML (raw bytes) into a list with one element per image (series).
ome_parse <- function(xml_raw, path, n_pages, call = rlang::caller_env()) {
  # Parse from raw bytes: going through a character string breaks non-ASCII
  # characters such as the micro sign in non-UTF-8 locales.
  doc <- tryCatch(
    xml2::read_xml(xml_raw),
    error = function(cnd) {
      cli::cli_abort("Can't parse the OME-XML metadata of {.file {path}}.", parent = cnd, call = call)
    }
  )
  xml2::xml_ns_strip(doc)
  images <- xml2::xml_find_all(doc, "/OME/Image")
  if (length(images) == 0) {
    cli::cli_abort("The OME-XML of {.file {path}} describes no images.", call = call)
  }
  lapply(seq_along(images), function(i) ome_parse_image(images[[i]], path, n_pages, call))
}

ome_parse_image <- function(image, path, n_pages, call) {
  px <- xml2::xml_find_first(image, "Pixels")
  attr_int <- function(node, name, default = NA_integer_) {
    v <- suppressWarnings(as.integer(xml2::xml_attr(node, name)))
    if (is.na(v)) default else v
  }
  attr_num <- function(node, name) suppressWarnings(as.numeric(xml2::xml_attr(node, name)))
  attr_chr <- function(node, name, default = NA_character_) {
    v <- xml2::xml_attr(node, name)
    if (is.na(v)) default else v
  }

  size_c <- attr_int(px, "SizeC", 1L)
  size_z <- attr_int(px, "SizeZ", 1L)
  size_t <- attr_int(px, "SizeT", 1L)
  dim_order <- attr_chr(px, "DimensionOrder", "XYCZT")

  ch_nodes <- xml2::xml_find_all(px, "Channel")
  spp <- if (length(ch_nodes) > 0) attr_int(ch_nodes[[1]], "SamplesPerPixel", 1L) else 1L
  # For RGB data, SizeC counts samples; planes are per channel node.
  n_plane_c <- max(1L, size_c %/% spp)

  channels <- data.frame(
    name = vapply(seq_len(n_plane_c), function(k) {
      if (k <= length(ch_nodes)) attr_chr(ch_nodes[[k]], "Name") else NA_character_
    }, character(1)),
    fluor = vapply(seq_len(n_plane_c), function(k) {
      if (k <= length(ch_nodes)) attr_chr(ch_nodes[[k]], "Fluor") else NA_character_
    }, character(1)),
    color = vapply(seq_len(n_plane_c), function(k) {
      if (k <= length(ch_nodes)) ome_color(xml2::xml_attr(ch_nodes[[k]], "Color")) else NA_character_
    }, character(1))
  )

  planes <- ome_planes(px, dim_order, c(C = n_plane_c, Z = size_z, T = size_t), path, n_pages, call)

  list(
    size_x = attr_int(px, "SizeX"),
    size_y = attr_int(px, "SizeY"),
    size_z = size_z,
    size_t = size_t,
    samples = spp,
    pixel_size = to_micron(attr_num(px, "PhysicalSizeX"), attr_chr(px, "PhysicalSizeXUnit", "\u00b5m")),
    z_step = to_micron(attr_num(px, "PhysicalSizeZ"), attr_chr(px, "PhysicalSizeZUnit", "\u00b5m")),
    channels = channels,
    planes = planes
  )
}

# Map every (c, z, t) plane to a page (1-based IFD index) using
# DimensionOrder and the TiffData elements.
ome_planes <- function(px, dim_order, sizes, path, n_pages, call) {
  order <- strsplit(substr(dim_order, 3, 5), "")[[1]]
  if (!setequal(order, c("C", "Z", "T"))) {
    cli::cli_abort("Unknown DimensionOrder {.val {dim_order}} in {.file {path}}.", call = call)
  }
  grid <- expand.grid(
    a = seq_len(sizes[[order[1]]]),
    b = seq_len(sizes[[order[2]]]),
    d = seq_len(sizes[[order[3]]])
  )
  names(grid) <- order
  grid <- grid[, c("C", "Z", "T")]
  n_planes <- nrow(grid)
  page <- rep(NA_real_, n_planes)

  tiff_data <- xml2::xml_find_all(px, "TiffData")
  file_names <- unique(stats::na.omit(xml2::xml_attr(xml2::xml_find_all(tiff_data, "UUID"), "FileName")))
  if (length(file_names) > 1) {
    cli::cli_abort(
      c(
        "Multi-file OME-TIFFs are not supported yet.",
        "i" = "{.file {path}} references {length(file_names)} files."
      ),
      call = call
    )
  }

  if (length(tiff_data) == 0) {
    page <- seq_len(n_planes)
  } else {
    plane_index <- function(c0, z0, t0) {
      which(grid$C == c0 + 1 & grid$Z == z0 + 1 & grid$T == t0 + 1)
    }
    for (i in seq_along(tiff_data)) {
      td <- tiff_data[[i]]
      num <- function(name) suppressWarnings(as.numeric(xml2::xml_attr(td, name)))
      ifd <- num("IFD")
      first <- c(num("FirstC"), num("FirstZ"), num("FirstT"))
      first[is.na(first)] <- 0
      k0 <- plane_index(first[1], first[2], first[3])
      if (length(k0) == 0) {
        next
      }
      count <- num("PlaneCount")
      if (is.na(count)) {
        count <- if (is.na(ifd)) n_planes - k0 + 1 else 1
      }
      if (is.na(ifd)) ifd <- 0
      k <- k0 + seq_len(count) - 1
      keep <- k <= n_planes
      page[k[keep]] <- ifd + seq_len(count)[keep]
    }
  }

  if (anyNA(page) || any(page > n_pages)) {
    cli::cli_abort(
      "The OME-XML of {.file {path}} does not map all {n_planes} planes to the {n_pages} pages of the file.",
      call = call
    )
  }
  data.frame(c = grid$C, z = grid$Z, t = grid$T, page = as.integer(page))
}

# OME colours are signed 32-bit RGBA integers.
ome_color <- function(x) {
  v <- suppressWarnings(as.numeric(x))
  if (length(v) == 0 || is.na(v)) {
    return(NA_character_)
  }
  if (v < 0) v <- v + 2^32
  sprintf("#%02X%02X%02X", (v %/% 2^24) %% 256, (v %/% 2^16) %% 256, (v %/% 2^8) %% 256)
}
