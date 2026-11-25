# Preview exposure options

Shows one image of a channel with 25 combinations of display ranges,
ordered by how the image looks: from left to right it gets brighter (the
upper end, `max`, decreases), from top to bottom the background gets
darker (the lower end, `min`, increases). The outlined panel is the
current setting of the montage (see
[`adjust_exposure()`](https://jbengler.github.io/tidymontage/reference/adjust_exposure.md)),
surrounded by up to two steps in each direction; at the ends of the
scale (e.g. `min = "p0"`) it moves off the middle. Read off the
percentiles of the panel you like and set them with
[`adjust_exposure()`](https://jbengler.github.io/tidymontage/reference/adjust_exposure.md).

## Usage

``` r
preview_exposure(montage, channel, ...)
```

## Arguments

- montage:

  A
  [`tidymontage()`](https://jbengler.github.io/tidymontage/reference/tidymontage.md)
  object.

- channel:

  The channel to preview. Can be left out if the montage has one channel
  only.

- ...:

  Conditions that pick one image of the channel, as in
  [`dplyr::filter()`](https://dplyr.tidyverse.org/reference/filter.html),
  e.g. `mutant == "L59A"`. By default, the brightest image is shown.

## Value

A montage with the options. Print it to see them.

## Details

The percentiles are computed from all images of the channel, as in the
montage, so the preview looks like the final figure. Repeat the preview
after adjusting the exposure to refine it further.

## Examples

``` r
if (FALSE) { # \dontrun{
montage |> preview_exposure("Cy3")
montage |> preview_exposure("Cy3", mutant == "L59A")
} # }
```
