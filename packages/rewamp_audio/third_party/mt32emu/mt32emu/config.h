/* rewamp: config.h PRÉ-CUIT pour la lib STATIQUE (l'amont le génère par cmake
 * depuis config.h.in — voir UPSTREAM_COMMIT). API C++ uniquement (type 0),
 * pas d'objet partagé, pas d'étiquetage de version. Mettre à jour la version
 * en resynchronisant. */
#ifndef MT32EMU_CONFIG_H
#define MT32EMU_CONFIG_H

#define MT32EMU_VERSION      "2.8.3"
#define MT32EMU_VERSION_MAJOR 2
#define MT32EMU_VERSION_MINOR 8
#define MT32EMU_VERSION_PATCH 3

#define MT32EMU_EXPORTS_TYPE 0

/* Static library build: MT32EMU_SHARED intentionally undefined. */

#define MT32EMU_WITH_VERSION_TAGGING 0
#undef MT32EMU_RUNTIME_VERSION_CHECK

#endif /* #ifndef MT32EMU_CONFIG_H */
