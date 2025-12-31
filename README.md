# bazzite
Scripts for Bazzite Linux installation

-qnap-nas-mounter.sh
Handles mounting, unmounting, and verifying QNAP TS-230 NAS to increase performance in Bazzite. Makes NAS connection more closely resemble Windows.

Uses the following CIFS mount options: uid=1000,gid=1000,noacl,noperm,soft,_netdev,serverino,iocharset=utf8
* uid=1000,gid=1000  Maps all mounted files to  local user/group. Avoids repeated permission checks for each file access. Reduces overhead caused by UID/GID translation between NAS and Linux.
* noacl  Skips fetching POSIX/NT ACLs from the server. Avoids multiple metadata queries per file/directory. Reduces latency for directory listings, especially with large folders.
* noperm  Prevents Linux from rechecking permissions on every file access. Reduces system calls per operation. Speeds up read/write for normal user operations.
* soft  Mount fails quickly if the server is unreachable, instead of blocking. Doesn’t improve throughput directly, but prevents long hangs that feel like slowness.
* _netdev  Tells systemd that this is a network device. Ensures mount attempts wait until networking is up. Avoids failed mount attempts that would slow boot or retries.
* serverino  Uses server-provided inode numbers. Avoids inode recalculation on the client. Improves performance for apps that track files by inode (like backup tools or rsync).
* iocharset=utf8  Ensures proper UTF-8 encoding for filenames. Doesn’t directly improve speed, but prevents client-side filename handling errors that can slow down access or cause repeated retries.
* actimeo=1	 Caches file attributes briefly so directory listings update quickly, similar to Explorer’s aggressive caching.
