MSKAI- Musculoskeletal adverse events following hormonal treatment for breast cancer
========================================================================================================================================================
## Cohort Diagnostics & Population Level Estimation Packages

<img src="https://img.shields.io/badge/Study%20Status-Started-blue.svg" alt="Study Status: Started">

- Analytics use case(s): **Characterization & Population Level Estimation**
- Study type: **Clinical Application**
- Tags: **OHDSI**
- Study lead: **Jenny Lane**
- Study lead forums tag: **jenniferlane** 
- Study start date: **1st December 2020**
- Study end date: **1st May 2021**
- Protocol: **[EU PAS 38362](http://www.encepp.eu/encepp/viewResource.htm?id=38363)**
- Publications: ** **
- Cohort Diagnostics explorer: **[ShinyApp](https://jenniferlane.shinyapps.io/CohortDiagnosticsMSKAI_FinalDesign/)**
- PLE Results explorer: **[EvidenceExplorer]()**

*A study to evaluate the risk of adverse musculoskeletal events in post-menopausal women taking Aromatase Inhibitors compared to Tamoxifen to treat breast cancer.*

# Cohort Diagnostics
If you are undertaking cohort diagnostics for the first time, you may need set up your environment using the instructions given in the [HADES installation guide](https://ohdsi.github.io/Hades/rSetup.html). To run the study you will need to load the package, enter the RProj, and build it. Once built, you will need to open the extras/CodeToRun.R file and enter your database connection details, where you want to save your results locally, and so on (see instructions in the file). In this same file you can then run the study, view the results locally in a shiny application, and share your results.

## Requirements
Please note prior to running (and as detailed in the file Extas/CodetoRun.R), you may also need to install packages in order for packages to run including. 

```From CRAN:  
- devtools
- dplyr
- ggplot2
- SqlRender
- DatabaseConnector
- parallel
- rJava  
From github:  
- OHDSI/FeatureExtraction@v3.1.0
- OHDSI/Andromeda@v0.4.0
- OHDSI/OhdsiSharing@v0.2.2
- edward-burn/CohortDiagnostics; branch = DiagAi
``` 
*Note, we suggest using the branch of cohort diagnostics from the edward-burn account rather than the OHDSI one so as to ensure consistency in results set (the OHDSI cohort diagnostics package continues to be developed - the version on Ed´s github is just a recent fork from the main OHDSI repo).*   

# PLE package

## Requirements
This package should run through the regeneration of the appropriate dependencies by using the `renv.lock` file. To install these dependencies, run
`renv::restore` after opening the project. The file given here requires `R4.0` minimum- contact us if you require a `renv.lock` file that runs with `R3.5.0` or above. You can execute the study using the `CodeToRun` file in the package. 

## Sharing Results
The output is contained in a .ZIP file within the `Output`folder, in the `Export` directory.
We recommend centres review the blinded results in their personal shiny app prior to sharing within OHDSI. We then invite centres to share the results with us via the SFTP server. To share these via the OHDSI SFTP you will need a key file which you will need to be sent separately. To get this please contact jennifer.lane@ndorms.ox.ac.uk.

We look forward to working with you!
