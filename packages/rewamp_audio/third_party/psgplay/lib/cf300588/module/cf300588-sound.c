// SPDX-License-Identifier: GPL-2.0
/*
 * Copyright (C) 2025 Fredrik Noring
 */

#include "cf300588/macro.h"
#include "cf300588/module/assert.h"
#include "cf300588/module/cf300588-sound.h"

enum {
	SAMPLE_RATE_CLK_DIVISOR = 8
};

static inline uint32_t mode_rate_period(struct cf300588_sound_mode mode)
{
	return 5 * (1 << (3 - mode.rate));
}

static void sound_active(struct cf300588_sound_module *module, bool active)
{
	struct cf300588_sound_state *state = &module->state;

	if (state->dma.sint.active == active)
		return;

	state->dma.sint.active = active;
	state->dma.sint.count++;
}

static void sound_start(struct cf300588_sound_module *module)
{
	struct cf300588_sound_state *state = &module->state;

	state->regs = state->hold;

	state->dma.base    = (state->regs.basehi << 16) |
			     (state->regs.basemi <<  8) |
			      state->regs.baselo;
	state->dma.counter =  state->dma.base;
	state->dma.end     = (state->regs.endhi  << 16) |
			     (state->regs.endmi  <<  8) |
			      state->regs.endlo;

	sound_active(module, true);
}

static void sound_stop(struct cf300588_sound_module *module)
{
	struct cf300588_sound_state *state = &module->state;

	state->hold.ctrl.play = false;

	state->regs = state->hold;

	state->dma.base = state->dma.counter = state->dma.end = 0;

	sound_active(module, false);
}

static size_t fifo_capacity(const struct cf300588_sound_module *module)
{
	return ARRAY_SIZE(module->state.fifo.b) - module->state.fifo.size;
}

static void wr_fifo(struct cf300588_sound_module *module, int8_t s)
{
	struct cf300588_sound_fifo *fifo = &module->state.fifo;

	if (fifo->size >= ARRAY_SIZE(fifo->b)) {
		pr_err(module, "%s: FIFO full\n", __func__);

		return;
	}

	fifo->b[(fifo->index + fifo->size++) % ARRAY_SIZE(fifo->b)] = s;
}

static int8_t rd_fifo(struct cf300588_sound_module *module)
{
	struct cf300588_sound_fifo *fifo = &module->state.fifo;

	if (!fifo->size) {
		pr_err(module, "%s: FIFO empty\n", __func__);

		return 0;
	}

	const int8_t s = fifo->b[fifo->index];

	fifo->index = (fifo->index + 1) % ARRAY_SIZE(fifo->b);
	fifo->size--;

	return s;
}

static inline uint8_t dma_rd8(struct cf300588_sound_module *module,
	struct cf300588_sound_dma_map dma_map)
{
	struct cf300588_sound_state *state = &module->state;
	const uint32_t counter = state->dma.counter;

	if (counter < dma_map.addr)
		return 0;

	const uint32_t offset = counter - dma_map.addr;

	if (offset >= dma_map.size)
		return 0;

	const uint8_t *u8 = dma_map.p;

	state->dma.counter++;

	return u8[offset];
}

static bool fill_fifo(struct cf300588_sound_module *module,
	struct cf300588_sound_dma_map dma_map)
{
	struct cf300588_sound_state *state = &module->state;

	while (state->regs.ctrl.play && fifo_capacity(module) >= 2 &&
	       state->dma.counter != state->dma.end) {
		wr_fifo(module, dma_rd8(module, dma_map));
		wr_fifo(module, dma_rd8(module, dma_map));

		if (state->dma.counter == state->dma.end) {
			const bool play_repeat = state->regs.ctrl.play_repeat;

			sound_stop(module);

			if (play_repeat) {
				state->regs.ctrl.play =
				state->hold.ctrl.play = true;

				sound_start(module);
			}
		}
	}

	return state->fifo.size > 0;
}

static struct cf300588_sound_sample dma_sample(
	struct cf300588_sound_module *module,
	struct cf300588_sound_dma_map dma_map, const uint32_t n)
{
	struct cf300588_sound_state *state = &module->state;

	if (state->dma.k > 0 || !fill_fifo(module, dma_map))
		goto repeat;

	if (state->regs.mode.mono) {
		const int8_t mono = rd_fifo(module);

		state->dma.sample.left  = mono;
		state->dma.sample.right = mono;
	} else {
		state->dma.sample.left  = rd_fifo(module);
		state->dma.sample.right = (state->fifo.size ?
			rd_fifo(module) : state->dma.sample.left);
	}

repeat:
	if (++state->dma.k >= n)
		state->dma.k = 0;

	return state->dma.sample;
}

static size_t sound_dma_size(const struct cf300588_sound_state_dma *dma)
{
	return dma->end > dma->base ?
	       dma->end - dma->base : 0;
}

static size_t sound_dma_remain(const struct cf300588_sound_state_dma *dma)
{
	return dma->end > dma->counter ?
	       dma->end - dma->counter : 0;
}

static struct cf300588_sound_dma_region sound_dma(
	struct cf300588_sound_module *module)
{
	if (!module->state.regs.ctrl.play)
		return (struct cf300588_sound_dma_region) { };

	return (struct cf300588_sound_dma_region) {
		.size = sound_dma_size(&module->state.dma),
		.addr = module->state.dma.base,
	};
}

static size_t sound_sample(struct cf300588_sound_module *module,
	struct cf300588_sound_cycle cycle,
	struct cf300588_sound_samples samples,
	struct cf300588_sound_dma_map dma_map)
{
	struct cf300588_sound_state *state = &module->state;
	const uint64_t d = SAMPLE_RATE_CLK_DIVISOR * module->cycle.d;
	size_t i = 0;

	if (!state->regs.ctrl.play && !state->fifo.size) {
		while (i < samples.size && module->cycle.c + d <= cycle.c) {
			samples.sample[i++] = state->dma.sample;

			module->cycle.c += d;
		}
	} else {
		const uint64_t n = mode_rate_period(module->state.regs.mode);

		while (i < samples.size && module->cycle.c + d <= cycle.c) {
			samples.sample[i++] = dma_sample(module, dma_map, n);

			module->cycle.c += d;
		}

		state->regs.counterhi = (state->dma.counter >> 16) & 0x3f;
		state->regs.countermi =  state->dma.counter >> 8;
		state->regs.counterlo =  state->dma.counter & 0xfe;
	}

	return i;
}

static struct cf300588_sound_event sound_event(
	struct cf300588_sound_module *module,
	struct cf300588_sound_cycle cycle)
{
	struct cf300588_sound_state *state = &module->state;

	if (module->cycle.c < cycle.c)
		pr_err(module, "%s: clock unsynchronised\n", __func__);

	const struct cf300588_sound_sint sint = state->dma.sint;
	state->dma.sint = (struct cf300588_sound_sint) {
		.active = sint.active,
		.count = 0,
	};

	if (!state->regs.ctrl.play)
		goto out;

	/*
	 * FIXME: Optimisation to avoid flooding the MFP with interrupts for
	 * very small buffers. This can be done more fine grained, for example
	 * by checking whether the MFP will ignore these interrupts anyway.
	 */
	if (sound_dma_size(&module->state.dma) < 16)
		goto out;

	const size_t m = state->regs.mode.mono ? 1 : 2;
	const size_t remaining = sound_dma_remain(&state->dma) / m;
	const size_t margin = ARRAY_SIZE(state->fifo.b) / m;
	const uint64_t n = mode_rate_period(module->state.regs.mode);
	const uint64_t timeout = remaining > margin ?
		SAMPLE_RATE_CLK_DIVISOR * n * (remaining - margin) : 0;

	/*
	 * Issue DMA completion event when the FIFO is expected
	 * to read the last sample.
	 */
	return (struct cf300588_sound_event) {
		.sint = sint,
		.cycle = (struct cf300588_sound_cycle) {
			.c = module->cycle.c + module->cycle.d * timeout,
			.d = module->cycle.d
		}
	};

out:
	return (struct cf300588_sound_event) { .sint = sint };
}

static uint8_t sound_rd_u8(struct cf300588_sound_module *module,
	struct cf300588_sound_cycle cycle, uint8_t reg)
{
	if (module->cycle.c < cycle.c)
		pr_err(module, "%s: clock unsynchronised\n", __func__);

	return reg < ARRAY_SIZE(module->state.regs.reg) ?
	       module->state.regs.reg[reg] : 0;
}

static void sound_hardwire(struct cf300588_sound_regs *regs)
{
	regs->reg[CF300588_SOUND_REG_CTRL]   &= 0x03;
	regs->reg[CF300588_SOUND_REG_BASEHI] &= 0x3f;
	regs->reg[CF300588_SOUND_REG_BASELO] &= 0xfe;
	regs->reg[CF300588_SOUND_REG_ENDHI]  &= 0x3f;
	regs->reg[CF300588_SOUND_REG_ENDLO]  &= 0xfe;
	regs->reg[CF300588_SOUND_REG_MODE]   &= 0x83;

	regs->unused = (struct cf300588_sound_reg_unused) { };
}

static struct cf300588_sound_event sound_wr_u8(
	struct cf300588_sound_module *module,
	struct cf300588_sound_cycle cycle, uint8_t reg, uint8_t val)
{
	struct cf300588_sound_state *state = &module->state;

	if (module->cycle.c < cycle.c)
		pr_err(module, "%s: clock unsynchronised\n", __func__);

	if (ARRAY_SIZE(state->regs.reg) <= reg)
		goto out;

	state->hold.reg[reg] = val;
	sound_hardwire(&state->hold);

	const bool ctrl_play = state->hold.ctrl.play !=
			       state->regs.ctrl.play;

	if (ctrl_play || !state->regs.ctrl.play)
		state->regs.reg[reg] = state->hold.reg[reg];

	if (ctrl_play)
		(state->regs.ctrl.play ?
			 sound_start : sound_stop)(module);

out:
	return sound_event(module, cycle);
}

static bool sound_wr_ar(struct cf300588_sound_module *module,
	uint32_t addr, uint32_t size)
{
	/* Note: The write address range could be made more fine-grained. */
	return module->state.regs.ctrl.play && size > 0 &&
	       module->state.dma.base < addr + size &&
					addr < module->state.dma.end;
}

struct cf300588_sound_module cf300588_sound_init(
	struct cf300588_sound_cycle cycle)
{
	BUILD_BUG_ON(sizeof(struct cf300588_sound_regs) != 17);

	return (struct cf300588_sound_module) {
		.port = {
			.rd_da   = sound_rd_u8,
			.wr_da   = sound_wr_u8,

			.event   = sound_event,

			.wr_ar   = sound_wr_ar,

			.dma     = sound_dma,
			.sample  = sound_sample,
		},

		.cycle = cycle,
	};
}
