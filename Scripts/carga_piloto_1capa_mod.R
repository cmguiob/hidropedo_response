if (!"pacman" %in% installed.packages()[,"Package"]) install.packages("pacman")
pacman::p_load("terra", "gdalUtilities")

# Bounding box IGH para Colombia: xmin, ymax, xmax, ymin (en metros IGH)
bb <- c(-8800000.000, 1400000.000, -7400000.000, -500000.000)
igh <- '+proj=igh +lat_0=0 +lon_0=0 +datum=WGS84 +units=m +no_defs'

sg_url <- "/vsicurl?max_retry=3&retry_delay=1&list_dir=no&url=https://files.isric.org/soilgrids/latest/data/"

var <- c("clay")
depth <- "0-5cm"
stat <- "mean"

layer_base <- paste0(var, "_", depth, "_", stat)
vrt_remote <- paste0(sg_url, var, "/", layer_base, ".vrt")
vrt_local  <- paste0("./", layer_base, ".vrt")
  
  # Elimina archivos previos si existen
  #if (file.exists(vrt_local)) file.remove(vrt_local)
  
  # 1. Recorte VRT
  gdal_translate(vrt_remote, 
                 vrt_local,
                 of="VRT", 
                 tr=c(250,250),
                 projwin=bb,
                 projwin_srs =igh)
  
  # 2. GeoTIFF comprimido (opcional)
  #tiff_local <- paste0("./", layer_base, "_colombia.tif")
  #if (file.exists(tiff_local)) file.remove(tiff_local)
  gdal_translate("./crop_roi_ll_r.vrt", #el error estaba en estas lineas
                 "./crop_roi_ll_r.tif", #el error estaba en estas lineas
                 of = "GTiff",
                 co = c("TILED=YES", "COMPRESS=DEFLATE", "PREDICTOR=2", "BIGTIFF=YES"))

  rst=rast("./crop_roi_igh_r.vrt") # Or any other of the files produce above
  
  plot(rst) # Plot the file  

