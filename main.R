library(tercen)
library(dplyr)
library(stringr)
library(progressr)
library("future.apply")

# plan(multisession) # works in R studio
plan(multicore) ## don't work on R studio

handler_tercen <- function(ctx, ...) {

  env <- new.env()
  assign("ctx", ctx, envir = env)

  reporter <- local({
    list(
      update = function(config, state, progression, ...) {
        evt = TaskProgressEvent$new()
        evt$taskId = ctx$task$id
        evt$total = config$max_steps
        evt$actual = state$step
        evt$message = paste0(state$message , " : ",  state$step, "/", config$max_steps)
        ctx$client$eventService$sendChannel(ctx$task$channelId, evt)
      }
    )
  }, envir = env)

  progressr::make_progression_handler("tercen", reporter, intrusiveness = getOption("progressr.intrusiveness.gui", 1), target = "gui", interval = 1, ...)
}

ctx <- tercenCtx()

options(progressr.enable = TRUE)
progressr::handlers(handler_tercen(ctx))

input_folder <- ctx$cselect()[[1]][[1]]

print(paste("This is the folder I'm looking for:", input_folder))

# Check if input path is on a tercen write or read folder
if ( !(str_starts(input_folder, "/var/lib/tercen/external/read/") | str_starts(input_folder, "/var/lib/tercen/external/write/")) ) {
  stop("Supplied path is not in a Tercen read or write folder.")
}

# Define input and output paths
input_path <- str_replace(input_folder, "/var/lib/tercen/external",
                                        "/var/lib/tercen/share")

if( dir.exists(input_path) == FALSE) {
  input_path <- str_replace(input_path, "/((read)|(write))/dev", "/\\1")

  if( dir.exists(input_path) == FALSE) {

    stop(paste("ERROR:", input_folder, "folder does not exist in project write folder."))

  }
}

if (length(dir(input_path)) == 0) {
  stop(paste("ERROR:", input_folder, "folder is empty."))
}

output_folder <- paste0(format(Sys.time(), "%Y_%m_%d_%H_%M_%S"),
                        "_trimmed_fastqs")

output_path <- paste0("/var/lib/tercen/share/write/",
                      output_folder, "/")

is_paired_end <- as.character(ctx$op.value('paired_end'))

if (is_paired_end == "yes") {

  r1_files <- list.files(input_path, "R1.fastq",
                         full.names = TRUE)

  if (length(r1_files) == 0) stop("ERROR: No R1 FastQ files found in demultiplex_fastqs folder.")

  samples = progressr::with_progress({
    progress = progressr::progressor(along = r1_files)
    trim_galore = function(r1_file) {
      r2_file <- str_replace(r1_file, "R1", "R2")
      sample_name <- str_split(basename(r1_file),
                               "_R1.fastq")[[1]][[1]]

      cmd <- paste("trim_galore --output_dir",
                   output_path,
                   "--paired",
                   r1_file, r2_file)

      exitCode = system(cmd, ignore.stdout = TRUE, ignore.stderr = TRUE)

      if (exitCode != 0) {
        stop("ERROR: trim_galore failed for sample: ", sample_name)
      }

      progress("Trim Galore")

      sample_name
    }
    future_lapply(r1_files, FUN=trim_galore)
  })
}


tibble(.ci = 0,
       trimmed_folder = output_folder) %>%
  ctx$addNamespace() %>%
  ctx$save()

