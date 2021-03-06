#' Interface for manage the Earth Engine Asset
#'
#' R functions for managing the Earth Engine Asset
#'
#' @name ee_manage-tools
#' @param path_asset Character. Name of the EE asset (Table, Image, Folder or
#' ImageCollection).
#' @param asset_type Character. The asset type to create ('Folder' or
#' 'ImageCollection').
#' @param final_path Character. Output filename
#' (e.g users/datacolecfbf/ic_moved)
#' @param add_properties List. Set of parameters to established as a property
#' of an EE object. See details.
#' @param del_properties Character. Names of properties to be deleted. See
#' details.
#' @param editor Character vector. Define editor users in the IAM Policy.
#' @param viewer Character vector. Define viewer users in the IAM Policy.
#' @param all_users_can_read Logical. All users can see the asset element.
#' @param cache Logical. If TRUE, the task report will be saved
#' in the /temp directory and used when the function .
#' @param quiet Logical. Suppress info message.
#' @importFrom stats na.omit
#' @importFrom utils write.csv read.csv
#' @details
#' If the argument `del_properties` is 'ee_rmv_all_prp',
#' \link[=rgee]{ee_manage_delete_properties} will delete all
#' the properties.
#' @author Samapriya Roy, adapted to R by csaybar.
#' @examples
#' \dontrun{
#' library(rgee)
#' ee_Initialize()
#' ee_user_info()
#'
#' # Change google account to be able to reproduce
#'
#' # 1. Create a folder or Image Collection
#' # Change path asset according to your specific user
#' ee_manage_create("users/datacolecfbf/rgee")
#'
#' # 1. List all the elements inside a folder or a ImageCollection
#' ee_manage_assetlist(path_asset = "users/datacolecfbf/rgee")
#'
#' # 2. Create a Folder or a ImageCollection
#' ee_manage_create(
#'   path_asset = "users/datacolecfbf/rgee/rgee_folder",
#'   asset_type = "Folder"
#' )
#'
#' ee_manage_create(
#'   path_asset = "users/datacolecfbf/rgee/rgee_ic",
#'   asset_type = "ImageCollection"
#' )
#'
#' ee_manage_assetlist(path_asset = "users/datacolecfbf/rgee")
#'
#' # 3. Shows Earth Engine quota
#' ee_manage_quota()
#'
#' # 4. Move an EE object to another folder
#' ee_manage_move(
#'   path_asset = "users/datacolecfbf/rgee/rgee_ic",
#'   final_path = "users/datacolecfbf/rgee/rgee_folder/rgee_ic_moved"
#' )
#'
#' ee_manage_assetlist(path_asset = "users/datacolecfbf/rgee/rgee_folder")
#'
#' # 5. Set properties to an EE object.
#' ee_manage_set_properties(
#'   path_asset = "users/datacolecfbf/rgee/rgee_folder/rgee_ic_moved",
#'   add_properties = list(message = "hello-world", language = "R")
#' )
#'
#' ic_id <- "users/datacolecfbf/rgee/rgee_folder/rgee_ic_moved"
#' test_ic <- ee$ImageCollection(ic_id)
#' test_ic$getInfo()
#'
#' # 6. Delete properties
#' ee_manage_delete_properties(
#'   path_asset = "users/datacolecfbf/rgee/rgee_folder/rgee_ic_moved",
#'   del_properties = c("message", "language")
#' )
#' test_ic$getInfo()
#'
#' # 7. Create a report based on all the tasks
#' # that are running or have already been completed.
#' ee_manage_task()
#'
#' # 8. Cancel all the running task
#' ee_manage_cancel_all_running_task()
#'
#' # 9. Delete EE objects or folders
#' ee_manage_delete("users/datacolecfbf/rgee/")
#' }
#' @export
ee_manage_create <- function(path_asset, asset_type = "Folder", quiet = FALSE) {

  # Is the same EE user?
  ee_path <- path.expand("~/.config/earthengine")
  user <- read.table(file = sprintf("%s/rgee_sessioninfo.txt", ee_path),
                     header = TRUE,
                     stringsAsFactors = FALSE)
  # Select first and second folder (lazzy)
  folders <- strsplit(path_asset,"/")[[1]][1:2]
  path_asset_root_folder <- sprintf("%s/%s",folders[1],folders[2])

  if (!identical(path_asset_root_folder, user$user)) {
    stop('The root folder "',path_asset_root_folder,'" is invalid')
  }

  path_asset <- ee_verify_filename(path_asset, strict = FALSE)
  asset_path_exist <- is.null(ee$data$getInfo(path_asset))
  if (asset_path_exist) {
    if (asset_type == "Folder") {
      new_path <- path_asset
      repeat {
        nested_folder <- try(
          ee$data$createAsset(
            list(type = ee$data$ASSET_TYPE_FOLDER),
            new_path),silent = TRUE
        )
        if (class(nested_folder) == 'try-error') {
          new_path <- dirname(new_path)
        } else {
          if (identical(new_path,path_asset)) {
            break
          }
          new_path <- path_asset
        }
      }
    } else if (asset_type == "ImageCollection") {
      ee$data$createAsset(
        value = list(type = ee$data$ASSET_TYPE_IMAGE_COLL),
        opt_path = path_asset
      )
    } else {
      stop("Invalid asset_type parameter")
    }
    if (!quiet) cat("GEE asset:", path_asset, "created\n")
  }
  else {
    if (!quiet) cat("GEE asset:", path_asset, "already exists\n")
  }
  invisible(TRUE)
}


#' @name ee_manage-tools
#' @export
ee_manage_delete <- function(path_asset, quiet = FALSE) {
  path_asset <- ee_verify_filename(path_asset, strict = TRUE)
  response <- ee$data$getInfo(path_asset)
  if (is.null(response)) stop("path_asset does not exist!")
  if (response$type %in% ee_manage_handle_names()) {
    list_files <- ee$data$getList(list(id = path_asset))
    items <- unlist(lapply(list_files, "[[", "id")) %>%
      ee_remove_project_chr()
    mapply(ee_manage_delete, items)
  }
  ee$data$deleteAsset(path_asset)
  if (!quiet) cat("EE object deleted:", path_asset, "\n")
  invisible(TRUE)
}

#' @name ee_manage-tools
#' @export
ee_manage_assetlist <- function(path_asset, quiet = FALSE) {
  if (missing(path_asset)) {
    path_asset <- ee$data$getAssetRoots()[[1]]$id %>%
      ee_remove_project_chr()
  }

  # Getting EE asset info: path + type
  path_asset <- ee_verify_filename(path_asset, strict = TRUE)
  response <- ee$data$getInfo(path_asset)
  if (is.null(response)) stop("path_asset does not exist!")
  list_files <- ee$data$getList(list(id = path_asset))
  ids <- unlist(lapply(list_files, "[[", "id")) %>%
    ee_remove_project_chr()
  type <- unlist(lapply(list_files, "[[", "type"))

  # Creating data.frame
  df_path <- data.frame(
    ID = ids,
    TYPE = type,
    stringsAsFactors = FALSE
  )

  if (nrow(df_path) != 0L) {
    df_path <- rbind(
      df_path[df_path$TYPE %in% ee_manage_handle_names("ImageCollection"), ],
      df_path[df_path$TYPE %in% ee_manage_handle_names("Folder"), ],
      df_path[df_path$TYPE %in% ee_manage_handle_names("Image"), ],
      df_path[df_path$TYPE %in% ee_manage_handle_names("Table"), ]
    )
  }
  return(df_path)
}

#' @name ee_manage-tools
#' @export
ee_manage_quota <- function() {
  oauth_func_path <- system.file("python/ee_manage.py", package = "rgee")
  ee_quota <- ee_source_python(oauth_func_path)
  ID <- ee$data$getAssetRoots()[[1]]$id %>%
    ee_remove_project_chr()
  quota <- ee_py_to_r(ee_quota$quota(ID))
  total_msg <- ee_humansize(as.numeric(quota[1]))
  used_msg <- ee_humansize(as.numeric(quota[2]))
  cat(sprintf(" Total Quota: %s \n Used Quota: %s", total_msg, used_msg))
  invisible(quota)
}

#' @name ee_manage-tools
#' @export
ee_manage_copy <- function(path_asset, final_path, quiet = FALSE) {
  path_asset <- ee_verify_filename(path_asset, strict = TRUE)
  final_path <- ee_verify_filename(final_path, strict = FALSE)
  header <- ee$data$getInfo(path_asset)[["type"]]
  eeasset_objects <- c("Image", "ImageCollection", "FeatureCollection")

  if (header %in% ee_manage_handle_names(eeasset_objects)) {
    ee$data$copyAsset(path_asset, final_path)
    if (!quiet) cat("Done\n")
  } else if (header %in% ee_manage_handle_names("Folder")) {
    to_copy_list <- ee$data$getList(params = list(id = path_asset)) %>%
      lapply("[[", "id") %>%
      unlist() %>%
      ee_remove_project_chr()
    ee_manage_create(
      path_asset = final_path,
      asset_type = "Folder"
    )
    if (!quiet) {
      cat(
        "Copying a total of", length(to_copy_list),
        " elements ..... please wait\n"
      )
    }
    folder_destination <- sprintf("%s/%s", final_path, basename(to_copy_list))
    for (z in seq_along(to_copy_list)) {
      cat(to_copy_list)
      cat(folder_destination)
      ee$data$copyAsset(to_copy_list[z], folder_destination[z])
    }
    if (!quiet) cat("Done\n")
  } else {
    stop("Unsupported EE asset object")
  }
  invisible(TRUE)
}

#' @name ee_manage-tools
#' @export
ee_manage_move <- function(path_asset, final_path, quiet = FALSE) {
  path_asset <- ee_verify_filename(path_asset, strict = TRUE)
  final_path <- ee_verify_filename(final_path, strict = FALSE)
  header <- ee$data$getInfo(path_asset)[["type"]]
  eeasset_objects <- c("Image", "Table", "FeatureCollection")
  if (header %in% ee_manage_handle_names(eeasset_objects)) {
    ee$data$renameAsset(path_asset, final_path)
    if (!quiet) cat("Done\n")
  } else if (header %in% ee_manage_handle_names()) {
    header_finalpath <- ee$data$getInfo(final_path)[["type"]]
    if (is.null(header_finalpath)) {
      if (header  %in%  ee_manage_handle_names('ImageCollection')) {
        ee_manage_create(dirname(final_path), quiet = quiet)
        ee_manage_create(final_path,'ImageCollection', quiet = quiet)
      } else {
        ee_manage_create(final_path, quiet = quiet)
      }
    }
    to_copy_list <- ee$data$getList(params = list(id = path_asset)) %>%
      lapply("[[", "id") %>%
      unlist() %>%
      ee_remove_project_chr()
    if (!quiet) {
      cat(
        "Moving a total of", length(to_copy_list),
        " elements ..... please wait ...\n"
      )
    }
    folder_destination <- sprintf("%s/%s", final_path, basename(to_copy_list))
    for (z in seq_along(to_copy_list)) {
      cat("Moving:", to_copy_list, " --> ", folder_destination, "\n")
      ee$data$renameAsset(
        sourceId = to_copy_list[z],
        destinationId = folder_destination[z]
      )
    }
    ee_manage_delete(path_asset, quiet = quiet)
    if (!quiet) cat("Done\n")
  } else {
    stop("Unsupported EE asset object")
  }
  invisible(TRUE)
}

#' @name ee_manage-tools
#' @export
ee_manage_set_properties <- function(path_asset, add_properties) {
  path_asset <- ee_verify_filename(path_asset, strict = TRUE)
  header <- ee$data$getInfo(path_asset)[["type"]]
  eeasset_objects <- c("Image", "ImageCollection", "FeatureCollection", "Table")
  if (header %in% ee_manage_handle_names(eeasset_objects)) {
    ee$data$setAssetProperties(path_asset, add_properties)
  } else {
    stop("Impossible assign properties to a Folder")
  }
  invisible(TRUE)
}

#' @name ee_manage-tools
#' @export
ee_manage_delete_properties <- function(path_asset,
                                        del_properties = "ee_rmv_all_prp") {
  path_asset <- ee_verify_filename(path_asset, strict = TRUE)
  header <- ee$data$getInfo(path_asset)[["type"]]
  eeasset_objects <- c("Image", "ImageCollection", "FeatureCollection", "Table")
  if (header %in% ee_manage_handle_names(eeasset_objects)) {
    if ("ee_rmv_all_prp" %in%  del_properties) {
      properties_todelete <- names(ee$data$getAsset(path_asset)$properties)
    } else {
      properties_todelete <- del_properties
    }
    del_list <- list()
    del_list[properties_todelete] <- list(NULL)
    ee$data$setAssetProperties(path_asset, del_list)
  } else {
    stop("Impossible delete properties to a Folder")
  }
  invisible(TRUE)
}

#' @name ee_manage-tools
#' @export
ee_manage_asset_access <- function(path_asset,
                                    editor = NULL,
                                    viewer = NULL,
                                    all_users_can_read = TRUE,
                                    quiet = FALSE) {
  bindings_template <- getOption('rgee.manage.setIamPolicy')
  bindings_template$bindings[[2]]$members <- paste0('user:', editor)
  if (isTRUE(all_users_can_read)) {
    bindings_template$bindings[[3]]$members <- c(viewer,'allUsers')
  } else {
    bindings_template$bindings[[3]]$members <- paste0('user:', viewer)
  }
  ee$data$setIamPolicy(path_asset, bindings_template)
  invisible(TRUE)
}

#' @name ee_manage-tools
#' @export
ee_manage_task <- function(cache = FALSE) {
  oauth_func_path <- system.file("python/ee_manage.py", package = "rgee")
  ee_manage_py <- ee_source_python(oauth_func_path)
  ee_temp <- tempdir()
  manage_task_file <- sprintf("%s/ee_manage_task_file.csv", ee_temp)
  if (!isTRUE(cache)) {
    py_names <- c(
      "tid", "tstate", "tdesc", "ttype", "tcreate",
      "tdiffstart", "tdiffend", "error_message"
    )
    df_names <- c(
      "ID", "State", "DestinationPath", "Type", "Start",
      "DeltaToCreate(s)", "DeltaToCompletedTask(s)", "ErrorMessage"
    )
    status <- ee_py_to_r(ee_manage_py$genreport())
    if (length(status) == 0) {
      message("No recent task to report")
      df_order <- data.frame(message = "No recent task to report")
      write.csv(df_order, manage_task_file, row.names = FALSE)
      return(invisible(df_order))
    }
    order_name <- names(status[[1]])
    df_status <- data.frame(
      matrix(unlist(status), nrow = length(status), byrow = TRUE),
      stringsAsFactors = FALSE
    )
    colnames(df_status) <- order_name
    df_order <- df_status[py_names]
    colnames(df_order) <- df_names
    df_order$DestinationPath <- sub(".*:\\s", "", df_order$DestinationPath)
    write.csv(df_order, manage_task_file, row.names = FALSE)
  } else {
    df_order <- read.csv(manage_task_file, stringsAsFactors = FALSE)
  }
  return(df_order)
}

#' @name ee_manage-tools
#' @export
ee_manage_cancel_all_running_task <- function() {
  all_task <- ee$data$getTaskList()
  running_task <- which(unlist(lapply(all_task, "[[", "state")) == "RUNNING")
  running <- all_task[running_task]
  if (length(running) == 0){
    message("There are not any tasks running")
  } else {
    for (z in seq_along(running)) {
      ee$data$cancelTask(running[[z]][["id"]])
      }
  }
  invisible(TRUE)
}

#' Verify is the EE path asset is correct
#' @noRd
ee_verify_filename <- function(path_asset, strict = TRUE) {
  ee_path_dirname <- gsub("\\..+$", "", path_asset)
  m <- gregexpr("[\\w']+", ee_path_dirname, perl = TRUE)
  folder <- ee_path_dirname %>%
    regmatches(m) %>%
    "[["(1) %>%
    paste(collapse = "/") %>%
    ee_remove_project_chr()
  response <- ee$data$getInfo(folder)
  if (is.null(response) & strict) {
    message <- c(
      "%s is not a valid destination.",
      " Make sure a correct full path is provided",
      " (e.g. either users/user/nameofcollection",
      " or projects/myproject/myfolder/newcollection).")
    stop(sprintf(message, path_asset))
  }
  return(folder)
}

#' Change the unit of measurement of bytes
#' @param x Integer. Number of bytes.
#' @return Number of bytes in a more human-comprehensible way
#' @noRd
ee_humansize <- function(x, suffixes = c("B", "KB", "MB", "GB", "TB", "PB")) {
  count <- 0
  while (x >= 1024 & (count < length(suffixes) - 1)) {
    x <- x / 1024
    count <- count + 1
  }
  if (suffixes[count + 1] == "B") {
    sprintf("%s %s", sprintf("%s", x), suffixes[count + 1])
  } else {
    sprintf("%s %s", sprintf("%.2f", x), suffixes[count + 1])
  }
}


#' Remove EE projects info
#' @param x Character (path_asset)
ee_remove_project_chr <- function(x) {
  new_x <- gsub("projects/earthengine/legacy/assets/", "", x)
  gsub("projects/earthengine-legacy/assets/", "", new_x)
}

#' EE asset object type
#'
#' The earth engine API constantly change of name to the EE assets
#' object. This function was created to help to handle it.
#'
#' @param type EE asset object to consider
#' @noRd
ee_manage_handle_names <- function(type = c("Folder", "ImageCollection")) {
  names <- NULL
  if ("Folder" %in% type) {
    names <- c(names, c("FOLDER", "Folder", "folder"))
  }
  if ("Image" %in% type) {
    names <- c(names, c("IMAGE", "Image", "image"))
  }
  if ("ImageCollection" %in% type) {
    names <- c(
      names,
      c("ImageCollection", "IMAGE_COLLECTION", "imagecollection")
    )
  }
  if ("Feature" %in% type) {
    names <- c(names, c("feature", "Feature", "FEATURE"))
  }
  if ("FeatureCollection" %in% type) {
    names <- c(
      names, c("featurecollection", "FeatureCollection", "FEATURE_COLLECTION")
    )
  }
  if ("Table" %in% type) {
    names <- c(names, c("table", "TABLE", "Table"))
  }
  names
}

#' @name ee_manage-tools
#' @export
ee_manage_asset_size <- function(path_asset) {
  info_data <- ee$data$getInfo(path_asset)
  size_file <- as.numeric(info_data$sizeBytes)
  cat('Type            :', info_data$type,'\n')
  cat('Size (in Bytes) :', size_file)
  invisible(size_file)
}
