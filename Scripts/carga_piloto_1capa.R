# The source of this script is 
#https://git.wur.nl/isric/soilgrids/soilgrids.notebooks/-/blob/master/markdown/webdav_from_R.md#to-local-vrt-in-homolosine-directly-from-the-webdav-connection
#Visited  and tried 25.05.30

# Install or load packages
if (!"pacman" %in% installed.packages()[,"Package"]) install.packages("pacman")
pacman::p_load("terra", "gdalUtilities")

# WebDAV: direct access to the maps in VRT format. --------------

# Ventana en Colombia
# Ejemplo: xmin, ymax, xmax, ymin (en metros IGH)
bb <- c(-8800000.000, 1400000.000, -7400000.000, -500000.000)

igh='+proj=igh +lat_0=0 +lon_0=0 +datum=WGS84 +units=m +no_defs' # proj string for Homolosine projection

#SoilGirds url
sg_url="/vsicurl?max_retry=3&retry_delay=1&list_dir=no&url=https://files.isric.org/soilgrids/latest/data/"


#To local VRT in homolosine (directly from the webdav connection). It is a light file, a few KB
#The first step is to obtain a VRT for the area of interest in the Homolosine projection. We suggest to use VRT for the intermediate steps to save space and computation times
gdal_translate(paste0(sg_url,'ocs/ocs_0-30cm_mean.vrt'),
               "./crop_roi_igh_r.vrt",
               of="VRT",tr=c(250,250),
               projwin=bb,
               projwin_srs =igh)



#To a final Geotiff
#The following command will generate a Geotiff in the projection of your choice for the area of interest defined above
gdal_translate("./crop_roi_ll_r.vrt",  
               "./crop_roi_ll_r.tif", 
               co=c("TILED=YES","COMPRESS=DEFLATE","PREDICTOR=2","BIGTIFF=YES"))


#Read in R
#Finally you can read any of the generated VRTs or GeoTiffs in R for further analysis
rst=rast("./crop_roi_igh_r.vrt") # Or any other of the files produce above

plot(rst) # Plot the file
