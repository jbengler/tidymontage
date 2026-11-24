# add_overlay() validates and prints

    Code
      add_overlay(m, C1)
    Condition
      Error in `add_overlay()`:
      ! An overlay needs at least two channels.
    Code
      add_overlay(m, C1, C9)
    Condition
      Error in `add_overlay()`:
      ! Unknown channel: "C9".
      i Available channels: "C1" and "C2".
    Code
      add_overlay(m, C1, C2, color = "notacolour")
    Condition
      Error in `add_overlay()`:
      ! `color` must be a single valid colour or a LUT, not a string.
    Code
      add_overlay(m, C1, C2, threshold = 2)
    Condition
      Error in `add_overlay()`:
      ! `threshold` must be a single number between 0 and 1, or `NULL`.
    Code
      add_overlay(add_merge(m, C1, C2, name = "both"), C1, C2, name = "both")
    Condition
      Error in `add_overlay()`:
      ! `name` "both" is already used by a channel, merge or overlay.

