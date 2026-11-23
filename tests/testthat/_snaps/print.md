# format() summarises the steps

    Code
      cat(format(m), sep = "\n")
    Output
      <tidymontage> 4 images from 2 files, 2 channels
      tidymontage(images)
      steps:
        (none)

---

    Code
      cat(format(m), sep = "\n")
    Output
      <tidymontage> 4 images from 2 files, 2 channels
      tidymontage(images)
      steps:
        1. adjust_colors(DAPI = "#0072B2")
        2. adjust_exposure(min = 0, max = "p99", GFP = c("p1", 4000), .by = c(channel, condition))
        3. adjust_layout(x = condition, y = channel, channel = c("GFP", "DAPI"))

