#' @export
doMetaAnalysis <- function(shinyDataFolder,  # shinyDataFolder <- "G:/StudyResults/mskai/shinyData"
                           maOutputFolder) { # maOutputFolder <- "G:/StudyResults/mskai/metaAnalysis"
  
  if (!file.exists(maOutputFolder)) {
    dir.create(maOutputFolder, recursive = TRUE)
  }
  
  allResults <- readRDS(file.path(shinyDataFolder, "cohortMethodResultCal.rds"))
  negativeControls <- read.csv("inst/settings/NegativeControls.csv")
  ncIds <- unique(negativeControls$outcomeId)
  allResults$type <- ""
  allResults$type[allResults$outcomeId %in% ncIds] <- "Negative control"
  allResults$type[allResults$type == ""] <- "Outcome of interest"
  
  groups <- split(x = allResults,
                  f = paste(allResults$targetId,
                            allResults$comparatorId,
                            allResults$analysisId),
                  drop = TRUE)

  results <- lapply(groups, computeGroupMetaAnalysis)
  results <- dplyr::bind_rows(results)
  colnames(results) <- SqlRender::camelCaseToSnakeCase(colnames(results))

  fileName <- file.path(maOutputFolder, "cohort_method_results_Meta-analysis.csv")
  write.csv(results, fileName, row.names = FALSE, na = "")
  fileName <- file.path(shinyDataFolder, "cohort_method_result_Meta-analysis.rds")
  results <- subset(results, select = -c(type, mdrr))
  saveRDS(results, fileName)

  database <- data.frame(database_id = "Meta-analysis",
                         database_name = "Meta-analysis",
                         description = "Meta-analysis",
                         is_meta_analysis = 1,
                         stringsAsFactors = FALSE)
  fileName <- file.path(shinyDataFolder, "database_Meta-analysis.rds")
  saveRDS(database, fileName)
}

computeGroupMetaAnalysis <- function(group) { # group <- groups[[3]]
  analysisId <- group$analysisId[1]
  targetId <- group$targetId[1]
  comparatorId <- group$comparatorId[1]
  print(c(analysisId, targetId, comparatorId))
  outcomeGroups <- split(x = group,
                         f = group$outcomeId,
                         drop = TRUE)
  outcomeGroupResults <- lapply(outcomeGroups, computeSingleMetaAnalysis)
  groupResults <- dplyr::bind_rows(outcomeGroupResults)

  ncs <- groupResults[groupResults$type == "Negative control", ]
  ncs <- ncs[!is.na(ncs$seLogRr), ]

  if (nrow(ncs) > 5) {
    null <- EmpiricalCalibration::fitMcmcNull(ncs$logRr, ncs$seLogRr) # calibrate CIs without synthesizing positive controls, assumes error consistent across effect sizes
    model <- EmpiricalCalibration::convertNullToErrorModel(null)
    calibratedP <- EmpiricalCalibration::calibrateP(null = null,
                                                    logRr = groupResults$logRr,
                                                    seLogRr = groupResults$seLogRr)
    calibratedCi <- EmpiricalCalibration::calibrateConfidenceInterval(logRr = groupResults$logRr,
                                                                      seLogRr = groupResults$seLogRr,
                                                                      model = model)
    groupResults$calibratedP <- calibratedP$p
    groupResults$calibratedRr <- exp(calibratedCi$logRr)
    groupResults$calibratedCi95Lb <- exp(calibratedCi$logLb95Rr)
    groupResults$calibratedCi95Ub <- exp(calibratedCi$logUb95Rr)
    groupResults$calibratedLogRr <- calibratedCi$logRr
    groupResults$calibratedSeLogRr <- calibratedCi$seLogRr
  } else {
    groupResults$calibratedP <- rep(NA, nrow(groupResults))
    groupResults$calibratedRr <- rep(NA, nrow(groupResults))
    groupResults$calibratedCi95Lb <- rep(NA, nrow(groupResults))
    groupResults$calibratedCi95Ub <- rep(NA, nrow(groupResults))
    groupResults$calibratedLogRr <- rep(NA, nrow(groupResults))
    groupResults$calibratedSeLogRr <- rep(NA, nrow(groupResults))
  }
  return(groupResults)
}

computeSingleMetaAnalysis <- function(outcomeGroup) { # outcomeGroup <- outcomeGroups[[12]]
  maRow <- outcomeGroup[1, ]
  
  print(c(maRow$analysisId, maRow$targetId, maRow$comparatorId, maRow$outcomeId))
  
  outcomeGroup <- outcomeGroup[!is.na(outcomeGroup$seLogRr), ] # drops rows with zero events in T or C

  if (nrow(outcomeGroup) == 0) {
    maRow$targetSubjects <- 0
    maRow$comparatorSubjects <- 0
    maRow$targetDays <- 0
    maRow$comparatorDays <- 0
    maRow$targetOutcomes <- 0
    maRow$comparatorOutcomes <- 0
    maRow$rr <- NA
    maRow$ci95Lb <- NA
    maRow$ci95Ub <- NA
    maRow$p <- NA
    maRow$logRr <- NA
    maRow$seLogRr <- NA
    maRow$i2 <- NA
  } else if (nrow(outcomeGroup) == 1) {
    maRow <- outcomeGroup[1, ]
    maRow$i2 <- 0
  } else {
    maRow$targetSubjects <- sumMinCellCount(outcomeGroup$targetSubjects)
    maRow$comparatorSubjects <- sumMinCellCount(outcomeGroup$comparatorSubjects)
    maRow$targetDays <- sum(outcomeGroup$targetDays)
    maRow$comparatorDays <- sum(outcomeGroup$comparatorDays)
    maRow$targetOutcomes <- sumMinCellCount(outcomeGroup$targetOutcomes)
    maRow$comparatorOutcomes <- sumMinCellCount(outcomeGroup$comparatorOutcomes)
    
    tryCatch({
      meta <- meta::metagen(TE = outcomeGroup$logRr,
                            seTE = outcomeGroup$seLogRr,
                            sm = "RR",
                            hakn = FALSE)
      }, 
      error = function(e) {
        conditionMessage(e)
      }
    )

    if (exists("meta")) {
      s <- summary(meta)
      maRow$i2 <- s$I2
      if (maRow$i2 < .40) {
        rnd <- s$random
        maRow$rr <- exp(rnd$TE)
        maRow$ci95Lb <- exp(rnd$lower)
        maRow$ci95Ub <- exp(rnd$upper)
        maRow$p <- rnd$p
        maRow$logRr <- rnd$TE
        maRow$seLogRr <- rnd$seTE
      } else {
        maRow$rr <- NA
        maRow$ci95Lb <- NA
        maRow$ci95Ub <- NA
        maRow$p <- NA
        maRow$logRr <- NA
        maRow$seLogRr <- NA
      }
    } else {
      maRow$rr <- NA
      maRow$ci95Lb <- NA
      maRow$ci95Ub <- NA
      maRow$p <- NA
      maRow$logRr <- NA
      maRow$seLogRr <- NA
    }
  }
  if (is.na(maRow$logRr)) {
    maRow$mdrr <- NA
  } else {
    alpha <- 0.05
    power <- 0.8
    z1MinAlpha <- qnorm(1 - alpha / 2)
    zBeta <- -qnorm(1 - power)
    pA <- maRow$targetSubjects / (maRow$targetSubjects + maRow$comparatorSubjects)
    pB <- 1 - pA
    totalEvents <- abs(maRow$targetOutcomes) + abs(maRow$comparatorOutcomes)
    maRow$mdrr <- exp(sqrt((zBeta + z1MinAlpha)^2 / (totalEvents * pA * pB)))
  }
  maRow$databaseId <- "Meta-analysis"
  maRow$sources <- paste(outcomeGroup$databaseId[order(outcomeGroup$databaseId)], collapse = ", ")
  return(maRow)
}


sumMinCellCount <- function(counts) {
  total <- sum(abs(counts))
  if (any(counts < 0)) {
    total <- -total
  }
  return(total)
}


