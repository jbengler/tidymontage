# layouts explain what is wrong

    Code
      get_panels(adjust_layout(m, x = channel))
    Condition
      Error in `get_panels()`:
      ! 2 images would share one panel (channel = DAPI).
      i Each panel shows one image. Summarise z-slices or time points first, e.g. `summarise(img = max(img), .by = ...)`, or map another column such as filepath to `x` or `y`.
    Code
      adjust_layout(m, x = channel, y = channel)
    Condition
      Error in `adjust_layout()`:
      ! channel can't be mapped to both `x` and `y`.
    Code
      tidymontage(example_images(), x = genotype)
    Condition
      Error in `tidymontage()`:
      ! Can't find genotype for `x`.
      i Use columns of the images tibble or view.
    Code
      tidymontage(example_images(), x = channel + 1)
    Condition
      Error in `tidymontage()`:
      ! `x` must be a column name or `c()` of column names, not `channel + 1`.
    Code
      tidymontage(example_images(), colour = "red")
    Condition
      Error in `tidymontage()`:
      ! Unknown argument or panel dimension: colour.
      i Arguments in `...` choose levels of columns of the images tibble, channel or view.
    Code
      tidymontage(example_images(), layout = "mosaic")
    Condition
      Error in `tidymontage()`:
      ! `layout` must be "grid", "hero", or created with `layout_grid()` or `layout_hero()`.
    Code
      tidymontage(example_images(), gap = -1)
    Condition
      Error in `tidymontage()`:
      ! `gap` must be a single non-negative number (mm).
    Code
      get_panels(tidymontage(example_images(), x = channel, channel = "RFP"))
    Condition
      Error in `get_panels()`:
      ! No images left after choosing levels.
    Code
      layout_hero(hero = list(channel = "merge"))
    Condition
      Error in `layout_hero()`:
      ! `hero` must be created with `panel()`.
    Code
      panel("merge")
    Condition
      Error in `panel()`:
      ! All arguments of `panel()` must be named with a panel dimension, e.g. `channel = "merge"`.

