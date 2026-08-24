#include "Shader.hpp"

#include <glm/gtc/type_ptr.hpp>

#include <iostream>
#include <sstream>
#include <iomanip>
#include <regex>
#include <optional>

//YOYOFR
#include <pthread.h>
#include <time.h>
#include <unistd.h>
#include <atomic>
#if !defined(_WIN32)
#include <EGL/egl.h>   // eglGetProcAddress — KHR_parallel_shader_compile lookup
#endif
// rewamp: was mach_port_t + pthread_mach_thread_np (Apple-only) — pthread_t +
// pthread_equal is the portable spelling of the same identity check, so this
// background-precompile guard also builds on Android.
extern pthread_t mdzMainThreadId;
extern volatile bool mdzRenderInProgress;

//YOYOFR/rewamp: preset-load profiling. Every Milkdrop shader (warp, comp, blur,
// motion vectors, custom shapes/waves) funnels through CompileProgram, so
// accumulating here captures the WHOLE GL half of a preset load. The renderer
// (rewamp_projectm_render.cpp) owns the globals, resets them before
// projectm_load_preset_file and logs the split after. Caveat, also logged
// there: GLES drivers may defer real compilation to link or even first draw,
// so read these together with the first-frame time.
extern "C" {
extern long long mdzGlCompileNs;
extern long long mdzGlLinkNs;
extern int       mdzGlProgramCount;
}
static long long mdzNowNs() {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (long long)ts.tv_sec * 1000000000LL + ts.tv_nsec;
}

namespace libprojectM {
namespace Renderer {

// ── rewamp: KHR_parallel_shader_compile on the preload worker ────────────────
// ANGLE serializes every context of a share group on ONE lock, so a blocking
// compile/link on the preload worker (Metal library builds, 30-100 ms each)
// stalls the render thread's frames for the whole call. With
// KHR_parallel_shader_compile the expensive work runs on ANGLE's own thread
// pool OUTSIDE that lock: glCompileShader/glLinkProgram return immediately and
// we POLL GL_COMPLETION_STATUS_KHR (a short locked call) instead of issuing
// the blocking status query. Worker thread only — the render thread's own
// compiles (transition shaders at init, sync fallback) keep the direct path.
#ifndef GL_COMPLETION_STATUS_KHR
#define GL_COMPLETION_STATUS_KHR 0x91B1
#endif
typedef void (*mdzMaxShaderCompilerThreadsFn)(GLuint);

static mdzMaxShaderCompilerThreadsFn mdzParallelCompileFn()
{
#if defined(_WIN32)
    return nullptr;    // no EGL there (yet) — sync path, as before this patch
#else
    static std::atomic<intptr_t> cached{-1};   // -1 unresolved, 0 unsupported
    intptr_t v = cached.load(std::memory_order_relaxed);
    if (v == -1) {
        v = (intptr_t)eglGetProcAddress("glMaxShaderCompilerThreadsKHR");
        cached.store(v, std::memory_order_relaxed);
    }
    return (mdzMaxShaderCompilerThreadsFn)v;
#endif
}

// Enables the pool for THIS thread's context once; false = ext unavailable.
static bool mdzParallelCompileEnable()
{
    auto fn = mdzParallelCompileFn();
    if (!fn) return false;
    static thread_local bool armed = false;
    if (!armed) { fn(4); armed = true; }
    return true;
}

// Short non-blocking polls until the object finishes compiling/linking on
// ANGLE's pool. Bounded: a driver that never flips the bit (or predates the
// ext despite exporting it) falls through to the caller's blocking query.
static void mdzPollCompletion(GLuint object, bool isProgram)
{
    for (int i = 0; i < 5000; ++i) {          // ≤ ~5 s, typical exit ≪ 200 ms
        GLint done = GL_FALSE;
        if (isProgram) glGetProgramiv(object, GL_COMPLETION_STATUS_KHR, &done);
        else           glGetShaderiv (object, GL_COMPLETION_STATUS_KHR, &done);
        if (done == GL_TRUE || glGetError() != GL_NO_ERROR) return;
        usleep(1000);
    }
}

Shader::Shader()
    : m_shaderProgram(glCreateProgram())
{
}

Shader::~Shader()
{
    if (m_shaderProgram)
    {
        glDeleteProgram(m_shaderProgram);
    }
}

void Shader::CompileProgram(const std::string& vertexShaderSource,
                            const std::string& fragmentShaderSource,
                            uint32_t shaderP)
{
    if (!shaderP) {
        //YOYOFR
        bool mainThread = pthread_equal(pthread_self(), mdzMainThreadId) != 0;
        
        if (!mainThread) {
            //wait for a new frame to be rendered to start
//            while (!mdzRenderInProgress) {
//                usleep(1000);
//            }
            //wait for frame to be finished
            while (mdzRenderInProgress) {
                usleep(1000);
            }
        }
        
#ifdef REWAMP_PM_PROFILE
        long long t0 = mdzNowNs();
#endif
        auto vertexShader = CompileShader(vertexShaderSource, GL_VERTEX_SHADER);
        
        auto fragmentShader = CompileShader(fragmentShaderSource, GL_FRAGMENT_SHADER);
        
#ifdef REWAMP_PM_PROFILE
        long long t1 = mdzNowNs();
#endif
        glAttachShader(m_shaderProgram, vertexShader);
        glAttachShader(m_shaderProgram, fragmentShader);
        glLinkProgram(m_shaderProgram);
#ifdef REWAMP_PM_PROFILE
        // Profiling only: force the link to complete NOW so its cost is
        // attributed here instead of smearing into the first draw.
        // glGetProgramiv is a SYNC POINT — which is exactly why this is not
        // compiled in by default.
        {
            GLint linked = GL_FALSE;
            glGetProgramiv(m_shaderProgram, GL_LINK_STATUS, &linked);
            (void)linked;
        }
        long long t2 = mdzNowNs();
        mdzGlCompileNs += t1 - t0;
        mdzGlLinkNs    += t2 - t1;
        mdzGlProgramCount++;
#endif
        
        //if precompiling (not main thread)
        //do not check linkage status to let the // thread work
        if (!mainThread) {
            // POLL FIRST, DETACH AFTER — the order is the whole point.
            //
            // glDetachShader OBSERVES the program: in ANGLE,
            // Program::detachShader calls resolveLink(), which blocks on the
            // link job PLUS every Metal shader-library subtask (30-100 ms
            // each). Doing it before the poll — as this code used to — meant
            // the worker blocked inside ANGLE's share-group lock and stalled
            // the render thread's frames, exactly the stall
            // KHR_parallel_shader_compile was added here to avoid, while
            // mdzPollCompletion below found the link already resolved and
            // returned instantly. The extension was enabled and its benefit
            // thrown away two lines later.
            //
            // Polling to completion here (rather than deferring to activation
            // as upstream does) is deliberate: we warm-draw each program on
            // this worker right after, and a pending link would resolve inside
            // that first locked draw call — same stall, later.
            if (mdzParallelCompileEnable()) mdzPollCompletion(m_shaderProgram, true);
            // Link settled: these are now cheap.
            glDetachShader(m_shaderProgram, vertexShader);
            glDetachShader(m_shaderProgram, fragmentShader);
            glDeleteShader(vertexShader);
            glDeleteShader(fragmentShader);
            return;
        }

        // Render thread: the link is resolved by the status query below
        // anyway, so detaching first costs nothing.
        // Shader objects are no longer needed after linking, free the memory.
        glDetachShader(m_shaderProgram, vertexShader);
        glDetachShader(m_shaderProgram, fragmentShader);
        glDeleteShader(vertexShader);
        glDeleteShader(fragmentShader);

        GLint programLinked;
        glGetProgramiv(m_shaderProgram, GL_LINK_STATUS, &programLinked);
        if (programLinked == GL_TRUE)
        {
            return;
        }
        
        GLint infoLogLength{};
        glGetProgramiv(m_shaderProgram, GL_INFO_LOG_LENGTH, &infoLogLength);
        std::vector<char> message(infoLogLength + 1);
        glGetProgramInfoLog(m_shaderProgram, infoLogLength, nullptr, message.data());
        
        throw ShaderException("Error compiling shader: " + std::string(message.data()));
    } else {
        if (m_shaderProgram) glDeleteProgram(m_shaderProgram);
        m_shaderProgram=shaderP;
        
        //YOYOFR: check linkage status at last step
        GLint programLinked;
        glGetProgramiv(m_shaderProgram, GL_LINK_STATUS, &programLinked);
        if (programLinked == GL_TRUE)
        {
            //std::cout<<"Program linkage ok"<<std::endl;
            return;
        }
        
        GLint infoLogLength{};
        glGetProgramiv(m_shaderProgram, GL_INFO_LOG_LENGTH, &infoLogLength);
        std::vector<char> message(infoLogLength + 1);
        glGetProgramInfoLog(m_shaderProgram, infoLogLength, nullptr, message.data());
        
        std::cout<<"Error in program linkage: "<<std::string(message.data())<<std::endl;
        
        throw ShaderException("Error compiling shader: " + std::string(message.data()));
    }
}

bool Shader::Validate(std::string& validationMessage) const
{
    GLint result{GL_FALSE};
    int infoLogLength;

    glValidateProgram(m_shaderProgram);

    glGetProgramiv(m_shaderProgram, GL_VALIDATE_STATUS, &result);
    glGetProgramiv(m_shaderProgram, GL_INFO_LOG_LENGTH, &infoLogLength);
    if (infoLogLength > 0)
    {
        std::vector<char> validationErrorMessage(infoLogLength + 1);
        glGetProgramInfoLog(m_shaderProgram, infoLogLength, nullptr, validationErrorMessage.data());
        validationMessage = std::string(validationErrorMessage.data());
    }

    return result;
}

void Shader::Bind() const
{
    if (m_shaderProgram > 0)
    {
        glUseProgram(m_shaderProgram);
    }
}

void Shader::Unbind()
{
    glUseProgram(0);
}

void Shader::   SetUniformFloat(const char* uniform, float value) const
{
    auto location = glGetUniformLocation(m_shaderProgram, uniform);
    if (location < 0)
    {
        return;
    }
    glUniform1fv(location, 1, &value);
}

void Shader::SetUniformInt(const char* uniform, int value) const
{
    auto location = glGetUniformLocation(m_shaderProgram, uniform);
    if (location < 0)
    {
        return;
    }
    glUniform1iv(location, 1, &value);
}

void Shader::SetUniformFloat2(const char* uniform, const glm::vec2& values) const
{
    auto location = glGetUniformLocation(m_shaderProgram, uniform);
    if (location < 0)
    {
        return;
    }
    glUniform2fv(location, 1, glm::value_ptr(values));
}

void Shader::SetUniformInt2(const char* uniform, const glm::ivec2& values) const
{
    auto location = glGetUniformLocation(m_shaderProgram, uniform);
    if (location < 0)
    {
        return;
    }
    glUniform2iv(location, 1, glm::value_ptr(values));
}

void Shader::SetUniformFloat3(const char* uniform, const glm::vec3& values) const
{
    auto location = glGetUniformLocation(m_shaderProgram, uniform);
    if (location < 0)
    {
        return;
    }
    glUniform3fv(location, 1, glm::value_ptr(values));
}

void Shader::SetUniformInt3(const char* uniform, const glm::ivec3& values) const
{
    auto location = glGetUniformLocation(m_shaderProgram, uniform);
    if (location < 0)
    {
        return;
    }
    glUniform3iv(location, 1, glm::value_ptr(values));
}

void Shader::SetUniformFloat4(const char* uniform, const glm::vec4& values) const
{
    auto location = glGetUniformLocation(m_shaderProgram, uniform);
    if (location < 0)
    {
        return;
    }
    glUniform4fv(location, 1, glm::value_ptr(values));
}

void Shader::SetUniformInt4(const char* uniform, const glm::ivec4& values) const
{
    auto location = glGetUniformLocation(m_shaderProgram, uniform);
    if (location < 0)
    {
        return;
    }
    glUniform4iv(location, 1, glm::value_ptr(values));
}

void Shader::SetUniformMat3x4(const char* uniform, const glm::mat3x4& values) const
{
    auto location = glGetUniformLocation(m_shaderProgram, uniform);
    if (location < 0)
    {
        return;
    }
    glUniformMatrix3x4fv(location, 1, GL_FALSE, glm::value_ptr(values));
}

void Shader::SetUniformMat4x4(const char* uniform, const glm::mat4x4& values) const
{
    auto location = glGetUniformLocation(m_shaderProgram, uniform);
    if (location < 0)
    {
        return;
    }
    glUniformMatrix4fv(location, 1, GL_FALSE, glm::value_ptr(values));
}

// Structure to store a compilation error
struct ShaderError {
    int lineNumber;
    std::string message;
    
    ShaderError(int line, const std::string& msg)
        : lineNumber(line), message(msg) {}
};

// Extracts the line number from a GLSL error line
std::optional<int> extractLineNumber(const std::string& errorLine) {
    // Method 1: With regex (more robust)
    // Patterns: "0:NUMBER", "0(NUMBER)", or just ":NUMBER"
    std::regex patterns[] = {
        std::regex(R"(0[:\(](\d+))"),      // 0:5 or 0(5)
        std::regex(R"(:(\d+)[:\(])"),       // :5: or :5(
        std::regex(R"(\((\d+)\))"),         // (5)
    };
    
    for (const auto& pattern : patterns) {
        std::smatch match;
        if (std::regex_search(errorLine, match, pattern)) {
            return std::stoi(match[1].str());
        }
    }
    
    return std::nullopt;
}

// Alternative version without regex (faster)
std::optional<int> extractLineNumberFast(const std::string& errorLine) {
    // Look for "0:" or "0("
    size_t pos = errorLine.find("0:");
    if (pos == std::string::npos) {
        pos = errorLine.find("0(");
    }
    
    if (pos != std::string::npos) {
        pos += 2; // Skip "0:" or "0("
        if (pos < errorLine.length() && std::isdigit(errorLine[pos])) {
            return std::stoi(errorLine.substr(pos));
        }
    }
    
    // Fallback: look for ":NUMBER"
    pos = errorLine.find(':');
    while (pos != std::string::npos && pos + 1 < errorLine.length()) {
        if (std::isdigit(errorLine[pos + 1])) {
            return std::stoi(errorLine.substr(pos + 1));
        }
        pos = errorLine.find(':', pos + 1);
    }
    
    return std::nullopt;
}

// Parses the complete error log
std::vector<ShaderError> parseShaderErrors(const std::string& log) {
    std::vector<ShaderError> errors;
    std::istringstream iss(log);
    std::string line;
    
    while (std::getline(iss, line)) {
        // Check if line contains "error" (case insensitive)
        std::string lowerLine = line;
        std::transform(lowerLine.begin(), lowerLine.end(), lowerLine.begin(), ::tolower);
        
        if (lowerLine.find("error") != std::string::npos) {
            if (auto lineNum = extractLineNumber(line)) {
                errors.emplace_back(*lineNum, line);
            }
        }
    }
    
    return errors;
}

// Splits source code into lines
std::vector<std::string> splitIntoLines(const std::string& source) {
    std::vector<std::string> lines;
    std::istringstream iss(source);
    std::string line;
    
    while (std::getline(iss, line)) {
        lines.push_back(line);
    }
    
    return lines;
}

// Displays a line with context
std::string printLineWithContext(const std::string& source, int lineNumber, int contextLines = 2) {
    auto lines = splitIntoLines(source);
    std::string result;
    
    for (size_t i = 0; i < lines.size(); i++) {
        int currentLine = static_cast<int>(i + 1);
        int distance = std::abs(currentLine - lineNumber);
        
        if (distance <= contextLines) {
            if (currentLine == lineNumber) {
                result+=">>> "+std::to_string(currentLine)+ " | "+ lines[i] + "  <-- ERROR HERE\n";
            } else {
                result+= "    " +std::to_string(currentLine)+" | "+lines[i]+"\n";
            }
        }
    }
    return result;
}

    
// Usage example
std::string Shader::addLineNumbers(const std::string& text, int width) {
    std::istringstream iss(text);
    std::ostringstream oss;
    std::string line;
    int lineNum = 1;
    
    while (std::getline(iss, line)) {
        oss << std::setw(width) << std::right << lineNum << " | " << line << "\n";
        lineNum++;
    }
    
    return oss.str();
}

GLuint Shader::CompileShader(const std::string& source, GLenum type)
{
    GLint shaderCompiled{};

    auto shader = glCreateShader(type);
    const auto* shaderSourceCStr = source.c_str();
    glShaderSource(shader, 1, &shaderSourceCStr, nullptr);

    glCompileShader(shader);

    // Worker thread: let ANGLE's pool do the translation off-lock, polling
    // instead of blocking (see the helpers above). Render thread: unchanged.
    if (pthread_equal(pthread_self(), mdzMainThreadId) == 0 &&
        mdzParallelCompileEnable()) {
        mdzPollCompletion(shader, false);
    }

    glGetShaderiv(shader, GL_COMPILE_STATUS, &shaderCompiled);
    if (shaderCompiled == GL_TRUE)
    {
        return shader;
    }

    GLint infoLogLength{};
    glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &infoLogLength);
    std::vector<char> message(infoLogLength + 1);
    glGetShaderInfoLog(shader, infoLogLength, nullptr, message.data());
    glDeleteShader(shader);
    
    std::string logStr;
    
    logStr+="Shader compilation error:\n";
    // Parse errors
    auto errors = parseShaderErrors(message.data());
    
    logStr+=std::to_string(errors.size())+" error(s) detected:\n";
    
    for (size_t i = 0; i < errors.size(); i++) {
        logStr+="Error #"+std::to_string(i + 1);
        logStr+=" - Line "+std::to_string(errors[i].lineNumber)+":";
        logStr+="  "+errors[i].message+"\n";
        
        logStr+=printLineWithContext(source, errors[i].lineNumber, 1);
    }
    std::string error_message=message.data()+std::string("\n")+logStr;
    
    printf("%s\n",error_message.c_str());
    

    throw ShaderException("Error compiling shader: " + std::string(error_message));
}

auto Shader::GetShaderLanguageVersion() -> Shader::GlslVersion
{
    const char* shaderLanguageVersion = reinterpret_cast<const char*>(glGetString(GL_SHADING_LANGUAGE_VERSION));

    if (shaderLanguageVersion == nullptr)
    {
        return {};
    }

    std::string shaderLanguageVersionString(shaderLanguageVersion);

    // Some OpenGL implementations add non-standard-conforming text in front, e.g. WebGL, which returns "OpenGL ES GLSL ES 3.00 ..."
    // Find the first digit and start there.
    auto firstDigit = shaderLanguageVersionString.find_first_of("0123456789");
    if (firstDigit != std::string::npos && firstDigit != 0)
    {
        shaderLanguageVersionString = shaderLanguageVersionString.substr(firstDigit);
    }

    // Cut off the vendor-specific information, if any
    auto spacePos = shaderLanguageVersionString.find(' ');
    if (spacePos != std::string::npos)
    {
        shaderLanguageVersionString.resize(spacePos);
    }

    auto dotPos = shaderLanguageVersionString.find('.');
    if (dotPos == std::string::npos)
    {
        return {};
    }

    int versionMajor = std::stoi(shaderLanguageVersionString.substr(0, dotPos));
    int versionMinor = std::stoi(shaderLanguageVersionString.substr(dotPos + 1));

    return {versionMajor, versionMinor};
}

} // namespace Renderer
} // namespace libprojectM
