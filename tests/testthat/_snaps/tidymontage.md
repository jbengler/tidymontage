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
      tidymontage(example_images(), x = genotype)
    Condition
      Error in `tidymontage()`:
      ! Can't map `x` to `genotype`.
      Caused by error:
      ! object 'genotype' not found
    Code
      tidymontage(example_images(), x = 1:3)
    Condition
      Error in `tidymontage()`:
      ! `x` must have length 1 or 4 (the number of images).
      x `1:3` has length 3.
    Code
      tidymontage(example_images(), layout = "grid")
    Condition
      Error in `tidymontage()`:
      ! Layouts are not implemented yet, `layout` must be `NULL`.

