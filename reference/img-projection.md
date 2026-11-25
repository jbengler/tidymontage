# Project images

Use [`max()`](https://rdrr.io/r/base/Extremes.html),
[`min()`](https://rdrr.io/r/base/Extremes.html) and
[`mean()`](https://rdrr.io/r/base/mean.html) on an image vector to
combine several images into one, typically a z-projection inside
[`summarise()`](https://dplyr.tidyverse.org/reference/summarise.html).
The result is lazy: pixels are read and combined plane by plane when the
montage is rendered.

## Usage

``` r
# S3 method for class 'tidymontage_img'
Summary(..., na.rm = FALSE)

# S3 method for class 'tidymontage_img'
mean(x, ...)
```

## Arguments

- na.rm:

  Ignored.

- x, ...:

  Image vectors.

## Value

An image vector of length 1.

## Examples

``` r
if (FALSE) { # \dontrun{
read_images("stack.ome.tif") |>
  dplyr::summarise(img = max(img), .by = c(filepath, channel))
} # }
```
