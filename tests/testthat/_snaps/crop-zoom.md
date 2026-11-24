# add_crop() and add_zoom() validate their arguments

    Code
      add_crop(m, width = -1)
    Condition
      Error in `add_crop()`:
      ! `width` must be a single positive number.
    Code
      add_crop(m, width = 1, center = c(0.5, 2))
    Condition
      Error in `add_crop()`:
      ! Relative `center` values must be between 0 and 1.
    Code
      add_crop(m, width = 1, center = 0.5)
    Condition
      Error in `add_crop()`:
      ! `center` must be `c(x, y)` or a data frame.
    Code
      add_crop(m, width = 1, center = data.frame(x = 0.5))
    Condition
      Error in `add_crop()`:
      ! A `center` data frame needs numeric columns x and y.
    Code
      add_crop(m, width = 1, center = data.frame(genotype = "a", x = 0.5, y = 0.5))
    Condition
      Error in `add_crop()`:
      ! `center` has column genotype that is not in the images tibble.
    Code
      add_crop(m, width = 1, units = "mm")
    Condition
      Error in `add_crop()`:
      ! `units` must be one of "um" or "px", not "mm".
      i Did you mean "um"?
    Code
      add_zoom(m, width = 1, name = "full")
    Condition
      Error in `add_zoom()`:
      ! The view name "full" is already used.
    Code
      add_zoom(add_zoom(m, width = 1), width = 2)
    Condition
      Error in `add_zoom()`:
      ! The view name "zoom" is already used.
    Code
      add_zoom(m, width = 1, box = "some")
    Condition
      Error in `add_zoom()`:
      ! `box` must be one of "all", "merge", or "none", not "some".
      i Did you mean "none"?

