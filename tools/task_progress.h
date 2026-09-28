#ifndef TASK_PROGRESS_H
#define TASK_PROGRESS_H

#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <string>
#include <unistd.h>

// Frame progress has a separate descriptor so callers can capture verdicts.
class TaskProgress {
  using Clock = std::chrono::steady_clock;
  FILE *stream = nullptr;
  bool terminal = false;
  Clock::time_point started = Clock::now(), previous = started;
  std::string label;
  int total;
public:
  TaskProgress(const std::string &name, int budget) : label(name), total(budget) {
    const char *mode = std::getenv("JGX_PROGRESS");
    if (mode && std::string(mode) == "0") return;
    const char *descriptor = std::getenv("JGX_PROGRESS_FD");
    int fd = descriptor ? std::atoi(descriptor) : STDERR_FILENO;
    if (!descriptor && !isatty(fd) && !(mode && std::string(mode) == "1")) return;
    int copy = dup(fd);
    if (copy < 0) return;
    stream = fdopen(copy, "w");
    if (!stream) { close(copy); return; }
    terminal = isatty(copy);
    update(0, "starting", true);
  }
  ~TaskProgress() { if (stream) fclose(stream); }
  void update(int done, const char *state = "running", bool force = false, bool finished = false) {
    if (!stream) return;
    auto now = Clock::now();
    auto interval = std::chrono::duration_cast<std::chrono::seconds>(now - previous).count();
    if (!force && interval < (terminal ? 2 : 30)) return;
    previous = now;
    auto elapsed = std::chrono::duration_cast<std::chrono::seconds>(now - started).count();
    if (finished) {
      fprintf(stream, "%sEMU %s || %d frames | %llds | %s\n",
              terminal ? "\r\033[K" : "", label.c_str(), done,
              static_cast<long long>(elapsed), state);
      fflush(stream);
      return;
    }
    int percent = total > 0 ? done * 100 / total : 100;
    if (percent > 100) percent = 100;
    int filled = percent / 5;
    std::string bar = std::string(filled, '#') + std::string(20-filled, '-');
    fprintf(stream, "%sEMU %s [%s] %d%% %d/%d frames | %llds | %s%s",
            terminal ? "\r\033[K" : "", label.c_str(), bar.c_str(), percent,
            done, total, static_cast<long long>(elapsed), state,
            terminal ? "" : "\n");
    fflush(stream);
  }
};
#endif
