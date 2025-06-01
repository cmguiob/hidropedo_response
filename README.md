# Patrones espacio-temporales de respuesta hidrológica de humedad del suelo satelital en Colombia. Una aproximación para la diferenciación hidropedológica.
## Spatio-temporal patterns of satellite-based soil moisture response in Colombia. 

La humedad del suelo es una variable climática esencial  (Bojinski et al., 2014; Hollmann et al., 2013), que modula procesos como la infiltración, la escorrentía y la evapotranspiración, y refleja la interacción dinámica entre propiedades edáficas e hidrológicas (Zhu et al., 2012; Vergopolan et al., 2022). Actualmente, la cartografía de suelos de Colombia no captura de forma adecuada dicha interacción. Como resultado, exsite una barrera para el uso de propiedades pedológicas -disponibles en los mapas y memorias de suelos- y el modelado de procesos hidrológicos.

En este contexto, las clases hidropedológicas surgen como una herramienta “suave” para segmentar funcionalmente el paisaje (Maréchal & Holman 2005, Rinderer & Seibert 2012, Van Tol et al. 2021, Smit et al. 2023), al identificar patrones de respuesta hidrológica que integran la humedad del suelo con sus propiedades morfológicas y fisicoquímicas. Ejemplos de este enfoque incluyen la “Hidrología de Tipos de Suelos” (HOST en inglés) desarrollados en el Reino Unido (Boorman et al., 1995), las clases hidropedológicas propuestas en Sudáfrica (Van Tol et al., 2013, 2024), y los Grupos Hidrológicos de Suelo (HSG) del Servicio de Conservación de Suelos de Estados Unidos (USDA-NRCS, 2007).

El presente estudio parte de dos hipótesis principales: (1) las interacciones de la evapotranspiración, la infiltración, y la escorrentía superficial y subsuperficial con la precipitación están parcialmente contenida en los patrones espacio-temporales de la humedad del suelo (Zhu et al., 2012, Rahmati et al. 2024), y esta a su vez, está modulada por propiedades edáficas relativamente estables a largo plazo (Bouma, 2020, Martínez- Fernández et al. 2021); (2) la “memoria” de humedad del suelo —i.e., la persistencia temporal de condiciones de humedad— permite analizar su respuesta hidrológica a través de series de tiempo de resolución diaria derivadas de sensores remotos (McColl et al. 2017, Rahmati et al. 2024).

*Objetivo general y alcance*
Este estudio tiene como objetivo identificar patrones espacio- temporales de la respuesta hidrológica de la humedad del suelo superficial, derivados de sensores remotos, y su relación con propiedades del perfil de suelos), para conceptualizar clases hidropedológicas espacializadas. 

*Datos*
La evaluación de datos de humedad del suelo satelital se basó en la revisión de 39 fuentes con enlaces verificados por Fan et al. (2025), que abarca sensores basados en microondas pasivas y activas, fusiones multisensor y datos de reanálisis. De estos, se escogió el producto *SMAP-DisPATCh (NSIDC-0779)* de la NASA, que es una desagregación a *1km* del producto original de 9km (NASA), con profundidad de penetración de aproximada de 5cm (Lv et al. 2018). SMAP ha mostrado mantener su sensibilidad durante y después de eventos de lluvia (Colliander et al. 2020) , por lo que se identifica su viabilidad para estudiar la respuesta hidrológica.

Los datos de precipitación para identificar respuesta hidrológica provienen de CHIRPS...(completar descripción, + referencias).

Los datos de suelos se usan como variables explicativas de la respuesta hidrológica de humedad del suelo. Estos se extrajeron de SoilGrids, una base de datos global espacializada de propiedades fisicoqímicas del suelo, cuya resolución original es de 250 m (ref Hengl... ). Se extraen sin embargo los datos a escala de 1 km para trabajar de forma armonizada con la humedad del suelo de SMAP. Se seleccionaron propiedades morfológicas (antiguas) y químicas (recientes) cuya variación vertical ha sido usada en estudios in-situ para develar la respuesta hidrológica del suelo (Bower et al. 2014): arcilla, limo, arena, densidad, pH y contenido de carbono orgánico, a 5 rangos de profundidades, hasta los 100 cm.







