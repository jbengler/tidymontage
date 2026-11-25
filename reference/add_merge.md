# Add a merge of channels

Adds a merged image of several channels as a new, virtual channel. It
can be placed in the layout like any other channel, e.g. a row
`GFP | Cy3 | merge` with `layout_grid(x = channel)`.

## Usage

``` r
add_merge(montage, ..., name = "merge", colors = NULL)
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

  Name of the merged channel, as it appears in the layout and in labels.

- colors:

  Colours of member channels in this merge only, as a named vector, e.g.
  `c(GFP = "red")`. Members not named keep their channel colour (or, if
  that is black, their original colour).

## Value

The montage with the merge step added.

## Details

Merges are always drawn on a black background: each member channel is
shown with its own colour and display range, and the colours are added
up like light. Member channels don't need their own panels.

A channel coloured black (`"#000000"`) is shown inverted in its own
panels, as dark signal on white. A channel coloured with a colormap
([`lut()`](https://jbengler.github.io/tidymontage/reference/lut.md)) is
shown with its map. Merges need single colours: in a merge, such
channels use their original colour from the image metadata (the `color`
column) instead, unless `colors` sets one.

A merge combines the images that would share a panel apart from their
channel, typically the channels of one file. Every panel of the merge
needs exactly one image of each member channel.

## Examples

``` r
if (FALSE) { # \dontrun{
montage |>
  add_merge(GFP, Cy3, name = "merge")

# both channels inverted on their own; in the merge, Cy3 in its original
# colour and GFP in green
montage |>
  adjust_colors(Cy3 = "black", GFP = "black") |>
  add_merge(Cy3, GFP, colors = c(GFP = "green"))
} # }
```
