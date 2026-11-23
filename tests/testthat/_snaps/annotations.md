# annotation verbs validate their arguments

    Code
      add_scale_bar(m, -1)
    Condition
      Error in `add_scale_bar()`:
      ! `length` must be positive numbers (micrometres) or `NULL`.
    Code
      add_scale_bar(m, c(1, 2))
    Condition
      Error in `add_scale_bar()`:
      ! Several lengths in `length` must be named by view, e.g. `c(crop = 10, zoom = 2)`.
    Code
      add_scale_bar(m, where = "first")
    Condition
      Error in `add_scale_bar()`:
      ! `where` must be one of "last", "all", or "merge", not "first".
    Code
      add_scale_bar(m, color = "notacolour")
    Condition
      Error in `add_scale_bar()`:
      ! `color` must be a single valid colour.
    Code
      add_scale_bar(m, outline = "notacolour")
    Condition
      Error in `add_scale_bar()`:
      ! `outline` must be a single valid colour.
    Code
      adjust_headers(m, size = 0)
    Condition
      Error in `adjust_headers()`:
      ! `size` must be a single positive number.

