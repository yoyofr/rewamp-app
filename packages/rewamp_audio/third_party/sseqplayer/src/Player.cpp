/*
 * SSEQ Player - Player structure
 * By Naram Qashat (CyberBotX) [cyberbotx@cyberbotx.com]
 * Last modification on 2014-10-23
 *
 * Adapted from source code of FeOS Sound System
 * By fincs
 * https://github.com/fincs/FSS
 */

#include <SSEQPlayer/Player.h>
#include <SSEQPlayer/common.h>

//TODO:  MODIZER changes start / YOYOFR
#include <cmath>
#include "../../../src/ModizerVoicesData.h"
//TODO:  MODIZER changes end / YOYOFR

/* rewamp: ces deux définitions d'id n'existaient que pour le codecvt.h
 * polyfill (voir convert.h). Avec le <codecvt> de la bibliothèque standard,
 * libstdc++ définit déjà ces spécialisations: les redéfinir ici donne un
 * « incomplete type 'std::locale' » à la compilation puis un symbole dupliqué
 * à l'édition de liens. Supprimées, sur toutes les plateformes. */

Player::Player() : prio(0), nTracks(0), tempo(0), tempoCount(0), tempoRate(0), masterVol(0), sseqVol(0), sseq(nullptr), sampleRate(0), interpolation(INTERPOLATION_NONE)
{
	memset(this->trackIds, 0, sizeof(this->trackIds));
	for (size_t i = 0; i < 16; ++i)
	{
		this->channels[i].chnId = i;
		this->channels[i].ply = this;
	}
	memset(this->variables, -1, sizeof(this->variables));
}

// Original FSS Function: Player_Setup
bool Player::Setup(const SSEQ *sseqToPlay)
{
	this->sseq = sseqToPlay;

	int firstTrack = this->TrackAlloc();
	if (firstTrack == -1)
		return false;
	this->tracks[firstTrack].Init(firstTrack, this, nullptr, 0);

	this->nTracks = 1;
	this->trackIds[0] = firstTrack;

	this->tracks[firstTrack].startPos = this->tracks[firstTrack].pos = &this->sseq->data[0];

	this->secondsPerSample = 1.0 / this->sampleRate;

	this->ClearState();

	return true;
}

// Original FSS Function: Player_ClearState
void Player::ClearState()
{
	this->tempo = 120;
	this->tempoCount = 0;
	this->tempoRate = 0x100;
	this->masterVol = 0; // this is actually the highest level
	memset(this->variables, -1, sizeof(this->variables));
	this->secondsIntoPlayback = 0;
	this->secondsUntilNextClock = SecondsPerClockCycle;
}

// Original FSS Function: Player_FreeTracks
void Player::FreeTracks()
{
	for (uint8_t i = 0; i < this->nTracks; ++i)
		this->tracks[this->trackIds[i]].Free();
	this->nTracks = 0;
}

// Original FSS Function: Player_Stop
void Player::Stop(bool bKillSound)
{
	this->ClearState();
	for (uint8_t i = 0; i < this->nTracks; ++i)
	{
		uint8_t trackId = this->trackIds[i];
		this->tracks[trackId].ClearState();
		for (int j = 0; j < 16; ++j)
		{
			Channel &chn = this->channels[j];
			if (chn.state != CS_NONE && chn.trackId == trackId)
			{
				if (bKillSound)
					chn.Kill();
				else
					chn.Release();
			}
		}
	}
	this->FreeTracks();
}

// Original FSS Function: Chn_Alloc
int Player::ChannelAlloc(int type, int priority)
{
	static const uint8_t pcmChnArray[] = { 4, 5, 6, 7, 2, 0, 3, 1, 8, 9, 10, 11, 14, 12, 15, 13 };
	static const uint8_t psgChnArray[] = { 8, 9, 10, 11, 12, 13 };
	static const uint8_t noiseChnArray[] = { 14, 15 };
	static const uint8_t arraySizes[] = { sizeof(pcmChnArray), sizeof(psgChnArray), sizeof(noiseChnArray) };
	static const uint8_t *const arrayArray[] = { pcmChnArray, psgChnArray, noiseChnArray };

	auto chnArray = arrayArray[type];
	int arraySize = arraySizes[type];

	int curChnNo = -1;
	for (int i = 0; i < arraySize; ++i)
	{
		int thisChnNo = chnArray[i];
		Channel &thisChn = this->channels[thisChnNo];
		Channel &curChn = this->channels[curChnNo];
		if (curChnNo != -1 && thisChn.prio >= curChn.prio)
		{
			if (thisChn.prio != curChn.prio)
				continue;
			if (curChn.vol <= thisChn.vol)
				continue;
		}
		curChnNo = thisChnNo;
	}

	if (curChnNo == -1 || priority < this->channels[curChnNo].prio)
		return -1;
	this->channels[curChnNo].noteLength = -1;
	this->channels[curChnNo].vol = 0x7FF;
	this->channels[curChnNo].clearHistory();
	return curChnNo;
}

// Original FSS Function: Track_Alloc
int Player::TrackAlloc()
{
	for (int i = 0; i < FSS_MAXTRACKS; ++i)
	{
		Track &thisTrk = this->tracks[i];
		if (!thisTrk.state[TS_ALLOCBIT])
		{
			thisTrk.Zero();
			thisTrk.state.set(TS_ALLOCBIT);
			thisTrk.updateFlags.reset();
			return i;
		}
	}
	return -1;
}

// Original FSS Function: Player_Run
void Player::Run()
{
	while (this->tempoCount > 240)
	{
		this->tempoCount -= 240;
		for (uint8_t i = 0; i < this->nTracks; ++i)
			this->tracks[this->trackIds[i]].Run();
	}
	this->tempoCount += (static_cast<int>(this->tempo) * static_cast<int>(this->tempoRate)) >> 8;
}

void Player::UpdateTracks()
{
	for (int i = 0; i < 16; ++i)
		this->channels[i].UpdateTrack();
	for (int i = 0; i < FSS_MAXTRACKS; ++i)
		this->tracks[i].updateFlags.reset();
}

// Original FSS Function: Snd_Timer
void Player::Timer()
{
	this->UpdateTracks();

	for (int i = 0; i < 16; ++i)
		this->channels[i].Update();

	this->Run();
}

static inline int32_t muldiv7(int32_t val, uint8_t mul)
{
	return mul == 127 ? val : ((val * mul) >> 7);
}

void Player::GenerateSamples(std::vector<uint8_t> &buf, unsigned offset, unsigned samples)
{
	//TODO:  MODIZER changes start / YOYOFR
	// Per-voice oscilloscope / notes / mute for rewamp's 16 NDS hardware
	// channels. The player renders at the output rate, so one rendered sample
	// = one scope sample (no resampling step, unlike the libvgm-style cores).
	unsigned long mute = this->mutes.to_ulong() | (unsigned long)(generic_mute_mask & 0xFFFF);
	//TODO:  MODIZER changes end / YOYOFR

	for (unsigned smpl = 0; smpl < samples; ++smpl)
	{
		this->secondsIntoPlayback += this->secondsPerSample;

		int32_t leftChannel = 0, rightChannel = 0;

		// I need to advance the sound channels here
		for (int i = 0; i < 16; ++i)
		{
			Channel &chn = this->channels[i];

			//TODO:  MODIZER changes start / YOYOFR
			int32_t scopeSample = 0;
			//TODO:  MODIZER changes end / YOYOFR

			if (chn.state > CS_NONE)
			{
				int32_t sample = chn.GenerateSample();
				chn.IncrementSample();

				if (mute & BIT(i))
				{
					//TODO:  MODIZER changes start / YOYOFR
					// Muted: the channel still runs (envelopes keep advancing,
					// so unmuting is click-free) but contributes nothing to the
					// mix NOR to the scope.
					goto scope_write;
					//TODO:  MODIZER changes end / YOYOFR
				}

				uint8_t datashift = chn.reg.volumeDiv;
				if (datashift == 3)
					datashift = 4;
				sample = muldiv7(sample, chn.reg.volumeMul) >> datashift;

				leftChannel += muldiv7(sample, 127 - chn.reg.panning);
				rightChannel += muldiv7(sample, chn.reg.panning);

				//TODO:  MODIZER changes start / YOYOFR
				scopeSample = sample;   // post-volume, pre-pan (mono trace)
				//TODO:  MODIZER changes end / YOYOFR
			}

			//TODO:  MODIZER changes start / YOYOFR
		scope_write:
			if (m_voice_buff[i])
			{
				int64_t ofs = m_voice_current_ptr[i];
				m_voice_buff[i][(ofs >> MODIZER_OSCILLO_OFFSET_FIXEDPOINT) &
				                (SOUND_BUFFER_SIZE_SAMPLE * 4 * 2 - 1)] =
				    LIMIT8(scopeSample >> 8);
				ofs += 1 << MODIZER_OSCILLO_OFFSET_FIXEDPOINT;
				while ((ofs >> MODIZER_OSCILLO_OFFSET_FIXEDPOINT) >=
				       SOUND_BUFFER_SIZE_SAMPLE * 4 * 2)
					ofs -= (int64_t)SOUND_BUFFER_SIZE_SAMPLE * 4 * 2
					       << MODIZER_OSCILLO_OFFSET_FIXEDPOINT;
				m_voice_current_ptr[i] = ofs;
			}
			//TODO:  MODIZER changes end / YOYOFR
		}

		//TODO:  MODIZER changes start / YOYOFR
		// Notes: the NDS channel carries the MIDI key it was started with and
		// an amplitude envelope (7 fractionary bits, negative = attenuation in
		// the DS's log scale). Report once per rendered block, not per sample.
		if (smpl == 0)
		{
			for (int i = 0; i < 16; ++i)
			{
				Channel &chn = this->channels[i];
				if (chn.state > CS_NONE && !(mute & BIT(i)))
				{
					vgm_last_note[i] =
					    (unsigned int)(440.0 * pow(2.0, (chn.key - 69) / 12.0));
					int v = (chn.velocity >> 4);       // 0..127-ish
					vgm_last_vol[i] = v < 0 ? 0 : (v > 255 ? 255 : v);
					vgm_last_instr[i] = (unsigned int)chn.trackId;
				}
				else
				{
					vgm_last_note[i] = 0;
					vgm_last_vol[i] = 0;
				}
			}
		}
		//TODO:  MODIZER changes end / YOYOFR

		clamp(leftChannel, -0x8000, 0x7FFF);
		clamp(rightChannel, -0x8000, 0x7FFF);

		buf[offset++] = leftChannel & 0xFF;
		buf[offset++] = (leftChannel >> 8) & 0xFF;
		buf[offset++] = rightChannel & 0xFF;
		buf[offset++] = (rightChannel >> 8) & 0xFF;

		if (this->secondsIntoPlayback > this->secondsUntilNextClock)
		{
			this->Timer();
			this->secondsUntilNextClock += SecondsPerClockCycle;
		}
	}
}

