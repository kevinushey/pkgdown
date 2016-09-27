#' Render complete page.
#'
#' @param package Path to package to document.
#' @param name Name of the template (e.g. index, demo, topic)
#' @param data Data for the template. Package metadata is always automatically
#'   added to this list under key \code{package}.
#' @param path Location to create file. If \code{""} (the default),
#'   prints to standard out.
#' @param depth Depth of path relative to base directory. Used to
#'   adjust links in navbar, and to provide template variable \code{root_path}.
#' @export
render_page <- function(package, name, data, path = "", depth = 0L) {
  package <- as_staticdocs(package)

  # Set up path to root docs
  data$root_path <- paste(rep.int("../", depth), collapse = "")

  # render template components
  pieces <- c("head", "header", "content", "footer")
  components <- lapply(pieces, render_template, package = package, name, data)
  names(components) <- pieces

  components$navbar <- package$navbar(depth)

  # render complete layout
  out <- render_template(package, "layout", name, components)
  write_if_different(out, path)
}

render_template <- function(package, type, name, data) {
  data$package <- package$package
  data$meta <- package$meta

  template <- readLines(find_template(package, type, name))
  if (length(template) == 0 || (length(template) == 1 && str_trim(template) == ""))
    return("")

  whisker::whisker.render(template, data)
}

# Find template by looking first in package/staticdocs then in
# staticdocs/templates, trying first for a type-name.html otherwise
# defaulting to type.html
find_template <- function(package, type, name) {
  package <- as_staticdocs(package)

  paths <- c(
    package$options$templates_path,
    pkg_sd_path(package),
    file.path(inst_path(), "templates")
  )

  names <- c(
    str_c(type, "-", name, ".html"),
    str_c(type, ".html")
  )

  locations <- as.vector(t(outer(paths, names, FUN = "file.path")))
  Find(file.exists, locations, nomatch =
    stop("Can't find template for ", type, "-", name, ".", call. = FALSE))
}


write_if_different <- function(contents, path) {
  if (!made_by_staticdocs(path)) {
    message("Skipping '", path, "': not generated by staticdocs")
    return(FALSE)
  }

  if (same_contents(path, contents)) {
    return(FALSE)
  }

  message("Writing '", path, "'")
  cat(contents, file = path)
  TRUE
}

same_contents <- function(path, contents) {
  if (!file.exists(path))
    return(FALSE)

  # contents <- paste0(paste0(contents, collapse = "\n"), "\n")

  text_hash <- digest::digest(contents, serialize = FALSE)
  file_hash <- digest::digest(file = path)

  identical(text_hash, file_hash)
}

made_by_staticdocs <- function(path) {
  if (!file.exists(path)) return(TRUE)

  first <- readLines(path, n = 1)
  check_made_by(first)
}

check_made_by <- function(first) {
  if (length(first) == 0L) return(FALSE)
  grepl("<!-- Generated by staticdocs", first, fixed = TRUE)
}
