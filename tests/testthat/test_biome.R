context("Running Hector with multiple biomes")

test_that("Hector runs with multiple biomes.", {

  quickrun <- function(ini_string, name, ini_file = NULL) {
    if (is.null(ini_file)) {
      ini_file <- tempfile()
      on.exit(file.remove(ini_file), add = TRUE)
      writeLines(ini_string, ini_file)
    }
    core <- newcore(ini_file, name = name, suppresslogging = TRUE)
    invisible(run(core))
    on.exit(shutdown(core), add = TRUE)
    dates <- seq(2000, 2100)
    vars <- c(
      ATMOSPHERIC_CO2(),
      RF_TOTAL(),
      GLOBAL_TEMP()
    )
    fetchvars(core, dates, vars)
  }

  rcp45_file <- system.file("input", "hector_rcp45.ini", package = "hector")
  raw_ini <- trimws(readLines(rcp45_file))
  new_ini <- raw_ini

  # Remove non-biome-specific variables
  biome_vars <- c("veg_c", "detritus_c", "soil_c", "npp_flux0",
                  "beta", "q10_rh")
  biome_rxp <- paste(biome_vars, collapse = "|")
  iremove <- grep(sprintf("^(%s) *=", biome_rxp), raw_ini)
  new_ini <- new_ini[-iremove]

  # Add biome-specific versions of above variables at top of
  # simpleNbox block
  isnbox <- grep("^\\[simpleNbox\\]$", new_ini)
  new_ini <- append(new_ini, c(
    "boreal.veg_c = 100",
    "tropical.veg_c = 450",
    "boreal.detritus_c = 15",
    "tropical.detritus_c = 45",
    "boreal.soil_c = 1200",
    "tropical.soil_c = 578",
    "boreal.npp_flux0 = 5.0",
    "tropical.npp_flux0 = 45.0",
    "boreal.beta = 0.36",
    "tropical.beta = 0.36",
    "boreal.q10_rh = 2.0",
    "tropical.q10_rh = 2.0"
  ), after = isnbox)

  # Make csv paths absolute (otherwise, they search in the tempfile directory)
  icsv <- grep("^ *.*?=csv:", new_ini)
  csv_paths_l <- regmatches(new_ini[icsv],
                            regexec(".*?=csv:(.*?\\.csv)", new_ini[icsv]))
  csv_paths <- vapply(csv_paths_l, `[[`, character(1), 2)
  csv_full_paths <- file.path(dirname(rcp45_file), csv_paths)
  new_ini_l <- Map(
    gsub,
    pattern = csv_paths,
    replacement = csv_full_paths,
    x = new_ini[icsv]
  )
  new_ini[icsv] <- unlist(new_ini_l, use.names = FALSE)

  biome_result <- quickrun(new_ini, "biome")
  rcp45_result <- quickrun(NULL, "default", ini_file = rcp45_file)

  result_diff <- rcp45_result$value - biome_result$value
  diff_summary <- tapply(result_diff, rcp45_result$variable, sum)
  expect_true(all(abs(diff_summary) > 0))

  # Add the warming tag
  warm_biome <- append(new_ini, c(
    "boreal.warmingfactor = 2.5",
    "tropical.warmingfactor = 1.0"
  ), after = isnbox)
  warm_biome_result <- quickrun(warm_biome, "warm_biome")
  default_tgav <- rcp45_result[rcp45_result[["variable"]] == "Tgav",
                               "value"]
  warm_tgav <- warm_biome_result[warm_biome_result[["variable"]] == "Tgav",
                                 "value"]
  expect_true(mean(default_tgav) < mean(warm_tgav))
})