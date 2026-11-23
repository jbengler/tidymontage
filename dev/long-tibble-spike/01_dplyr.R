suppressMessages({devtools::load_all(quiet = TRUE); library(dplyr)})
source("dev/long-tibble-spike/img.R")
options(width = 120)

stack <- read_images("demo_images/DIV14Actin-01-Airyscan Processing-02.tif") |> as_long()
cat("long stack:", nrow(stack), "rows\n")
print(select(stack, channel, z, t, img), n = 6)

cat("\n-- filter / arrange / slice keep the class:\n")
f <- stack |> filter(z %in% 2:4) |> arrange(desc(z)) |> slice(1:3)
print(class(f$img)); print(format(f$img))

cat("\n-- summarise(max, .by):\n")
proj <- stack |> filter(t == 1) |> summarise(img = max(img), .by = c(filepath, channel, color))
print(select(proj, channel, img))

cat("\n-- mean projection:\n")
print(format(summarise(stack, img = mean(img), .by = channel)$img))

cat("\n-- mutate(exposure, .by = channel):\n")
ex <- proj |> mutate(img = exposure(img, "p0.1", "p99.9"), .by = channel)
print(select(ex, channel, img))
recs <- vctrs::vec_data(ex$img)
cat("one range env per channel:", length(unique(lapply(recs, function(r) r$range))), "\n")

cat("\n-- mutate(exposure) without .by -> one shared env:\n")
ex_all <- proj |> mutate(img = exposure(img))
cat("distinct envs:", length(unique(lapply(vctrs::vec_data(ex_all$img), function(r) r$range))), "\n")

cat("\n-- bind_rows and count:\n")
b <- bind_rows(proj, proj)
print(class(b$img)); print(count(b, channel))

cat("\n-- unsupported summary:\n")
print(tryCatch(summarise(stack, img = sum(img), .by = channel), error = conditionMessage))

cat("\n-- materialise max projection of channel 1:\n")
cache <- new.env()
t0 <- Sys.time(); m <- materialize(vctrs::vec_data(proj$img)[[1]]$node, cache); print(Sys.time() - t0)
print(dim(m)); print(range(m))
cat("range p0.1-p99.9 for channel 1:", range_value(recs[[1]]$range, cache), "\n")
