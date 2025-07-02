## ----configuracion--------------------------------------------------------------------------------------------

#Para exportar como .R plano
# knitr::purl('01_procesamiento_eda_SMAP.qmd')

# Para cargar librerias se verifica pacman
if ("pacman" %in% installed.packages() == FALSE) install.packages("pacman")

# Se cargan las librerias
pacman::p_load(char = c(
  "here",                   # manejo de rutas
  "googledrive",            # manejo de archivos en Google Drive
  "rsoi",                   # serie de tiempo ONI
  "sf",                     # manipulación de datos espaciales
  "terra",                  # rasters
  "dplyr",                  # procesamiento de data frames
  "tidyr",                  # limpieza y transformación de datos
  "lubridate",              # manejo de fechas
  "spatstat.geom",          # estructuras geométricas de spatstat
  "spatstat.random",        # generación de patrones de puntos aleatorios
  "spatstat.explore",       # análisis exploratorio de patrones espaciales
  "ggplot2",                # graficación
  "patchwork",              # mosaicos gráficos
  "paletteer",              # paleta de colores
  "qs"                      # l
))

# Ajusta tamaño de letra para las gráficas que genere el script
theme(base_size = 14)

#Paleta de colores
pal <- paletteer::paletteer_d("wesanderson::Zissou1Continuous", n = 11)

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


## -------------------------------------------------------------------------------------------------------------

# Cargar polígono de Colombia
colombia <- vect(here::here("Data","mascara_colombia.gpkg"))


## ----tabla_oni------------------------------------------------------------------------------------------------

# 1. Descargar serie ENSO
enso_raw <- rsoi::download_enso()

# 2. Preparar datos
enso_df <- enso_raw |>
  mutate(
    Date = as.Date(Date),
    year = year(Date),
    month = month(Date),
    oni_cat = case_when(
      ONI >= 0.5 ~ "El Niño",
      ONI <= -0.5 ~ "La Niña",
      TRUE ~ "Neutral"
    )
  )

# 3. Identificar bloques Niño/Niña de al menos 5 meses consecutivos
get_events <- function(df, target_phase, min_length = 5) {
  df <- df %>%
    mutate(flag = oni_cat == target_phase,
           grp = cumsum(c(0, diff(flag)) != 0 & flag)) %>%
    group_by(grp) %>%
    filter(flag) %>%
    summarise(start = min(Date), end = max(Date), n_months = n()) %>%
    filter(n_months >= min_length) %>%
    mutate(phase = target_phase) %>%
    select(phase, start, end, n_months)
  return(df)
}

nino_events <- get_events(enso_df, "El Niño", 5)
nina_events <- get_events(enso_df, "La Niña", 5)

# 4. Mostrar periodos válidos
events_tbl <- bind_rows(nino_events, nina_events) %>%
  arrange(start)

print(events_tbl)



## ----visualiza_oni--------------------------------------------------------------------------------------------

# Crear data frame con los periodos seleccionados
selected_periods <- data.frame(
  start = as.Date(c("2015-03-31", "2021-07-01")),
  end   = as.Date(c("2016-06-01", "2023-02-01"))
)

# Gráfico final corregido
enso_plot <- ggplot(enso_df, aes(x = Date, y = ONI)) +
  # Áreas sombreadas de Niño y Niña seleccionados (sin leyenda)
  geom_rect(data = selected_periods,
            aes(xmin = start, xmax = end, ymin = -Inf, ymax = Inf),
            fill = "gray50", alpha = 0.2,
            inherit.aes = FALSE, show.legend = FALSE) +
  # Barras ONI codificadas por fase
  geom_col(aes(fill = oni_cat), show.legend = TRUE) +
  scale_fill_manual(
    values = c("La Niña" = pal[1], "Neutral" = "gray70", "El Niño" = pal[10]),
    name = NULL
  ) +
  # Eje temporal
  scale_x_date(
    date_breaks = "10 years",
    date_labels = "%Y",
    expand = expansion(mult = c(0.01, 0.01))
  ) +
  # Líneas horizontales clave
  geom_hline(yintercept = c(-0.5, 0.5),
             linetype = "dotted", color = "gray40") +
  # Inicio SMAP 1 abril 2015
  geom_vline(xintercept = as.Date("2015-03-31"), 
             color = "black", 
             linetype = "solid", 
             linewidth = 0.6) +
  annotate("text", 
           x = as.Date("2015-03-31"), y = 1.6, 
           label = "Inicio SMAP", 
           angle = 90, vjust = -0.5, hjust = 0, size = 3.5) +
  # Inicio CHIRPS 1 enero 1981
  geom_vline(xintercept = as.Date("1981-01-01"), 
             color = "gray40", 
             linetype = "solid", 
             linewidth = 0.6) +
  annotate("text", 
           x = as.Date("1981-01-01"), y = 1.3, 
           label = "Inicio CHIRPS", 
           angle = 90, vjust = -0.5, hjust = 0, size = 3.5) +
  # Estética general
  labs(
    title = "Índice ONI y fases ENSO seleccionadas",
    y = "ONI (Oceanic Niño Index)",
    x = NULL
  ) +
  theme_minimal(base_size = 14) +
  theme(
    legend.position = "top",
    panel.grid.major.y = element_line(color = "gray90", linetype = "dotted"),
    panel.grid.minor.y = element_blank(),
    panel.grid.major.x = element_blank(),
    panel.grid.minor.x = element_blank()
  )

# Mostrar gráfico
enso_plot

# Guardar
ggsave(
  filename = here::here("Figures", "ENSO_ONI_fases_sombreado.png"),
  plot = enso_plot,
  width = 9, height = 5, dpi = 350
)



## ----descarga_smap--------------------------------------------------------------------------------------------

# Descarga de SMAP NSIDC-0779 para Colombia en los periodos ENSO definidos
# - El Niño: marzo 2015 a junio 2016
# - La Niña: julio 2021 a febrero 2023
# Los archivos .tif se almacenan en Google Drive (ID definido)
# ------------------------------------------------------------------------------

source("00_funcion_descarga_smap_dispatch.R")   # carga función de descarga SMAP

# 1. Credenciales Earthdata
Sys.setenv(EARTHDATA_USER = "cmguiob@unal.edu.co", EARTHDATA_PASS = "Emacacus56900!")

# 2. Bounding box para Colombia (EPSG:4326)
bbox_col <- c(-79.11, -4.49, -65.65, 12.58)

# 3. Folder en Google Drive donde se guardan los archivos descargados
drive_folder_id <- "1a7XAOTseCCJhs7Ynw2KZPMMmrcGGHjlW" #es un id de cm.guiob@gmail.com

# 4. Descarga: El Niño 2015–2016 (ajustado a inicio de SMAP) - 914 imágenes encontradas
# download_smap_dispatch(
#   start_date      = "2015-10-09",
#   end_date        = "2016-06-30",
#   bbox            = bbox_col,
#   drive_folder_id = drive_folder_id,
#   earthdata_user  = Sys.getenv("EARTHDATA_USER"),
#   earthdata_pass  = Sys.getenv("EARTHDATA_PASS")
# )

# 5. Descarga: La Niña 2021–2022
# download_smap_dispatch(
#   start_date      = "2022-04-04",
#   end_date        = "2022-12-01",
#   bbox            = bbox_col,
#   drive_folder_id = drive_folder_id,
#   earthdata_user  = Sys.getenv("EARTHDATA_USER"),
#   earthdata_pass  = Sys.getenv("EARTHDATA_PASS")
# )



## ----carga_niño-----------------------------------------------------------------------------------------------

# ==== Periodo El Niño ====

# Ruta con archivos SMAP descargados
dir_nino <- here("Data", "SMAP 1km - NSIDC-0779")

# Seleccionar archivos correspondientes al periodo El Niño (2015–2016)
files_nino <- list.files(dir_nino, pattern = "SM_DS_201[5-6][0-9]{4}\\.tif$", full.names = TRUE)

# Cargar como stack de raster
sm_stack_nino <- rast(files_nino)

# Extraer metainformación
n_nino     <- nlyr(sm_stack_nino)            # Número de capas
res_nino   <- res(sm_stack_nino)             # Resolución espacial (grados)
n_pix_nino <- ncell(sm_stack_nino[[1]])      # Número de celdas por capa

# Calcular estadísticas
mean_nino <- mean(sm_stack_nino, na.rm = TRUE)      # Promedio
sd_nino   <- stdev(sm_stack_nino, na.rm = TRUE)     # Desviación estándar
cv_nino   <- sd_nino / mean_nino                    # Coeficiente de variación


# ==== Mapa promedio SMAP - El Niño ====

png(here("Figures", "SMAP_promedio_nino.png"), width = 1500, height = 1100, res = 150)

plot(mean_nino,
     col = viridis::viridis(20, direction = -1),   # Paleta invertida (más seco = claro)
     main = NULL,                                  # Título se añade manualmente
     plg = list(title = "m³/m³", title.cex = 1.5, cex = 1.5),  # Leyenda con tamaño aumentado
     pax = list(cex.axis = 1.8),                   # Tamaño del texto en ejes
     cex.main = 1.8)                               # Para el title() posterior

title(main = "Promedio SMAP - El Niño", line = 3, cex.main = 1.5)
title(main = paste0("N° píxeles: ", format(n_pix_nino, big.mark = ",")),
       line = 1, cex.main = 1.3)

dev.off()


# ==== Mapa coeficiente de variación SMAP - El Niño ====

png(here("Figures", "SMAP_cv_nino.png"), width = 1500, height = 1100, res = 150)

plot(cv_nino,
     col = viridis::magma(20),                      # Paleta magma para variabilidad
     main = NULL,
     plg = list(title = "CV", title.cex = 1.5, cex = 1.5),
     pax = list(cex.axis = 1.8),
     cex.main = 1.8)

title(main = "Coef. de variación SMAP - El Niño", line = 3, cex.main = 1.5)
title(main = paste0("N° píxeles: ", format(n_pix_nino, big.mark = ",")),
       line = 1, cex.main = 1.3)

dev.off()



## ----carga_niña-----------------------------------------------------------------------------------------------

# Seleccionar archivos para periodo La Niña (2021–2022)
files_nina <- list.files(dir_nino, pattern = "SM_DS_202[1-2][0-9]{4}\\.tif$", full.names = TRUE)

# Cargar como stack de raster
sm_stack_nina <- rast(files_nina)

# Extraer metadatos
n_nina     <- nlyr(sm_stack_nina)
res_nina   <- res(sm_stack_nina)
n_pix_nina <- ncell(sm_stack_nina[[1]])

# Estadísticas
mean_nina <- mean(sm_stack_nina, na.rm = TRUE)
sd_nina   <- stdev(sm_stack_nina, na.rm = TRUE)
cv_nina   <- sd_nina / mean_nina

# ==== Mapa promedio SMAP - La Niña ====

png(here("Figures", "SMAP_promedio_nina.png"), width = 1500, height = 1100, res = 150)

plot(mean_nina,
     col = viridis::viridis(20, direction = -1),
     main = NULL,
     plg = list(title = "m³/m³", title.cex = 1.5, cex = 1.5),
     pax = list(cex.axis = 1.8),
     cex.main = 1.8)

title(main = "Promedio SMAP - La Niña", line = 3, cex.main = 1.5)
title(main = paste0("N° píxeles: ", format(n_pix_nina, big.mark = ",")),
       line = 1, cex.main = 1.3)

dev.off()


# ==== Mapa coeficiente de variación SMAP - La Niña ====

png(here("Figures", "SMAP_cv_nina.png"), width = 1500, height = 1100, res = 150)

plot(cv_nina,
     col = viridis::magma(20),
     main = NULL,
     plg = list(title = "CV", title.cex = 1.5, cex = 1.5),
     pax = list(cex.axis = 1.8),
     cex.main = 1.8)

title(main = "Coef. de variación SMAP - La Niña", line = 3, cex.main = 1.5)
title(main = paste0("N° píxeles: ", format(n_pix_nina, big.mark = ",")),
       line = 1, cex.main = 1.3)

dev.off()




## ----cobertura_util-------------------------------------------------------------------------------------------

n_nino <- nlyr(sm_stack_nino)
n_nina <- nlyr(sm_stack_nina)

# Calcular número de observaciones válidas por pixel
cobertura_raw_nino <- app(sm_stack_nino, fun = function(x) sum(!is.na(x)))
cobertura_raw_nina <- app(sm_stack_nina, fun = function(x) sum(!is.na(x)))

# Exportar mapa de cobertura cruda - Niño
png(here("Figures", "SMAP_cobertura_raw_nino.png"), width = 1500, height = 1100, res = 150)
plot(cobertura_raw_nino,
     col = pal,
     main = "Observaciones válidas - El Niño",
     cex.main = 1.8,  # Tamaño del título principal
     plg = list(title = "N días", title.cex = 1.5, cex = 2),
     pax = list(cex.axis = 1.8))
dev.off()

# Exportar mapa de cobertura cruda - Niña
png(here("Figures", "SMAP_cobertura_raw_nina.png"), width = 1500, height = 1100, res = 150)
plot(cobertura_raw_nina,
     col = pal,
     main = "Observaciones válidas - La Niña",
     cex.main = 1.8,  # Tamaño del título principal
     plg = list(title = "N días", title.cex = 1.5, cex = 2),
     pax = list(cex.axis = 1.8))
dev.off()

# Definir umbral mínimo basado en la inspección visual: aprox 50% de la suma max. de obs por pixel
cobertura_nino <- cobertura_raw_nino >= 100 
cobertura_nina <- cobertura_raw_nina >= 150

# Intersección de ambas coberturas
cobertura_ambos <- cobertura_nino & cobertura_nina

# Restringir cobertura al territorio nacional
cobertura_final <- mask(crop(cobertura_ambos, colombia), colombia)

# Exportar mapa de cobertura final
png(here("Figures", "SMAP_cobertura_final.png"), width = 1500, height = 1100, res = 150)
plot(cobertura_final,
     col = pal[1:6],
     main = "Observaciones válidas SMAP",
     cex.main = 1.8,  # Tamaño del título principal
     plg = list(title = "Área de muestreo", title.cex = 1.5, cex = 2),
     pax = list(cex.axis = 1.8))
dev.off()

# Guardar como raster para visualización opcional
writeRaster(cobertura_final, here("Data", "SMAP_cobertura_valida_ambos_periodos.tif"), overwrite = TRUE)


plot(cobertura_final)


## ----muestreo_inhibido_rssi-----------------------------------------------------------------------------------


# Paso 1: Convertir coordenadas válidas de cobertura_final a objeto sf y proyectarlas a EPSG:3857
val_coords_sf <- sf::st_as_sf(val_coords, coords = c("x", "y"), crs = 4326)
val_coords_proj <- sf::st_transform(val_coords_sf, 9377)

# Extraer coordenadas como matriz para usarlas con ppp()
val_coords_mat <- sf::st_coordinates(val_coords_proj)

# Paso 2: Preparar el polígono de Colombia como ventana owin (en metros)
# Se parte del objeto `colombia_proj` ya en EPSG:3857
# 2.1 Unificar geometrías si hay múltiples features
colombia_union <- sf::st_union(colombia_proj)

# 2.2 Validar geometría para evitar errores de topología
colombia_union <- sf::st_make_valid(colombia_union)

# 2.3 Convertir a ventana 'owin' directamente desde objeto sf
owin_col <- spatstat.geom::as.owin(colombia_union)

# Paso 3: Crear objeto ppp con los píxeles válidos dentro del polígono de Colombia
coords_ppp <- spatstat.geom::ppp(
  x = val_coords_mat[, "X"],
  y = val_coords_mat[, "Y"],
  window = owin_col
)

# Verificación
cat("✔️ Objeto ppp creado correctamente con", coords_ppp$n, "puntos válidos\n")


## -------------------------------------------------------------------------------------------------------------





## -------------------------------------------------------------------------------------------------------------

# Convertir raster lógico a data.frame para fondo del mapa
df_mask <- as.data.frame(cobertura_final, xy = TRUE, na.rm = TRUE)
names(df_mask)[3] <- "valido"

# Convertir puntos de muestreo a data.frame
df_muestreo <- as.data.frame(muestreo)

# Mapa base + puntos
ggplot() +
  geom_raster(data = df_mask, aes(x = x, y = y, fill = valido)) +
  scale_fill_manual(values = c("white", "grey80"), name = "Cobertura válida") +
  geom_point(data = df_muestreo, aes(x = x, y = y), color = "red", size = 0.7) +
  coord_sf(expand = FALSE) +
  labs(title = "Puntos de muestreo inhibido (rSSI) sobre zonas con datos SMAP válidos") +
  theme_minimal(base_size = 14)


## -------------------------------------------------------------------------------------------------------------

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



## -------------------------------------------------------------------------------------------------------------

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



## -------------------------------------------------------------------------------------------------------------


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




## -------------------------------------------------------------------------------------------------------------

# Precip cv temporal
precip_cv_temp <- readr::read_csv(
  here::here("Data/OUT_PRECIP_cv_temporal_combinado.csv"),
  show_col_types = FALSE
)

