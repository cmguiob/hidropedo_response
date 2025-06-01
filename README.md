# Patrones espacio-temporales de respuesta hidrológica de humedad del suelo satelital en Colombia. Una aproximación para la diferenciación hidropedológica.
## Spatio-temporal patterns of satellite-based soil moisture response in Colombia. 

La humedad del suelo es una variable climática esencial  (Bojinski et al., 2014; Hollmann et al., 2013), que modula procesos como la infiltración, la escorrentía y la evapotranspiración, y refleja la interacción dinámica entre propiedades edáficas e hidrológicas (Zhu et al., 2012; Vergopolan et al., 2022). Actualmente, la cartografía de suelos de Colombia no captura de forma adecuada dicha interacción. Como resultado, exsite una barrera para el uso de propiedades pedológicas -disponibles en los mapas y memorias de suelos- y el modelado de procesos hidrológicos.

En este contexto, las clases hidropedológicas surgen como una herramienta “suave” para segmentar funcionalmente el paisaje (Maréchal & Holman 2005, Rinderer & Seibert 2012, Van Tol et al. 2021, Smit et al. 2023), al identificar patrones de respuesta hidrológica que integran la humedad del suelo con sus propiedades morfológicas y fisicoquímicas. Ejemplos de este enfoque incluyen la “Hidrología de Tipos de Suelos” (HOST en inglés) desarrollados en el Reino Unido (Boorman et al., 1995), las clases hidropedológicas propuestas en Sudáfrica (Van Tol et al., 2013, 2024), y los Grupos Hidrológicos de Suelo (HSG) del Servicio de Conservación de Suelos de Estados Unidos (USDA-NRCS, 2007).

El presente estudio parte de dos hipótesis principales: (1) las interacciones de la evapotranspiración, la infiltración, y la escorrentía superficial y subsuperficial con la precipitación están parcialmente contenida en los patrones espacio-temporales de la humedad del suelo (Zhu et al., 2012, Rahmati et al. 2024), y esta a su vez, está modulada por propiedades edáficas relativamente estables a largo plazo (Bouma, 2020, Martínez- Fernández et al. 2021); (2) la “memoria” de humedad del suelo —i.e., la persistencia temporal de condiciones de humedad— permite analizar su respuesta hidrológica a través de series de tiempo de resolución diaria derivadas de sensores remotos (McColl et al. 2017, Rahmati et al. 2024).

**Objetivo general y alcance**

Este estudio tiene como objetivo identificar patrones espacio- temporales de la respuesta hidrológica de la humedad del suelo superficial, derivados de sensores remotos, y su relación con propiedades del perfil de suelos), para conceptualizar clases hidropedológicas espacializadas. 

**Datos**
* La comparación inicial de productos satelitales de humedad del suelo se apoyó en la síntesis de 16 conjuntos de datos activos, pasivos, combinados y de re-análisis compilada por Fan et al. (2025), de la cual se seleccionó SMAP-DisPATCh (NSIDC-0779) por su mayor resolución (1 km) y robustez durante eventos de lluvia (Colliander et al., 2020). SMAP-DisPATCh se basa en el algoritmo DisPATCh (Lv et al., 2018), que desagrega el producto radiométrico de 9 km de SMAP a escalas hectométricas usando la temperatura de la superficie terrestre y un modelo físico-empírico.

* Los datos de precipitación utilizados para evaluar la respuesta hidrológica provienen de *CHIRPS* (Climate Hazards Group InfraRed Precipitation with Station data), un producto cuasi-global (50 °S-50 °N) con resolución espacial de 0,05 ° (~5 km) y período 1981-presente, que combina observaciones de satélite en el infrarrojo con datos de más de 20 000 estaciones pluviométricas (Funk et al., 2015).

* Los datos de suelos se usan como variables explicativas de la respuesta hidrológica de humedad del suelo. Estos se extrajeron de SoilGrids v.2, una base global derivada mediante machine-learning que predice 12 propiedades físico-químicas a seis profundidades hasta 200 cm (Hengl et al., 2017, Poggio et al. 2021). En este trabajo se re-muestraron dichos datos a 1 km para mantener coherencia espacial con SMAP-DisPATCh. Se seleccionaron propiedades morfológicas (antiguas) y químicas (recientes) cuya variación vertical ha sido usada en estudios in-situ para develar la respuesta hidrológica del suelo (Bower et al. 2014): arcilla, limo, arena, densidad, pH y contenido de carbono orgánico, a 5 rangos de profundidades, hasta los 100 cm.







