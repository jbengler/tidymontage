# tidymontage() validates its inputs

    Code
      tidymontage("not a data frame")
    Condition
      Error in `tidymontage()`:
      ! `images` must be a data frame, not a string.
    Code
      tidymontage(example_images()[, "filepath"])
    Condition
      Error in `tidymontage()`:
      ! `images` must contain the columns filepath, channel, and img.
      x Missing: channel and img.
    Code
      tidymontage(transform(example_images(), img = 1:4))
    Condition
      Error in `tidymontage()`:
      ! Column img must be an image vector, not an integer vector.
      i Create images with `read_images()`.
    Code
      tidymontage(dplyr::mutate(example_images(), filepath = 1:4))
    Condition
      Error in `tidymontage()`:
      ! Column filepath must be a character vector, not an integer vector.
    Code
      tidymontage(dplyr::mutate(example_images(), view = "a"))
    Condition
      Error in `tidymontage()`:
      ! `images` can't have a column named view: it is reserved for the montage views.

