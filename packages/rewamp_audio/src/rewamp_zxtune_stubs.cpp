// libzxtune link stubs.
//
// Flutter force-loads plugin static libraries (-force_load), so every object in
// the zxtune archive is pulled into the final binary whether reached or not.
// That drags in three subsystems we never use for in-memory chiptune playback —
// boost::filesystem (real-file IO providers), libcurl (network IO provider) and
// the AYM stream dumpers (used only for format CONVERSION/export) — whose
// definitions Modizer's own build leaves undefined and relies on dead-stripping
// to drop. We can't dead-strip (force_load), so we provide minimal definitions
// here, compiled against the real boost 1.57 headers so the signatures match.
// None of these paths run during playback (zx_open feeds the decoder an in-memory
// buffer), so the stubs only need to satisfy the linker.
#ifdef REWAMP_WITH_ZXTUNE

#include <boost/filesystem/path.hpp>
#include <boost/filesystem/operations.hpp>

#include "devices/aym/dumper.h"
#include "io/providers/gates/curl_api.h"

// --- boost::filesystem (normally in libs/filesystem/src, not vendored) ---------
namespace boost { namespace filesystem {

path  path::root_path()      const { return path(); }
path  path::root_directory() const { return path(); }
path  path::parent_path()    const { return path(); }
path  path::filename()       const { return path(); }
path  path::stem()           const { return path(); }
path  path::extension()      const { return path(); }
int   path::compare(const path& p) const BOOST_NOEXCEPT { return m_pathname.compare(p.m_pathname); }
path& path::operator/=(const path& p) { m_pathname += p.m_pathname; return *this; }
path& path::remove_filename() { return *this; }

path::iterator path::begin() const { return iterator(); }
path::iterator path::end()   const { return iterator(); }
void path::m_path_iterator_increment(path::iterator& it) { (void)it; }

namespace detail {
file_status      status(const path& p, system::error_code* ec)         { (void)p; if (ec) ec->clear(); return file_status(); }
bool             create_directory(const path& p, system::error_code* ec){ (void)p; if (ec) ec->clear(); return false; }
boost::uintmax_t file_size(const path& p, system::error_code* ec)      { (void)p; if (ec) ec->clear(); return 0; }
}

}}

// --- AYM stream dumpers (devices/aym/dumper/*.cpp — conversion only) -----------
namespace Devices { namespace AYM {
Dumper::Ptr CreatePSGDumper(DumperParameters::Ptr)        { return Dumper::Ptr(); }
Dumper::Ptr CreateZX50Dumper(DumperParameters::Ptr)       { return Dumper::Ptr(); }
Dumper::Ptr CreateDebugDumper(DumperParameters::Ptr)      { return Dumper::Ptr(); }
Dumper::Ptr CreateRawStreamDumper(DumperParameters::Ptr)  { return Dumper::Ptr(); }
Dumper::Ptr CreateFYMDumper(FYMDumperParameters::Ptr)     { return Dumper::Ptr(); }
}}

// --- libcurl dynamic API (network IO provider) --------------------------------
namespace IO { namespace Curl {
Api::Ptr LoadDynamicApi() { return Api::Ptr(); }
}}

#endif /* REWAMP_WITH_ZXTUNE */
