#' @export
calibrateEstimates <- function(shinyDataFolder, # shinyDataFolder <- "G:/StudyResults/mskai/shinyData"
                               maxCores = parallel::detectCores()) { 
  
  load(file.path(shinyDataFolder, "PreMergedShinyData.RData"))
  rm("attrition",
     "cmFollowUpDist",
     "cohortMethodAnalysis",
     "comparisonSummary",
     "covariate",
     "covariateAnalysis",
     "csv",
     "database",
     "exposureOfInterest",
     "exposureSummary",
     "outcomeOfInterest",
     "propensityModel")

  shinyFolder <- "inst/shiny/EvidenceExplorer"
    
  # data clean
  cohortMethodResult$ci95Ub <- as.numeric(cohortMethodResult$ci95Ub)
  
  # blinding
  mdrr <- readRDS(file.path(shinyFolder, "mdrr.rds"))
  asmd <- readRDS(file.path(shinyFolder, "asmd.rds"))
  equipoise <- readRDS(file.path(shinyFolder, "equipoise.rds"))
  
  cohortMethodResult <- merge(cohortMethodResult, mdrr, all.x = TRUE)
  cohortMethodResult <- merge(cohortMethodResult, asmd, all.x = TRUE)
  cohortMethodResult <- merge(cohortMethodResult, equipoise, all.x = TRUE)
  rm(mdrr, asmd, equipoise)
  
  blinds <- cohortMethodResult$mdrrPass == 1 & cohortMethodResult$asmdPass == 1 & cohortMethodResult$equipoisePass == 1
  cohortMethodResult$rr[!blinds] <- NA
  cohortMethodResult$ci95Ub[!blinds] <- NA
  cohortMethodResult$ci95Lb[!blinds] <- NA
  cohortMethodResult$logRr[!blinds] <- NA
  cohortMethodResult$seLogRr[!blinds] <- NA
  cohortMethodResult$p[!blinds] <- NA
  cohortMethodResult$calibratedRr[!blinds] <- NA
  cohortMethodResult$calibratedCi95Ub[!blinds] <- NA
  cohortMethodResult$calibratedCi95Lb[!blinds] <- NA
  cohortMethodResult$calibratedLogRr[!blinds] <- NA
  cohortMethodResult$calibratedSeLogRr[!blinds] <- NA
  cohortMethodResult$calibratedP[!blinds] <- NA
  
  # calibrate
  subsets <- split(cohortMethodResult, paste(cohortMethodResult$targetId,
                                             cohortMethodResult$comparatorId,
                                             cohortMethodResult$analysisId,
                                             cohortMethodResult$databaseId))
  
  cluster <- ParallelLogger::makeCluster(min(4, maxCores))
  results <- ParallelLogger::clusterApply(cluster,
                                          subsets,
                                          calibrate,
                                          negativeControlOutcome = negativeControlOutcome)
  ParallelLogger::stopCluster(cluster)
  results <- do.call("rbind", results)
  saveRDS(results, file.path(shinyFolder, "cohortMethodResultCal.rds"))
}

calibrate <- function(subset, negativeControlOutcome) { # subset <- subsets[[1]]
  ncs <- subset[subset$outcomeId %in% negativeControlOutcome$outcomeId, ]
  ncs <- ncs[!is.na(ncs$seLogRr), ]
  if (nrow(ncs) > 5) {
    null <- EmpiricalCalibration::fitMcmcNull(ncs$logRr, ncs$seLogRr)
    model <- EmpiricalCalibration::convertNullToErrorModel(null)
    
    calibratedP <- EmpiricalCalibration::calibrateP(null = null,
                                                    logRr = subset$logRr,
                                                    seLogRr = subset$seLogRr)
    
    calibratedCi <- EmpiricalCalibration::calibrateConfidenceInterval(logRr = subset$logRr,
                                                                      seLogRr = subset$seLogRr,
                                                                      model = model)
    subset$calibratedP <- calibratedP$p
    subset$calibratedRr <- exp(calibratedCi$logRr)
    subset$calibratedCi95Lb <- exp(calibratedCi$logLb95Rr)
    subset$calibratedCi95Ub <- exp(calibratedCi$logUb95Rr)
    subset$calibratedLogRr <- calibratedCi$logRr
    subset$calibratedSeLogRr <- calibratedCi$seLogRr
  } else {
    subset$calibratedP <- rep(NA, nrow(subset))
    subset$calibratedRr <- rep(NA, nrow(subset))
    subset$calibratedCi95Lb <- rep(NA, nrow(subset))
    subset$calibratedCi95Ub <- rep(NA, nrow(subset))
    subset$calibratedLogRr <- rep(NA, nrow(subset))
    subset$calibratedSeLogRr <- rep(NA, nrow(subset))
  }
  subset$i2 <- rep(NA, nrow(subset))
  subset <- subset[, c("targetId",
                       "comparatorId",
                       "outcomeId",
                       "analysisId",
                       "databaseId",
                       "rr",
                       "ci95Lb",
                       "ci95Ub",
                       "p",
                       "i2",
                       "logRr",
                       "seLogRr",
                       "targetSubjects",
                       "comparatorSubjects",
                       "targetDays",
                       "comparatorDays",
                       "targetOutcomes",
                       "comparatorOutcomes",
                       "calibratedP",
                       "calibratedRr",
                       "calibratedCi95Lb",
                       "calibratedCi95Ub",
                       "calibratedLogRr",
                       "calibratedSeLogRr")]
  return(subset)
}

