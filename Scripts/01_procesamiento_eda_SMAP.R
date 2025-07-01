## ----configuracion------------------------------------------------------------------------------------------

#Para exportar como .R plano
# knitr::purl('03_analisis_eda_rao_colombia.Rmd')

# Para cargar librerias se verifica pacman
if ("pacman" %in% installed.packages() == FALSE) install.packages("pacman")

# Se cargan las librerias
pacman::p_load(char = c(
  "here",                   # manejo de rutas
  "googledrive",            # manejo de archivos en Google Drive
  "sf",                     # manipulación de dats espaciales
  "terra",                  # rasters
  "dplyr",                  # procesamiento de data frames
  "tidyr", 
  "lubridate",              # manejo de fechas
  "ggplot2",                # graficación
  "patchwork",              # mosaicos gráficos
  "paletteer",              # paleta de colores
  "qs"                      # escribir y leer rápidamente objetos R
  )
)


# Ajusta tamaño de letra para las gráficas que genere el script
theme(base_size = 14)


# Selección entorno ya existente antes de cualquier llamado que use Python
reticulate::use_condaenv("rgee_py", required = TRUE)

## Librerías que usan Python 
library(reticulate)
library(rgee)
library(googledrive)

# ==== Autenticación y backend Python ====
# Se fuerzan credenciales limpias para evitar colisiones de proyectos GEE entre sesiones
ee_clean_user_credentials()      # Limpia credenciales de GEE
ee_clean_pyenv()           # Limpia variables de entorno de reticulate
reticulate::py_run_string("import ee; ee.Authenticate()")
reticulate::py_run_string("import ee; ee.Initialize(project='even-electron-461718-g2')") #cuenta gmail propia
#reticulate::py_run_string("import ee; ee.Initialize(project='optimal-signer-459113-i1')") #cuenta UNAL

# === Autenticación Google Drive ===
googledrive::drive_auth()


## -----------------------------------------------------------------------------------------------------------

#Falta código



## ----carga--------------------------------------------------------------------------------------------------


source("00_funcion_descarga_smap_dispatch.R")   # carga función

# 1. Credenciales Earthdata
Sys.setenv(EARTHDATA_USER = "cmguiob@unal.edu.co", EARTHDATA_PASS = "Emacacus56900!")

# 2. Bounding box Colombia (lat/long WGS-84)
bbox_col <- c(-79.11, -4.49, -65.65, 12.58)

# 4. Ejecuta la función para 2022-2023
download_smap_dispatch(
  start_date      = "2022-01-01", #modificar según ONI
  end_date        = "2023-12-31", #modificar según ONI
  bbox            = bbox_col,
  drive_folder_id = "1MO7foHhqvcI6zRI2EFJ2ic_KvVdlWQXM", #acá se guardan los .tif
  earthdata_user  = Sys.getenv("EARTHDATA_USER"),
  earthdata_pass  = Sys.getenv("EARTHDATA_PASS")
)



## -----------------------------------------------------------------------------------------------------------

dir_smap <- here::here("Data")
files <- list.files(dir_smap, pattern = "SM_DS_[0-9]{8}\\.tif$", full.names = TRUE)
stopifnot(length(files) > 0)

sm_stack <- rast(files)

# Calculo de raster promedio mensual
mean_r <- mean(sm_stack, na.rm = TRUE)

# Grafica y guarda como PNG
out_plot <- file.path(here::here("Figures"), "SMAP_1km_SM_DS_202207_media_plot.png")
png(out_plot, width = 1500, height = 1100, res = 150)
plot(mean_r, main = "Media Humedad del Suelo (SM_DS, 202207)", col = terrain.colors(20))
dev.off()
cat("Plot saved to:", out_plot, "\n")




## -----------------------------------------------------------------------------------------------------------

dir_smap <- here::here("Data")
out_dir  <- here::here("Figures")

files <- list.files(dir_smap, pattern = "SM_DS_[0-9]{8}\\.tif$", full.names = TRUE)
stopifnot(length(files) > 0)

# Extrae fechas
dates <- as.Date(sub(".*SM_DS_([0-9]{8})\\.tif$", "\\1", files), "%Y%m%d")
df <- data.frame(file = files, date = dates)
df <- arrange(df, date)

# Define ventanas de 4 días no solapados
n <- 4
n_blocks <- ceiling(nrow(df)/n)
block_ids <- rep(seq_len(n_blocks), each = n)[seq_len(nrow(df))]
df$block <- block_ids

# Calcula raster promedio por bloque de 4 días y guarda los títulos
block_means <- list()
titles <- character()
for (i in unique(df$block)) {
  blk_files <- df$file[df$block == i]
  if (length(blk_files) == 0) next
  r <- rast(blk_files)
  mean_r <- mean(r, na.rm = TRUE)
  block_means[[i]] <- mean_r
  blk_dates <- df$date[df$block == i]
  titles[i] <- sprintf("Humedad del Suelo Promedio\n%s a %s",
                       format(min(blk_dates)), format(max(blk_dates)))
}

block_means <- Filter(Negate(is.null), block_means)
titles <- titles[seq_along(block_means)]

# Apila todos los promedios
stack_blocks <- rast(block_means)
names(stack_blocks) <- titles

# Plotea mosaico con títulos por panel
out_plot <- file.path(out_dir, "SMAP_1km_SM_DS_4day_mosaic.png")
png(out_plot, width = 2200, height = 1400, res = 120)
plot(stack_blocks,
     main = titles,
     col = terrain.colors(20),
     mar = c(2,2,4,6))
dev.off()
cat("Mosaico PNG guardado en:", out_plot, "\n")



## -----------------------------------------------------------------------------------------------------------

# Primero se seleccionan y verifican 4 puntos
coords <- data.frame(
  x = c(-70, -74.5, -74, -76.5),
  y = c(4,    5,   10,   5.5)
)
point_names <- c("Amazonia", "Andina", "Caribe", "Pacífico")

# Se visualizan los puntos espacialmente
plot(sm_stack[[1]])
points(coords$x, coords$y, pch=19, col=2:5, cex=2)

dir_smap <- here::here("Data")
files <- list.files(dir_smap, pattern = "SM_DS_[0-9]{8}", full.names = TRUE)
stopifnot(length(files) > 0)

# Se crea serie con nombres de archivo
dates <- as.Date(sub(".*SM_DS_([0-9]{8}).*", "\\1", files), "%Y%m%d")
ord <- order(dates)
files <- files[ord]
dates <- dates[ord]
sm_stack <- rast(files)

# Verifica que los puntos están dentro del extent
ext_r <- ext(sm_stack)
for(i in 1:nrow(coords)) {
  if(!(coords$x[i] >= ext_r[1] && coords$x[i] <= ext_r[2] && coords$y[i] >= ext_r[3] && coords$y[i] <= ext_r[4])) {
    warning(sprintf("El punto %s (%.2f, %.2f) está fuera del extent del raster.", point_names[i], coords$x[i], coords$y[i]))
  }
}

# Extrae valores (usa method="simple" y desactiva ID)
valores <- terra::extract(sm_stack, coords, method = "simple", ID = FALSE)

if (all(is.na(valores))) {
  stop("Ningún punto coincide con píxeles válidos. Prueba con coordenadas ligeramente distintas o revisa el extent del raster.")
}

# Si algún punto quedó vacío, adviértelo:
for(i in 1:nrow(coords)) {
  if(all(is.na(valores[i, ]))) warning(sprintf("El punto %s quedó vacío (NAs)", point_names[i]))
}

# Dataframe largo
df_long <- as.data.frame(t(valores))
colnames(df_long) <- point_names
df_long$fecha <- dates

df_long <- pivot_longer(df_long, -fecha, names_to = "Zona", values_to = "SM")

# Grafica sólo si hay datos
if(any(!is.na(df_long$SM))) {
  ggplot(df_long, aes(x = fecha, y = SM, color = Zona)) +
    geom_point(size = 1.2) +
    labs(title = "Serie diaria de humedad del suelo",
         x = "Fecha", y = "Humedad del suelo (m³/m³)", color = "Zona") +
    theme_minimal(base_size = 14)
} else {
  cat("No hay datos válidos para graficar en los puntos seleccionados.\n")
}

# Imprime coordenadas y revisa
coords$Zona <- point_names
print(coords)



## -----------------------------------------------------------------------------------------------------------

# Colección diaria recortada
chirps_daily <- ee$ImageCollection("UCSB-CHG/CHIRPS/DAILY")$
  filterBounds(bbox_ee)$  #descarta las imágenes cuyo footprint no toca tu bbox_ee
  filterDate("2013-01-01", "2023-01-01")

# ── Agregación mensual (mm por mes) ──────────────────────────────────────────
chirps_monthly_ic <- ee$ImageCollection(
  ee$List$sequence(2013, 2023)$map(ee_utils_pyfunc(function(y) {
    ee$List$sequence(1, 12)$map(ee_utils_pyfunc(function(m) {
      start <- ee$Date$fromYMD(y, m, 1)
      end   <- start$advance(1, "month")
      chirps_daily$
        filterDate(start, end)$
        sum()$                         # mm del mes
        clip(bbox_ee)$
        set("system:time_start", start)
    }))
  }))$flatten()
)

# ── (1) CV TEMPORAL POR PÍXEL (mensual) ─────────────────────────────────────
precip_mean_temp <- chirps_monthly_ic$mean()$rename("precip_mean_temp")
precip_sd_temp   <- chirps_monthly_ic$reduce(ee$Reducer$stdDev())$rename("precip_sd_temp")
precip_cv_temp   <- precip_sd_temp$divide(precip_mean_temp)$rename("precip_cv_temp")

# Verificación visual en el visor de Earth Engine
Map$setCenter(lon = -74, lat = 4, zoom = 5)
Map$addLayer(
  precip_cv_temp,
  list(min = 0, max = 1, palette = pal_prec),
  "Precip CV temporal (mensual)"
)



## -----------------------------------------------------------------------------------------------------------


#Extrae estadísticas  por UCS y las envía a Drive en lotes adaptativos - debe cambiarse a localizaciones de pixeles
source(here::here("Scripts", "00_funcion_procesamiento_lotes_imagen.R"), encoding = "UTF-8")

registro_precip_cv_temporal <- procesamiento_lotes_imagen(ucs_sf_4326, image = precip_cv_temp, start_idx = 1, max_index = nrow(ucs_sf_4326), batch_s = 300, reduce_batch_by = 3, variable_name  = "PRECIP_cv_temporal", scale = 500)


#Copia local de archivos combinados para reproducibilidad offline
combinar_y_subir_csv <- function(PRECIP_cv_temporal,
                                 carpeta_drive_id_origen = "17yxwhlpgL4EG8inI5u8Nwi08wOrnhJiM",  # GEE_exports
                                 carpeta_drive_id_destino = "1PhfwOQOuHXmEIKE20i2-nqZaRrRfW0V9",  # Proyecto
                                 carpeta_temporal = "tmp_csv") {

  # Crea carpeta temporal local si no existe
  if (!dir.exists(carpeta_temporal)) {
    dir.create(carpeta_temporal)
  }

  # Listar archivos en Google Drive (solo .csv con prefijo exacto)
  archivos_drive <- googledrive::drive_ls(
    path = as_id(carpeta_drive_id_origen),
    pattern = glue::glue("^{propiedad}_.*\\.csv$")
  ) |>
    dplyr::filter(stringr::str_ends(name, ".csv"))

  if (nrow(archivos_drive) == 0) {
    stop(glue::glue("No se encontraron archivos CSV para la propiedad '{propiedad}' en GEE_exports."))
  }

  message(glue::glue("📥 Descargando {nrow(archivos_drive)} archivos CSV para '{propiedad}'..."))

  # Descargar archivos al directorio temporal
  purrr::walk2(
    archivos_drive$name,
    archivos_drive$id,
    ~ googledrive::drive_download(
      file = as_id(.y),
      path = file.path(carpeta_temporal, .x),
      overwrite = TRUE
    )
  )

  # Leer y combinar
  archivos_locales <- list.files(path = carpeta_temporal,
                                 pattern = paste0("^", propiedad, "_.*\\.csv$"),
                                 full.names = TRUE)

  combinado <- purrr::map_dfr(archivos_locales, readr::read_csv, show_col_types = FALSE)

  # Escribir archivo combinado
  nombre_salida <- paste0("OUT_", propiedad, "_combinado.csv")
  ruta_salida <- file.path(carpeta_temporal, nombre_salida)
  readr::write_csv(combinado, ruta_salida)

  # Subir a carpeta final de proyecto en Drive
  archivo_subido <- googledrive::drive_upload(
    media = ruta_salida,
    path = as_id(carpeta_drive_id_destino),
    name = nombre_salida,
    overwrite = TRUE
  )

  message(glue::glue("✅ Archivo combinado subido: {archivo_subido$name} (ID: {archivo_subido$id})"))

  # Limpieza automática
  unlink(carpeta_temporal, recursive = TRUE)
  message("🧹 Archivos temporales eliminados.")
}




## -----------------------------------------------------------------------------------------------------------

# Precip cv temporal
precip_cv_temp <- readr::read_csv(
  here::here("Data/OUT_PRECIP_cv_temporal_combinado.csv"),
  show_col_types = FALSE
)

