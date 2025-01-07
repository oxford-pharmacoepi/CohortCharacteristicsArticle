-----
header: "Introduction"
-----

#### CohortCharacteristics package

[CohortCharacteristics](https://darwin-eu.github.io/CohortCharacteristics/) is an R package that is used to summarise and visualise the characteristics of patients in data mapped to the Observational Medical Outcomes Partnership (OMOP) common data model (CDM) [1]. The package can be found in cran [2], with version 0.4.0 as of December 2024.

The package is build around omopgenerics [3] and PatientProfiles [4]. omopgenerics define classes and methods for a set of packages to query OMOP CDM databases and PatientProfiles is used to identify the characteristics of patients at the patient level.

The main functionality is to characterise cohorts (a cohort is a set of individuals that fulfill some inclusion criteria during a certain time). The data

- Summarise cohort counts.
- Summarise attrition of a cohort.
- Summarise cohort overlap between different cohorts.
- Summarise timing between different cohorts.
- Summarise the demographics and intersections of different cohorts.
- Summarise the concepts recorded 

The output of 

#### The study

This shiny presents the results of the CohortCharacteristics methods study:

In this study we created 5 cohorts of interest:

1. 

Then we extracted the counts.

The study was run in 5 databases:

The code for this study can be found in: <https://github.com/oxford-pharmacoepi/CohortCharacteristicsArticle>.

#### The shiny

This shiny app contains different tabs:

- `Cohort details`
- `Codelist details`
- `Database details`
- `Cohort count`
- `Cohort attrition`
- `Cohort characteristics`
- `Cohort overlap`
- `Cohort timing`
- `Large scale characteristics`

#### References

[1] Overhage, J. M., Ryan, P. B., Reich, C. G., Hartzema, A. G., & Stang, P. E. (2012). Validation of a common data model for active safety surveillance research. Journal of the American Medical Informatics Association, 19(1), 54-60.

[2] The Comprehensive R Archive Network (CRAN). Available at: https://CRAN.R-project.org.

[3] Català M, Burn E (2024). _omopgenerics: Methods and Classes for the OMOP Common Data Model_. R package version 0.4.1, <https://CRAN.R-project.org/package=omopgenerics>.
  
[4] Catala M, Guo Y, Du M, Lopez-Guell K, Burn E, Mercade-Besora N (2024). _PatientProfiles: Identify Characteristics of Patients in the OMOP Common Data Model_. R package version 1.2.3, <https://CRAN.R-project.org/package=PatientProfiles>.

![](logo.png){width=200px}
