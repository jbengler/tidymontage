# Panels of a montage

Returns the panels of a montage as a tibble: their panel dimensions,
grid position, rectangle in mm (measured from the top-left corner of the
figure) and the region of the source image they show. No pixels are
read, so this is a quick way to check a layout.

## Usage

``` r
get_panels(montage)
```

## Arguments

- montage:

  A
  [`tidymontage()`](https://jbengler.github.io/tidymontage/reference/tidymontage.md)
  object.

## Value

A tibble with one row per panel.

## Details

The region is given in pixels (`px_xmin` ... `px_ymax`, 1-based) and as
`angle`. For rotated regions (`angle` not 0), the pixel columns describe
the region before it is rotated about its center.
