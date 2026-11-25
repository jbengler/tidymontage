# Adjust the row and column headers

Headers name the levels mapped to `x` (above the columns) and `y` (left
of the rows). When several dimensions share an axis, headers are nested:
the outer level spans the columns or rows it contains.

## Usage

``` r
adjust_headers(montage, x = TRUE, y = TRUE, size = 7, color = "black")
```

## Arguments

- montage:

  A
  [`tidymontage()`](https://jbengler.github.io/tidymontage/reference/tidymontage.md)
  object.

- x, y:

  Show the column (`x`) and row (`y`) headers?

- size:

  Text size in points.

- color:

  Text colour.

## Value

The montage with the header step added.

## Examples

``` r
if (FALSE) { # \dontrun{
montage |> adjust_headers(y = FALSE, size = 8)
} # }
```
