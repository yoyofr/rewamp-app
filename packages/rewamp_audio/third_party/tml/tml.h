/* TinyMidiLoader - v0.7 - Minimalistic midi parsing library - https://github.com/schellingb/TinySoundFont
   ALTERED for rewamp (2026-09): two changes.
   1. System Exclusive messages are KEPT (tml_load_filename_ex / tml_sysex_get) instead of
      being skipped — the MT-32 engine needs the Roland sysex that loads custom timbres.
      Loading through the original tml_load* entry points is unchanged.
   2. A RIFF/RMID wrapper is SKIPPED (tml_skip_rmid_wrapper, both stdio loaders). Upstream
      requires 'MThd' at offset 0, so an .mid that is really a RIFF container — Tyrian's
      soundtrack, and most Windows-era rips — failed to load with no usable diagnosis: the
      probe recognised RIFF....RMID and scored it, then the open refused it and the file
      played on nothing at all.
                                     no warranty implied; use at your own risk
   Do this:
      #define TML_IMPLEMENTATION
   before you include this file in *one* C or C++ file to create the implementation.
   // i.e. it should look like this:
   #include ...
   #include ...
   #define TML_IMPLEMENTATION
   #include "tml.h"

   [OPTIONAL] #define TML_NO_STDIO to remove stdio dependency
   [OPTIONAL] #define TML_MALLOC, TML_REALLOC, and TML_FREE to avoid stdlib.h
   [OPTIONAL] #define TML_MEMCPY to avoid string.h

   LICENSE (ZLIB)

   Copyright (C) 2017, 2018, 2020 Bernhard Schelling

   This software is provided 'as-is', without any express or implied
   warranty.  In no event will the authors be held liable for any damages
   arising from the use of this software.

   Permission is granted to anyone to use this software for any purpose,
   including commercial applications, and to alter it and redistribute it
   freely, subject to the following restrictions:

   1. The origin of this software must not be misrepresented; you must not
      claim that you wrote the original software. If you use this software
      in a product, an acknowledgment in the product documentation would be
      appreciated but is not required.
   2. Altered source versions must be plainly marked as such, and must not be
      misrepresented as being the original software.
   3. This notice may not be removed or altered from any source distribution.

*/

#ifndef TML_INCLUDE_TML_INL
#define TML_INCLUDE_TML_INL

#ifdef __cplusplus
extern "C" {
#endif

// Define this if you want the API functions to be static
#ifdef TML_STATIC
#define TMLDEF static
#else
#define TMLDEF extern
#endif

// Channel message type
enum TMLMessageType
{
	TML_NOTE_OFF = 0x80, TML_NOTE_ON = 0x90, TML_KEY_PRESSURE = 0xA0, TML_CONTROL_CHANGE = 0xB0, TML_PROGRAM_CHANGE = 0xC0, TML_CHANNEL_PRESSURE = 0xD0, TML_PITCH_BEND = 0xE0, TML_SET_TEMPO = 0x51,
	// rewamp: a kept System Exclusive message (see tml_load_filename_ex); `sysex` indexes the store
	TML_SYSEX_MESSAGE = 0xF0
};

// Midi controller numbers
enum TMLController
{
	TML_BANK_SELECT_MSB,      TML_MODULATIONWHEEL_MSB, TML_BREATH_MSB,       TML_FOOT_MSB = 4,      TML_PORTAMENTO_TIME_MSB,   TML_DATA_ENTRY_MSB, TML_VOLUME_MSB,
	TML_BALANCE_MSB,          TML_PAN_MSB = 10,        TML_EXPRESSION_MSB,   TML_EFFECTS1_MSB,      TML_EFFECTS2_MSB,          TML_GPC1_MSB = 16, TML_GPC2_MSB, TML_GPC3_MSB, TML_GPC4_MSB,
	TML_BANK_SELECT_LSB = 32, TML_MODULATIONWHEEL_LSB, TML_BREATH_LSB,       TML_FOOT_LSB = 36,     TML_PORTAMENTO_TIME_LSB,   TML_DATA_ENTRY_LSB, TML_VOLUME_LSB,
	TML_BALANCE_LSB,          TML_PAN_LSB = 42,        TML_EXPRESSION_LSB,   TML_EFFECTS1_LSB,      TML_EFFECTS2_LSB,          TML_GPC1_LSB = 48, TML_GPC2_LSB, TML_GPC3_LSB, TML_GPC4_LSB,
	TML_SUSTAIN_SWITCH = 64,  TML_PORTAMENTO_SWITCH,   TML_SOSTENUTO_SWITCH, TML_SOFT_PEDAL_SWITCH, TML_LEGATO_SWITCH,         TML_HOLD2_SWITCH,
	TML_SOUND_CTRL1,          TML_SOUND_CTRL2,         TML_SOUND_CTRL3,      TML_SOUND_CTRL4,       TML_SOUND_CTRL5,           TML_SOUND_CTRL6,
	TML_SOUND_CTRL7,          TML_SOUND_CTRL8,         TML_SOUND_CTRL9,      TML_SOUND_CTRL10,      TML_GPC5, TML_GPC6,        TML_GPC7, TML_GPC8,
	TML_PORTAMENTO_CTRL,      TML_FX_REVERB = 91,      TML_FX_TREMOLO,       TML_FX_CHORUS,         TML_FX_CELESTE_DETUNE,     TML_FX_PHASER,
	TML_DATA_ENTRY_INCR,      TML_DATA_ENTRY_DECR,     TML_NRPN_LSB,         TML_NRPN_MSB,          TML_RPN_LSB,               TML_RPN_MSB,
	TML_ALL_SOUND_OFF = 120,  TML_ALL_CTRL_OFF,        TML_LOCAL_CONTROL,    TML_ALL_NOTES_OFF,     TML_OMNI_OFF, TML_OMNI_ON, TML_POLY_OFF, TML_POLY_ON
};

// A single MIDI message linked to the next message in time
typedef struct tml_message
{
	// Time of the message in milliseconds
	unsigned int time;

	// Type (see TMLMessageType) and channel number
	unsigned char type, channel;

	// 2 byte of parameter data based on the type:
	// - key, velocity for TML_NOTE_ON and TML_NOTE_OFF messages
	// - key, key_pressure for TML_KEY_PRESSURE messages
	// - control, control_value for TML_CONTROL_CHANGE messages (see TMLController)
	// - program for TML_PROGRAM_CHANGE messages
	// - channel_pressure for TML_CHANNEL_PRESSURE messages
	// - pitch_bend for TML_PITCH_BEND messages
	union
	{
		#ifdef _MSC_VER
		#pragma warning(push)
		#pragma warning(disable:4201) //nonstandard extension used: nameless struct/union
		#elif defined(__GNUC__)
		#pragma GCC diagnostic push
		#pragma GCC diagnostic ignored "-Wpedantic" //ISO C++ prohibits anonymous structs
		#endif

		struct { union { char key, control, program, channel_pressure; }; union { char velocity, key_pressure, control_value; }; };
		struct { unsigned short pitch_bend; };
		// rewamp: index into the tml_sysex_store for TML_SYSEX messages (type 0xF0)
		struct { unsigned short sysex; };

		#ifdef _MSC_VER
		#pragma warning( pop )
		#elif defined(__GNUC__)
		#pragma GCC diagnostic pop
		#endif
	};

	// The pointer to the next message in time following this event
	struct tml_message* next;
} tml_message;

// The load functions will return a pointer to a struct tml_message.
// Normally the linked list gets traversed by following the next pointers.
// Make sure to keep the pointer to the first message to free the memory.
// On error the tml_load* functions will return NULL most likely due to an
// invalid MIDI stream (or if the file did not exist in tml_load_filename).

#ifndef TML_NO_STDIO
// Directly load a MIDI file from a .mid file path
TMLDEF tml_message* tml_load_filename(const char* filename);
#endif

// Load a MIDI file from a block of memory
TMLDEF tml_message* tml_load_memory(const void* buffer, int size);

// rewamp: same loaders, but System Exclusive messages are kept as TML_SYSEX (0xF0)
// messages whose `sysex` field indexes an opaque store returned through out_sysex
// (free it with tml_sysex_free, separately from tml_free). Each entry is a complete
// framed message (F0 ... F7) for a status-F0 event, raw bytes for an F7 escape.
struct tml_sysex_store;
struct tml_stream; // defined below
#ifndef TML_NO_STDIO
TMLDEF tml_message* tml_load_filename_ex(const char* filename, struct tml_sysex_store** out_sysex);
#endif
TMLDEF tml_message* tml_load_ex(struct tml_stream* stream, struct tml_sysex_store** out_sysex);
TMLDEF const unsigned char* tml_sysex_get(const struct tml_sysex_store* store, unsigned int index, unsigned int* out_len);
TMLDEF unsigned int tml_sysex_count(const struct tml_sysex_store* store);
TMLDEF void tml_sysex_free(struct tml_sysex_store* store);

// Get infos about this loaded MIDI file, returns the note count
// NULL can be passed for any output value pointer if not needed.
//   used_channels:   Will be set to how many channels play notes
//                    (i.e. 1 if channel 15 is used but no other)
//   used_programs:   Will be set to how many different programs are used
//   total_notes:     Will be set to the total number of note on messages
//   time_first_note: Will be set to the time of the first note on message
//   time_length:     Will be set to the total time in milliseconds
TMLDEF int tml_get_info(tml_message* first_message, int* used_channels, int* used_programs, int* total_notes, unsigned int* time_first_note, unsigned int* time_length);

// Read the tempo (microseconds per quarter note) value from a message with the type TML_SET_TEMPO
TMLDEF int tml_get_tempo_value(tml_message* set_tempo_message);

// Free all the memory of the linked message list (can also call free() manually)
TMLDEF void tml_free(tml_message* f);

// Stream structure for the generic loading
struct tml_stream
{
	// Custom data given to the functions as the first parameter
	void* data;

	// Function pointer will be called to read 'size' bytes into ptr (returns number of read bytes)
	int (*read)(void* data, void* ptr, unsigned int size);
};

// Generic Midi loading method using the stream structure above
TMLDEF tml_message* tml_load(struct tml_stream* stream);

// If this library is used together with TinySoundFont, tsf_stream (equivalent to tml_stream) can also be used
struct tsf_stream;
TMLDEF tml_message* tml_load_tsf_stream(struct tsf_stream* stream);

#ifdef __cplusplus
}
#endif

// end header
// ---------------------------------------------------------------------------------------------------------
#endif //TML_INCLUDE_TML_INL

#ifdef TML_IMPLEMENTATION

#if !defined(TML_MALLOC) || !defined(TML_FREE) || !defined(TML_REALLOC)
#  include <stdlib.h>
#  define TML_MALLOC  malloc
#  define TML_FREE    free
#  define TML_REALLOC realloc
#endif

#if !defined(TML_MEMCPY)
#  include <string.h>
#  define TML_MEMCPY  memcpy
#endif

#ifndef TML_NO_STDIO
#  include <stdio.h>
#endif

#define TML_NULL 0

////crash on errors and warnings to find broken midi files while debugging
//#define TML_ERROR(msg) *(int*)0 = 0xbad;
//#define TML_WARN(msg)  *(int*)0 = 0xf00d;

////print errors and warnings
//#define TML_ERROR(msg) printf("ERROR: %s\n", msg);
//#define TML_WARN(msg)  printf("WARNING: %s\n", msg);

#ifndef TML_ERROR
#define TML_ERROR(msg)
#endif

#ifndef TML_WARN
#define TML_WARN(msg)
#endif

#ifdef __cplusplus
extern "C" {
#endif

#ifndef TML_NO_STDIO
static int tml_stream_stdio_read(FILE* f, void* ptr, unsigned int size) { return (int)fread(ptr, 1, size, f); }
/* rewamp: a .mid may be a RIFF container ("RIFF" <size> "RMID" then chunks,
 * the Standard MIDI File living in the 'data' one). Upstream tml wants MThd
 * at offset 0, so position the stream on the SMF and let the parser run as
 * usual. Leaves a plain SMF untouched (rewinds to 0), and gives up quietly on
 * a wrapper with no 'data' chunk — the parser then reports the invalid header
 * exactly as before. */
static void tml_skip_rmid_wrapper(FILE* f)
{
	unsigned char hdr[12], chunk[8];
	unsigned int size;
	if (fread(hdr, 1, 12, f) != 12) { fseek(f, 0, SEEK_SET); return; }
	if (hdr[0] != 'R' || hdr[1] != 'I' || hdr[2] != 'F' || hdr[3] != 'F' ||
	    hdr[8] != 'R' || hdr[9] != 'M' || hdr[10] != 'I' || hdr[11] != 'D') {
		fseek(f, 0, SEEK_SET);
		return;
	}
	for (;;) {
		if (fread(chunk, 1, 8, f) != 8) { fseek(f, 0, SEEK_SET); return; }
		size = (unsigned int)chunk[4] | ((unsigned int)chunk[5] << 8) |
		       ((unsigned int)chunk[6] << 16) | ((unsigned int)chunk[7] << 24);
		if (chunk[0] == 'd' && chunk[1] == 'a' && chunk[2] == 't' && chunk[3] == 'a')
			return;                       /* stream now sits on the SMF */
		if (size & 1) size++;             /* RIFF chunks are word-aligned */
		if (fseek(f, (long)size, SEEK_CUR) != 0) { fseek(f, 0, SEEK_SET); return; }
	}
}

TMLDEF tml_message* tml_load_filename(const char* filename)
{
	struct tml_message* res;
	struct tml_stream stream = { TML_NULL, (int(*)(void*,void*,unsigned int))&tml_stream_stdio_read };
	#if __STDC_WANT_SECURE_LIB__
	FILE* f = TML_NULL; fopen_s(&f, filename, "rb");
	#else
	FILE* f = fopen(filename, "rb");
	#endif
	if (!f) { TML_ERROR("File not found"); return 0; }
	tml_skip_rmid_wrapper(f);
	stream.data = f;
	res = tml_load(&stream);
	fclose(f);
	return res;
}
#endif

struct tml_stream_memory { const char* buffer; unsigned int total, pos; };
static int tml_stream_memory_read(struct tml_stream_memory* m, void* ptr, unsigned int size) { if (size > m->total - m->pos) size = m->total - m->pos; TML_MEMCPY(ptr, m->buffer+m->pos, size); m->pos += size; return size; }
TMLDEF struct tml_message* tml_load_memory(const void* buffer, int size)
{
	struct tml_stream stream = { TML_NULL, (int(*)(void*,void*,unsigned int))&tml_stream_memory_read };
	struct tml_stream_memory f = { 0, 0, 0 };
	f.buffer = (const char*)buffer;
	f.total = size;
	stream.data = &f;
	return tml_load(&stream);
}

struct tml_track
{
	unsigned int Idx, End, Ticks;
};

struct tml_tempomsg
{
	unsigned int time;
	unsigned char type, Tempo[3];
	tml_message* next;
};

// rewamp: sysex payloads, appended to one growing blob + (offset,len) table
struct tml_sysex_store
{
	unsigned char* data; unsigned int size, cap;
	unsigned int *offs, *lens; unsigned int count, ecap;
};

static int tml_sysex_append(struct tml_sysex_store* sx, unsigned char status, const unsigned char* data, unsigned int len)
{
	unsigned int need = len + (status == 0xF0 ? 1u : 0u);
	if (sx->count >= 0xFFFF) return -1;
	if (sx->size + need > sx->cap) { unsigned int nc = sx->cap ? sx->cap : 4096; while (nc < sx->size + need) nc *= 2; unsigned char* nd = (unsigned char*)TML_REALLOC(sx->data, nc); if (!nd) return -1; sx->data = nd; sx->cap = nc; }
	if (sx->count >= sx->ecap) { unsigned int ne = sx->ecap ? sx->ecap * 2 : 64; unsigned int* no = (unsigned int*)TML_REALLOC(sx->offs, ne * sizeof(unsigned int)); if (!no) return -1; sx->offs = no; unsigned int* nl = (unsigned int*)TML_REALLOC(sx->lens, ne * sizeof(unsigned int)); if (!nl) return -1; sx->lens = nl; sx->ecap = ne; }
	sx->offs[sx->count] = sx->size; sx->lens[sx->count] = need;
	if (status == 0xF0) sx->data[sx->size++] = 0xF0;
	if (len) { TML_MEMCPY(sx->data + sx->size, data, len); sx->size += len; }
	return (int)sx->count++;
}

TMLDEF const unsigned char* tml_sysex_get(const struct tml_sysex_store* store, unsigned int index, unsigned int* out_len)
{
	if (!store || index >= store->count) { if (out_len) *out_len = 0; return TML_NULL; }
	if (out_len) *out_len = store->lens[index];
	return store->data + store->offs[index];
}

TMLDEF unsigned int tml_sysex_count(const struct tml_sysex_store* store) { return store ? store->count : 0u; }

TMLDEF void tml_sysex_free(struct tml_sysex_store* store)
{
	if (!store) return;
	TML_FREE(store->data); TML_FREE(store->offs); TML_FREE(store->lens); TML_FREE(store);
}

struct tml_parser
{
	unsigned char *buf, *buf_end; 
	int last_status, message_array_size, message_count;
	struct tml_sysex_store* sysex; // rewamp: NULL = skip sysex (original behaviour)
};

enum TMLSystemType
{
	TML_TEXT  = 0x01, TML_COPYRIGHT    = 0x02, TML_TRACK_NAME     = 0x03, TML_INST_NAME     = 0x04, TML_LYRIC           = 0x05, TML_MARKER       = 0x06, TML_CUE_POINT = 0x07,
	TML_EOT   = 0x2f, TML_SMPTE_OFFSET = 0x54, TML_TIME_SIGNATURE = 0x58, TML_KEY_SIGNATURE = 0x59, TML_SEQUENCER_EVENT = 0x7f,
	TML_SYSEX = 0xf0, TML_TIME_CODE    = 0xf1, TML_SONG_POSITION  = 0xf2, TML_SONG_SELECT   = 0xf3, TML_TUNE_REQUEST    = 0xf6, TML_EOX          = 0xf7, TML_SYNC      = 0xf8,
	TML_TICK  = 0xf9, TML_START        = 0xfa, TML_CONTINUE       = 0xfb, TML_STOP          = 0xfc, TML_ACTIVE_SENSING  = 0xfe, TML_SYSTEM_RESET = 0xff
};

static int tml_readbyte(struct tml_parser* p)
{
	return (p->buf == p->buf_end ? -1 : *(p->buf++));
}

static int tml_readvariablelength(struct tml_parser* p)
{
	unsigned int res = 0, i = 0;
	unsigned char c;
	for (; i != 4; i++)
	{
		if (p->buf == p->buf_end) { TML_WARN("Unexpected end of file"); return -1; }
		c = *(p->buf++);
		if (c & 0x80) res = ((res | (c & 0x7F)) << 7);
		else return (int)(res | c);
	}
	TML_WARN("Invalid variable length byte count"); return -1;
}

static int tml_parsemessage(tml_message** f, struct tml_parser* p)
{
	int deltatime = tml_readvariablelength(p), status = tml_readbyte(p);
	tml_message* evt;

	if (deltatime & 0xFFF00000) deltatime = 0; //throw away delays that are insanely high for malformatted midis
	if (status < 0) { TML_WARN("Unexpected end of file"); return -1; }
	if ((status & 0x80) == 0)
	{
		// Invalid, use same status as before
		if ((p->last_status & 0x80) == 0) { TML_WARN("Undefined status and invalid running status"); return -1; }
		p->buf--;
		status = p->last_status;
	}
	else p->last_status = status;

	if (p->message_array_size == p->message_count)
	{
		//start allocated memory size of message array at 64, double each time until 8192, then add 1024 entries until done
		p->message_array_size += (!p->message_array_size ? 64 : (p->message_array_size > 4096 ? 1024 : p->message_array_size));
		*f = (tml_message*)TML_REALLOC(*f, p->message_array_size * sizeof(tml_message));
		if (!*f) { TML_ERROR("Out of memory"); return -1; }
	}
	evt = *f + p->message_count;

	//check what message we have
	if ((status == TML_SYSEX) || (status == TML_EOX)) //sysex
	{
		// rewamp: kept when the caller asked for them (tml_load_ex), skipped otherwise
		int len = tml_readvariablelength(p);
		if (len < 0 || p->buf + len > p->buf_end) { TML_WARN("Unexpected end of file"); p->buf = p->buf_end; return -1; }
		evt->type = 0;
		if (p->sysex)
		{
			int idx = tml_sysex_append(p->sysex, (unsigned char)status, p->buf, (unsigned int)len);
			if (idx >= 0) { evt->type = TML_SYSEX_MESSAGE; evt->channel = 0; evt->sysex = (unsigned short)idx; }
		}
		p->buf += len;
	}
	else if (status == 0xFF) //meta events
	{
		int meta_type = tml_readbyte(p), buflen = tml_readvariablelength(p);
		unsigned char* metadata = p->buf;
		if (meta_type < 0) { TML_WARN("Unexpected end of file"); return -1; }
		if (buflen > 0 && (p->buf += buflen) > p->buf_end) { TML_WARN("Unexpected end of file"); p->buf = p->buf_end; return -1; }

		switch (meta_type)
		{
			case TML_EOT:
				if (buflen != 0) { TML_WARN("Invalid length for EndOfTrack event"); return -1; }
				if (!deltatime) return TML_EOT; //no need to store this message
				evt->type = TML_EOT;
				break;

			case TML_SET_TEMPO:
				if (buflen != 3) { TML_WARN("Invalid length for SetTempo meta event"); return -1; }
				evt->type = TML_SET_TEMPO;
				((struct tml_tempomsg*)evt)->Tempo[0] = metadata[0];
				((struct tml_tempomsg*)evt)->Tempo[1] = metadata[1];
				((struct tml_tempomsg*)evt)->Tempo[2] = metadata[2];
				break;

			default:
				evt->type = 0;
		}
	}
	else //channel message
	{
		int param; 
		if ((param = tml_readbyte(p)) < 0) { TML_WARN("Unexpected end of file"); return -1; }
		evt->key = (param & 0x7f);
		evt->channel = (status & 0x0f);
		switch (evt->type = (status & 0xf0))
		{
			case TML_NOTE_OFF:
			case TML_NOTE_ON:
			case TML_KEY_PRESSURE:
			case TML_CONTROL_CHANGE:
				if ((param = tml_readbyte(p)) < 0) { TML_WARN("Unexpected end of file"); return -1; }
				evt->velocity = (param & 0x7f);
				break;

			case TML_PITCH_BEND:
				if ((param = tml_readbyte(p)) < 0) { TML_WARN("Unexpected end of file"); return -1; }
				evt->pitch_bend = ((param & 0x7f) << 7) | evt->key;
				break;

			case TML_PROGRAM_CHANGE:
			case TML_CHANNEL_PRESSURE:
				evt->velocity = 0;
				break;

			default: //ignore system/manufacture messages
				evt->type = 0;
				break;
		}
	}

	if (deltatime || evt->type)
	{
		evt->time = deltatime;
		p->message_count++;
	}
	return evt->type;
}

TMLDEF tml_message* tml_load(struct tml_stream* stream)
{
	return tml_load_ex(stream, TML_NULL);
}

#ifndef TML_NO_STDIO
TMLDEF tml_message* tml_load_filename_ex(const char* filename, struct tml_sysex_store** out_sysex)
{
	struct tml_message* res;
	struct tml_stream stream = { TML_NULL, (int(*)(void*,void*,unsigned int))&tml_stream_stdio_read };
	FILE* f = fopen(filename, "rb");
	if (!f) { if (out_sysex) *out_sysex = TML_NULL; TML_ERROR("File not found"); return 0; }
	tml_skip_rmid_wrapper(f);
	stream.data = f;
	res = tml_load_ex(&stream, out_sysex);
	fclose(f);
	return res;
}
#endif

TMLDEF tml_message* tml_load_ex(struct tml_stream* stream, struct tml_sysex_store** out_sysex)
{
	int num_tracks, division, trackbufsize = 0;
	unsigned char midi_header[14], *trackbuf = TML_NULL;
	struct tml_message* messages = TML_NULL;
	struct tml_track *tracks, *t, *tracksEnd;
	struct tml_parser p = { TML_NULL, TML_NULL, 0, 0, 0, TML_NULL };
	if (out_sysex) { *out_sysex = TML_NULL; p.sysex = (struct tml_sysex_store*)TML_MALLOC(sizeof(struct tml_sysex_store)); if (p.sysex) { p.sysex->data = TML_NULL; p.sysex->size = p.sysex->cap = 0; p.sysex->offs = p.sysex->lens = TML_NULL; p.sysex->count = p.sysex->ecap = 0; } }

	// Parse MIDI header
	if (stream->read(stream->data, midi_header, 14) != 14) { TML_ERROR("Unexpected end of file"); tml_sysex_free(p.sysex); return messages; }
	if (midi_header[0] != 'M' || midi_header[1] != 'T' || midi_header[2] != 'h' || midi_header[3] != 'd' ||
	    midi_header[7] != 6   || midi_header[9] >  2) { TML_ERROR("Doesn't look like a MIDI file: invalid MThd header"); tml_sysex_free(p.sysex); return messages; }
	if (midi_header[12] & 0x80) { TML_ERROR("File uses unsupported SMPTE timing"); tml_sysex_free(p.sysex); return messages; }
	num_tracks = (int)(midi_header[10] << 8) | midi_header[11];
	division = (int)(midi_header[12] << 8) | midi_header[13]; //division is ticks per beat (quarter-note)
	if (num_tracks <= 0 && division <= 0) { TML_ERROR("Doesn't look like a MIDI file: invalid track or division values"); tml_sysex_free(p.sysex); return messages; }

	// Allocate temporary tracks array for parsing
	tracks = (struct tml_track*)TML_MALLOC(sizeof(struct tml_track) * num_tracks);
	tracksEnd = &tracks[num_tracks];
	for (t = tracks; t != tracksEnd; t++) t->Idx = t->End = t->Ticks = 0;

	// Read all messages for all tracks
	for (t = tracks; t != tracksEnd; t++)
	{
		unsigned char track_header[8];
		int track_length;
		if (stream->read(stream->data, track_header, 8) != 8) { TML_WARN("Unexpected end of file"); break; }
		if (track_header[0] != 'M' || track_header[1] != 'T' || track_header[2] != 'r' || track_header[3] != 'k')
			{ TML_WARN("Invalid MTrk header"); break; }

		// Get size of track data and read into buffer (allocate bigger buffer if needed)
		track_length = track_header[7] | (track_header[6] << 8) | (track_header[5] << 16) | (track_header[4] << 24);
		if (track_length < 0) { TML_WARN("Invalid MTrk header"); break; }
		if (trackbufsize < track_length) { TML_FREE(trackbuf); trackbuf = (unsigned char*)TML_MALLOC(trackbufsize = track_length); }
		if (stream->read(stream->data, trackbuf, track_length) != track_length) { TML_WARN("Unexpected end of file"); break; }

		t->Idx = p.message_count;
		for (p.buf_end = (p.buf = trackbuf) + track_length; p.buf != p.buf_end;)
		{
			int type = tml_parsemessage(&messages, &p);
			if (type == TML_EOT || type < 0) break; //file end or illegal data encountered
		}
		if (p.buf != p.buf_end) { TML_WARN( "Track length did not match data length"); }
		t->End = p.message_count;
	}
	TML_FREE(trackbuf);

	// Change message time signature from delta ticks to actual msec values and link messages ordered by time
	if (p.message_count)
	{
		tml_message *PrevMessage = TML_NULL, *Msg, *MsgEnd, Swap;
		unsigned int ticks = 0, tempo_ticks = 0; //tick counter and value at last tempo change
		int step_smallest, msec, tempo_msec = 0; //msec value at last tempo change
		double ticks2time = 500000 / (1000.0 * division); //milliseconds per tick

		// Loop through all messages over all tracks ordered by time
		for (step_smallest = 0; step_smallest != 0x7fffffff; ticks += step_smallest)
		{
			step_smallest = 0x7fffffff;
			msec = tempo_msec + (int)((ticks - tempo_ticks) * ticks2time);
			for (t = tracks; t != tracksEnd; t++)
			{
				if (t->Idx == t->End) continue;
				for (Msg = &messages[t->Idx], MsgEnd = &messages[t->End]; Msg != MsgEnd && t->Ticks + Msg->time == ticks; Msg++, t->Idx++)
				{
					t->Ticks += Msg->time;
					if (Msg->type == TML_SET_TEMPO)
					{
						unsigned char* Tempo = ((struct tml_tempomsg*)Msg)->Tempo;
						ticks2time = ((Tempo[0]<<16)|(Tempo[1]<<8)|Tempo[2])/(1000.0 * division);
						tempo_msec = msec;
						tempo_ticks = ticks;
					}
					if (Msg->type)
					{
						Msg->time = msec;
						if (PrevMessage) { PrevMessage->next = Msg; PrevMessage = Msg; }
						else { Swap = *Msg; *Msg = *messages; *messages = Swap; PrevMessage = messages; }
					}
				}
				if (Msg != MsgEnd && t->Ticks + Msg->time > ticks)
				{
					int step = (int)(t->Ticks + Msg->time - ticks);
					if (step < step_smallest) step_smallest = step;
				}
			}
		}
		if (PrevMessage) PrevMessage->next = TML_NULL;
		else p.message_count = 0;
	}
	TML_FREE(tracks);

	if (p.message_count == 0)
	{
		TML_FREE(messages);
		messages = TML_NULL;
	}

	if (p.sysex) { if (messages && out_sysex) *out_sysex = p.sysex; else tml_sysex_free(p.sysex); }
	return messages;
}

TMLDEF tml_message* tml_load_tsf_stream(struct tsf_stream* stream)
{
	return tml_load((struct tml_stream*)stream);
}

TMLDEF int tml_get_info(tml_message* Msg, int* out_used_channels, int* out_used_programs, int* out_total_notes, unsigned int* out_time_first_note, unsigned int* out_time_length)
{
	int used_programs = 0, used_channels = 0, total_notes = 0;
	unsigned int time_first_note = 0xffffffff, time_length = 0;
	unsigned char channels[16] = { 0 }, programs[128] = { 0 };
	for (;Msg; Msg = Msg->next)
	{
		time_length = Msg->time;
		if (Msg->type == TML_PROGRAM_CHANGE && !programs[(int)Msg->program]) { programs[(int)Msg->program] = 1; used_programs++; }
		if (Msg->type != TML_NOTE_ON) continue;
		if (time_first_note == 0xffffffff) time_first_note = time_length;
		if (!channels[Msg->channel]) { channels[Msg->channel] = 1; used_channels++; }
		total_notes++;
	}
	if (time_first_note == 0xffffffff) time_first_note = 0;
	if (out_used_channels  ) *out_used_channels   = used_channels;
	if (out_used_programs  ) *out_used_programs   = used_programs;
	if (out_total_notes    ) *out_total_notes     = total_notes;
	if (out_time_first_note) *out_time_first_note = time_first_note;
	if (out_time_length    ) *out_time_length     = time_length;
	return total_notes;
}

TMLDEF int tml_get_tempo_value(tml_message* msg)
{
	unsigned char* Tempo;
	if (!msg || msg->type != TML_SET_TEMPO) return 0;
	Tempo = ((struct tml_tempomsg*)msg)->Tempo;
	return ((Tempo[0]<<16)|(Tempo[1]<<8)|Tempo[2]);
}

TMLDEF void tml_free(tml_message* f)
{
	TML_FREE(f);
}

#ifdef __cplusplus
}
#endif

#endif //TML_IMPLEMENTATION
