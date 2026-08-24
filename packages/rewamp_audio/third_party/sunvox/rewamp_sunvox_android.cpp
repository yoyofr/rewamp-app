/* Android glue stand-in for the headless SunVox build.
 *
 * SunDog's real Android layer (lib_sundog/main/android/sundog_bridge.cpp) is a
 * full NativeActivity host: JNI lifecycle, EGL surface, camera, MIDI, clipboard.
 * It does not build with NOGUI/NOVIDEO — its `engine` struct holds EGLDisplay /
 * EGLSurface / EGLContext members whose headers only arrive through the GUI
 * path — and rewamp wants none of it: the plugin feeds SunVox from memory
 * (`sv_load_from_memory`) and pulls PCM back out, with no window, no activity
 * and no Java side.
 *
 * Once NOMAIN removes the android_sundog_* API from sundog_bridge.h, all the
 * compiled SunDog TUs still need from that file is this handful of path
 * globals. file.cpp's sfs_get_work_path / conf_path / temp_path return "" when
 * they are null, which is the right answer here: nothing on the headless path
 * touches the filesystem.
 *
 * The header is included on purpose rather than re-declaring the globals, so a
 * type change upstream fails here loudly instead of silently mismatching.
 */
#include "lib_sundog/main/android/sundog_bridge.h"

char* g_android_cache_int_path        = NULL;
char* g_android_cache_ext_path        = NULL;
char* g_android_files_int_path        = NULL;
char* g_android_files_ext_path        = NULL;
char* g_android_version               = NULL;
char  g_android_version_correct[ 16 ] = { 0 };
int   g_android_version_nums[ 8 ]     = { 0 };
char* g_android_lang                  = NULL;
char* g_android_requested_permissions = NULL;
