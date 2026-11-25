# Set global defaults for montages

Like `tidyplots_options()` in tidyplots, `tidymontage_options()` sets
defaults for the rest of the session, for example the size of all
montages in a report. Arguments given to
[`tidymontage()`](https://jbengler.github.io/tidymontage/reference/tidymontage.md)
or
[`adjust_size()`](https://jbengler.github.io/tidymontage/reference/adjust_size.md)
still take precedence.

## Usage

``` r
tidymontage_options(width = NULL, height = NULL, units = NULL, gap = NULL)
```

## Arguments

- width, height:

  Size of the box the panel grid fits into, see
  [`adjust_size()`](https://jbengler.github.io/tidymontage/reference/adjust_size.md).
  One of them can be `NA`. Package default: 90 x 90 mm.

- units:

  Units of `width` and `height`: `"mm"`, `"cm"` or `"in"`. Package
  default: `"mm"`.

- gap:

  Gap between panels in mm. Package default: 1.

## Value

The previous options, invisibly, as a list that can be passed to
[`options()`](https://rdrr.io/r/base/options.html) to restore them.

## Details

Each call sets all options at once, as in tidyplots: options not given
are reset to the package defaults. Calling `tidymontage_options()`
without arguments resets all of them.

## Examples

``` r
old <- tidymontage_options(width = 140, height = 140)
# ... montages are now fitted into 140 x 140 mm ...
options(old)

# back to the package defaults
tidymontage_options()
```
