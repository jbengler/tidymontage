# add_merge() validates merge colours

    Code
      add_merge(m, C1, C2, colors = "red")
    Condition
      Error in `add_merge()`:
      ! `colors` must be named by channel, e.g. `c(GFP = "red")`.
    Code
      add_merge(m, C1, C2, colors = c(C3 = "red"))
    Condition
      Error in `add_merge()`:
      ! `colors` names "C3", which is not in the merge.
    Code
      add_merge(m, C1, C2, colors = c(C2 = "notacolour"))
    Condition
      Error in `add_merge()`:
      ! The colour for "C2" in `colors` must be a single valid colour.

