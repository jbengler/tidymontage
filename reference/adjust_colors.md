# Adjust channel colours

Set the colour of channels by name. Colours are a display property: by
default, each image is shown in the colour of its `color` column, which
[`read_images()`](https://jbengler.github.io/tidymontage/reference/read_images.md)
fills from the microscope metadata. `adjust_colors()` overrides it for
the channels you name.

## Usage

``` r
adjust_colors(montage, ...)
```

## Arguments

- montage:

  A
  [`tidymontage()`](https://jbengler.github.io/tidymontage/reference/tidymontage.md)
  object.

- ...:

  Name-value pairs of channel names and colours, for example
  `DAPI = "#0072B2"`. Colours can be any colour R understands, such as
  hex strings or names like `"white"`, or colormaps made with
  [`lut()`](https://jbengler.github.io/tidymontage/reference/lut.md),
  for example `GCaMP = lut("magma")`.

## Value

The montage with the colour step added.

## Details

Instead of a single colour, a channel can get a colormap such as magma
or viridis with
[`lut()`](https://jbengler.github.io/tidymontage/reference/lut.md). In
merges, such a channel uses its original colour (see
[`add_merge()`](https://jbengler.github.io/tidymontage/reference/add_merge.md)).

## Examples

``` r
if (FALSE) { # \dontrun{
montage |> adjust_colors(DAPI = "#0072B2", GFP = "#009E73")
montage |> adjust_colors(GCaMP = lut("magma"))
} # }
```
