% Generated manually
\name{plotAlignmentByCohort}
\alias{plotAlignmentByCohort}
\title{Plot alignment output relative to cohort start}
\usage{
plotAlignmentByCohort(pa, known_drugs = NULL)
}
\arguments{
\item{pa}{A patient alignment dataframe created by processAlignments() or calculateEras}
}
\value{
plot - A list of ggplot objects
}
\description{
For each patient separately, plot drug exposures and aligned regimens on an x-axis where cohort start is day 0, with vertical lines indicating cohort start and cohort end.
}
