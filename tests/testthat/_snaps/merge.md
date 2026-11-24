# add_merge() validates its arguments

    Code
      add_merge(m, DAPI)
    Condition
      Error in `add_merge()`:
      ! A merge needs at least two channels.
    Code
      add_merge(m, DAPI, RFP)
    Condition
      Error in `add_merge()`:
      ! Unknown channel: "RFP".
      i Available channels: "DAPI" and "GFP".
    Code
      add_merge(m, DAPI, GFP, name = "DAPI")
    Condition
      Error in `add_merge()`:
      ! `name` "DAPI" is already used by a channel, merge or overlay.
    Code
      add_merge(add_merge(m, DAPI, GFP), DAPI, GFP)
    Condition
      Error in `add_merge()`:
      ! `name` "merge" is already used by a channel, merge or overlay.
    Code
      add_merge(m, DAPI, GFP, name = "")
    Condition
      Error in `add_merge()`:
      ! `name` must be a single non-empty string.
    Code
      add_merge(m, DAPI, 1 + 1)
    Condition
      Error in `add_merge()`:
      ! Channels in `...` must be names or strings, not `1 + 1`.

# merges need one image of each member per panel

    Code
      montage_panels(adjust_layout(m, x = channel))
    Condition
      Error in `montage_panels()`:
      ! Merge "merge" would combine several "DAPI" and "GFP" images.
      i Map another column, such as filepath, to `x` or `y`, or summarise z-slices first.
    Code
      montage_panels((function(x) {
        x$images <- x$images[-4, ]
        x
      })(adjust_layout(m, x = channel, y = condition, condition = "ko")))
    Condition
      Error in `montage_panels()`:
      ! Merge "merge" needs "DAPI" and "GFP", but "GFP" is missing (condition = ko).

