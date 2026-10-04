/* Traceur de plantage pour Windows — REWAMP_CRASH_TRACE=1.
 *
 * Pourquoi: un plantage dans un pilote graphique (nvwgf2umx.dll, appelé par
 * ANGLE) ne dit rien de QUI l'a provoqué, et la machine de dev n'a pas de
 * débogueur en ligne de commande. Ce gestionnaire imprime sur stderr, au
 * premier plantage fatal, la pile complète: module + décalage, et le symbole
 * quand un .pdb est à côté de la DLL (le nôtre, celui d'ANGLE). C'est la
 * frontière entre le pilote et nous qui dit quel appel GL l'a fâché.
 *
 * Gestionnaire VECTORISÉ: il passe avant ceux du CRT et de Flutter. Il ne
 * TRAITE rien (EXCEPTION_CONTINUE_SEARCH) — il regarde passer et laisse le
 * processus mourir comme avant. Ne réagit qu'aux codes fatals, et seulement
 * une fois: les violations d'accès « normales » d'un runtime JIT ne passent
 * pas par un module que nous connaissons, voir le filtre plus bas. */
#include <windows.h>
#include <dbghelp.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#pragma comment(lib, "dbghelp.lib")

static volatile LONG g_fired = 0;

static void module_of(DWORD64 addr, char* name, size_t cap, DWORD64* base) {
    HMODULE m = NULL;
    *base = 0;
    strcpy_s(name, cap, "?");
    if (GetModuleHandleExA(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS |
                           GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
                           (LPCSTR)(uintptr_t)addr, &m) && m) {
        char path[MAX_PATH];
        if (GetModuleFileNameA(m, path, MAX_PATH)) {
            const char* s = strrchr(path, '\\');
            strcpy_s(name, cap, s ? s + 1 : path);
        }
        *base = (DWORD64)(uintptr_t)m;
    }
}

/* Faut-il parler ? Seulement si l'exception tombe dans un module de la chaîne
 * graphique ou dans les nôtres: un runtime (la VM Dart) peut provoquer et
 * traiter lui-même des violations d'accès ailleurs. */
static int interesting(const char* mod) {
    static const char* k[] = { "rewamp", "libGLESv2", "libEGL", "nvwgf2", "nvd3d",
                               "d3d11", "dxgi", "atidxx", "igd10", "igd11", NULL };
    for (int i = 0; k[i]; i++) if (_strnicmp(mod, k[i], strlen(k[i])) == 0) return 1;
    return 0;
}

static LONG CALLBACK on_exception(PEXCEPTION_POINTERS ep) {
    const DWORD code = ep->ExceptionRecord->ExceptionCode;
    if (code != EXCEPTION_ACCESS_VIOLATION && code != EXCEPTION_STACK_OVERFLOW &&
        code != EXCEPTION_ILLEGAL_INSTRUCTION && code != EXCEPTION_INT_DIVIDE_BY_ZERO &&
        code != 0xC0000374 /* STATUS_HEAP_CORRUPTION */)
        return EXCEPTION_CONTINUE_SEARCH;

    char mod[MAX_PATH]; DWORD64 base;
    const DWORD64 at = (DWORD64)(uintptr_t)ep->ExceptionRecord->ExceptionAddress;
    module_of(at, mod, sizeof mod, &base);
    if (!interesting(mod)) return EXCEPTION_CONTINUE_SEARCH;
    if (InterlockedExchange(&g_fired, 1)) return EXCEPTION_CONTINUE_SEARCH;

    HANDLE proc = GetCurrentProcess(), thr = GetCurrentThread();
    fprintf(stderr, "\n[rewamp_crash] exception 0x%08lX dans %s+0x%llx (fil %lu)\n",
            code, mod, (unsigned long long)(at - base), GetCurrentThreadId());
    if (code == EXCEPTION_ACCESS_VIOLATION && ep->ExceptionRecord->NumberParameters >= 2)
        fprintf(stderr, "[rewamp_crash] %s à l'adresse 0x%llx\n",
                ep->ExceptionRecord->ExceptionInformation[0] ? "écriture" : "lecture",
                (unsigned long long)ep->ExceptionRecord->ExceptionInformation[1]);

    SymSetOptions(SYMOPT_UNDNAME | SYMOPT_DEFERRED_LOADS | SYMOPT_LOAD_LINES);
    SymInitialize(proc, NULL, TRUE);   /* chemin = dossiers des modules: les .pdb voisins */

    CONTEXT ctx = *ep->ContextRecord;
    STACKFRAME64 f; memset(&f, 0, sizeof f);
    f.AddrPC.Offset = ctx.Rip;    f.AddrPC.Mode = AddrModeFlat;
    f.AddrFrame.Offset = ctx.Rbp; f.AddrFrame.Mode = AddrModeFlat;
    f.AddrStack.Offset = ctx.Rsp; f.AddrStack.Mode = AddrModeFlat;

    char buf[sizeof(SYMBOL_INFO) + 512];
    for (int i = 0; i < 48; i++) {
        if (!StackWalk64(IMAGE_FILE_MACHINE_AMD64, proc, thr, &f, &ctx, NULL,
                         SymFunctionTableAccess64, SymGetModuleBase64, NULL)) break;
        const DWORD64 pc = f.AddrPC.Offset;
        if (!pc) break;
        module_of(pc, mod, sizeof mod, &base);
        SYMBOL_INFO* s = (SYMBOL_INFO*)buf;
        memset(buf, 0, sizeof buf);
        s->SizeOfStruct = sizeof(SYMBOL_INFO); s->MaxNameLen = 511;
        DWORD64 disp = 0;
        IMAGEHLP_LINE64 line; DWORD ldisp = 0;
        memset(&line, 0, sizeof line); line.SizeOfStruct = sizeof line;
        if (SymFromAddr(proc, pc, &disp, s)) {
            if (SymGetLineFromAddr64(proc, pc, &ldisp, &line))
                fprintf(stderr, "  #%02d %s!%s+0x%llx  (%s:%lu)\n", i, mod, s->Name,
                        (unsigned long long)disp, line.FileName, line.LineNumber);
            else
                fprintf(stderr, "  #%02d %s!%s+0x%llx\n", i, mod, s->Name, (unsigned long long)disp);
        } else {
            fprintf(stderr, "  #%02d %s+0x%llx\n", i, mod, (unsigned long long)(pc - base));
        }
    }
    fflush(stderr);
    return EXCEPTION_CONTINUE_SEARCH;
}

void rewamp_win_crash_trace_install(void) {
    static int done = 0;
    const char* v = getenv("REWAMP_CRASH_TRACE");
    if (done || !v || v[0] != '1') return;
    done = 1;
    AddVectoredExceptionHandler(1, on_exception);
    fprintf(stderr, "[rewamp_crash] traceur de plantage armé (REWAMP_CRASH_TRACE=1)\n");
}
