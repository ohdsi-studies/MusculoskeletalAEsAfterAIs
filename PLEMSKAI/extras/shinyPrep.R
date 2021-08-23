prepareForEvidenceExplorer <- function(resultsZipFile,
                                       dataFolder) { # resultsZipFile <- zipFiles[2]
  if (!file.exists(dataFolder)) {
    dir.create(dataFolder, recursive = TRUE)
  }
  tempFolder <- paste(tempdir(), "unzip")
  on.exit(unlink(tempFolder, recursive = TRUE))
  utils::unzip(resultsZipFile, exdir = tempFolder)
  databaseFileName <- file.path(tempFolder, "database.csv")
  if (!file.exists(databaseFileName)) {
    stop("Cannot find file database.csv in zip file")
  }
  databaseId <- read.csv(databaseFileName, stringsAsFactors = FALSE)$database_id
  splittableTables <- c("covariate_balance", "preference_score_dist", "kaplan_meier_dist")
  
  processSubet <- function(subset, tableName) {
    targetId <- subset$target_id[1]
    comparatorId <- subset$comparator_id[1]
    fileName <- sprintf("%s_t%s_c%s_%s.rds", tableName, targetId, comparatorId, databaseId)
    saveRDS(subset, file.path(dataFolder, fileName))
  }
  
  processFile <- function(file) {  # file <- files[4]
    tableName <- gsub(".csv$", "", file)
    table <- readr::read_csv(file.path(tempFolder, file), col_types = readr::cols())
    if (tableName %in% splittableTables) {
      subsets <- split(table, list(table$target_id, table$comparator_id))
      plyr::l_ply(subsets, processSubet, tableName = tableName)
    } else {
      saveRDS(table, file.path(dataFolder, sprintf("%s_%s.rds", tableName, databaseId)))  
    }
  }
  
  files <- list.files(tempFolder, ".*.csv")
  plyr::l_ply(files, processFile, .progress = "text")
}

resultsFolder <- "G:/StudyResults/mskai"
shinyDataFolder <- file.path(resultsFolder, "shinyData")
dataFolder <- shinyDataFolder
zipFiles <- list.files(resultsFolder, pattern = "Results_", full.names = TRUE, recursive = FALSE)
for (zipFile in zipFiles[14]) {
  print(zipFile)
  prepareForEvidenceExplorer(zipFile, shinyDataFolder)
}

preMergeShinyData <- function(shinyDataFolder) { # shinyDataFolder <- "G:/StudyResults/mskai/shinyData"
  shinySettings <- list(dataFolder = shinyDataFolder, blind = TRUE)
  dataFolder <- shinySettings$dataFolder
  blind <- shinySettings$blind
  connection <- NULL
  positiveControlOutcome <- NULL
  splittableTables <- c("covariate_balance", "preference_score_dist", "kaplan_meier_dist")
  files <- list.files(dataFolder, pattern = ".rds")
  files <- files[!grepl("_tNA", files)]
  databaseFileName <- files[grepl("^database", files)]
  removeParts <- paste0(gsub("database", "", databaseFileName), "$")
  
  for (removePart in removeParts) {  # removePart <- removeParts[2]
    tableNames <- gsub("_t[0-9]+_c[0-9]+$", "", gsub(removePart, "", files[grepl(removePart, files)]))
    tableNames <- tableNames[!grepl("_tNA", tableNames)]
    camelCaseNames <- SqlRender::snakeCaseToCamelCase(tableNames)
    camelCaseNames <- unique(camelCaseNames)
    camelCaseNames <- camelCaseNames[!(camelCaseNames %in% SqlRender::snakeCaseToCamelCase(splittableTables))]
    suppressWarnings(
      rm(list = camelCaseNames)
    )
  }
  loadFile <- function(file, removePart) { # file <- dbFiles[1]
    tableName <- gsub("_t[0-9]+_c[0-9]+$", "", gsub(removePart, "", file))
    camelCaseName <- SqlRender::snakeCaseToCamelCase(tableName)
    if (!(tableName %in% splittableTables)) {
      newData <- readRDS(file.path(dataFolder, file))
      colnames(newData) <- SqlRender::snakeCaseToCamelCase(colnames(newData))
      if (exists(camelCaseName, envir = .GlobalEnv)) {
        existingData <- get(camelCaseName, envir = .GlobalEnv)
        newData$tau <- NULL
        newData$traditionalLogRr <- NULL
        newData$traditionalSeLogRr <- NULL
        if (!all(colnames(newData) %in% colnames(existingData))) {
          stop(sprintf("Columns names do not match in %s. \nObserved:\n %s, \nExpecting:\n %s", 
                       file,
                       paste(colnames(newData), collapse = ", "),
                       paste(colnames(existingData), collapse = ", ")))
        }
        newData <- rbind(existingData, newData)
        newData <- unique(newData)
      }
      assign(camelCaseName, 
             newData, 
             envir = .GlobalEnv)
    }
    invisible(NULL)
  }
  
  for (removePart in removeParts) { # removePart <- removeParts[13]
    dbFiles <- files[grepl(removePart, files)]
    if (removePart == "_SIDIAP.rds$") {
      dbFiles <- dbFiles[!grepl("_H_SIDIAP.rds$", dbFiles)]
    }
    invisible(lapply(dbFiles, loadFile, removePart))
  }
  
  dfs <- Filter(function(x) is.data.frame(get(x)) , ls())
  save(list = dfs, 
       file = file.path(dataFolder, "PreMergedShinyData.RData"),
       compress = TRUE,
       compression_level = 2)
}