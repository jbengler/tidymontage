# Adjust the size of a montage

Like plots in tidyplots, montages have a fixed physical size, so that
they look the same on screen and in every saved file. The size refers to
the grid of panels (panels and the gaps between them); headers are added
outside of it.

## Usage

``` r
adjust_size(montage, width = NULL, height = NULL, units = NULL)
```

## Arguments

- montage:

  A
  [`tidymontage()`](https://jbengler.github.io/tidymontage/reference/tidymontage.md)
  object.

- width, height:

  Size of the box the panel grid has to fit into. One of them can be
  `NA`. `NULL` uses
  [`tidymontage_options()`](https://jbengler.github.io/tidymontage/reference/tidymontage_options.md),
  or 90 mm.

- units:

  Units of `width` and `height`: `"mm"`, `"cm"` or `"in"`. `NULL` uses
  [`tidymontage_options()`](https://jbengler.github.io/tidymontage/reference/tidymontage_options.md),
  or `"mm"`.

## Value

The montage with the size step added.

## Details

The panel grid is scaled to fit into a box of `width` x `height`,
keeping the shape of the panels: depending on the layout, one side of
the grid will be shorter than the box. Use `NA` for one of them to
constrain only the other side. The default is a box of 90 x 90 mm;
change it for all montages with
[`tidymontage_options()`](https://jbengler.github.io/tidymontage/reference/tidymontage_options.md).

## Examples

``` r
if (FALSE) { # \dontrun{
montage |> adjust_size(width = 180, height = NA)
} # }
```
