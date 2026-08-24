/*
/* Poor man's audio.device implementation.
 *
 * Copyright 2022, Juergen Wothke
 */

#include "audiodevice.h"

#include <stdio.h>
#include <stdarg.h>
#include <stdlib.h>
#include <limits.h>
#include <stddef.h>

#include "devices/audio/audio.h"
#include "exec/libraries.h"


#include "sysconfig.h"
#include "sysdeps.h"	// FIXME the below includes need this.. UADE's include files should be fixed!
#include "audio.h"
#include "custom.h"
#include "memory.h"

/* rewamp: these live in custom.c (made non-static there for this file). In
 * Wothke's tree they were declared through his modified custom.h; ours stays
 * untouched, so declare them here. */
extern void DMACON (uae_u16 v);
extern void disable_audio_dma (int channel);

/* rewamp: validated amiga->host translation. Wothke's original calls
 * get_real_address() on pointers read from player-supplied structs without
 * any check. In his Emscripten build amiga memory is one flat array, so a
 * garbage pointer silently reads/writes junk and playback carries on; in this
 * native build the UAE memory banks route it through default_xlate(), which
 * kills the song ("did something terribly stupid"). Digital Sound Creations
 * hit exactly that: an uninitialized IOAudio field (BE 0x0DEA0000) followed
 * during OpenDevice. Translate through valid_address() and let callers skip
 * gracefully instead. */
static void ad_logf(const char *fmt, ...);

static uint8_t *ad_real_address(uint32_t amiga_addr_be, uint32_t size)
{
	uint32_t a = swap32(amiga_addr_be);
	if (!valid_address(a, size)) {
		ad_logf( "audio.device: invalid amiga pointer 0x%x (size %u)\n",
			a, size);
		return NULL;
	}
	return get_real_address(a);
}

/* rewamp: audio.device chatter (AbortIO/CMD_INVALID/… warnings fire every
 * frame on some players) is debug-gated — silent in normal use. */
static void ad_logf(const char *fmt, ...)
{
	static int verbose = -1;
	if (verbose < 0)
		verbose = getenv("REWAMP_UADE_DEBUG") != NULL;
	if (!verbose)
		return;
	va_list ap;
	va_start(ap, fmt);
	vfprintf(stderr, fmt, ap);
	va_end(ap);
}

//#define TRACE_AD_CALLS 1

static int _use_audio_device = 0;

static void start_write_command(int8_t targetchnl, uint32_t al_msg_addr);


// just a simple list to keep try of pending "WRITE" commands (per audio channel)
struct MsgNode {
	struct  MsgNode *next;
	uint32_t al_msg_addr;		// little-endian Message address in amiga mem
};

struct MsgNode* _write_msg_list[4];

static struct MsgNode* get_write_message(int channel) {
	return _write_msg_list[channel];
}
static struct MsgNode* new_node() {
	return calloc(1, sizeof(struct MsgNode));
}
static void delete_node(struct MsgNode* n) {
	free(n);
}

static struct MsgNode* get_last_node(struct MsgNode* n) {
	while(n->next) {
		n= n->next;
	}
	return n;
}

static void add_write_message(int channel, uint32_t al_msg_addr) {
	struct MsgNode*n = new_node();
	n->al_msg_addr = al_msg_addr;

	if (_write_msg_list[channel] == 0) {
		_write_msg_list[channel] = n;
	} else {
		get_last_node(_write_msg_list[channel])->next = n;
	}
}

static void remove_write_message(int channel) {
	if (_write_msg_list[channel] != 0) {
		struct MsgNode* n = _write_msg_list[channel];
		_write_msg_list[channel] = n->next;

		delete_node(n);
#ifdef TRACE_AD_CALLS
		ad_logf( "audio.device WRITE REMOVE %d\n", channel);
#endif
	}
}

static void reset_channel(int channel) {
	while (get_write_message(channel)) {
		remove_write_message(channel);
	}
}

uint16_t swap16(uint16_t in) {
	return (in >> 8) | (in << 8);
}
uint32_t swap32(uint32_t in) {
	return((in>>24)&0xff) |
			((in<<8)&0xff0000) |
			((in>>8)&0xff00) |
			((in<<24)&0xff000000);
}

static const char* cmd_labels[] = {
	"CMD_INVALID", 		// 0
	"CMD_RESET", 		// 1
	"CMD_READ",			// 2
	"CMD_WRITE",		// 3
	"CMD_UPDATE", 		// 4
	"CMD_CLEAR",		// 5
	"CMD_STOP",			// 6
	"CMD_START",		// 7
	"CMD_FLUSH",		// 8
	"ADCMD_FREE",		// 9
	"ADCMD_SETPREC",	// 10
	"ADCMD_FINISH",		// 11
	"ADCMD_PERVOL",		// 12
	"ADCMD_LOCK",		// 13
	"ADCMD_WAITCYCLE",	// 14
	"","","","","","","","","","","","","","","","","",
	"ADCMD_ALLOCATE",	// 32
};
static const char* get_cmd_label(struct IOAudio *req) {
	uint16_t cmd = swap16(req->ioa_Request.io_Command);
	return cmd <= 32 ? cmd_labels[cmd] : "invalid";
}

static int8_t get_target_channel(uint32_t unit) {
	unit &= 0xf; // only bottom bits are relevant
	for (int i= 0; i<4; i++) {
		if (unit & 0x1) {
			return i;
		}
		unit >>= 1;
	}
	return -1;
}

static const uint32_t SCORE_HAVE_REPLYMSG  = 0x1fc;	// duplicated from uade.c

// send a ReplyMsg back to the associated message port
void reply_message(uint32_t al_msg_addr, uint32_t al_dst_addr) {

	uint32_t* msgBuf = (uint32_t*) ad_real_address(al_msg_addr, 8);
	if (!msgBuf) return;
	msgBuf[0] = msgBuf[1] = 0; 			// reset next/pred pointers just in case

	uint32_t* ptr= (uint32_t*)ad_real_address(al_dst_addr, 4);
	if (!ptr) return;

	if (*ptr == 0) {
		*ptr = al_msg_addr;
	} else {
		// there already is a backlog.. add new entry to the end of this list
		uint32_t* node= (uint32_t*) ad_real_address(*ptr, 8);
		if (!node) return;

		while (node != msgBuf) {			// avoid duplicates
			if (node[0] == 0) {
				node[0] = al_msg_addr;
				break;
			}
			node = (uint32_t*) ad_real_address(node[0], 8);
			if (!node) return;
		}
	}
}

void reply_message_DMA(uint32_t al_msg_addr, int audioChannel) {
	// note: score only checks this 1x per playloop and the extra latency might be a problem

	reply_message(al_msg_addr, swap32(SCORE_HAVE_REPLYMSG));
}


void audiodevice_DMA_signal(int audioChannel) {
	if (!_use_audio_device) return;

	// DMA playback has reached the end of the sample buffer

	struct MsgNode* msg_node = get_write_message(audioChannel);
	if (msg_node) {
		struct IOAudio *req = (struct IOAudio*) ad_real_address(msg_node->al_msg_addr, sizeof(struct IOAudio));
		if (!req) return;
		uint16_t   ioa_Cycles = swap16(req->ioa_Cycles);	// 0  thru 65535, 0 for infinite

		if (ioa_Cycles == 1) {
			// write command completed
			disable_audio_dma(audioChannel);			// stop automatic looping
			reply_message_DMA(msg_node->al_msg_addr, audioChannel);	// return them to their MessagePort
			remove_write_message(audioChannel);

			// testcase: MarbleMadness - the next message may already be ready..
			struct MsgNode* msg_node = get_write_message(audioChannel);
			if (msg_node != 0) {
				start_write_command(audioChannel, msg_node->al_msg_addr);
			}

			// issue: howto send reply message to Amiga side with as little latency as possible?
			// the current hack is probably not ideal
		} else if (ioa_Cycles == 0) {
			// infinite looping - must be cancelled via CMD_FLUSH to stop
		} else {
			ioa_Cycles -= 1;
			req->ioa_Cycles = swap16(ioa_Cycles);	// this might be a problem if player does not reset before reuse
		}

	} else {
		// testcase: stoneplayer.library - doesn't seeem to hurt when this happens
//		ad_logf( "error: audio.device no playing channel found!");
	}
}


static void alloc_write_lists() {
	reset_channel(0);
	reset_channel(1);
	reset_channel(2);
	reset_channel(3);
}

uint8_t _allocated_channels = 0;

void audiodevice_reset() {
	_use_audio_device= _allocated_channels= 0;
	alloc_write_lists();
}

uint8_t alloc_channels(uint8_t *prefs, int prefs_len) {
	// flawed impl: Request's prio (req->ioa_Request.mn_Node.ln_Pri) allows to potentially
	// steal channels -> but that would be rather braindead in a standalone song scenario...
	for (int i= 0; i<prefs_len; i++) {
		uint8_t chnmask= prefs[i] & 0xf;	// only lower four bits are considered for channel alloc

		if (chnmask && ((_allocated_channels & chnmask) == 0)) {
			_allocated_channels |= chnmask;
			return chnmask;
		}
	}
	return 0; // alloc failed
}


// "al_" prefix signifies that the var contains an original amiga memory
// address in little endian byte order
void audiodevice_open(uint32_t al_msg_addr) {
	struct IOAudio *req = (struct IOAudio*) ad_real_address(al_msg_addr, sizeof(struct IOAudio));
	if (!req) return;
	struct Library *lib = (struct Library*)ad_real_address((uint32_t)req->ioa_Request.io_Device, sizeof(struct Library));

	// unclear which additional fields might need to be initialized
	if (lib) {
		lib->lib_OpenCnt = swap16(1);	// just mark as "in use".. could track open/close if needed
		lib->lib_Version = swap16(39);	// MaxTrax uses this to act differently depending on OS version
		lib->lib_NegSize = swap16(36);	// see audio.device's function vectors
	}


	uint16_t cmd = swap16(req->ioa_Request.io_Command);

	// only bottom 4-bits are considered for channel allocation!
	uint16_t ioa_AllocKey = swap16(req->ioa_AllocKey);

		// channel combination array, e.g. [0xf, 0xf]
		// note: seems this garbage API later reuses the same ioa_Data field to
		// pass the audio buffer.. everything to save a byte..
	uint8_t* ioa_Data = (uint8_t*)ad_real_address((uint32_t)req->ioa_Data, 2);
	uint32_t ioa_Length = swap32(req->ioa_Length);
	if (!ioa_Data) ioa_Length = 0;   /* garbage channel array -> plain open */

//	req->io_Error = IOERR_OPENFAIL; 	// if ioa_AllocKey and io_Device could not be set

	if ((ioa_AllocKey == 0 || (cmd == ADCMD_ALLOCATE)) && ioa_Length > 0) {
		// implicit allocation
		uint8_t allo= alloc_channels(ioa_Data, ioa_Length);
#ifdef TRACE_AD_CALLS
		ad_logf( "audio.device Open implicit ADCMD_ALLOCATE %d\n", allo);
#endif

		// testcase: MaxTrax, e.g. 1 x 15 (i.e. all 4 channel bits set) means the
		// app wants all 4 channels..
		// testcase: "G&T Game Systems".. song performs 3 open calls - using ioa_AllocKey=0

		uint32_t al_portAddr = (uint32_t)req->ioa_Request.io_Message.mn_ReplyPort;
		struct  MsgPort *reply_port = al_portAddr
			? (struct MsgPort*) ad_real_address(al_portAddr, 34) : NULL;
		if (reply_port) {
			// http://amigadev.elowar.com/read/ADCD_2.1/Includes_and_Autodocs_2._guide/node04B8.html says:
			// "To allocate channels, OpenDevice also requires a properly initialized
			// reply port (mn_ReplyPort) with an allocated signal bit."

			// however: this doc seems to be incorrect: testcase: "Music-X Driver" which comes here
			// without ever having called AllocSignal before.. QED

			if (reply_port->mp_SigBit > 31) {
				ad_logf( "audio.device error: Open without allocated signal bit\n");
				allo = 0;
			}
		} else {
			ad_logf( "audio.device error: Open without reply message port\n", allo);
		}

		if (allo) {
			req->ioa_Request.io_Unit = swap32((uint32_t)allo);

			// FIXME: only reset when 0?
			req->ioa_AllocKey = 0x7777;	// hack: unique key
			req->ioa_Request.io_Error = 0;
		} else {
			req->ioa_Request.io_Unit= 0;
			req->ioa_Request.io_Error = ADIOERR_ALLOCFAILED; 	// if requested channel combo no available
		}

	} else {
#ifdef TRACE_AD_CALLS
		ad_logf("audio.device Open\n");
#endif
		req->ioa_Request.io_Error = 0;
	}

	_use_audio_device= 1;
	audio_use_text_scope(); // see use of TEXT_SCOPE in AUDxXXX calls..
}

static void start_write_command(int8_t targetchnl, uint32_t al_msg_addr) {

	struct IOAudio* req = (struct IOAudio*) ad_real_address(al_msg_addr, sizeof(struct IOAudio));
	if (!req) return;

	req->ioa_Request.io_Flags = req->ioa_Request.io_Flags & ~IOF_QUICK;	// only clear if no error

	if (targetchnl == -1) {
		ad_logf( "audio.device CMD_WRITE - error: no target channel\n");
		return;
	}

#ifdef TRACE_AD_CALLS
	ad_logf( "      WRITE chn: 0x%x buf: %x len: %x cycles: %x\n", targetchnl, swap32(req->ioa_Data), swap32(req->ioa_Length), swap16(req->ioa_Cycles)  );
#endif
	uint8_t flags = req->ioa_Request.io_Flags;

	if (flags & ADIOF_PERVOL) {
		uint16_t	ioa_Period=  swap16(req->ioa_Period);; //  >= 124!
		uint16_t	ioa_Volume=  swap16(req->ioa_Volume);; //  0 thru 64, linear

#ifdef TRACE_AD_CALLS
		ad_logf( "      WRITE period %x volume %x\n", ioa_Period, ioa_Volume);
#endif
		AUDxPER(targetchnl, ioa_Period);
		AUDxVOL(targetchnl, ioa_Volume);
	}


	int8_t* ioa_Data = (uint8_t *)ad_real_address((uint32_t)req->ioa_Data, 2);
	if (!ioa_Data) return;

	int8_t* ioa_Data_amiga = (uint8_t *)(uintptr_t)(swap32((uint32_t)req->ioa_Data));

	int8_t* data = ioa_Data_amiga;	// seems the below calls need the original amiga address for their chipmem logic

	// UADE's semantics of these regs seem to be different from the original!
	AUDxLCL(targetchnl, (uint32_t)data & 0xffff);	// 16-bit instead of 15
	AUDxLCH(targetchnl, (uint32_t)data >> 16);		// 16-bit instead of 5

	uint32_t ioa_Length = swap32(req->ioa_Length);	// 2 thru 131072 must be even number!!!
	AUDxLEN(targetchnl, ioa_Length >> 1);	// in words? or did UADE also change these semantics?

#ifdef TRACE_AD_CALLS
	ad_logf( "      WRITE START dat: %d len: %d chn: %d\n", data, ioa_Length, targetchnl);
#endif

	// all the DMA setup should be ready...try to turn on DMA for the target audio channel..
	DMACON(0x8200 | (1<<targetchnl));

	update_audio();	// needed?

	if (flags & ADIOF_WRITEMESSAGE) {
		// means that separate ioa_WriteMsg should be used to signal when command starts processing
		ad_logf( "audio.device error: CMD_WRITE - use of ioa_writeMsg not implemented!");
	}

	// another code example uses Wait(port->mp_SigBit) and GetMsg(port)==0 to "poll" for the "Write" to complete..
	// => not implemented yet (find a testcase 1st)

	req->ioa_Request.io_Error = 0;
}



static void add_write_command(int8_t targetchnl, uint32_t al_msg_addr) {

#ifdef TRACE_AD_CALLS
	struct IOAudio* req = (struct IOAudio*) ad_real_address(al_msg_addr, sizeof(struct IOAudio));
	if (!req) return;
	int8_t* ioa_Data_amiga = (uint8_t *)(swap32((uint32_t)req->ioa_Data));
	int8_t* data = ioa_Data_amiga;	// seems the below calls need the original amiga address for their chipmem logic
	uint32_t ioa_Length = swap32(req->ioa_Length);	// 2 thru 131072 must be even number!!!
	ad_logf( "   CMD_WRITE ADD dat: %d len: %d chn: %d\n", data, ioa_Length, targetchnl);
#endif

	struct MsgNode* msg_node = get_write_message(targetchnl);

	if (msg_node != 0) {
		add_write_message(targetchnl, al_msg_addr); // just add to the end of the list
	} else {
		add_write_message(targetchnl, al_msg_addr);
		start_write_command(targetchnl, al_msg_addr);
	}
}

static void handle_flush_command(uint32_t al_msg_addr, uint32_t al_dst_addr, struct IOAudio *req, const char* dbg_text) {
	// synchronous; multiple channels; cancels all pending I/O
	// see http://amigadev.elowar.com/read/ADCD_2.1/Includes_and_Autodocs_3._guide/node006B.html

	uint8_t chn_map = swap32((uint32_t)req->ioa_Request.io_Unit) & 0xf;	// channel bit map

#ifdef TRACE_AD_CALLS
	ad_logf( "   %s %d\n", dbg_text, chn_map);
#endif

	for (int i= 0; i<4; i++) {
		if(chn_map & 0x1) {
			struct MsgNode* msg_node = get_write_message(i);
			if (msg_node) {
				disable_audio_dma(i);
			}
			while (msg_node = get_write_message(i)) {
				reply_message(msg_node->al_msg_addr, al_dst_addr);	// return them to their MessagePort
				remove_write_message(i);
			}
		}
		chn_map >>= 1;
	}

	uint8_t flags = req->ioa_Request.io_Flags;

	if (!(flags & IOF_QUICK)) {
		// send message to mn_ReplyPort (testcase: "G&T Game Systems" player)
		reply_message(al_msg_addr, al_dst_addr);

	} else {
#ifdef TRACE_AD_CALLS
 		ad_logf( "   %s\n", dbg_text);
#endif
	}
}

static void handle_finish_command(uint32_t al_msg_addr, uint32_t al_dst_addr, struct IOAudio *req) {
	// same as CMD_FLUSH with added control over timing when "flush" is triggered

	handle_flush_command(al_msg_addr, al_dst_addr, req, "ADCMD_FINISH");

	uint8_t flags = req->ioa_Request.io_Flags;
	if (flags & ADIOF_SYNCCYCLE) {
		// would need to wait for end of current cycle first
 		ad_logf( "   warning: used ADIOF_SYNCCYCLE not supported\n");
	}
}



static uint16_t _alloc_key = 0x7777;

static void handle_allocate_command(struct IOAudio *req) {

	// only bottom 4-bits are considered for channel allocation!
	uint16_t ioa_AllocKey = swap16(req->ioa_AllocKey);

		// channel combination array, e.g. [0xf, 0xf]
		// note: seems this garbage API later reuses the same ioa_Data field to
		// pass the audio buffer.. fucking morons..
	uint8_t* ioa_Data = (uint8_t*)ad_real_address((uint32_t)req->ioa_Data, 2);
	uint32_t ioa_Length = swap32(req->ioa_Length);
	if (!ioa_Data) ioa_Length = 0;


	if (ioa_Length > 0) {
		uint8_t allo= alloc_channels(ioa_Data, ioa_Length);

#ifdef TRACE_AD_CALLS
		ad_logf( "   CMD_ALLOCATE; %d\n", allo);
#endif

		if (allo) {
			req->ioa_Request.io_Unit = swap32(allo);

			// FIXME: only reset when 0?
			req->ioa_AllocKey = _alloc_key;
			req->ioa_Request.io_Error = 0;
		} else {
			req->ioa_Request.io_Unit= 0;
			req->ioa_Request.io_Error = ADIOERR_ALLOCFAILED; 	// if requested channel combo no available

			ad_logf("audio.device CMD_ALLOCATE error\n");
		}

	} else {
		ad_logf("audio.device CMD_ALLOCATE error\n");
		req->ioa_Request.io_Error = 0;
	}
}


static void handle_PERVOL_command(int8_t targetchnl, struct IOAudio *req) {
	// see http://amigadev.elowar.com/read/ADCD_2.1/Includes_and_Autodocs_2._guide/node04AA.html

	uint8_t flags = req->ioa_Request.io_Flags;

	if (!(flags & IOF_QUICK)) {
		// send message to mn_ReplyPort
		ad_logf( "audio.device error: ADCMD_PERVOL - IOF_QUICK mode not implemented!\n");
	}

	if (flags & ADIOF_SYNCCYCLE) {
		// make change at end of cycle
		ad_logf( "audio.device error: ADCMD_PERVOL - ADIOF_SYNCCYCLE mode not implemented!\n");
	}

	uint16_t ioa_Period = swap16(req->ioa_Period);; //  >= 124!
	if (ioa_Period<124) {
		ad_logf( "audio.device error: ADCMD_PERVOL period: %d!\n", ioa_Period);
	}


	uint16_t ioa_Volume = swap16(req->ioa_Volume);; //  0 thru 64, linear
	if (ioa_Volume>64) {
		// SkyFox actually uses 72! so let's presume that the OK range is actually wider
//		ad_logf( "audio.device error: ADCMD_PERVOL volume: %d!\n", ioa_Volume);
	}

	AUDxPER(targetchnl, ioa_Period);
	AUDxVOL(targetchnl, ioa_Volume);

#ifdef TRACE_AD_CALLS
	ad_logf( "   ADCMD_PERVOL quick: %d sync: %d period: %d vol: %d\n", !(flags & IOF_QUICK), (flags & ADIOF_SYNCCYCLE), ioa_Period, ioa_Volume);
#endif
}


void audiodevice_abortIO(uint32_t al_msg_addr) {
	struct IOAudio* req = (struct IOAudio*) ad_real_address(al_msg_addr, sizeof(struct IOAudio));
	if (!req) return;

	uint32_t unit = swap32((uint32_t)req->ioa_Request.io_Unit);	// channel bit map
	int8_t targetchnl= get_target_channel(unit);	// if more than 1 channel is selected get the "LOWEST" channel used!

	uint16_t cmd = swap16(req->ioa_Request.io_Command);

	switch (cmd) {
		case CMD_WRITE:
			ad_logf( "audio.device warning: AbortIO for channel %d not implemented\n", targetchnl);
			break;
		default:
			ad_logf( "audio.device warning: ignoring attempt to AbortIO for %s\n", cmd_labels[cmd]);
			break;
	}
}

void audiodevice_beginIO(uint32_t al_msg_addr, uint32_t al_dst_addr) {

	struct IOAudio* req = (struct IOAudio*) ad_real_address(al_msg_addr, sizeof(struct IOAudio));
	if (!req) return;

	uint32_t unit = swap32((uint32_t)req->ioa_Request.io_Unit);	// channel bit map
	int8_t targetchnl= get_target_channel(unit);	// if more than 1 channel is selected get the "LOWEST" channel used!

	uint16_t cmd = swap16(req->ioa_Request.io_Command);

#ifdef TRACE_AD_CALLS
	ad_logf( "audio.device BeginIO: %s\n", get_cmd_label(req));
#endif

	switch (cmd) {
		case CMD_INVALID:	 	// 0
		case CMD_RESET: 		// 1 synchronous; only replies if flag (IOF_QUICK) is clear
		case CMD_READ: 			// 2 single channel; synchronous; only replies if flag (IOF_QUICK) is clear
		case CMD_UPDATE: 		// 4 synchronous; only replies if flag (IOF_QUICK) is clear
		case CMD_CLEAR:			// 5 synchronous; only replies if flag (IOF_QUICK) is clear
		case CMD_STOP:			// 6 synchronous; only replies if flag (IOF_QUICK) is clear
		case CMD_START:			// 7 synchronous; only replies if flag (IOF_QUICK) is clear
		case ADCMD_FREE:		// 9
		case ADCMD_SETPREC:		// 10
		case ADCMD_LOCK:		// 13
		case ADCMD_WAITCYCLE:	// 14
			ad_logf( "audio.device error: %s not implemented\n", cmd_labels[cmd]);
			break;

		case CMD_WRITE:			// 3 queues up requests; asynchronous; only replies if flag (IOF_QUICK) is clear
			add_write_command(targetchnl, al_msg_addr);	// WRITE is a single channel command
			break;

		case CMD_FLUSH:			// 8 synchronous; only replies if flag (IOF_QUICK) is clear
			handle_flush_command(al_msg_addr, al_dst_addr, req, "CMD_FLUSH");
			break;

		case ADCMD_PERVOL:		// 12; testcase MaxTrax
			handle_PERVOL_command(targetchnl, req);
			break;

		case ADCMD_ALLOCATE:	// 32
			handle_allocate_command(req);
			break;

		case ADCMD_FINISH:		// 11; // testcase: cust.Astate
			handle_finish_command(al_msg_addr, al_dst_addr, req);
			break;
		default:
			ad_logf( "audio.device error: %s not implemented!\n", get_cmd_label(req));
	}
}

