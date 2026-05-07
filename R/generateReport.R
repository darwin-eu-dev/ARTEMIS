#' Generate an ARTEMIS report from saved outputs
#'
#' @param outputFolder Folder containing the `.rds` outputs written by `runArtemis()`
#' @param nExamples Number of example subjects with longer drug records to include per cohort
#' @param render Whether to render the Quarto report immediately when `quarto` is available
#' @param reportFile Name of the Quarto source file to create inside `outputFolder`
#' @param outputFile Name of the rendered HTML file
#' @return Invisibly returns a list with the report source path and rendered output path
#' @export
generateReport <- function(
  outputFolder = "Results",
  nExamples = 15,
  render = TRUE,
  reportFile = "artemis_report.qmd",
  outputFile = "artemis_report.html"
) {
  if (!dir.exists(outputFolder)) {
    stop("Output folder not found: ", outputFolder)
  }

  template <- system.file("quarto", "artemis_report.qmd", package = "ARTEMIS")
  if (!nzchar(template) || !file.exists(template)) {
    stop("Could not find bundled Quarto template for ARTEMIS report generation.")
  }

  report_path <- file.path(outputFolder, reportFile)
  ok <- file.copy(template, report_path, overwrite = TRUE)
  if (!ok) {
    stop("Failed to write report template to: ", report_path)
  }

  rendered_path <- file.path(outputFolder, outputFile)

  if (render) {
    quarto_bin <- Sys.which("quarto")
    if (!nzchar(quarto_bin)) {
      warning(
        "Quarto CLI was not found on PATH. Wrote the report source but did not render it: ",
        report_path
      )
    } else {
      args <- c(
        "render",
        basename(report_path),
        "--to", "html",
        "--output", basename(rendered_path),
        "-P", paste0("output_folder:", normalizePath(outputFolder, winslash = "/", mustWork = TRUE)),
        "-P", paste0("n_examples:", as.integer(nExamples))
      )

      status <- system2(
        quarto_bin,
        args = args,
        stdout = TRUE,
        stderr = TRUE,
        wd = outputFolder
      )

      attr(status, "status") <- attr(status, "status", exact = TRUE)
      if (!is.null(attr(status, "status")) && attr(status, "status") != 0) {
        warning(
          "Quarto rendering failed. Wrote the report source to ",
          report_path,
          "\n",
          paste(status, collapse = "\n")
        )
      }
    }
  }

  invisible(list(report = report_path, html = rendered_path))
}
