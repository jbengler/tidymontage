# Crop the images

`add_crop()` shows a region of each image instead of the full image. The
size of the region is the same for all images, so all panels share the
same magnification; only its position can differ between images.

## Usage

``` r
add_crop(
  montage,
  width,
  height = width,
  center = c(0.5, 0.5),
  units = c("um", "px"),
  center_units = c("rel", "px"),
  name = "crop",
  angle = NULL
)
```

## Arguments

- montage:

  A
  [`tidymontage()`](https://jbengler.github.io/tidymontage/reference/tidymontage.md)
  object.

- width, height:

  Size of the region. In micrometres by default, which keeps the
  magnification equal even if images have different pixel sizes.

- center:

  Position of the region's center: a numeric vector `c(x, y)` used for
  all images, or a data frame with columns `x`, `y` and one or more
  columns of the images tibble to match on, e.g. `condition` or
  `filepath`. The data frame can also have an `angle` column, for a
  different angle per image.

- units:

  Units of `width` and `height`: `"um"` (micrometres, needs a known
  pixel size) or `"px"` (pixels).

- center_units:

  Units of `center`: `"rel"` (relative, 0-1) or `"px"`.

- name:

  Name of the view in the layout.

- angle:

  Rotation of the region in degrees, counterclockwise, as Fiji measures
  the angle of a line. `NULL` (the default) means no rotation, unless
  `center` has an `angle` column.

## Value

The montage with the crop step added.

## Details

Positions are given as the **center** of the region, either one position
for all images or a data frame with one position per image or group. By
default, positions are relative to the full image (`0` = left or top
edge, `1` = right or bottom edge); with `center_units = "px"` they are
pixel coordinates of the full image, counted from 0 as in ImageJ / Fiji.

Display ranges are always computed from the full images, so moving a
crop doesn't change brightness.

A montage has one crop: calling `add_crop()` again replaces the earlier
crop. Use
[`add_zoom()`](https://jbengler.github.io/tidymontage/reference/add_zoom.md)
for further regions.

With `angle`, the region is rotated, for structures that run at an
angle, such as a neurite. The angle is the one Fiji reports for a line
drawn along the structure (*Analyze \> Measure*): in degrees,
counterclockwise. The region's width runs along that line, and the panel
shows it upright, so the structure lies horizontal. Rotated regions are
sampled with bilinear interpolation, at the original pixel size. Unlike
upright regions, they are not moved inside the image: all their corners
must lie within it.

## Examples

``` r
if (FALSE) { # \dontrun{
centers <- tibble::tibble(condition = c("ctrl", "ko"), x = c(0.4, 0.6), y = c(0.5, 0.3))
montage |> add_crop(width = 40, center = centers)

# rotated, with an angle per image
centers$angle <- c(30, -15)
montage |> add_crop(width = 40, center = centers)
} # }
```
