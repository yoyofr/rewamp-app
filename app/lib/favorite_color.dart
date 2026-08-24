import 'package:flutter/material.dart';

/// Canonical golden colour of the "favourite" star. Used everywhere the star
/// indicates favourite status — artwork overlays, list rows, and toggle buttons
/// alike — so it always renders the same gold (it was previously white on some
/// artwork overlays and theme-tinted elsewhere).
const Color kFavoriteColor = Color(0xFFFFB300); // amber 700 — reads as gold on
                                                // both dark artwork and light rows
