#ifndef _AMIGAMSG_H_
#define _AMIGAMSG_H_

enum amigamsg {
	AMIGAMSG_SETSUBSONG = 1,
	AMIGAMSG_SONG_END,
	AMIGAMSG_PLAYERNAME,
	AMIGAMSG_MODULENAME,
	AMIGAMSG_SUBSINFO,
	AMIGAMSG_CHECKERROR,
	AMIGAMSG_SCORECRASH,
	AMIGAMSG_SCOREDEAD,
	AMIGAMSG_GENERALMSG,
	AMIGAMSG_NTSC,
	AMIGAMSG_FORMATNAME,
	AMIGAMSG_LOADFILE,
	AMIGAMSG_READ,
	AMIGAMSG_FILESIZE,
	AMIGAMSG_TIME_CRITICAL,
	AMIGAMSG_GET_INFO,
	AMIGAMSG_START_OUTPUT,  /* 17 */
	AMIGAMSG_RESERVED_0,  /* 18: For an audio.device experiment */
	AMIGAMSG_STATE_DETECTION_INIT, /* 19 */
	AMIGAMSG_STATE_DETECTION_STEP, /* 20 */
	AMIGAMSG_TEST_LOGGING, /* 21 */
	AMIGAMSG_DEBUG_U32_STRING, /* 22 */
	AMIGAMSG_DEBUG_U32_I32_STRING, /* 23 */

	/* rewamp: webUADE+ (Wothke) score extensions. ICON_* were 18/19 in his
	 * tree and are renumbered here to dodge the upstream 18-23 block (his
	 * AUDIO_DEV_* already sat safely at 50+). Numbers are mirrored by the
	 * equ block in amigasrc/score/score.s — keep both in sync. */
	AMIGAMSG_ICON_LOAD = 24,           /* icon.library GetDiskObject (.info) */
	AMIGAMSG_ICON_TOOLTYPE = 25,       /* icon.library FindToolType */
	AMIGAMSG_AUDIO_DEV_OPEN = 50,      /* audio.device OpenDevice */
	AMIGAMSG_AUDIO_DEV_BEGINIO = 51,   /* audio.device BeginIO/DoIO */
	AMIGAMSG_AUDIO_DEV_ABORTIO = 52,   /* audio.device AbortIO */
};

#endif
