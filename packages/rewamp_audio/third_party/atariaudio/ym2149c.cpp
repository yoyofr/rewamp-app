//----------------------------------------------------------
//
//	AtariAudio 1.27
//	Small & accurate ATARI-ST audio emulation
//	by Arnaud Carré aka Leonard/Oxygene (@leonard_coder)
//
//----------------------------------------------------------
#include <assert.h>
#include "ym2149c.h"
#include "ym2149_tables.h"
#include "ModizerVoicesData.h"   // REWAMP: per-voice oscilloscope + notes

// REWAMP: defined after s_ViewVolTab, below.
static int rewampView(unsigned int index);

static uint32_t sRndSeed = 1;
// this rnd func is only used at init time to randomize the square oscillator state
// (it's *not* the ym2149 noise RNG)
uint16_t stdLibRand()
{
	sRndSeed = sRndSeed*214013+2531011;
	return uint16_t((sRndSeed >> 16) & 0x7fff);
}

void	Ym2149c::Reset(uint32_t hostReplayRate, uint32_t ymClock, bool predictibleYm2149State)
{

	if (predictibleYm2149State)
	{
		for (int v = 0; v < 3; v++)
		{
			m_toneCounter[v] = 0;
			m_tonePeriod[v] = 0;
			m_edgeNeedReset[v] = false;
		}
		m_toneEdges = 0;
		m_envCounter = 0;
		m_noiseCounter = 0;
		m_envPeriod = 0;
		m_noisePeriod = 0;
		m_currentNoiseMask = ~0;
	}
	else
		m_toneEdges = (stdLibRand()&((1<<10)|(1<<5)|(1<<0)))*0x1f;		// YM internal edge state are un-predictable

	for (int v = 0; v < 3; v++)
	{
		m_toneCounter[v] = 0;
		m_tonePeriod[v] = 0;
		m_edgeNeedReset[v] = false;
	}
	m_insideTimerIrq = false;
	MuteVoices(0);	// do not mute anything
	m_insideTimerIrq = false;
	m_hostReplayRate = hostReplayRate;
	// operate at original YM freq divided by 8 (so 250Khz, as nothing runs faster in the chip)
	m_ymClockOneEighth = ymClock/8;
	m_noiseRndRack = 1;
	m_noiseHalf = 0;
	for (int r=0;r<14;r++)
		WriteReg(r, (7==r)?0x3f:0);
	m_selectedReg = 0;
	m_innerCycle = 0;
	m_envPos = 0;
	m_currentVisualLevels = 0;
	m_dcAdjustPos = 0;
	m_dcAdjustSum = 0;
	for (int i=0;i<1<<kDcAdjustHistoryBit;i++)
		m_dcAdjustBuffer[i] = 0;
}

void	Ym2149c::WritePort(uint8_t port, uint8_t value)
{
	if (port & 2)
		WriteReg(m_selectedReg, value);
	else
		m_selectedReg = value;
}

void	Ym2149c::WriteReg(int reg, uint8_t value)
{
	if ((unsigned int)reg < 14)
	{
		static const uint8_t regMask[14] = { 0xff,0x0f,0xff,0x0f,0xff,0x0f,0x1f,0x3f,0x1f,0x1f,0x1f,0xff,0xff,0x0f };
		m_regs[reg] = value & regMask[reg];

		switch (reg)
		{
		case 0:
		case 1:
		case 2:
		case 3:
		case 4:
		case 5:
		{
			const int voice = reg >> 1;
			m_tonePeriod[voice] = (m_regs[voice * 2 + 1] << 8) | m_regs[voice * 2];
/*
			// when period change and counter is above, counter will restart at next YM cycle
			// but there is some delay if you do that on 3 voices using CPU. Simulate this delay
			// with empirical offset
			if (m_toneCounter[voice] >= m_tonePeriod[voice])
				m_toneCounter[voice] = voice * 8;
*/
			if (m_tonePeriod[voice] <= 1)
			{
				if (m_insideTimerIrq)
					m_edgeNeedReset[voice] = true;
			}
			break;
		}
		case 6:
			m_noisePeriod = m_regs[6];
			break;
		case 7:
		{
			static const uint32_t masks[8] = { 0x0000,0x001f,0x03e0,0x03ff,0x7c00,0x7c1f,0x7fe0,0x7fff };
			m_toneMask = masks[value & 0x7];
			m_noiseMask = masks[(value >> 3) & 0x7];
		}
			break;
		case 11:
		case 12:
			m_envPeriod = (m_regs[12] << 8) | m_regs[11];
			break;
		case 13:
		{
			static const uint8_t shapeToEnv[16] = { 0,0,0,0,1,1,1,1,2,3,4,5,6,7,8,9 };
			m_pCurrentEnv = s_envData + (shapeToEnv[m_regs[13]] * 32 * 4);
			m_envPos = -64;
			m_envCounter = 0;
			break;
		}
		default:
			break;
		}
	}
}

uint8_t Ym2149c::ReadPort(uint8_t port) const
{
	if (0 == (port & 2))
		return m_regs[m_selectedReg];
	return ~0;
}

int16_t	Ym2149c::dcAdjust(int16_t v)
{
	m_dcAdjustSum -= m_dcAdjustBuffer[m_dcAdjustPos];
	m_dcAdjustSum += v;
	m_dcAdjustBuffer[m_dcAdjustPos] = v;
	m_dcAdjustPos++;
	m_dcAdjustPos &= (1 << kDcAdjustHistoryBit) - 1;
	int32_t ov = int32_t(v) - int32_t(m_dcAdjustSum >> kDcAdjustHistoryBit);
	// max amplitude is 15bits (not 16) so dc adjuster should never overshoot
	return int16_t(ov);
}

// Tick internal YM2149 state machine at 250Khz ( 2Mhz/8 )
int Ym2149c::Tick()
{

	// three voices at same time
	const uint32_t vmask = (m_toneEdges | m_toneMask) & (m_currentNoiseMask | m_noiseMask);

	// update internal state
	for (int v = 0; v < 3; v++)
	{
		m_toneCounter[v]++;
		if (m_toneCounter[v] >= m_tonePeriod[v])
		{
			m_toneEdges ^= 0x1f<<(v*5);
			m_toneCounter[v] = 0;
		}
	}

	m_envCounter++;
	if ( m_envCounter >= m_envPeriod )
	{
		m_envPos++;
		if (m_envPos > 0)
			m_envPos &= 63;
		m_envCounter = 0;
	}

	// noise state machine is running half speed
	m_noiseHalf ^= 1;
	if (m_noiseHalf)
	{
		// noise
		m_noiseCounter++;
		if (m_noiseCounter >= m_noisePeriod)
		{
			m_currentNoiseMask = ((m_noiseRndRack ^ (m_noiseRndRack >> 2))&1) ? ~0 : 0;
			m_noiseRndRack = (m_noiseRndRack >> 1) | ((m_currentNoiseMask&1) << 16);
			m_noiseCounter = 0;
		}
	}

	const uint32_t envLevel = m_pCurrentEnv[m_envPos + 64];
	uint32_t levels;
	levels  = ((m_regs[8] & 0x10) ? envLevel : ((m_regs[8]<<1)|1)) << 0;
	levels |= ((m_regs[9] & 0x10) ? envLevel : ((m_regs[9]<<1)|1)) << 5;
	levels |= ((m_regs[10] & 0x10) ? envLevel : ((m_regs[10]<<1)|1)) << 10;
	levels &= vmask;
	assert(levels < 0x8000);

	levels &= m_enableMask;		// ability to artificially mute some voices

	m_currentVisualLevels = uint16_t(levels);

	return (s_ym2149RecordedMixTable[levels]);
}

void Ym2149c::MuteVoices(uint32_t muteMask)
{
	m_enableMask = 0;
	for (int i = 0; i < 3; i++)
		m_enableMask |= muteMask&(1 << i) ? 0 : 31 << (i * 5);
}

// called at host replay rate ( like 48Khz )
// internally update YM chip state machine at 250Khz and average output for each host sample
int16_t Ym2149c::ComputeNextSample()
{
	int acc = 0;
	int counter = 0;
	int rwView[3] = { 0, 0, 0 };	// REWAMP: per-voice scope, averaged like the mix
	do
	{
		acc += Tick();
		for (int v = 0; v < 3; v++)	// REWAMP
			rwView[v] += rewampView((m_currentVisualLevels >> (v * 5)) & 31);
		counter++;
		m_innerCycle += m_hostReplayRate;
	}
	while (m_innerCycle < m_ymClockOneEighth);
	m_innerCycle -= m_ymClockOneEighth;
	RewampScopeSample(rwView, counter);	// REWAMP
	return dcAdjust(acc / counter);
}

#define	k15toS8(a)	((((a*127)>>15)+63)^0x80)	// signed 8bits value for oscillators viewing display per voice
static const uint32_t	s_ViewVolTab[16*2] =
{
	k15toS8(152),k15toS8(181),k15toS8(215),k15toS8(255),
	k15toS8(304),k15toS8(362),k15toS8(430),k15toS8(511),
	k15toS8(608),k15toS8(724),k15toS8(861),k15toS8(1023),
	k15toS8(1217),k15toS8(1448),k15toS8(1722),k15toS8(2047),
	k15toS8(2435),k15toS8(2896),k15toS8(3444),k15toS8(4095),
	k15toS8(4870),k15toS8(5792),k15toS8(6888),k15toS8(8191),
	k15toS8(9741),k15toS8(11584),k15toS8(13776),k15toS8(16383),
	k15toS8(19483),k15toS8(23169),k15toS8(27553),k15toS8(32767)
};

// REWAMP: a voice's level as the author's per-voice oscilloscope table gives
// it (signed 8-bit, centred by k15toS8's ^0x80) — the gated level, so a tone
// draws its square wave.
static int rewampView(unsigned int index)
{
	return (int8_t)(uint8_t)s_ViewVolTab[index & 31];
}

// REWAMP: one output sample of the three voice scopes (the ticks of this
// sample averaged, as the mix is), and the notes: tone (else noise) period ->
// Hz, volume 1 while the voice is audible. A muted voice (MuteVoices, from
// rewamp's generic_mute_mask) draws a flat line. Ring mask = the plugin's
// SNDH_RING_SIZE (SOUND_BUFFER_SIZE_SAMPLE*4*2: the scope's trigger search
// needs ~2212 samples of history).
void Ym2149c::RewampScopeSample(const int* view, int counter)
{
	for (int v = 0; v < 3; v++)
	{
		const bool muted = 0 == (m_enableMask & (31u << (v * 5)));
		const int8_t s = muted ? 0 : (int8_t)(view[v] / (counter > 0 ? counter : 1));
		if (m_voice_buff[v])
			m_voice_buff[v][(m_voice_current_ptr[v] >> MODIZER_OSCILLO_OFFSET_FIXEDPOINT) & (SOUND_BUFFER_SIZE_SAMPLE * 4 * 2 - 1)] = s;
		m_voice_current_ptr[v] += 1 << MODIZER_OSCILLO_OFFSET_FIXEDPOINT;

		uint32_t period = 0;
		if (0 == (m_toneMask & (1u << (v * 5))))
			period = m_tonePeriod[v];
		else if (0 == (m_noiseMask & (1u << (v * 5))))
			period = m_noisePeriod;
		const uint8_t reg = m_regs[8 + v];
		const bool audible = !muted && period > 0 && ((reg & 0x10) || (reg & 0x0f));
		vgm_last_note[v] = audible ? (unsigned int)(m_ymClockOneEighth / period / 2) : 0;
		vgm_last_vol[v]  = audible ? 1 : 0;
	}
}

uint32_t Ym2149c::ComputeCurrentVisualLevels() const
{
	const unsigned int indexA = (m_currentVisualLevels >> 0) & 31;
	const unsigned int indexB = (m_currentVisualLevels >> 5) & 31;
	const unsigned int indexC = (m_currentVisualLevels >> 10) & 31;
	uint32_t visualLevels = (s_ViewVolTab[indexA] << 0) | (s_ViewVolTab[indexB] << 8) | (s_ViewVolTab[indexC] << 16);
	return visualLevels;
}

void	Ym2149c::InsideTimerIrq(bool inside)
{
	if (!inside)
	{
		// when exiting timer IRQ code, do any pending edge reset ( "square-sync" modern fx )
		for (int v = 0; v < 3; v++)
		{
			if (m_edgeNeedReset[v])
			{
				m_toneEdges ^= 0x1f<<(v*5);
				m_toneCounter[v] = 0;
				m_edgeNeedReset[v] = false;
			}
		}
	}
	m_insideTimerIrq = inside;
}
