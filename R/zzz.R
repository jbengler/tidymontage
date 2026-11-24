# tidylayouts integration --------------------------------------------------
#
# tidylayouts (in Suggests) places any object with an `as_layout_gtable()`
# method in a layout and aligns it on its "panel" track. For a montage that
# is the image grid; headers, legends and labels are decoration. The method
# is registered when tidylayouts is loaded, so neither package depends on
# the other.

as_layout_gtable.tidymontage <- function(x, ...) {
  montage_gtable(x, dpi = 300)
}

.onLoad <- function(libname, pkgname) {
  s3_register("tidylayouts::as_layout_gtable", "tidymontage")
  invisible()
}

# Register an S3 method for a generic in a suggested package, now or as soon
# as that package is loaded. From vctrs (`vctrs::s3_register()`, MIT).
s3_register <- function(generic, class, method = NULL) {
  stopifnot(is.character(generic), length(generic) == 1)
  stopifnot(is.character(class), length(class) == 1)

  pieces <- strsplit(generic, "::")[[1]]
  stopifnot(length(pieces) == 2)
  package <- pieces[[1]]
  generic <- pieces[[2]]

  caller <- parent.frame()

  get_method_env <- function() {
    top <- topenv(caller)
    if (isNamespace(top)) asNamespace(environmentName(top)) else caller
  }
  get_method <- function(method) {
    if (is.null(method)) {
      get(paste0(generic, ".", class), envir = get_method_env())
    } else {
      method
    }
  }

  register <- function(...) {
    envir <- asNamespace(package)
    # refresh the method each time: it might have changed (load_all())
    method_fn <- get_method(method)
    stopifnot(is.function(method_fn))
    # only register if the generic exists (older versions may lack it)
    if (exists(generic, envir)) {
      registerS3method(generic, class, method_fn, envir = envir)
    }
  }

  setHook(packageEvent(package, "onLoad"), function(...) register())
  if (isNamespaceLoaded(package)) register()
  invisible()
}
