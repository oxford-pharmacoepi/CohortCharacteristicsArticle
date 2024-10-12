createLogger <- function(results = getwd(), name = character()) {
  file <- here::here(
    results,
    paste0("log_", name, "_", format(Sys.time(), "%Y_%m_%d_%H_%M_%S"), ".txt")
  )
  file.create(file)
  options("log_file_og" = file)
  return(invisible(file))
}
log <- function(message = character(), .envir = parent.frame()) {
  message <- glue::glue(message, .envir = .envir) |>
    as.character()
  fileName <- getOption("log_file_og")
  time <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  cli::cli_inform("{.pkg {time}} {message}")
  con <- file(fileName, open = "a")
  writeLines(paste0("[", time, "] ", message), con = con)
  close(con)
  return(invisible(NULL))
}
