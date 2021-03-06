bzcat $1 | \
    sed  -e 's/JS Sour~ Thread/Sour Thread/g' \
    -e 's/Proxy R~olution/Proxy Rolution/g' \
    -e 's/DNS Res~ver #10/DNS Resver #10/g' \
    -e 's/DNS Res~ver #11/DNS Resver #11/g' \
    > .tmp_corr.$2

#--- page fault transformation starts here ---#
cat .tmp_corr.$2 | grep '^1|' | \
    awk -F'|' -v read='116' -v write='117' -v str='' '{$5==0?str=read","$4","$6 : str=write","$4","$6} {print str}' >> .tmp.$2
#--- page fault transformation ends here ---#

#--- nw bytes transformation starts here ---#
cat .tmp_corr.$2 | grep '^13|' | \
    awk -F'|' -v nw_recv='118' -v str='' '{str=nw_recv","$4","$5} {print str}' >> .tmp.$2

cat .tmp_corr.$2 | grep '^14|' | \
    awk -F'|' -v nw_sent='119' -v str='' '{str=nw_sent","$4","$5} {print str}' >> .tmp.$2
#--- nw bytes transformation ends here ---#

#--- sockets transformation starts here ---#
cat .tmp_corr.$2 | grep '^6|' | \
    awk -F'|' -v sock_create='120' -v str='' '{str=sock_create","$4","$5} {print str}' >> .tmp.$2

cat .tmp_corr.$2 | grep '^7|' | \
    awk -F'|' -v sock_close='121' -v str='' '{str=sock_close","$4","$5} {print str}' >> .tmp.$2
#--- nw bytes transformation ends here ---#

#--- thread transformation starts here ---#
cat .tmp_corr.$2 | grep '^3|' | \
    awk -F'|' -v thread='122' -v str='' '{str=thread","$4",1"} {print str}' >> .tmp.$2
#--- thread transformation ends here ---#

#--- context switch transformation starts here ---#
cat .tmp_corr.$2 | grep '^2|' | \
    awk -F'|' -v context='123' -v str='' '{str=context","$4","$7} {print str}' >> .tmp.$2
#--- context switch transformation ends here ---#

#--- async write transformation starts here ---#
cat .tmp_corr.$2 | grep '^5|' | \
    awk -F'|' -v async_wr='124' -v str='' '{str=async_wr","$4","$6} {print str}' >> .tmp.$2
#--- async write transformation ends here ---#

#--- system call transformation starts here ---#
cat .tmp_corr.$2 | grep '^12|' | \
    sed -e s/accept/1/g \
    -e s/access/2/g \
    -e s/arch_prctl/3/g \
    -e s/bind/4/g \
    -e s/brk/5/g \
    -e s/chmod/6/g \
    -e s/clock_getres/7/g \
    -e s/clone/8/g \
    -e s/close/9/g \
    -e s/connect/10/g \
    -e s/dup/11/g \
    -e s/dup2/12/g \
    -e s/epoll_create/13/g \
    -e s/epoll_ctl/14/g \
    -e s/epoll_wait/15/g \
    -e s/eventfd2/16/g \
    -e s/execve/17/g \
    -e s/exit/18/g \
    -e s/exit_group/19/g \
    -e s/faccessat/20/g \
    -e s/fadvise64/21/g \
    -e s/fadvise64_64/22/g \
    -e s/fchmodat/23/g \
    -e s/fchown/24/g \
    -e s/fcntl/25/g \
    -e s/fork/26/g \
    -e s/fstat/27/g \
    -e s/fstatfs/28/g \
    -e s/fsync/29/g \
    -e s/ftruncate/30/g \
    -e s/futex/31/g \
    -e s/getcwd/32/g \
    -e s/getdents/33/g \
    -e s/getegid/34/g \
    -e s/geteuid/35/g \
    -e s/getgid/36/g \
    -e s/getpeername/37/g \
    -e s/getpid/38/g \
    -e s/getppid/39/g \
    -e s/getresgid/40/g \
    -e s/getresuid/41/g \
    -e s/getrlimit/42/g \
    -e s/getrusage/43/g \
    -e s/getsockname/44/g \
    -e s/getsockopt/45/g \
    -e s/gettid/46/g \
    -e s/getuid/47/g \
    -e s/inotify_add_watch/48/g \
    -e s/inotify_init1/49/g \
    -e s/ioctl/50/g \
    -e s/kill/51/g \
    -e s/listen/52/g \
    -e s/lseek/53/g \
    -e s/lstat/54/g \
    -e s/madvise/55/g \
    -e s/mkdir/56/g \
    -e s/mkdirat/57/g \
    -e s/mmap2/58/g \
    -e s/mprotect/59/g \
    -e s/munmap/60/g \
    -e s/nanosleep/61/g \
    -e s/open/62/g \
    -e s/openat/63/g \
    -e s/pipe/64/g \
    -e s/pipe2/65/g \
    -e s/poll/66/g \
    -e s/prctl/67/g \
    -e s/pwrite/68/g \
    -e s/quotactl/69/g \
    -e s/read/70/g \
    -e s/readahead/71/g \
    -e s/readlink/72/g \
    -e s/readlinkat/73/g \
    -e s/recvfrom/74/g \
    -e s/recvmsg/75/g \
    -e s/rename/76/g \
    -e s/renameat/77/g \
    -e s/rmdir/78/g \
    -e s/rt_sigaction/79/g \
    -e s/rt_sigprocmask/80/g \
    -e s/rt_sigreturn/81/g \
    -e s/sched_get_priority_max/82/g \
    -e s/sched_get_priority_min/83/g \
    -e s/sched_getaffinity/84/g \
    -e s/sched_getparam/85/g \
    -e s/sched_getscheduler/86/g \
    -e s/sched_setscheduler/87/g \
    -e s/sched_yield/88/g \
    -e s/select/89/g \
    -e s/semop/90/g \
    -e s/semtimedop/91/g \
    -e s/sendmsg/92/g \
    -e s/sendto/93/g \
    -e s/set_tid_address/94/g \
    -e s/setsockopt/95/g \
    -e s/shmat/96/g \
    -e s/shmctl/97/g \
    -e s/shmdt/98/g \
    -e s/shmget/99/g \
    -e s/shutdown/100/g \
    -e s/socket/101/g \
    -e s/socketpair/102/g \
    -e s/stat/103/g \
    -e s/statfs/104/g \
    -e s/symlink/105/g \
    -e s/symlinkat/106/g \
    -e s/sysinfo/107/g \
    -e s/truncate/108/g \
    -e s/umask/109/g \
    -e s/uname/110/g \
    -e s/unlink/111/g \
    -e s/utime/112/g \
    -e s/wait4/113/g \
    -e s/write/114/g \
    -e s/writev/115/g \
    -e 's/[^0-9|]*//g'\
    -e 's/|/,/g' \
    -e 's/,,/,-1,/g' \
    -e 's/,$//' | \
    awk -F, '{print $5","$4","$6}' \
    >> .tmp.$2
#--- system call transformation ends here ---#
rm .tmp_corr.$2
