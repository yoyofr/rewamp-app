// vgm_v3.h: conversion between the first ES55xx / ZSG-2 VGM encoding (v1: MAME logger and libvgm
// "es55xx" branch until 2026-10) and the v3 encoding of VGM-proposal-v3-allocation.md, both ways.
// Used by vgm_v3conv (v1 -> v3 files) and vgm_trim (v3 input processed as v1, written back as v3).
// Every command maps to commands that drive the same emulation entry points of the players; a command
// with no exact counterpart is refused (exception), never approximated.
#pragma once
#include <algorithm>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <initializer_list>
#include <map>
#include <stdexcept>
#include <string>
#include <vector>

namespace vgmv3 {

typedef std::vector<uint8_t> Bytes;

inline uint32_t rd32(const Bytes& d, size_t o) { return d[o] | (d[o + 1] << 8) | (d[o + 2] << 16) | ((uint32_t)d[o + 3] << 24); }
inline void wr32(Bytes& d, size_t o, uint32_t v) { for (int i = 0; i < 4; i++) d[o + i] = (uint8_t)(v >> (8 * i)); }

[[noreturn]] inline void fail(const std::string& s) { throw std::runtime_error(s); }

// length of the command at d[p] (0x67 data blocks handled by the caller), 0 = unknown
inline size_t cmd_len(uint8_t o)
{
	if (o >= 0x30 && o <= 0x3F) return 2;
	if (o >= 0x40 && o <= 0x4E) return 3;
	if (o == 0x4F || o == 0x50) return 2;
	if (o >= 0x51 && o <= 0x5F) return 3;
	if (o == 0x61) return 3;
	if (o == 0x62 || o == 0x63 || o == 0x66) return 1;
	if (o == 0x68) return 12;
	if (o >= 0x70 && o <= 0x8F) return 1;
	switch (o) { case 0x90: case 0x91: case 0x95: return 5; case 0x92: return 6; case 0x93: return 11; case 0x94: return 2; }
	if (o >= 0xA0 && o <= 0xBF) return 3;
	if (o >= 0xC0 && o <= 0xDF) return 4;
	if (o >= 0xE0) return 5;
	return 0;
}

struct Conv
{
	const Bytes& in;
	Bytes out;          // command stream only
	bool es = false, zsg = false;
	bool espUsed[2] = {false, false};
	bool espCreated[2] = {false, false};
	// v1 ESP routing state, simulated so that presets can be expressed as 0xE2 commands
	uint8_t routeIn[2][6] = {{0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF}, {0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF}};
	bool direct[2][12] = {{true, true, true, true, true, true, true, true, true, true, true, true},
	                      {true, true, true, true, true, true, true, true, true, true, true, true}};
	uint8_t dramLog2 = 0;
	uint8_t window[2][4] = {}, alias[2][4] = {{0, 1, 2, 3}, {0, 1, 2, 3}};
	std::map<std::string, unsigned> stats;

	explicit Conv(const Bytes& d) : in(d) {}

	void put(std::initializer_list<uint8_t> b) { out.insert(out.end(), b); }
	void count(const std::string& k) { stats[k]++; }

	// v3 0xE2 (as the player applies it): input ii <- channel cc, and that channel leaves the direct mix
	void route(uint8_t chip, uint8_t ii, uint8_t cc)
	{
		uint8_t c7 = chip << 7;
		put({0xE2, (uint8_t)(0x35 | c7), ii, (uint8_t)(0x25 | c7), cc});
		if (ii < 6) { routeIn[chip][ii] = cc; if (cc < 12) direct[chip][cc] = false; }
	}

	// v1 preset = reset (all channels direct, no input) + preset routes. Representable when no channel that
	// the preset makes direct again is currently routed away from the direct mix (0xE2 cannot restore it).
	void es_preset(uint8_t chip, uint8_t preset)
	{
		uint8_t tIn[6]; bool tDir[12];
		for (int c = 0; c < 12; c++) tDir[c] = true;
		for (int i = 0; i < 6; i++) tIn[i] = 0xFF;
		if (preset == 0) for (int i = 0; i < 6; i++) { tIn[i] = (uint8_t)(i + 2); tDir[i + 2] = false; }
		else if (preset == 1) for (int i = 0; i < 6; i++) { tIn[i] = (uint8_t)i; tDir[i] = false; }
		for (int c = 0; c < 12; c++)
			if (tDir[c] && !direct[chip][c]) fail("ES5510 routing preset would put channel " + std::to_string(c) + " back in the direct mix: not representable in v3");
		espCreated[chip] = espUsed[chip] = true;
		bool any = false;
		for (uint8_t i = 0; i < 6; i++)
			if (routeIn[chip][i] != tIn[i] || (tIn[i] < 12 && direct[chip][tIn[i]])) { route(chip, i, tIn[i]); any = true; }
		if (!any)   // nothing changes: a no-op route still creates the ESP like the v1 command did
			put({0xE2, (uint8_t)(0x35 | (chip << 7)), 0x00, (uint8_t)(0x25 | (chip << 7)), routeIn[chip][0]});
	}

	void es_d7(uint8_t pp, uint8_t aa, uint8_t dd)
	{
		uint8_t chip = pp >> 7, c7 = pp & 0x80;
		switch (pp & 0x7F)
		{
		case 0x00: put({0x49, (uint8_t)((aa & 0x1F) | c7), dd}); count("D7 00 bank -> 49"); break;
		case 0x01:
			if (dd > 0x3F) fail("ES5506 region window beyond 63M words");
			window[chip][aa & 3] = dd;
			put({0x4A, (uint8_t)((aa & 3) | c7), (uint8_t)((dd << 2) | alias[chip][aa & 3])}); count("D7 01 window -> 4A"); break;
		case 0x02:
			alias[chip][aa & 3] = dd & 3;
			put({0x4A, (uint8_t)((aa & 3) | c7), (uint8_t)((window[chip][aa & 3] << 2) | (dd & 3))}); count("D7 02 alias -> 4A"); break;
		case 0x03: count("D7 03 IRQ ack (dropped)"); break;
		case 0x04:
			if (!dd) fail("ES5506 IRQ auto-ack disabled (D7 04 00): not representable in v3");
			count("D7 04 IRQ auto-ack (dropped)"); break;
		default: fail("unknown ES5506 extension D7 " + std::to_string(pp));
		}
	}

	void es_d8(uint8_t pp, uint8_t aa, uint8_t dd)
	{
		uint8_t chip = pp >> 7, c7 = pp & 0x80;
		uint8_t sub = pp & 0x7F;
		if (sub == 0x06)
		{
			if (espCreated[chip]) fail("ES5510 DRAM size set after the ESP started");
			if (dramLog2 && dramLog2 != dd) fail("two different ES5510 DRAM sizes");
			dramLog2 = dd;
			count("D8 06 DRAM size -> header 0x11C");
			return;
		}
		espCreated[chip] = espUsed[chip] = true;
		switch (sub)
		{
		case 0x00: put({0xCC, c7, aa, dd}); count("D8 00 host -> CC"); break;
		case 0x01: put({0x4B, c7, (uint8_t)(dd ? 1 : 0)}); count("D8 01 halt -> 4B"); break;
		case 0x02:
			if (aa >= 6) { count("D8 02 route of a missing input (dropped)"); break; }
			route(chip, aa, dd); count("D8 02 route -> E2"); break;
		case 0x03:
			if ((aa != 6 && aa != 7) || (dd & 1) != (aa & 1)) fail("ES5510 output routed to the other side: not representable in v3");
			count("D8 03 route out (default, dropped)"); break;
		case 0x04: fail("ES5506 direct-mix flag (D8 04): not representable in v3");
		case 0x05: es_preset(chip, aa); count("D8 05 preset -> E2"); break;
		default: fail("unknown ES5510 command D8 " + std::to_string(pp));
		}
	}

	void es_e3(uint8_t pp, uint8_t cc, uint8_t g0, uint8_t g1)
	{
		uint8_t c7 = pp & 0x80;
		if (cc < 12) put({0xE3, (uint8_t)(0x25 | c7), cc, g0, g1});
		else if (cc == 0x10 || cc == 0x11) put({0xE3, (uint8_t)(0x35 | c7), (uint8_t)(6 + (cc & 1)), g0, g1});
		else if (cc == 0x12 || cc == 0x13) put({0xE3, (uint8_t)(0x25 | c7), (uint8_t)(0xFE + (cc & 1)), g0, g1});
		else { count("E3 unused gain channel (dropped)"); return; }
		count("E3 gain -> E3 tt");
	}

	void zsg_e4(uint8_t ss, uint8_t aa, uint8_t d0, uint8_t d1)
	{
		uint8_t c7 = ss & 0x80;
		uint16_t dddd = (uint16_t)((d0 << 8) | d1);
		switch (ss & 0x0F)
		{
		case 0x0: case 0x1: case 0x2: case 0x3:
			put({0xE4, (uint8_t)(c7 | (ss & 3)), aa, d0, d1}); count("E4 reg -> E4 oooo"); break;
		case 0x4: put({0x4D, c7, d1}); count("E4 4 DSP data -> 4D"); break;
		case 0x5: put({0x4E, c7, (uint8_t)(d1 & 3)}); count("E4 5 DSP lines -> 4E"); break;
		case 0x6:
		{
			uint8_t tt, cc;
			if (aa < 4) { tt = 0x36; cc = 0x80 + aa; }
			else if (aa >= 0x10 && aa < 0x14 && !(aa & 1)) { tt = 0x36; cc = aa & 3; }
			else if (aa >= 0x14 && aa < 0x18 && (aa & 1)) { tt = 0x36; cc = aa & 3; }
			else if (aa >= 0x20 && aa < 0x24 && !(aa & 1)) { tt = 0x34; cc = aa & 3; }
			else if (aa >= 0x24 && aa < 0x28 && (aa & 1)) { tt = 0x34; cc = aa & 3; }
			else if (aa < 0x28 && dddd == 0) { count("E4 6 zero gain to the other side (default, dropped)"); return; }
			else fail("ZSG-2 mixer gain channel " + std::to_string(aa) + " not representable in v3");
			put({0xE3, (uint8_t)(tt | c7), cc, d0, d1}); count("E4 6 gain -> E3"); break;
		}
		case 0x7: put({0x4C, c7, 0x01}); put({0x4E, c7, 0x04}); count("E4 7 reset -> 4C + 4E"); break;
		case 0x8:
		{
			uint32_t n = ((uint32_t)aa << 16) | dddd;
			do
			{
				uint16_t k = (uint16_t)(n > 0xFFFF ? 0xFFFF : n);
				put({0xCD, c7, (uint8_t)(k >> 8), (uint8_t)k});
				n -= k;
			} while (n);
			count("E4 8 pre-run -> CD"); break;
		}
		default: fail("unknown ZSG-2 extension E4 " + std::to_string(ss));
		}
	}

	// returns the new offset (in the command stream) of every old command offset, for the loop point
	void run(size_t start, size_t end, std::map<size_t, size_t>& ofsMap)
	{
		size_t p = start;
		while (p < end)
		{
			ofsMap[p] = out.size();
			uint8_t o = in[p];
			if (o == 0x67)
			{
				if (p + 7 > end) fail("truncated data block");
				uint8_t type = in[p + 2];
				uint32_t szf = rd32(in, p + 3), sz = szf & 0x7FFFFFFF;
				if (p + 7 + sz > end) fail("truncated data block");
				if (type == 0x90 && es && sz >= 8)
				{
					uint32_t memsize = rd32(in, p + 7), ofs = rd32(in, p + 11);
					uint8_t region = (ofs >> 28) & 3;
					bool is8 = ofs >> 31;
					ofs &= 0x0FFFFFFF;
					uint8_t nt = region ? (uint8_t)(0x98 + region) : 0x90;
					Bytes data(in.begin() + p + 15, in.begin() + p + 7 + sz);
					if (is8)
					{
						Bytes w(data.size() * 2);
						for (size_t i = 0; i < data.size(); i++) { w[2 * i] = 0; w[2 * i + 1] = data[i]; }
						data.swap(w);
						memsize *= 2; ofs *= 2;
						count("block 90 8-bit -> 16-bit");
					}
					if (region) count("block 90 region -> 99..9B");
					uint32_t nsz = 8 + (uint32_t)data.size();
					put({0x67, 0x66, nt});
					size_t q = out.size(); out.resize(q + 12);
					wr32(out, q, nsz | (szf & 0x80000000)); wr32(out, q + 4, memsize); wr32(out, q + 8, ofs);
					out.insert(out.end(), data.begin(), data.end());
				}
				else if (type == 0x98 && zsg && sz >= 8)
				{
					uint32_t ofs = rd32(in, p + 11);
					uint32_t dlen = sz - 8;
					put({0x67, 0x66, 0xE2});
					size_t q = out.size(); out.resize(q + 8);
					wr32(out, q, (4 + dlen) | (szf & 0x80000000)); wr32(out, q + 4, ofs);
					out.insert(out.end(), in.begin() + p + 15, in.begin() + p + 7 + sz);
					count("block 98 DSP state -> E2");
				}
				else
					out.insert(out.end(), in.begin() + p, in.begin() + p + 7 + sz);
				p += 7 + sz;
				continue;
			}
			size_t l = cmd_len(o);
			if (!l) { char b[64]; snprintf(b, sizeof b, "unknown command 0x%02X at 0x%zX", o, p); fail(b); }
			if (p + l > end) fail("truncated command");
			const uint8_t* c = &in[p];
			if (es && o == 0xBE && (c[1] & 0x7F) >= 0x40) { put({0x49, (uint8_t)((c[1] & 0x9F)), c[2]}); count("BE 40+v bank -> 49"); }
			else if (es && o == 0xD6 && (c[1] & 0x7F) >= 0x40)
			{
				if (c[2]) fail("ES5506 16-bit bank write beyond 255M words");
				put({0x49, (uint8_t)(c[1] & 0x9F), c[3]}); count("D6 40+v bank -> 49");
			}
			else if (es && o == 0xD7) es_d7(c[1], c[2], c[3]);
			else if (es && o == 0xD8) es_d8(c[1], c[2], c[3]);
			else if (es && o == 0xE3) es_e3(c[1], c[2], c[3], c[4]);
			else if (zsg && o == 0xE4) zsg_e4(c[1], c[2], c[3], c[4]);
			else if ((o >= 0x49 && o <= 0x4E) || o == 0xCC || o == 0xCD || o == 0xE2 || (!es && (o == 0xD7 || o == 0xD8 || o == 0xE3)) || (!zsg && o == 0xE4))
			{ char b[64]; snprintf(b, sizeof b, "command 0x%02X at 0x%zX has no v1 meaning", o, p); fail(b); }
			else out.insert(out.end(), c, c + l);
			p += l;
			if (o == 0x66) break;
		}
		ofsMap[p] = out.size();
	}
};


enum Kind { NONE = 0, ES = 1, ZSG = 2 };

struct Layout { size_t dataOfs, dataEnd, gd3, loop; };
inline Layout layout(const Bytes& d)
{
	if (d.size() < 0x40 || memcmp(d.data(), "Vgm ", 4)) fail("not a VGM file");
	Layout l;
	uint32_t ver = rd32(d, 0x08);
	l.dataOfs = ver >= 0x150 && rd32(d, 0x34) ? 0x34 + rd32(d, 0x34) : 0x40;
	size_t eof = 0x04 + (size_t)rd32(d, 0x04);
	if (eof > d.size()) eof = d.size();
	l.gd3 = rd32(d, 0x14) ? 0x14 + rd32(d, 0x14) : 0;
	l.loop = rd32(d, 0x1C) ? 0x1C + rd32(d, 0x1C) : 0;
	l.dataEnd = l.gd3 && l.gd3 > l.dataOfs && l.gd3 <= eof ? l.gd3 : eof;
	if (l.dataOfs > 0xBC + 4 && rd32(d, 0xBC)) fail("extra header present: not handled");
	return l;
}

// a v3 file that uses the ES55xx / ZSG-2 additions (header >= 0x120 with an ES5505/6 or ZSG-2 clock)
inline bool is_v3_ext(const Bytes& d)
{
	if (d.size() < 0x40 || memcmp(d.data(), "Vgm ", 4)) return false;
	size_t dataOfs = rd32(d, 0x08) >= 0x150 && rd32(d, 0x34) ? 0x34 + rd32(d, 0x34) : 0x40;
	if (dataOfs < 0x120 || d.size() < 0x120) return false;
	return rd32(d, 0xD0) != 0 || rd32(d, 0x110) != 0;
}

// build the output file: new header (copied from the input up to hdrLen, then patched by the caller),
// command stream, loop offset remapped, GD3 copied
inline Bytes assemble(const Bytes& d, const Layout& l, size_t hdrLen, const Bytes& cmds, const std::map<size_t, size_t>& ofsMap)
{
	Bytes o(hdrLen, 0);
	memcpy(o.data(), d.data(), l.dataOfs < hdrLen ? l.dataOfs : hdrLen);
	for (size_t i = l.dataOfs; i < hdrLen; i++) o[i] = 0;
	wr32(o, 0x34, (uint32_t)(hdrLen - 0x34));
	if (l.loop)
	{
		auto it = ofsMap.find(l.loop);
		if (it == ofsMap.end()) fail("loop offset is not on a command boundary");
		wr32(o, 0x1C, (uint32_t)(hdrLen + it->second - 0x1C));
	}
	o.insert(o.end(), cmds.begin(), cmds.end());
	if (l.gd3 && l.gd3 + 12 <= d.size() && !memcmp(&d[l.gd3], "Gd3 ", 4))
	{
		size_t glen = 12 + rd32(d, l.gd3 + 8);
		wr32(o, 0x14, (uint32_t)(o.size() - 0x14));
		o.insert(o.end(), d.begin() + l.gd3, d.begin() + std::min(d.size(), l.gd3 + glen));
	}
	else
		wr32(o, 0x14, 0);
	wr32(o, 0x04, (uint32_t)(o.size() - 0x04));
	return o;
}

// v1 -> v3. kind = what was converted (NONE: the file is returned unchanged). force: convert a header
// that does not look like v1.
inline Bytes to_v3(const Bytes& d, int& kind, std::map<std::string, unsigned>* stats = nullptr, bool force = false)
{
	Layout l = layout(d);
	uint32_t esClk = l.dataOfs >= 0xD4 ? rd32(d, 0xD0) : 0;
	uint32_t zsgClk = l.dataOfs >= 0x104 ? rd32(d, 0x100) : 0;
	Conv cv(d);
	cv.es = esClk != 0;
	cv.zsg = zsgClk != 0 && l.dataOfs == 0x110;   // v1 ZSG-2 header (v3 / PR #151 headers are >= 0x120)
	kind = NONE;
	if (zsgClk && !cv.zsg && !force) { char b[96]; snprintf(b, sizeof b, "clock at 0x100 with a 0x%zX header: not a v1 ZSG-2 file", l.dataOfs); fail(b); }
	if ((l.dataOfs >= 0x120 && !force) || (!cv.es && !cv.zsg)) return d;
	std::map<size_t, size_t> ofsMap;
	if (cv.zsg)   // board wiring of the Taito Zoom board, explicit (the player uses it by default)
		for (uint8_t i = 0; i < 4; i++) cv.put({0xE2, 0x36, i, 0x34, i});
	cv.run(l.dataOfs, l.dataEnd, ofsMap);
	const size_t HDR = 0x120;
	Bytes o = assemble(d, l, HDR, cv.out, ofsMap);
	if (rd32(o, 0x08) > 0x172) wr32(o, 0x08, 0x172);
	if (cv.zsg)
	{
		wr32(o, 0x100, 0);
		wr32(o, 0x110, zsgClk);
		wr32(o, 0x118, ((zsgClk & 0x3FFFFFFF) / 2) | (zsgClk & 0x40000000));
	}
	if (cv.espUsed[0] || cv.espUsed[1])
		wr32(o, 0x114, 10000000 | (cv.espUsed[1] ? 0x40000000 : 0));
	o[0x11C] = cv.dramLog2;
	kind = cv.es ? ES : ZSG;
	if (stats) *stats = cv.stats;
	return o;
}

// v3 -> v1 (the inverse mapping). Only for files that is_v3_ext() accepts.
struct Down
{
	const Bytes& in;
	Bytes out;
	bool es = false, zsg = false;
	uint8_t window[2][4] = {}, alias[2][4] = {{0, 1, 2, 3}, {0, 1, 2, 3}};

	explicit Down(const Bytes& d) : in(d) {}
	void put(std::initializer_list<uint8_t> b) { out.insert(out.end(), b); }
	[[noreturn]] void bad(uint8_t o, size_t p, const char* why) { char b[128]; snprintf(b, sizeof b, "command 0x%02X at 0x%zX: %s", o, p, why); fail(b); }

	void run(size_t start, size_t end, std::map<size_t, size_t>& ofsMap)
	{
		size_t p = start;
		while (p < end)
		{
			ofsMap[p] = out.size();
			uint8_t o = in[p];
			if (o == 0x67)
			{
				if (p + 7 > end) fail("truncated data block");
				uint8_t type = in[p + 2];
				uint32_t szf = rd32(in, p + 3), sz = szf & 0x7FFFFFFF;
				if (p + 7 + sz > end) fail("truncated data block");
				if (es && type >= 0x99 && type <= 0x9B && sz >= 8)
				{
					uint32_t ofs = rd32(in, p + 11);
					if (ofs & 0xF0000000) fail("ES5506 region block start beyond 256M words");
					out.insert(out.end(), in.begin() + p, in.begin() + p + 7 + sz);
					size_t q = out.size() - sz;   // start of the block payload
					out[q - 5] = 0x90;
					wr32(out, q + 4, ofs | ((uint32_t)(type - 0x98) << 28));
				}
				else if (zsg && type == 0xE2 && sz >= 4)
				{
					uint32_t ofs = rd32(in, p + 7), dlen = sz - 4;
					put({0x67, 0x66, 0x98});
					size_t q = out.size(); out.resize(q + 12);
					wr32(out, q, (8 + dlen) | (szf & 0x80000000)); wr32(out, q + 4, dlen); wr32(out, q + 8, ofs);
					out.insert(out.end(), in.begin() + p + 11, in.begin() + p + 7 + sz);
				}
				else if ((type >= 0x99 && type <= 0x9B) || type == 0xE2 || type == 0x98 || type == 0x09 || (type >= 0xC4 && type <= 0xC7))
				{ char b[64]; snprintf(b, sizeof b, "data block 0x%02X has no v1 meaning here", type); fail(b); }
				else
					out.insert(out.end(), in.begin() + p, in.begin() + p + 7 + sz);
				p += 7 + sz;
				continue;
			}
			size_t len = cmd_len(o);
			if (!len) { char b[64]; snprintf(b, sizeof b, "unknown command 0x%02X at 0x%zX", o, p); fail(b); }
			if (p + len > end) fail("truncated command");
			const uint8_t* c = &in[p];
			uint8_t c7 = c[1] & 0x80, chip = c[1] >> 7;
			if (o >= 0x45 && o <= 0x48) bad(o, p, "Namco WSG write, no v1 counterpart");
			else if (o == 0xCA || o == 0xCB) bad(o, p, "Namco WSG memory write, no v1 counterpart");
			else if (o == 0x49)
			{
				if (!es) bad(o, p, "ES5506 command without an ES5506");
				if (c[1] & 0x60) bad(o, p, "voice number out of range");
				put({0xBE, (uint8_t)(c[1] | 0x40), c[2]});
			}
			else if (o == 0x4A)
			{
				if (!es) bad(o, p, "ES5506 command without an ES5506");
				uint8_t r = c[1] & 3, w = c[2] >> 2, a = c[2] & 3;
				if (c[1] & 0x7C) bad(o, p, "region out of range");
				bool cw = window[chip][r] != w, ca = alias[chip][r] != a;
				window[chip][r] = w; alias[chip][r] = a;
				if (cw || !ca) put({0xD7, (uint8_t)(0x01 | c7), r, w});
				if (ca) put({0xD7, (uint8_t)(0x02 | c7), r, a});
			}
			else if (o == 0x4B)
			{
				if (!es || (c[1] & 0x7F)) bad(o, p, "ES5510 command without an ES5510");
				put({0xD8, (uint8_t)(0x01 | c7), 0x00, (uint8_t)(c[2] ? 1 : 0)});
			}
			else if (o == 0xCC)
			{
				if (!es || (c[1] & 0x7F)) bad(o, p, "ES5510 command without an ES5510");
				put({0xD8, (uint8_t)(0x00 | c7), c[2], c[3]});
			}
			else if (o == 0x4C)
			{
				// v1 has only the combined reset (ZSG-2 + DSP): 0x4C cc 01 followed by 0x4E cc 04
				if (!zsg || (c[1] & 0x7F) || c[2] != 1 || p + 6 > end || in[p + 3] != 0x4E || in[p + 4] != c[1] || !(in[p + 5] & 4))
					bad(o, p, "ZSG-2 reset without the DSP reset: no v1 counterpart");
				put({0xE4, (uint8_t)(0x07 | c7), 0, 0, 0});
				ofsMap[p + 3] = out.size();
				p += 6;
				continue;
			}
			else if (o == 0x4D)
			{
				if (!zsg || (c[1] & 0x7F)) bad(o, p, "TMS57002 command without a TMS57002");
				put({0xE4, (uint8_t)(0x04 | c7), 0, 0, c[2]});
			}
			else if (o == 0x4E)
			{
				if (!zsg || (c[1] & 0x7F) || (c[2] & 4)) bad(o, p, "TMS57002 reset without the ZSG-2 reset: no v1 counterpart");
				put({0xE4, (uint8_t)(0x05 | c7), 0, 0, (uint8_t)(c[2] & 3)});
			}
			else if (o == 0xCD)
			{
				if (!zsg || (c[1] & 0x7F)) bad(o, p, "TMS57002 command without a TMS57002");
				put({0xE4, (uint8_t)(0x08 | c7), 0, c[2], c[3]});
			}
			else if (o == 0xE2)
			{
				uint8_t dd = c[1], ii = c[2], ss = c[3], cc = c[4];
				if (es && (dd & 0x7F) == 0x35 && (ss & 0x7F) == 0x25 && (dd & 0x80) == (ss & 0x80))
					put({0xD8, (uint8_t)(0x02 | (dd & 0x80)), ii, cc});
				else if (zsg && (dd & 0x7F) == 0x36 && (ss & 0x7F) == 0x34 && (dd & 0x80) == (ss & 0x80) && ii < 4 && ii == cc)
					;   // Taito Zoom board wiring: the v1 default
				else bad(o, p, "routing with no v1 counterpart");
			}
			else if (o == 0xE3)
			{
				uint8_t tt = c[1] & 0x7F, t7 = c[1] & 0x80, cc = c[2];
				if (es && tt == 0x25 && cc < 12) put({0xE3, t7, cc, c[3], c[4]});
				else if (es && tt == 0x25 && cc >= 0xFE) put({0xE3, t7, (uint8_t)(0x12 + (cc & 1)), c[3], c[4]});
				else if (es && tt == 0x35 && (cc == 6 || cc == 7)) put({0xE3, t7, (uint8_t)(0x10 + (cc & 1)), c[3], c[4]});
				else if (zsg && tt == 0x36 && cc >= 0x80 && cc < 0x84) put({0xE4, (uint8_t)(0x06 | t7), (uint8_t)(cc - 0x80), c[3], c[4]});
				else if (zsg && tt == 0x36 && cc < 4) put({0xE4, (uint8_t)(0x06 | t7), (uint8_t)((cc & 1 ? 0x14 : 0x10) + cc), c[3], c[4]});
				else if (zsg && tt == 0x34 && cc < 4) put({0xE4, (uint8_t)(0x06 | t7), (uint8_t)((cc & 1 ? 0x24 : 0x20) + cc), c[3], c[4]});
				else bad(o, p, "gain with no v1 counterpart");
			}
			else if (o == 0xE4)
			{
				if (!zsg || (c[1] & 0x7C)) bad(o, p, "ZSG-2 register write out of range");
				out.insert(out.end(), c, c + len);
			}
			else if (es && (o == 0xD7 || o == 0xD8))
				bad(o, p, "v1 ES55xx command in a v3 file");
			else out.insert(out.end(), c, c + len);
			p += len;
			if (o == 0x66) break;
		}
		ofsMap[p] = out.size();
	}
};

inline Bytes to_v1(const Bytes& d)
{
	Layout l = layout(d);
	Down dn(d);
	uint32_t esClk = rd32(d, 0xD0), zsgClk = rd32(d, 0x110), espClk = rd32(d, 0x114), tmsClk = rd32(d, 0x118);
	dn.es = esClk != 0;
	dn.zsg = zsgClk != 0;
	for (size_t o = 0x100; o < 0x110; o += 4)
		if (rd32(d, o)) fail("Namco WSG clock in the header: no v1 counterpart");
	if (espClk && (espClk & 0xBFFFFFFF) != 10000000) fail("ES5510 clock other than 10 MHz: no v1 counterpart");
	if (zsgClk && tmsClk != (((zsgClk & 0x3FFFFFFF) / 2) | (zsgClk & 0x40000000))) fail("TMS57002 clock other than ZSG-2 clock / 2: no v1 counterpart");
	if (!zsgClk && tmsClk) fail("TMS57002 without a ZSG-2: no v1 counterpart");
	for (size_t o = 0x11D; o < l.dataOfs && o < 0x120; o++)
		if (d[o]) fail("unknown header field set");
	if (d[0x11C])   // DRAM size: v1 sets it with 0xD8 06, before the ESP is created
	{
		dn.put({0xD8, 0x06, 0x00, d[0x11C]});
		if (espClk & 0x40000000) dn.put({0xD8, 0x86, 0x00, d[0x11C]});
	}
	std::map<size_t, size_t> ofsMap;
	dn.run(l.dataOfs, l.dataEnd, ofsMap);
	size_t hdr = dn.zsg ? 0x110 : 0x100;
	Bytes o = assemble(d, l, hdr, dn.out, ofsMap);
	if (dn.zsg) wr32(o, 0x100, zsgClk);
	return o;
}

} // namespace vgmv3
