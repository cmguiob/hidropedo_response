# 1. Se consulta el catálogo CMR (Earthdata) para listar todos los granulos .tif
#    disponibles que cumplan con los filtros temporales y espaciales.
# 2. Cada archivo se descarga en dos pasos:
#    a) Primero sin autenticación, para obtener una posible redirección HTTP.
#    b) Luego con autenticación básica (usuario y contraseña Earthdata).
#    Este flujo reproduce el comportamiento requerido por el servicio URS.
# 3. Los archivos descargados se validan, se recortan a la zona de interés,
#    se reproyectan a EPSG:4326, y se suben directamente a Google Drive.
#
# NOTAS:
# - Todos los archivos temporales se almacenan localmente en `tempdir()` y se
#   eliminan automáticamente al finalizar.
# - Esta función requiere conexión activa a internet y permisos válidos para
#   acceder al dataset NSIDC-0779 desde Earthdata.
# - Si la autenticación falla con error 401, verificar que se haya iniciado sesión
#   en Earthdata y autorizado el acceso al producto: https://nsidc.org/data/nsidc-0779
#
# Autor: Carlos Guío 
# Última revisión funcional: junio de 2025
# ------------------------------------------------------------------------------

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
    
    ## Paso 1: intento sin autenticación para obtener redirección (si aplica)
    try({
      redirect_url <- httr::RETRY("GET", url, times=1, pause_min=1)
      url <- redirect_url$url  # actualiza la URL si fue redirigida
    }, silent = TRUE)
    
    ## Paso 2: intento con autenticación explícita
    auth <- httr::authenticate(earthdata_user, earthdata_pass)
    response <- httr::RETRY("GET", url,
                            auth,
                            httr::write_disk(g, overwrite=TRUE),
                            times=max_tries, pause_min=2)
    
    ## Verifica si el archivo descargado es sospechoso o inválido
    if (file.size(g) < 10 * 1024 || grepl("html", tolower(readLines(g, n = 1)))) {
      warning(paste("Archivo sospechoso o inválido:", nm))
      return(NA)
    }
    
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
