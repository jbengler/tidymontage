# Test if an object is an image vector

Image vectors are the `img` column of
[`read_images()`](https://jbengler.github.io/tidymontage/reference/read_images.md).
Each element is a lazy reference to a greyscale image: a plane in a
file, or a projection of several planes. Pixels are only read when a
montage is rendered.

## Usage

``` r
is_img(x)
```

## Arguments

- x:

  An object.

## Value

`TRUE` if `x` is an image vector, otherwise `FALSE`.
