# Adjust the layout of a montage

Changes the mapping, the level choices, the layout or the gap of a
montage after
[`tidymontage()`](https://jbengler.github.io/tidymontage/reference/tidymontage.md).
Only the arguments you give are changed.

## Usage

``` r
adjust_layout(montage, x, y, ..., layout, gap)
```

## Arguments

- montage:

  A
  [`tidymontage()`](https://jbengler.github.io/tidymontage/reference/tidymontage.md)
  object.

- x, y:

  Columns mapped to the columns (`x`) and rows (`y`) of the montage: a
  bare name such as `condition`, or several with
  [`c()`](https://rdrr.io/r/base/c.html) (the first one varies slowest).
  In the grid layout, `channel` and `view` can be mapped too.

- ...:

  Choose and order the levels of panel dimensions, for example
  `channel = c("GFP", "DAPI")` or `condition = "ctrl"`.

- layout:

  `"grid"` (the default) or `"hero"`, or a layout created with
  [`layout_grid()`](https://jbengler.github.io/tidymontage/reference/layouts.md)
  or
  [`layout_hero()`](https://jbengler.github.io/tidymontage/reference/layouts.md).

- gap:

  Gap between panels in mm. `NULL` (the default) uses
  [`tidymontage_options()`](https://jbengler.github.io/tidymontage/reference/tidymontage_options.md),
  or 1.

## Value

The montage with the layout step added.

## Examples

``` r
if (FALSE) { # \dontrun{
montage |> adjust_layout(layout = "hero")
montage |> adjust_layout(x = channel, y = condition)
} # }
```
