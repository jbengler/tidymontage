# Add an overlay of channels

Adds a panel that shows where channels coincide: a single-colour image
that is bright only where all member channels are bright. It is computed
as the minimum of the members' display-scaled intensities (0 to 1 within
their display ranges), so it is "as bright as the weakest channel". Like
a merge, an overlay is a new, virtual channel that can be placed in the
layout like any other channel.

## Usage

``` r
add_overlay(montage, ..., name = "overlay", color = "white", threshold = NULL)
```

## Arguments

- montage:

  A
  [`tidymontage()`](https://jbengler.github.io/tidymontage/reference/tidymontage.md)
  object.

- ...:

  Channels to merge, as bare names or strings. Use backticks or strings
  for names with spaces, e.g. `` `Alexa Fluor 488` ``.

- name:

  Name of the overlay, as it appears in the layout and in labels.

- color:

  Colour of the overlay. `"black"` shows it inverted, as dark signal on
  white. A colormap made with
  [`lut()`](https://jbengler.github.io/tidymontage/reference/lut.md),
  such as `lut("inferno")`, colours the overlay by its strength.

- threshold:

  Optional threshold between 0 and 1 on the overlay intensity: pixels
  below it are shown as background. `NULL` (the default) shows the
  overlay as it is.

## Value

The montage with the overlay step added.

## Details

The overlay keeps the 0-1 scale it inherits and is not stretched again,
so a faint overlap looks faint. Because it depends on the display
ranges, keep them linked (the default of
[`adjust_exposure()`](https://jbengler.github.io/tidymontage/reference/adjust_exposure.md))
when comparing conditions.

## Examples

``` r
if (FALSE) { # \dontrun{
montage |>
  add_overlay(GFP, Cy3, name = "overlap", color = "yellow")
} # }
```
