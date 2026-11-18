/* Disposable test process: no Wayland, input devices, or key emission. */
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/signalfd.h>
static void record(int event) {
    const char *path = getenv("SENOMY_OSK_STUB_RECORD");
    if (!path) return;
    FILE *stream = fopen(path,"a");
    if (stream) { fprintf(stream,"%ld %d\n",(long)getpid(),event); fclose(stream); }
}
int main(void) {
    sigset_t mask; sigemptyset(&mask); sigaddset(&mask,SIGUSR1); sigaddset(&mask,SIGUSR2);
    if (sigprocmask(SIG_BLOCK,&mask,NULL)) return 1;
    record(0);
    int fd = signalfd(-1,&mask,SFD_CLOEXEC);
    if (fd < 0) return 1;
    for (;;) { struct signalfd_siginfo event; if (read(fd,&event,sizeof(event)) != sizeof(event)) return 1; record(event.ssi_signo); }
}
