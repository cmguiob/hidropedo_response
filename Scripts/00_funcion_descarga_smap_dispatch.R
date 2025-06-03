download_smap_dispatch <- function(start_date, end_date, bbox,
                                   drive_folder_id,
                                   earthdata_user, earthdata_pass,
                                   tmp_dir   = file.path(tempdir(), "smap_tmp"),
                                   page_size = 2000, max_tries = 3) {
  
  ## ---------- paquetes --------------------------------------------------
  options(repos = c(CRAN = "https://cloud.r-project.org"))
  for (pkg in c("httr","jsonlite","terra","googledrive",
                "progress","fs","purrr"))
    if (!requireNamespace(pkg, quietly = TRUE)) install.packages(pkg, quiet=TRUE)
  lapply(c("httr","jsonlite","terra","googledrive",
           "progress","fs","purrr"),
         library, character.only = TRUE, quietly = TRUE)
  
  Sys.setenv(PROJ_LIB = system.file("proj", package = "terra"))
  terra::terraOptions(progress = FALSE)              # desactiva barra terra
  dir.create(tmp_dir, showWarnings = FALSE, recursive = TRUE)
  googledrive::drive_auth(email = TRUE)
  
  ## ---------- 1. lista URLs --------------------------------------------
  cmr_list <- function() {
    q <- list(short_name   = "NSIDC-0779",
              temporal     = sprintf("%sT00:00:00Z,%sT23:59:59Z",
                                     start_date, end_date),
              bounding_box = paste(bbox, collapse = ","),
              page_size    = page_size,
              sort_key     = "start_date")
    url  <- httr::modify_url("https://cmr.earthdata.nasa.gov",
                             path="/search/granules.json", query=q)
    links <- character(); after <- NULL
    pb <- progress::progress_bar$new(" Buscando [:bar] :current", clear=FALSE)
    repeat {
      hdr <- if (is.null(after)) NULL else c("CMR-Search-After"=after)
      r   <- httr::RETRY("GET", url, httr::add_headers(.headers=hdr),
                         times=max_tries, pause_min=2)
      httr::stop_for_status(r)
      ent <- jsonlite::fromJSON(rawToChar(r$content),
                                simplifyVector = FALSE)$feed$entry
      if (!length(ent)) break
      batch <- unlist(lapply(ent, \(e)
                             vapply(e$links, \(l) l$href, character(1))))
      keep <- grepl("^https?://", batch) &            # http
        grepl("\\.tif$",  batch) &              # tif
        grepl("SM_DS|SM_AS", batch, TRUE) &     # DS / AS
        !grepl("BRWS", batch, TRUE)             # ⇦ descarta _BRWS.tif
      links <- c(links, batch[keep])
      after <- httr::headers(r)[["cmr-search-after"]]
      pb$tick(); if (is.null(after)) break
    }
    pb$terminate(); unique(links)
  }
  
  ## ---------- 2. procesa un enlace -------------------------------------
  process_one <- function(url) {
    nm <- fs::path_file(url)
    g  <- file.path(tmp_dir, nm)
    c  <- file.path(tmp_dir, paste0("cut_", nm))
    
    on.exit(purrr::walk(c(g, c), \(f) unlink(f, force=TRUE)), add=TRUE)
    
    httr::RETRY("GET", url,
                httr::authenticate(earthdata_user, earthdata_pass),
                httr::write_disk(g, overwrite=TRUE),
                times=max_tries, pause_min=2)
    
    r_g <- terra::rast(g)                   # puede venir sin CRS
    if (is.na(terra::crs(r_g, describe=TRUE)$code))
      terra::crs(r_g) <- "EPSG:6933"        # ⇦ asigna CRS faltante
    
    bb4326 <- terra::vect(matrix(
      c(bbox[1],bbox[4], bbox[3],bbox[4],
        bbox[3],bbox[2], bbox[1],bbox[2],
        bbox[1],bbox[4]), ncol=2, byrow=TRUE),
      type="polygons", crs="EPSG:4326")
    bb6933 <- terra::project(bb4326, "EPSG:6933")
    r_cut  <- try(terra::crop(r_g, bb6933), silent=TRUE)
    if (inherits(r_cut,"try-error") || terra::ncell(r_cut)==0) return(NA)
    
    r_wgs <- terra::project(r_cut, "EPSG:4326", method="bilinear")
    terra::writeRaster(r_wgs, c,
                       datatype="FLT4S",
                       wopt=list(gdal=c("COMPRESS=LZW","TILED=YES")), overwrite=TRUE)
    
    googledrive::drive_upload(
      media = c, path = googledrive::as_id(drive_folder_id),
      name  = nm, overwrite = TRUE)$name
  }
  
  ## ---------- 3. orquestación ------------------------------------------
  urls <- cmr_list()
  message(length(urls), " granulos encontrados")
  
  pb <- progress::progress_bar$new(
    " Procesando [:bar] :current/:total",
    total = length(urls), clear = FALSE)
  
  out <- purrr::map_chr(urls, \(u){res<-process_one(u); pb$tick(); res})
  pb$terminate(); fs::dir_delete(tmp_dir)
  invisible(out)
}
