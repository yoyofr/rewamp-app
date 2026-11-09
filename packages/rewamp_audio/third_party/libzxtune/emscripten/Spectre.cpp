/**
* Impl of ZxTune interface used by SpectreZX player
* code based on "foobar2000 plugin"
*
* Copyright (C) 2015 Juergen Wothke
*
* LICENSE
* 
* This library is free software; you can redistribute it and/or modify it
* under the terms of the GNU General Public License as published by
* the Free Software Foundation; either version 2.1 of the License, or (at
* your option) any later version. This library is distributed in the hope
* that it will be useful, but WITHOUT ANY WARRANTY; without even the implied
* warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
* GNU General Public License for more details.
* 
* You should have received a copy of the GNU General Public
* License along with this library; if not, write to the Free Software
* Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA
**/

//local includes
#define ZXTUNE_API ZXTUNE_API_EXPORT
#include "Spectre.h"
//common includes
#include <contract.h>
#include "cycle_buffer.h"
#include "error_tools.h"
#include "progress_callback.h"
//library includes
#include "binary/container.h"
#include "binary/container_factories.h"
#include "core/core_parameters.h"
#include "core/data_location.h"
#include "core/module_attrs.h"
#include "core/module_detect.h"
#include "core/module_open.h"
#include "core/module_holder.h"
#include "core/module_player.h"
#include "core/module_types.h"
#include "parameters/container.h"
#include "platform/version/api.h"
#include "sound/sound_parameters.h"
#include "sound/service.h"
#include "sound/render_params.h"

#include "core/plugins/enumerator.h"


//std includes
#include <map>
#include <iostream>
#include <string>
#include <stdexcept>

//boost includes
#include <boost/bind.hpp>
#include <boost/make_shared.hpp>
#include <boost/static_assert.hpp>
#include <boost/range/end.hpp>
#include <boost/type_traits/is_signed.hpp>


#include "player.h"

// -------------------- SongInfo -------------------

static const char *EMPTY= "";

class SongInfo::SongInfoImpl {
public:
	SongInfoImpl() {}
	virtual ~SongInfoImpl() {}

	void set_codec(std::string c)		{ _codec= c.empty() ? std::string(EMPTY) : c; }
	const char *get_codec()		 		{ return _codec.c_str(); }

	void set_author(std::string a) 		{ _author= a.empty() ? std::string(EMPTY) : a;  }
	const char *get_author()		 	{ return _author.c_str(); }

	void set_title(std::string t) 		{ _title= t.empty() ? std::string(EMPTY) : t; }
	const char *get_title()		 		{ return _title.c_str(); }

	void set_sub_path(std::string n)	{ _subPath= n.empty() ? std::string(EMPTY) : n; }
	const char *get_subpath()		 	{ return _subPath.c_str(); } // archive path to specific sub-song
	
	void set_comment(std::string c) 	{ _comment= c.empty() ? std::string(EMPTY) : c; }
	const char *get_comment()		 	{ return _comment.c_str(); }
	
	void set_program(std::string p) 	{ _program= p.empty() ? std::string(EMPTY) : p; }
	const char *get_program()			{ return _program.c_str(); }
	
	void set_track_number(int n) 		{ _track_number = std::to_string(n);}
	const char * get_track_number()		{ return _track_number.c_str(); }
	
	void set_total_tracks(int n) 		{ _total_tracks= std::to_string(n);}
	const char * get_total_tracks() 	{ return _total_tracks.c_str();;}
	
	void reset() {
		_codec = std::string(EMPTY);
		_author = std::string(EMPTY);
		_title = std::string(EMPTY);
		_subPath = std::string(EMPTY);
		_comment = std::string(EMPTY);
		_program = std::string(EMPTY);
		_track_number = std::string(EMPTY);
		_total_tracks = std::string(EMPTY);
	}
	
private:
	std::string _codec;
	std::string _author;
	std::string _title;
	std::string _subPath;
	std::string _comment;
	std::string _program;
	std::string _track_number;
	std::string _total_tracks;
};

SongInfo::SongInfo() : _pimpl(new SongInfoImpl()) {}
SongInfo::~SongInfo() 						{ delete _pimpl; _pimpl= 0; }
const char *SongInfo::get_codec()		 	{ return _pimpl->get_codec(); }
const char *SongInfo::get_author()		 	{ return _pimpl->get_author(); }
const char *SongInfo::get_title()		 	{ return _pimpl->get_title(); }
const char *SongInfo::get_subpath()			{ return _pimpl->get_subpath(); }
const char *SongInfo::get_comment()		 	{ return _pimpl->get_comment(); }
const char *SongInfo::get_program()		 	{ return _pimpl->get_program(); }
const char *SongInfo::get_track_number()	{ return _pimpl->get_track_number(); }
const char *SongInfo::get_total_tracks()	{ return _pimpl->get_total_tracks(); }
void SongInfo::reset()		 	{ _pimpl->reset(); }


//YOYOFR (rewamp): the generic track model, filled by every tracker-based player.
#include "core/plugins/players/tracking.h"

// -------------------- ZxTuneWrapper -------------------

class ZxTuneWrapper::ZxTuneWrapperImpl {
private:
	unsigned int _frameDurationMs;
	// REWAMP: vitesse de lecture. La duree de trame du RENDU (FRAMEDURATION)
	// devient nominale / vitesse: les trames du lecteur se rapprochent, les
	// puces gardent leur horloge (hauteur conservee). _frameDurationMs reste
	// la NOMINALE: position, duree et seek (trames x _frameDurationMs)
	// restent donc en temps du MORCEAU.
	long long _frameDurationUsNominal = 0;
public:
	ZxTuneWrapperImpl(std::string modulePath, const void* data, size_t size, int sampleRate) {
		_sampleRate = sampleRate;
		_moduleFilePath = modulePath; 
		_inputFile = createData(data, size);
	}
	
	virtual ~ZxTuneWrapperImpl() {
		close();
	}
	
	void close() {
		if(_inputFile)
		{
			_player.reset();
			_inputModules.clear();
			_moduleHolder.reset();
			_inputFile.reset();
		}
	}

	void parseModules() {
		struct ModuleDetector : public Module::DetectCallback
		{
			ModuleDetector(Modules* _mods) : modules(_mods) {}
			virtual void ProcessModule(ZXTune::DataLocation::Ptr location, ZXTune::Plugin::Ptr, Module::Holder::Ptr holder) const
			{
				ModuleDesc m;
				m.module = holder;
				m.subpath = location->GetPath()->AsString();
				modules->push_back(m);
			}
			virtual Log::ProgressCallback* GetProgress() const { return NULL; }
			virtual Parameters::Accessor::Ptr GetPluginsParameters() const { return Parameters::Container::Create(); }
			Modules* modules;
		};

		ModuleDetector md(&_inputModules);
		Module::Detect(ZXTune::CreateLocation(_inputFile), md);
		if(_inputModules.empty())
		{
			_inputFile.reset();
			throw  std::invalid_argument("io unsupported format");
		}
	}
    
    void setLoopMode(int loop) {
        // YOYOFR (rewamp): honorer l'ARGUMENT — l'original posait 1 quel que
        // soit `loop`, donc « couper la boucle » était impossible. Sous
        // LOOPED, le renderer zxtune reboucle au POINT DE BOUCLE du module
        // (pas au début): c'est ce qui rend le repeat-morceau d'un .ay
        // inaudible là où une relance à zéro s'entendait.
        Parameters::Container::Ptr params= _player->GetParameters();
        params->SetValue(Parameters::ZXTune::Sound::LOOPED, loop ? 1 : 0);
    }
		
	void decodeInitialize(unsigned int p_subsong, SongInfo & p_info) {
		std::string subpath = get_subpath(p_subsong, p_info);

		ZXTune::DataLocation::Ptr loc= ZXTune::OpenLocation(Parameters::Container::Create(), _inputFile, subpath);
		_moduleHolder = Module::Open(loc);
		if(!_moduleHolder)
			throw  std::invalid_argument("io unsupported format"); 

		Module::Information::Ptr mi = _moduleHolder->GetModuleInformation();
		if(!mi)
			throw  std::invalid_argument("io unsupported format"); 

		//YOYOFR (rewamp): the players publish their TrackModel while the renderer
		//is being built, so the collection has to be empty right before — and this
		//instance takes the result over right after. The collector is a
		//process-wide global; leaving the pattern view reading it later would let
		//any other open() (a playability probe, the next track) pull the models
		//out from under a song that is still playing.
		Module::RewampTrackModelsClear();
		_player = PlayerWrapper::Create(_moduleHolder, _sampleRate);
		_trackModels.clear();
		_modelDelegate.clear();
		for (std::size_t i = 0, n = Module::RewampTrackModelsCount(); i < n; ++i) {
			_trackModels.push_back(Module::RewampTrackModelAt(i));
			_modelDelegate.push_back((int)Module::RewampTrackModelDelegateAt(i));
		}
		//Delegates of a MultiTrackContainer, with their voice counts; a lone
		//module is one delegate owning every voice.
		_delegateHw.clear();
		for (std::size_t i = 0, n = Module::RewampDelegateCount(); i < n; ++i)
			_delegateHw.push_back((int)Module::RewampDelegateChannels(i));
		if (_delegateHw.empty())
			_delegateHw.push_back(_player->GetRenderer()->GetHWChannels());
		Module::RewampTrackModelsClear();
		const std::size_t models = _trackModels.size();
		_timeline.assign(models, std::vector<TimelineEntry>());
		_posStart.assign(models, std::vector<uint_t>());
		_loopTick.assign(models, 0);
		_totalTicks.assign(models, 0);
		_modelChans.clear();
		for (int m = 0; m < (int)models; ++m) {
			build_timeline(m);
			_modelChans.push_back(model_channels(m));
		}
		layout_models();
				
		if(!_player)
			throw  std::invalid_argument("io unsupported format"); 	

	   _player->GetRenderer()->SetPosition(0);

	   
		Parameters::Container::Ptr params= _player->GetParameters();
		const Sound::RenderParameters::Ptr sound = Sound::RenderParameters::Create(params);
		_frameDurationMs = sound->FrameDuration().Get() / 1000;	// API delivers micros NOT millis
		_frameDurationUsNominal = sound->FrameDuration().Get();
	}

	// REWAMP: vitesse de lecture (voir _frameDurationUsNominal).
	bool set_speed(double speed) {
		if (!_player || _frameDurationUsNominal <= 0 || !(speed > 0.0)) return false;
		long long us = (long long)((double)_frameDurationUsNominal / speed + 0.5);
		if (us < Parameters::ZXTune::Sound::FRAMEDURATION_MIN ||
		    us > Parameters::ZXTune::Sound::FRAMEDURATION_MAX) return false;
		Parameters::Container::Ptr params = _player->GetParameters();
		params->SetValue(Parameters::ZXTune::Sound::FRAMEDURATION, us);
		return true;
	}
	
	void get_song_info(unsigned int p_subsong, SongInfo & p_info)	{
		SongInfo::SongInfoImpl &info= *(p_info._pimpl);
	
		Module::Information::Ptr mi;
		Parameters::Accessor::Ptr props;
		std::string subpath;
		if(!_inputModules.empty())
		{
			if(p_subsong > _inputModules.size())
				throw  std::invalid_argument("io unsupported format");
			mi = _inputModules[p_subsong - 1].module->GetModuleInformation();
			props = _inputModules[p_subsong - 1].module->GetModuleProperties();
			if(!mi)
				throw  std::invalid_argument("io unsupported format");
			subpath = _inputModules[p_subsong - 1].subpath;
			
			info.set_sub_path(subpath);
		}
		else
		{
			subpath = get_subpath(p_subsong, p_info);
			Module::Holder::Ptr m = Module::Open(ZXTune::OpenLocation(Parameters::Container::Create(), _inputFile, subpath));
			if(!m)
				throw  std::invalid_argument("io unsupported format");
			mi = m->GetModuleInformation();
			props = m->GetModuleProperties();
			if(!mi)
				throw  std::invalid_argument("io unsupported format");
		}
		
		String type;
		info.set_codec(props->FindValue(Module::ATTR_TYPE, type) ? type : std::string("undefined"));
		
		String author;
		info.set_author(props->FindValue(Module::ATTR_AUTHOR, author) ? author : std::string("undefined"));

		String title;
		if(props->FindValue(Module::ATTR_TITLE, title) && !title.empty())
			info.set_title(title);
		else
			info.set_title(subpath);
		
		String comment;
		info.set_comment(props->FindValue(Module::ATTR_COMMENT, comment) ? comment : std::string("undefined"));

		String program;
		info.set_program(props->FindValue(Module::ATTR_PROGRAM, program) ? program : std::string("undefined"));
		
		if(_inputModules.size() > 1)
		{
			info.set_track_number(p_subsong);
			info.set_total_tracks(_inputModules.size());
		} else {
			info.set_track_number(0);
			info.set_total_tracks(1);
		}
	}

	int render_sound(void* buffer, size_t samples) {	
		try {
			return _player->RenderSound(reinterpret_cast<Sound::Sample*>(buffer), samples);
		}
		catch (const Error&) {
			return -1;
		}
		catch (const std::exception&) {
			return -1;
		}
	}
	
	int get_current_position() {
		return _player->GetRenderer()->GetTrackState()->Frame() * _frameDurationMs;
	}
	
	int get_max_position() {
		return _moduleHolder->GetModuleInformation()->FramesCount() * _frameDurationMs;
	}
    
    int get_channels_count() {
        return _player->GetRenderer()->GetHWChannels();;
    }

    //YOYOFR (rewamp) — pattern view.
    //
    //One model per chip: a plain module publishes one, a TurboSound pair two.
    //The models are INDEPENDENT — own order list, own patterns, own tempo — and
    //they do NOT have to agree: a real TurboSound text pair was measured with
    //128 rows at position 3 on one chip and 64 on the other, eight positions out
    //of twenty-one, both halves at speed 6. Their ROWS therefore never line up,
    //and one (position,row) cursor cannot name a line on both.
    //
    //What they DO share is time. Every line lasts `tempo` frames, so walking a
    //model once gives each of its lines an absolute start TICK; the grid is then
    //built on the FIRST chip's rows — the ones the cursor names, since the
    //TurboSound track state reports chip one (MergedTrackState) — and every
    //other chip contributes whatever it is PLAYING at that tick. The row number
    //shown is the first chip's; the notes are what is heard on all six voices.
    //Where the two halves do have the same shape the mapping is the identity, so
    //there is a single path for both cases.
    //
    //A chip that runs out first loops, exactly as it does in playback, hence the
    //fold back onto its loop position rather than a clamp.
    //
    //Patterns are keyed by ORDER POSITION rather than by a model's own pattern
    //number, because a position is what the cursor reports.
    struct TimelineEntry {
        uint_t tick;
        uint_t position;
        uint_t row;
    };

    int pattern_models() const {
        return (int)_trackModels.size();
    }

    Module::TrackModel::Ptr model_at(int idx) const {
        return (idx >= 0 && (std::size_t)idx < _trackModels.size())
            ? _trackModels[(std::size_t)idx] : Module::TrackModel::Ptr();
    }

    //One pass over a model: every line gets its absolute start tick. Per-line
    //tempo changes are honoured here, which is why the mapping stays exact when
    //one chip changes speed and the other does not.
    void build_timeline(int m) {
        std::vector<TimelineEntry>& tl = _timeline[m];
        tl.clear();
        _posStart[m].clear();
        _loopTick[m] = 0;
        _totalTicks[m] = 0;
        const Module::TrackModel::Ptr model = model_at(m);
        if (!model) return;
        const Module::OrderList& order = model->GetOrder();
        const uint_t positions = order.GetSize();
        const uint_t loopPos = order.GetLoopPosition();
        uint_t tempo = model->GetInitialTempo();
        if (!tempo) tempo = 1;
        uint_t tick = 0;
        for (uint_t p = 0; p < positions; ++p) {
            _posStart[m].push_back((uint_t)tl.size());
            if (p == loopPos) _loopTick[m] = tick;
            const Module::Pattern::Ptr pat = model->GetPatterns().Get(order.GetPatternIndex(p));
            const uint_t rows = pat ? pat->GetSize() : 0;
            for (uint_t r = 0; r < rows; ++r) {
                if (pat) {
                    const Module::Line::Ptr line = pat->GetLine(r);
                    if (line) if (const uint_t t = line->GetTempo()) tempo = t;
                }
                TimelineEntry e;
                e.tick = tick;
                e.position = p;
                e.row = r;
                tl.push_back(e);
                tick += tempo;
            }
        }
        _totalTicks[m] = tick;
    }

    //The first line of model `m` that STARTS inside [from, from+span). An event
    //must appear once, on the row where it fires — not repeated on every row it
    //happens to span, which would read as a re-trigger. When a chip runs faster
    //than the reference and several of its lines fall inside one row, the first
    //is the one shown.
    const TimelineEntry* first_line_in(int m, uint_t from, uint_t span) const {
        const std::vector<TimelineEntry>& tl = _timeline[m];
        if (tl.empty() || !span) return 0;
        if (from >= _totalTicks[m]) {
            const uint_t loop = _totalTicks[m] - _loopTick[m];
            from = loop ? _loopTick[m] + (from - _loopTick[m]) % loop : _loopTick[m];
        }
        std::size_t lo = 0, hi = tl.size();   //first entry with tick >= from
        while (lo < hi) {
            const std::size_t mid = (lo + hi) / 2;
            if (tl[mid].tick < from) lo = mid + 1; else hi = mid;
        }
        if (lo >= tl.size()) return 0;
        return tl[lo].tick < from + span ? &tl[lo] : 0;
    }

    //Line width of model `m`: what GetChannel() accepts on its lines. Read from
    //the first line the model has (a model's lines all share one width — the
    //players build them from one MultichannelMutableLine<N>, or TSLine for a
    //TurboSound pair). 0 when the model has no line at all.
    uint_t model_channels(int m) const {
        const Module::TrackModel::Ptr model = model_at(m);
        if (!model) return 0;
        const Module::PatternsSet& pats = model->GetPatterns();
        for (uint_t p = 0, np = pats.GetSize(); p < np; ++p) {
            const Module::Pattern::Ptr pat = pats.Get(p);
            if (!pat) continue;
            for (uint_t r = 0, nr = pat->GetSize(); r < nr; ++r)
                if (const Module::Line::Ptr line = pat->GetLine(r))
                    return line->GetChannelsCount();
        }
        return 0;
    }

    //Grid column of model `m`'s first channel, -1 when it has none (see
    //layout_models).
    int model_offset(int m) const {
        return (m >= 0 && (std::size_t)m < _modelOffset.size()) ? _modelOffset[(std::size_t)m] : -1;
    }

    //Columns are the hardware voices, in delegate order — the pattern view maps
    //columns onto voices (mute, colour, oscilloscope). A model sits on the
    //voices of the delegate that built it: first voice of that delegate, after
    //the models the same delegate built before (a TurboSound pair yields two
    //3-wide models on one 6-voice delegate). A delegate without a model (an AY
    //register dump, a TFM stream) keeps its columns EMPTY — until 2026-10-31
    //such a container had no grid at all (14 of the 31 zxart .mtc), and before
    //2026-10-18 `hw / models` stood for the per-model width and read past the
    //lines of a PT3+TFM (boost::array assertion, app killed). A model that
    //does not fit its delegate's voices disqualifies the whole grid.
    void layout_models() {
        _modelOffset.clear();
        std::vector<int> used(_delegateHw.size(), 0);
        for (std::size_t m = 0; m < _trackModels.size(); ++m) {
            const int d = m < _modelDelegate.size() ? _modelDelegate[m] : -1;
            const int width = m < _modelChans.size() ? (int)_modelChans[m] : 0;
            if (d < 0 || (std::size_t)d >= _delegateHw.size() || width <= 0) { _modelOffset.push_back(-1); continue; }
            int base = 0;
            for (int i = 0; i < d; ++i) base += _delegateHw[(std::size_t)i];
            const int off = base + used[(std::size_t)d];
            if (used[(std::size_t)d] + width > _delegateHw[(std::size_t)d]) { _modelOffset.push_back(-1); continue; }
            used[(std::size_t)d] += width;
            _modelOffset.push_back(off);
        }
    }

    int pattern_channels() {
        const int models = pattern_models();
        if (models <= 0 || !_player) return 0;
        const int hw = _player->GetRenderer()->GetHWChannels();
        if (hw <= 0) return 0;
        if (!pattern_orders()) return 0;
        for (int m = 0; m < models; ++m) {
            if (_timeline[(std::size_t)m].empty()) return 0;
            const int off = model_offset(m);
            if (off < 0 || off + (int)_modelChans[(std::size_t)m] > hw) return 0;
        }
        return hw;
    }

    //For the harness (verify_zxtune_voices): how the grid was laid out.
    int pattern_model_width(int m) const {
        return (m >= 0 && (std::size_t)m < _modelChans.size()) ? (int)_modelChans[(std::size_t)m] : 0;
    }
    int pattern_model_delegate(int m) const {
        return (m >= 0 && (std::size_t)m < _modelDelegate.size()) ? _modelDelegate[(std::size_t)m] : -1;
    }

    int pattern_orders() {
        const Module::TrackModel::Ptr m = model_at(0);
        return m ? (int)m->GetOrder().GetSize() : 0;
    }

    int pattern_order(int idx) {
        const int n = pattern_orders();
        return (idx >= 0 && idx < n) ? idx : -1;   // keyed by position
    }

    int pattern_rows(int pattern) {
        return pattern_rows_of(0, pattern);
    }

    int pattern_cells(int pattern, ZxPatternCell *out, int maxCells) {
        const int chans = pattern_channels();
        const int models = pattern_models();
        if (!out || chans <= 0 || models <= 0) return 0;
        const int rows = pattern_rows_of(0, pattern);
        if (rows <= 0) return 0;
        int cells = rows * chans;
        if (cells > maxCells) cells = maxCells - (maxCells % chans);
        if (cells <= 0) return 0;
        const int usableRows = cells / chans;
        if ((std::size_t)pattern >= _posStart[0].size()) return 0;
        const uint_t base = _posStart[0][(std::size_t)pattern];

        for (int i = 0; i < cells; ++i) {
            out[i].note = out[i].sample = out[i].ornament = -1;
            out[i].volume = -1;
            out[i].enabled = -1;
            out[i].lineTempo = -1;
            out[i].numCmd = 0;
        }
        for (int r = 0; r < usableRows; ++r) {
            const std::size_t idx = base + (std::size_t)r;
            if (idx >= _timeline[0].size()) break;
            const uint_t tick = _timeline[0][idx].tick;
            const uint_t next = idx + 1 < _timeline[0].size()
                ? _timeline[0][idx + 1].tick : _totalTicks[0];
            const uint_t span = next > tick ? next - tick : 1;
            for (int mi = 0; mi < models; ++mi) {
                //Chip one is read straight from the requested position; the
                //others contribute the line they START during it.
                const TimelineEntry *e = mi == 0 ? &_timeline[0][idx]
                                                 : first_line_in(mi, tick, span);
                if (!e) continue;
                const Module::Pattern::Ptr pat = pattern_object(mi, (int)e->position);
                if (!pat) continue;
                const Module::Line::Ptr line = pat->GetLine(e->row);
                if (!line) continue;
                //Bounded by THIS line's width, never by a share of the voices:
                //GetChannel past it is an out-of-range boost::array read.
                const int off = model_offset(mi);
                int width = (int)_modelChans[(std::size_t)mi];
                if ((int)line->GetChannelsCount() < width) width = (int)line->GetChannelsCount();
                if (off + width > chans) width = chans - off;
                if (const uint_t tempo = line->GetTempo())
                    for (int c = 0; c < width; ++c)
                        out[(size_t)r * chans + off + c].lineTempo = (int)tempo;
                for (int c = 0; c < width; ++c) {
                    const Module::Cell::Ptr cell = line->GetChannel((uint_t)c);
                    if (!cell) continue;
                    ZxPatternCell &dst = out[(size_t)r * chans + off + c];
                    if (const uint_t *v = cell->GetNote())     dst.note = (int)*v;
                    if (const uint_t *v = cell->GetSample())   dst.sample = (int)*v;
                    if (const uint_t *v = cell->GetOrnament()) dst.ornament = (int)*v;
                    if (const uint_t *v = cell->GetVolume())   dst.volume = (int)*v;
                    if (const bool *v = cell->GetEnabled())    dst.enabled = *v ? 1 : 0;
                    for (Module::CommandsIterator it = cell->GetCommands();
                         it && dst.numCmd < 4; ++it) {
                        dst.cmdType[dst.numCmd] = (int)it->Type;
                        dst.cmdP1[dst.numCmd] = it->Param1;
                        dst.cmdP2[dst.numCmd] = it->Param2;
                        dst.cmdP3[dst.numCmd] = it->Param3;
                        dst.numCmd++;
                    }
                }
            }
        }
        return cells;
    }

    void pattern_cursor(int *order, int *row) {
        if (order) *order = -1;
        if (row) *row = -1;
        if (!_player) return;
        const Module::TrackState::Ptr st = _player->GetRenderer()->GetTrackState();
        if (!st) return;
        if (order) *order = (int)st->Position();
        if (row) *row = (int)st->Line();
    }
  private:
    Module::Pattern::Ptr pattern_object(int model, int position) const {
        const Module::TrackModel::Ptr m = model_at(model);
        if (!m || position < 0) return Module::Pattern::Ptr();
        const Module::OrderList &ord = m->GetOrder();
        if ((uint_t)position >= ord.GetSize()) return Module::Pattern::Ptr();
        return m->GetPatterns().Get(ord.GetPatternIndex((uint_t)position));
    }

    int pattern_rows_of(int model, int position) const {
        const Module::Pattern::Ptr p = pattern_object(model, position);
        return p ? (int)p->GetSize() : 0;
    }
  public:
    
    const char *get_channel_name(int chan) {
        return _player->GetRenderer()->GetHWChannelName(chan);
    }
    
    const char *get_system_name() {
        return _player->GetRenderer()->GetHWSystemName();
    }
	
	void seek_position(int ms) {
	   _player->GetRenderer()->SetPosition(ms/_frameDurationMs);
	}
	
	int getSampleRate() {
		return _sampleRate;
	}
    
    char *get_all_extension() {
        std::cout<<"Player plugins\n";
        const ZXTune::PlayerPluginsEnumerator::Ptr usedPlugins = ZXTune::PlayerPluginsEnumerator::Create();
        for (ZXTune::PlayerPlugin::Iterator::Ptr iter = usedPlugins->Enumerate(); iter->IsValid(); iter->Next())
        {
          const ZXTune::PlayerPlugin::Ptr plugin = iter->Get();
            std::cout<<plugin->GetDescription()->Id()<<",";
//          if (DataLocation::Ptr result = plugin->Open(coreParams, location, subPath))
//          {
//            return result;
//          }
        }
        std::cout<<"\nArchive plugins\n";
        const ZXTune::ArchivePluginsEnumerator::Ptr usedAPlugins = ZXTune::ArchivePluginsEnumerator::Create();
        for (ZXTune::ArchivePlugin::Iterator::Ptr iter = usedAPlugins->Enumerate(); iter->IsValid(); iter->Next())
        {
          const ZXTune::ArchivePlugin::Ptr plugin = iter->Get();
            std::cout<<plugin->GetDescription()->Description()<<"\n";
//          if (DataLocation::Ptr result = plugin->Open(coreParams, location, subPath))
//          {
//            return result;
//          }
        }
        return NULL;
    }
protected:
	std::string get_subpath(unsigned int p_subsong, SongInfo & p_info) {
		const char* subpath = p_info.get_subpath();
		if(subpath && strlen(subpath))
			return std::string(subpath);
		return std::string();
	}
	
	Binary::Container::Ptr createData(const void* data, size_t size) {
		try	{
			Binary::Container::Ptr result = Binary::CreateContainer(data, size);	// use my existing "aligned" buffer
			return result;
		} catch (const std::exception& e) {
			std::cerr << "ERROR in createData() "<< e.what()<<std::endl;		
			return Binary::Container::Ptr();
		}
	}
	
private:
	int 					_sampleRate;
	std::string				_moduleFilePath;
	Binary::Container::Ptr	_inputFile;

	struct ModuleDesc
	{
		Module::Holder::Ptr module;
		std::string subpath;
	};
	typedef std::vector<ModuleDesc> Modules;
	Modules					_inputModules;
	Module::Holder::Ptr		_moduleHolder;
	PlayerWrapper::Ptr		_player;
	//YOYOFR (rewamp): the track models this instance owns, one per chip, and the
	//tick timeline of each — see the pattern view above.
	std::vector<Module::TrackModel::Ptr> _trackModels;
	std::vector<uint_t> _modelChans;   //line width of each model (see model_channels)
	std::vector<int>    _modelDelegate; //delegate that built each model (0 for a lone module)
	std::vector<int>    _modelOffset;   //grid column of each model, -1 = none (layout_models)
	std::vector<int>    _delegateHw;    //hardware voices of each delegate, in order
	std::vector<std::vector<TimelineEntry> > _timeline;
	std::vector<std::vector<uint_t> >        _posStart;
	std::vector<uint_t>                      _loopTick;
	std::vector<uint_t>                      _totalTicks;
};

ZxTuneWrapper::ZxTuneWrapper(std::string p, const void* data, size_t size, int sampleRate) : _pimpl(new ZxTuneWrapper::ZxTuneWrapperImpl(p, data, size, sampleRate)) {
}

ZxTuneWrapper::~ZxTuneWrapper() { 
	delete _pimpl; _pimpl = 0;
}

void ZxTuneWrapper::parseModules() {
	_pimpl->parseModules();
}

void ZxTuneWrapper::setLoopMode(int loop) {
    _pimpl->setLoopMode(loop);
}


void ZxTuneWrapper::decodeInitialize(unsigned int p_subsong, SongInfo & p_info) {
	_pimpl->decodeInitialize(p_subsong, p_info);
}

void ZxTuneWrapper::get_song_info(unsigned int p_subsong, SongInfo & p_info) {
	_pimpl->get_song_info(p_subsong, p_info);
}

int ZxTuneWrapper::render_sound(void* buffer, size_t samples) {
	return _pimpl->render_sound(buffer, samples);
}

int ZxTuneWrapper::get_current_position() {
	return _pimpl->get_current_position();
}

void ZxTuneWrapper::seek_position(int ms) {
	return _pimpl->seek_position(ms);
}

bool ZxTuneWrapper::set_speed(double speed) {
	return _pimpl->set_speed(speed);
}

int ZxTuneWrapper::get_max_position() {
	return _pimpl->get_max_position();
}

int ZxTuneWrapper::getSampleRate() {
	return _pimpl->getSampleRate();
}

int ZxTuneWrapper::get_channels_count() {
    return _pimpl->get_channels_count();
}

//YOYOFR (rewamp)
int  ZxTuneWrapper::pattern_channels()            { return _pimpl->pattern_channels(); }
int  ZxTuneWrapper::pattern_orders()              { return _pimpl->pattern_orders(); }
int  ZxTuneWrapper::pattern_order(int idx)        { return _pimpl->pattern_order(idx); }
int  ZxTuneWrapper::pattern_rows(int pattern)     { return _pimpl->pattern_rows(pattern); }
int  ZxTuneWrapper::pattern_model_count()        { return _pimpl->pattern_models(); }
int  ZxTuneWrapper::pattern_model_width(int m)   { return _pimpl->pattern_model_width(m); }
int  ZxTuneWrapper::pattern_model_offset(int m)  { return _pimpl->model_offset(m); }
int  ZxTuneWrapper::pattern_model_delegate(int m){ return _pimpl->pattern_model_delegate(m); }
int  ZxTuneWrapper::pattern_cells(int pattern, ZxPatternCell *out, int maxCells) {
    return _pimpl->pattern_cells(pattern, out, maxCells);
}
void ZxTuneWrapper::pattern_cursor(int *order, int *row) { _pimpl->pattern_cursor(order, row); }

const char *ZxTuneWrapper::get_channel_name(int chan) {
    return _pimpl->get_channel_name(chan);
}

const char *ZxTuneWrapper::get_system_name() {
    return _pimpl->get_system_name();
}


char *ZxTuneWrapper::get_all_extension() {
    return _pimpl->get_all_extension();
}
