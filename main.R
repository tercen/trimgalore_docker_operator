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

folder = ctx$cselect()[[1]][[1]]
parts =  unlist(strsplit(folder, '/'))
volume = parts[[1]]
input_folder <- paste(parts[-1], collapse="/")

# Define input and output paths
input_path <- paste0("/var/lib/tercen/share/", volume, "/",  input_folder)

if( dir.exists(input_path) == FALSE) {

  stop(paste("ERROR:", input_folder, "folder does not exist in project volume ", volume ))

}

if (length(dir(input_path)) == 0) {
  stop(paste("ERROR:", input_folder, "folder is empty  in project volume ", volume))
}

output_volume = "write"
output_folder <- paste0(output_volume, "/",
                        format(Sys.time(), "%Y_%m_%d_%H_%M_%S"),
                        "_trimmed_fastqs")

output_path <- paste0("/var/lib/tercen/share/",
                      output_folder, "/")

system(paste("mkdir -p", output_path))

# Check if a second column variable is used to select samples to trim
run_selected_samples <- FALSE
if (length(ctx$cselect()) > 1) {
  run_selected_samples <- TRUE
  samples_to_run <- ctx$cselect()[[2]]
}

# Check if there's a third column with new sample names
rename_samples <- FALSE
if (length(ctx$cselect()) > 2) {
  rename_samples <- TRUE
  new_sample_names <- ctx$cselect()[[3]]
  names(new_sample_names) <- samples_to_run
}

is_paired_end <- as.character(ctx$op.value('paired_end'))

if (is_paired_end == "yes") {

  r1_files <- list.files(input_path, "_R1.+fastq", recursive = TRUE,
                         full.names = TRUE)

  if (length(r1_files) == 0) stop("ERROR: No R1 FastQ files found in demultiplex_fastqs folder.")

  samples = progressr::with_progress({
    progress = progressr::progressor(along = r1_files)
    trim_galore = function(r1_file) {
      r2_file <- str_replace(r1_file, "R1", "R2")
      sample_name <- str_split(basename(r1_file),
                               "_R1.fastq")[[1]][[1]]

      if (run_selected_samples & !(sample_name %in% samples_to_run)) return("NA")

      if (rename_samples) {
        cmd <- paste("trim_galore --output_dir",
                     output_path, "--basename", new_sample_names[sample_name],
                     "--paired",
                     r1_file, r2_file)
        sample_name <- new_sample_names[sample_name]
      } else {
        cmd <- paste("trim_galore --output_dir",
                     output_path,
                     "--paired",
                     r1_file, r2_file)
      }
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
       trimmed_folder = output_folder,
       samples = samples) %>%
  ctx$addNamespace() %>%
  ctx$save()

