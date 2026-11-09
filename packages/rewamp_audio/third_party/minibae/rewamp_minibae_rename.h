// rewamp: renommage des symboles EXTERNES de miniBAE qui existent ailleurs dans
// le même binaire. Forcé en tête de CHAQUE TU miniBAE (cmake: -include;
// podspec: #include du wrapper avant la source), jamais modifié dans l'arbre
// vendoré. Liste MESURÉE le 2026-11-07 par intersection `nm` contre le pod
// macOS, les .a Android et les prébuilts libopenmpt/vgmstream:
//   adpcm_*          adpcm-xq, aussi vendoré par Furnace
//   mp3dec_*         minimp3, aussi dans libopenmpt et vgmstream
//   g72x_init_state  vgmstream
// À refaire à chaque resynchro (PLUGINS.md §6.5).
#ifndef REWAMP_MINIBAE_RENAME_H
#define REWAMP_MINIBAE_RENAME_H
#define adpcm_align_block_size bae_adpcm_align_block_size
#define adpcm_align_block_size_no_header bae_adpcm_align_block_size_no_header
#define adpcm_block_size_to_sample_count bae_adpcm_block_size_to_sample_count
#define adpcm_block_size_to_sample_count_no_header bae_adpcm_block_size_to_sample_count_no_header
#define adpcm_create_context bae_adpcm_create_context
#define adpcm_decode_block bae_adpcm_decode_block
#define adpcm_decode_block_ex bae_adpcm_decode_block_ex
#define adpcm_encode_block bae_adpcm_encode_block
#define adpcm_encode_block_ex bae_adpcm_encode_block_ex
#define adpcm_free_context bae_adpcm_free_context
#define adpcm_sample_count_to_block_size bae_adpcm_sample_count_to_block_size
#define adpcm_sample_count_to_block_size_no_header bae_adpcm_sample_count_to_block_size_no_header
#define adpcm_set_shaping_weight bae_adpcm_set_shaping_weight
#define g72x_init_state bae_g72x_init_state
#define mp3dec_decode_frame bae_mp3dec_decode_frame
#define mp3dec_init bae_mp3dec_init
#endif
