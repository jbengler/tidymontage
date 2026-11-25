# Choose panels for a layout

`panel()` picks panels by the levels of panel dimensions, for the `hero`
and `side` arguments of
[`layout_hero()`](https://jbengler.github.io/tidymontage/reference/layouts.md).

## Usage

``` r
panel(...)
```

## Arguments

- ...:

  Name-value pairs of panel dimensions and levels, e.g.
  `channel = "merge"`, `view = "crop"` or `channel = c("GFP", "DAPI")`.
  The order of the levels sets the order of the panels.

## Value

A panel specification.

## Examples

``` r
panel(channel = "merge", view = "crop")
#> $channel
#> [1] "merge"
#> 
#> $view
#> [1] "crop"
#> 
#> attr(,"class")
#> [1] "tidymontage_panel"
```
