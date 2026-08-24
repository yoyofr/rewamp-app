/* PT3PLAYER.H
 *
 * player functions for PT3
 *
 */

#ifndef PT3PLAYER_H

#define PT3PLAYER_H

//MAIN FUNCTION - instantly stops music
void func_mute();
//MAIN FUNCTION - runs 1 tick of music
// return 0 by default; 1 if reaches end/loop point;
int func_play_tick(int ch);
//MAIN FUNCTION - setup music for playing
int func_setup_music(uint8_t* music_ptr, int length, int ch, int first);
int func_restart_music(int ch);


void func_getregs(uint8_t *dest, int ch);

//YOYOFR (rewamp) — read-only views for the pattern visualizer.
// func_get_cursor: live (position, row). row is -1 before the first row.
// func_get_channel: what the pattern last asked of one channel.
// func_get_module: the module bytes as loaded for this chip; returns the TS
//   field (0x20 = not TurboSound), which the pattern-pointer lookup needs.
void func_get_cursor(int ch, int *position, int *row);
void func_get_channel(int ch, int chan, int *note, int *volume, int *enabled);
int  func_get_module(int ch, const uint8_t **data, int *length);

extern int forced_notetable;

#endif
