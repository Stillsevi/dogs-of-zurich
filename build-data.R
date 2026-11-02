# Erzeugt data.js aus der Shiny-App (einmalig mit Rscript ausführen).
# Nutzt helper.R der Original-App, damit die Zahlen identisch sind.
library(sf); library(dplyr); library(jsonlite)

app_dir <- path.expand("~/Documents/Rstudio/Dogs Part 3/dogs-app")
out_dir <- dirname(normalizePath(sub("--file=", "", grep("--file=", commandArgs(FALSE), value = TRUE))))

old <- setwd(app_dir); source("helper.R"); setwd(old)

# Geometrie leicht vereinfachen (1 m Toleranz) und Koordinaten runden
m <- st_simplify(st_make_valid(map), dTolerance = 1, preserveTopology = TRUE)
bb <- st_bbox(m)

ring_to_path <- function(ring) {
  x <- round(ring[, 1] - bb["xmin"]); y <- round(bb["ymax"] - ring[, 2])
  paste0("M", paste(x, y, sep = ",", collapse = "L"), "Z")
}
geom_to_path <- function(g) {
  polys <- if (inherits(g, "MULTIPOLYGON")) unclass(g) else list(unclass(g))
  paste(unlist(lapply(polys, function(p) vapply(p, ring_to_path, ""))), collapse = "")
}

districts <- lapply(seq_len(nrow(m)), function(i) list(
  qnr = m$qnr[i], qname = m$qname[i], knr = as.integer(m$knr[i]),
  d = geom_to_path(st_geometry(m)[[i]])
))

stats <- dogs_pop_per_nbrh %>%
  transmute(year, qnr = nbrh_no, inh = Number_of_inhabitants, dogs = Number_of_dogs)

out <- list(
  width = unname(round(bb["xmax"] - bb["xmin"])),
  height = unname(round(bb["ymax"] - bb["ymin"])),
  years = available_years,
  districts = districts,
  stats = stats
)
writeLines(paste0("window.DOGS_DATA = ", toJSON(out, auto_unbox = TRUE, dataframe = "rows"), ";"),
           file.path(out_dir, "data.js"))
cat("OK:", nrow(m), "Quartiere,", nrow(stats), "Zeilen, Jahre", range(available_years), "\n")
