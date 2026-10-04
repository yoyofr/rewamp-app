/*
    Copyright 2016-2026 melonDS team

    This file is part of melonDS.

    melonDS is free software: you can redistribute it and/or modify it under
    the terms of the GNU General Public License as published by the Free
    Software Foundation, either version 3 of the License, or (at your option)
    any later version.

    melonDS is distributed in the hope that it will be useful, but WITHOUT ANY
    WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
    FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

    You should have received a copy of the GNU General Public License along
    with melonDS. If not, see http://www.gnu.org/licenses/.
*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include <string>

/* YOYOFR (rewamp): Windows n'a pas de pthread. Cette couche-ci ne demande que
 * des primitives que la bibliothèque standard C++ fournit depuis C++11, donc on
 * la réimplémente ici plutôt que de poser un faux <pthread.h> — un shim aurait
 * eu à émuler `pthread_cond_timedwait` et sa notion de temps ABSOLU, ce qui est
 * précisément l'endroit où l'amont a un bug (voir Semaphore_TryWait).
 * Le chemin POSIX n'est pas touché. */
#ifdef _WIN32
#include <thread>
#include <mutex>
#include <condition_variable>
#include <chrono>
#else
#include <pthread.h>
#endif

#include <vio2sf/Platform.h>
#include <vio2sf/SPI_Firmware.h>

#ifdef __WIN32__
#include <io.h>
#define fdopen _fdopen
#define fseek _fseeki64
#define ftell _ftelli64
#define dup _dup
#endif // __WIN32__

namespace melonDS::Platform
{

void SignalStop(StopReason reason, void* userdata)
{
}


constexpr char AccessMode(FileMode mode, bool file_exists)
{
    if (mode & FileMode::Append)
        return  'a';

    if (!(mode & FileMode::Write))
        // If we're only opening the file for reading...
        return 'r';

    if (mode & (FileMode::NoCreate))
        // If we're not allowed to create a new file...
        return 'r'; // Open in "r+" mode (IsExtended will add the "+")

    if ((mode & FileMode::Preserve) && file_exists)
        // If we're not allowed to overwrite a file that already exists...
        return 'r'; // Open in "r+" mode (IsExtended will add the "+")

    return 'w';
}

constexpr bool IsExtended(FileMode mode)
{
    // fopen's "+" flag always opens the file for read/write
    return (mode & FileMode::ReadWrite) == FileMode::ReadWrite;
}

static std::string GetModeString(FileMode mode, bool file_exists)
{
    std::string modeString;

    modeString += AccessMode(mode, file_exists);

    if (IsExtended(mode))
        modeString += '+';

    if (!(mode & FileMode::Text))
        modeString += 'b';

    return modeString;
}

FileHandle* OpenFile(const std::string& path, FileMode mode)
{
	return nullptr;
}

std::string GetLocalFilePath(const std::string& filename)
{
	return "";
}

FileHandle* OpenLocalFile(const std::string& path, FileMode mode)
{
    return OpenFile(GetLocalFilePath(path), mode);
}

bool CloseFile(FileHandle* file)
{
    return false;
}

bool IsEndOfFile(FileHandle* file)
{
    return true;
}

bool FileReadLine(char* str, int count, FileHandle* file)
{
    return false;
}

bool FileExists(const std::string& name)
{
	return false;
}

bool LocalFileExists(const std::string& name)
{
    return false;
}

bool CheckFileWritable(const std::string& filepath)
{
	return false;
}

bool CheckLocalFileWritable(const std::string& name)
{
    return false;
}

bool FileSeek(FileHandle* file, s64 offset, FileSeekOrigin origin)
{
    return false;
}

void FileRewind(FileHandle* file)
{
}

u64 FilePosition(FileHandle* file)
{
    return 0;
}

u64 FileRead(void* data, u64 size, u64 count, FileHandle* file)
{
    return 0;
}

bool FileFlush(FileHandle* file)
{
    return false;
}

u64 FileWrite(const void* data, u64 size, u64 count, FileHandle* file)
{
    return 0;
}

u64 FileWriteFormatted(FileHandle* file, const char* fmt, ...)
{
    return 0;
}

u64 FileLength(FileHandle* file)
{
    return 0;
}

void Log(LogLevel level, const char* fmt, ...)
{
#ifdef DEBUG
	if (fmt == nullptr)
		return;

	va_list args;
	va_start(args, fmt);
	vprintf(fmt, args);
	va_end(args);
#endif
}

#ifdef _WIN32

// ── Portage Windows de la couche threads/sync/horloge ────────────────────────
// Correspondance stricte avec la version POSIX ci-dessous, y compris ses
// particularités. Les deux qui comptent:
//
//  * `Thread_Free` ET `Thread_Wait` JOIGNENT tous les deux, et l'amont appelle
//    parfois les deux. Sur POSIX un second `pthread_join` est un comportement
//    indéfini qui passe inaperçu; `std::thread::join` LÈVE. On teste donc
//    `joinable()`, ce qui rend le second appel inoffensif au lieu de le rendre
//    fatal.
//  * `Semaphore_TryWait` passait à `pthread_cond_timedwait` un timespec
//    RELATIF, alors que cette fonction attend une date ABSOLUE: amont demandait
//    donc en réalité « expire immédiatement » (une date de 1970). On implémente
//    l'INTENTION — un délai relatif — ce qui est ce que le nom et l'argument
//    `timeout_ms` décrivent.

namespace {

struct WinThread { std::thread t; };

struct WinSem {
    std::mutex              lock;
    std::condition_variable bump;
    unsigned                count = 0;
};

} // namespace

Thread* Thread_Create(std::function<void()> func)
{
    WinThread* th = new WinThread;
    try {
        th->t = std::thread(std::move(func));
    } catch (...) {
        delete th;
        return nullptr;
    }
    return (Thread*) th;
}

void Thread_Free(Thread* thread)
{
    WinThread* th = (WinThread*) thread;
    if (!th) return;
    if (th->t.joinable()) th->t.join();
    delete th;
}

void Thread_Wait(Thread* thread)
{
    WinThread* th = (WinThread*) thread;
    if (th && th->t.joinable()) th->t.join();
}

Semaphore* Semaphore_Create()
{
    return (Semaphore*) new WinSem;
}

void Semaphore_Free(Semaphore* sema)
{
    delete (WinSem*) sema;
}

void Semaphore_Reset(Semaphore* sema)
{
    WinSem* sem = (WinSem*) sema;
    std::lock_guard<std::mutex> g(sem->lock);
    sem->count = 0;
}

void Semaphore_Wait(Semaphore* sema)
{
    WinSem* sem = (WinSem*) sema;
    std::unique_lock<std::mutex> g(sem->lock);
    // `wait` avec prédicat: il absorbe les réveils intempestifs, que la version
    // POSIX laissait passer (elle ne décrémente alors simplement pas).
    sem->bump.wait(g, [sem] { return sem->count > 0; });
    sem->count--;
}

bool Semaphore_TryWait(Semaphore* sema, int timeout_ms)
{
    WinSem* sem = (WinSem*) sema;
    std::unique_lock<std::mutex> g(sem->lock);
    if (sem->count == 0) {
        if (timeout_ms <= 0) return false;
        if (!sem->bump.wait_for(g, std::chrono::milliseconds(timeout_ms),
                                [sem] { return sem->count > 0; }))
            return false;
    }
    sem->count--;
    return true;
}

void Semaphore_Post(Semaphore* sema, int count)
{
    WinSem* sem = (WinSem*) sema;
    {
        std::lock_guard<std::mutex> g(sem->lock);
        sem->count += (unsigned) count;
    }
    // ⚠️ `notify_all` et non `notify_one`: `count` peut monter de PLUSIEURS
    // d'un coup, et un seul réveil laisserait les autres jetons inexploités.
    // La version POSIX ne signale qu'une fois — c'est son troisième écart, et
    // le seul qu'on corrige franchement.
    sem->bump.notify_all();
}

Mutex* Mutex_Create()
{
    return (Mutex*) new std::mutex;
}

void Mutex_Free(Mutex* mutex)
{
    delete (std::mutex*) mutex;
}

void Mutex_Lock(Mutex* mutex)
{
    ((std::mutex*) mutex)->lock();
}

void Mutex_Unlock(Mutex* mutex)
{
    ((std::mutex*) mutex)->unlock();
}

bool Mutex_TryLock(Mutex* mutex)
{
    return ((std::mutex*) mutex)->try_lock();
}

void Sleep(u64 usecs)
{
    std::this_thread::sleep_for(std::chrono::microseconds(usecs));
}

u64 GetMSCount()
{
    using namespace std::chrono;
    return (u64) duration_cast<milliseconds>(
        steady_clock::now().time_since_epoch()).count();
}

u64 GetUSCount()
{
    using namespace std::chrono;
    return (u64) duration_cast<microseconds>(
        steady_clock::now().time_since_epoch()).count();
}

#else   // !_WIN32

Thread* Thread_Create(std::function<void()> func)
{
	pthread_t t;
	// Allocate the function on the heap so it can be passed through void*
	std::function<void()>* heapFunc = new std::function<void()>(std::move(func));
	int rc = pthread_create(&t, NULL, [](void* arg) -> void* {
		std::function<void()>* func = (std::function<void()>*) arg;
		(*func)();
		delete func;
		return nullptr;
	}, heapFunc);
	if (rc != 0) {
		delete heapFunc;
		return nullptr;
	}
	return (Thread*) t;
}

void Thread_Free(Thread* thread)
{
	pthread_t t = (pthread_t) thread;
	pthread_join(t, NULL);
}

void Thread_Wait(Thread* thread)
{
	pthread_join((pthread_t)thread, NULL);
}

typedef struct
{
	pthread_mutex_t count_lock;
	pthread_cond_t  count_bump;
	unsigned count;
}
bosal_sem_t;

Semaphore* Semaphore_Create()
{
	bosal_sem_t* sem = new bosal_sem_t;
	int rc = pthread_mutex_init(&sem->count_lock, NULL);
	if (rc != 0) {
		delete sem;
		return nullptr;
	}
	rc = pthread_cond_init(&sem->count_bump, NULL);
	if (rc != 0) {
		pthread_mutex_destroy(&sem->count_lock);
		delete sem;
		return nullptr;
	}
	sem->count = 0;
	return (Semaphore*)sem;
}

void Semaphore_Free(Semaphore* sema)
{
	bosal_sem_t* sem = (bosal_sem_t*) sema;
	pthread_mutex_destroy(&sem->count_lock);
	pthread_cond_destroy(&sem->count_bump);
    delete sem;
}

void Semaphore_Reset(Semaphore* sema)
{
	bosal_sem_t* sem = (bosal_sem_t*) sema;
	pthread_mutex_lock(&sem->count_lock);
	sem->count = 0;
	pthread_mutex_unlock(&sem->count_lock);
}

void Semaphore_Wait(Semaphore* sema)
{
	bosal_sem_t* sem = (bosal_sem_t*) sema;
	int xresult;
	int result = pthread_mutex_lock(&sem->count_lock);
	if (result)
		return;
	xresult = 0;
	if (sem->count == 0) {
		xresult = pthread_cond_wait(&sem->count_bump, &sem->count_lock);
	}
	if (!xresult) {
		if (sem->count > 0)
			sem->count--;
	}
	pthread_mutex_unlock(&sem->count_lock);
}

bool Semaphore_TryWait(Semaphore* sema, int timeout_ms)
{
	bosal_sem_t* sem = (bosal_sem_t*) sema;
	struct timespec timeout = { timeout_ms / 1000, (timeout_ms % 1000) * 1000000 };
	int result, xresult;
	
	result = pthread_mutex_lock(&sem->count_lock);
	if (result)
		return false;

	xresult = 0;

	if (sem->count == 0) {
		if (!timeout_ms)
			xresult = EAGAIN;
		else
			xresult = pthread_cond_timedwait(&sem->count_bump, &sem->count_lock, &timeout);
	}

	if (!xresult) {
		if (sem->count > 0)
			sem->count--;
	}

	pthread_mutex_unlock(&sem->count_lock);

	return !xresult;
}

void Semaphore_Post(Semaphore* sema, int count)
{
	bosal_sem_t* sem = (bosal_sem_t*) sema;
	int result;

	result = pthread_mutex_lock(&sem->count_lock);
	if (result)
		return;

	sem->count += count;

	pthread_cond_signal(&sem->count_bump);

	pthread_mutex_unlock(&sem->count_lock);
}

Mutex* Mutex_Create()
{
	pthread_mutex_t *m = new pthread_mutex_t;
	int rc = pthread_mutex_init(m, NULL);
	if (rc) {
		delete m;
		return nullptr;
	}
    return (Mutex*)m;
}

void Mutex_Free(Mutex* mutex)
{
	pthread_mutex_t *m = (pthread_mutex_t*) mutex;
	pthread_mutex_destroy(m);
	delete m;
}

void Mutex_Lock(Mutex* mutex)
{
	pthread_mutex_lock((pthread_mutex_t*)mutex);
}

void Mutex_Unlock(Mutex* mutex)
{
	pthread_mutex_unlock((pthread_mutex_t*)mutex);
}

bool Mutex_TryLock(Mutex* mutex)
{
	return !pthread_mutex_trylock((pthread_mutex_t*)mutex);
}

void Sleep(u64 usecs)
{
	usleep(usecs);
}

u64 GetMSCount()
{
	struct timespec tp;
	clock_gettime(CLOCK_MONOTONIC, &tp);
	return tp.tv_sec * 1000 + tp.tv_nsec / 1000000ULL;
}

u64 GetUSCount()
{
	struct timespec tp;
	clock_gettime(CLOCK_MONOTONIC, &tp);
    return tp.tv_sec * 1000000ULL + tp.tv_nsec / 1000;
}


#endif  // _WIN32

void WriteNDSSave(const u8* savedata, u32 savelen, u32 writeoffset, u32 writelen, void* userdata)
{
}

void WriteGBASave(const u8* savedata, u32 savelen, u32 writeoffset, u32 writelen, void* userdata)
{
}

void WriteFirmware(const Firmware& firmware, u32 writeoffset, u32 writelen, void* userdata)
{
}

void WriteDateTime(int year, int month, int day, int hour, int minute, int second, void* userdata)
{
}


void MP_Begin(void* userdata)
{
}

void MP_End(void* userdata)
{
}

int MP_SendPacket(u8* data, int len, u64 timestamp, void* userdata)
{
	return -1;
}

int MP_RecvPacket(u8* data, u64* timestamp, void* userdata)
{
	return -1;
}

int MP_SendCmd(u8* data, int len, u64 timestamp, void* userdata)
{
	return -1;
}

int MP_SendReply(u8* data, int len, u64 timestamp, u16 aid, void* userdata)
{
	return -1;
}

int MP_SendAck(u8* data, int len, u64 timestamp, void* userdata)
{
	return -1;
}

int MP_RecvHostPacket(u8* data, u64* timestamp, void* userdata)
{
	return -1;
}

u16 MP_RecvReplies(u8* data, u64 timestamp, u16 aidmask, void* userdata)
{
	return -1;
}


int Net_SendPacket(u8* data, int len, void* userdata)
{
	return 0;
}

int Net_RecvPacket(u8* data, void* userdata)
{
	return 0;
}


void Mic_Start(void* userdata)
{
}

void Mic_Stop(void* userdata)
{
}

int Mic_ReadInput(s16* data, int maxlength, void* userdata)
{
	memset(data, 0, maxlength * sizeof(s16));
	return maxlength;   // rewamp: upstream omits the return (-Werror,-Wreturn-type)
}


void Camera_Start(int num, void* userdata)
{
}

void Camera_Stop(int num, void* userdata)
{
}

void Camera_CaptureFrame(int num, u32* frame, int width, int height, bool yuv, void* userdata)
{
}

bool Addon_KeyDown(KeyType type, void* userdata)
{
	return false;
}

void Addon_RumbleStart(u32 len, void* userdata)
{
}

void Addon_RumbleStop(void* userdata)
{
}

float Addon_MotionQuery(MotionQueryType type, void* userdata)
{
	return 0;
}

DynamicLibrary* DynamicLibrary_Load(const char* lib)
{
	return nullptr;
}

void DynamicLibrary_Unload(DynamicLibrary* lib)
{
}

void* DynamicLibrary_LoadFunction(DynamicLibrary* lib, const char* name)
{
	return nullptr;
}

}
