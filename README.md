# haxv6

haxv6 is an experimental fork of the extremely awesome [xv6][xv6] learning OS.

The idea is to have a place to play with xv6. The [original readme][xv6_readme] is available in
the repo.

## Getting Started

I've written [a guide][xv6_blog] to getting xv6 working on OS X over at [my blog][blog].

## Exploits

Part of the fun of having a small OS to play with is the ability to explore stuff in more
detail and ease than would otherwise be possible. One of these fun games is playing around with
security exploits :)

### Exploit 1

This is a simple buffer overflow exploit, and in fact my first ever attempt at writing an
exploit, so forgive the hackiness (no pun intended...)

To see the exploit in action simply run `exploit1 | exploited1` after running the xv6 shell via
`make qemu-nox`.

The [exploited program][exploited1] intentionally overwrites a buffer from `stdin`, which the
[exploit program][exploit1] takes advantage of by overwriting the return address of the
current stack frame to jump into code which executes `ls` as a probably-not-quite-malicious
payload :)

[blog]:http://blog.ljs.io
[exploit1]:/exploit1.c
[exploited1]:/exploited1.c
[xv6]:http://pdos.csail.mit.edu/6.828/2012/xv6.html
[xv6_blog]:http://blog.ljs.io/post/71424794630/xv6
[xv6_readme]:/README.XV6
