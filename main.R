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

# Define input and output paths
input_path <- "/var/lib/tercen/share/write/demultiplexed_fastqs"

if( dir.exists(input_path) == FALSE) {
  stop("ERROR: demultiplexed_fastqs folder does not exist in project write folder.")
}

if (length(dir(input_path)) == 0) {
  stop("ERROR: demultiplexed_fastqs folder is empty.")
}

output_path <- "/var/lib/tercen/share/write/trimmed_fastqs"

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

      system(cmd, ignore.stdout = TRUE, ignore.stderr = TRUE)

      progress("Trim Galore")

      sample_name
    }
    future_lapply(r1_files, FUN=trim_galore)
  })
}


tibble(.ci = 1,
       n_cores_detected = parallel::detectCores()) %>%
  ctx$addNamespace() %>%
  ctx$save()

