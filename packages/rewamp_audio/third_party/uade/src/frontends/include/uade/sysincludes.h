/* rewamp: sous Windows, htonl/ntohl viennent de <winsock2.h> (lié par ws2_32)
 * et il n'y a pas de select() — voir unixatomic.c. WIN32_LEAN_AND_MEAN est
 * posé par le force-include (src/windows/compat/rewamp_uade_msvc.h), donc
 * l'ordre windows.h/winsock2.h ne compte plus. */
#ifdef _WIN32
#include <winsock2.h>
#else
#include <netinet/in.h>
#include <sys/select.h>
#endif
