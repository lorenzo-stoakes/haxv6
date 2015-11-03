OBJS = \
	mm/bio.o\
	drivers/char/console.o\
	fs/exec.o\
	fs/file.o\
	fs/fs.o\
	drivers/ide/ide.o\
	drivers/acpi/ioapic.o\
	mm/kalloc.o\
	drivers/hid/kbd.o\
	drivers/acpi/lapic.o\
	fs/log.o\
	arch/x86/boot/main.o\
	arch/x86/kernel/mp.o\
	arch/x86/kernel/picirq.o\
	fs/pipe.o\
	kernel/proc.o\
	kernel/locking/spinlock.o\
	lib/string.o\
	kernel/swtch.o\
	arch/x86/kernel/syscall.o\
	fs/sysfile.o\
	arch/x86/kernel/sysproc.o\
	arch/x86/kernel/timer.o\
	arch/x86/kernel/trapasm.o\
	arch/x86/kernel/trap.o\
	drivers/tty/serial/uart.o\
	vectors.o\
	mm/vm.o\

# Cross-compiling (e.g., on Mac OS X)
#TOOLPREFIX = i386-jos-elf-

# Using native tools (e.g., on X86 Linux)
#TOOLPREFIX =

# Try to infer the correct TOOLPREFIX if not set
ifndef TOOLPREFIX
TOOLPREFIX := $(shell if i386-jos-elf-objdump -i 2>&1 | grep '^elf32-i386$$' >/dev/null 2>&1; \
	then echo 'i386-jos-elf-'; \
	elif objdump -i 2>&1 | grep 'elf32-i386' >/dev/null 2>&1; \
	then echo ''; \
	else echo "***" 1>&2; \
	echo "*** Error: Couldn't find an i386-*-elf version of GCC/binutils." 1>&2; \
	echo "*** Is the directory with i386-jos-elf-gcc in your PATH?" 1>&2; \
	echo "*** If your i386-*-elf toolchain is installed with a command" 1>&2; \
	echo "*** prefix other than 'i386-jos-elf-', set your TOOLPREFIX" 1>&2; \
	echo "*** environment variable to that prefix and run 'make' again." 1>&2; \
	echo "*** To turn off this error, run 'gmake TOOLPREFIX= ...'." 1>&2; \
	echo "***" 1>&2; exit 1; fi)
endif

# If the makefile can't find QEMU, specify its path here
QEMU = qemu-system-i386

# Try to infer the correct QEMU
ifndef QEMU
QEMU = $(shell if which qemu > /dev/null; \
	then echo qemu; exit; \
	else \
	qemu=/Applications/Q.app/Contents/MacOS/i386-softmmu.app/Contents/MacOS/i386-softmmu; \
	if test -x $$qemu; then echo $$qemu; exit; fi; fi; \
	echo "***" 1>&2; \
	echo "*** Error: Couldn't find a working QEMU executable." 1>&2; \
	echo "*** Is the directory containing the qemu binary in your PATH" 1>&2; \
	echo "*** or have you tried setting the QEMU variable in Makefile?" 1>&2; \
	echo "***" 1>&2; exit 1)
endif

CC = $(TOOLPREFIX)gcc
AS = $(TOOLPREFIX)gas
LD = $(TOOLPREFIX)ld
OBJCOPY = $(TOOLPREFIX)objcopy
OBJDUMP = $(TOOLPREFIX)objdump
#CFLAGS = -fno-pic -static -fno-builtin -fno-strict-aliasing -O2 -Wall -MD -ggdb -m32 -Werror -fno-omit-frame-pointer
CFLAGS = -fno-pic -static -fno-builtin -fno-strict-aliasing -Wall -MD -ggdb -m32 -Werror -fno-omit-frame-pointer
CFLAGS += $(shell $(CC) -fno-stack-protector -E -x c /dev/null >/dev/null 2>&1 && echo -fno-stack-protector)
CFLAGS += -Iinclude
ASFLAGS = -m32 -gdwarf-2 -Wa,-divide -Iinclude
# FreeBSD ld wants ``elf_i386_fbsd''
LDFLAGS += -m $(shell $(LD) -V | grep elf_i386 2>/dev/null)

xv6.img: bootblock kernel.img fs.img
	dd if=/dev/zero of=xv6.img count=10000
	dd if=bootblock of=xv6.img conv=notrunc
	dd if=kernel.img of=xv6.img seek=1 conv=notrunc

xv6memfs.img: bootblock kernelmemfs.img
	dd if=/dev/zero of=xv6memfs.img count=10000
	dd if=bootblock of=xv6memfs.img conv=notrunc
	dd if=kernelmemfs.img of=xv6memfs.img seek=1 conv=notrunc

bootblock: arch/x86/boot/bootasm.S arch/x86/boot/bootmain.c
	$(CC) $(CFLAGS) -fno-pic -O -nostdinc -I. -c arch/x86/boot/bootmain.c
	$(CC) $(CFLAGS) -fno-pic -nostdinc -I. -c arch/x86/boot/bootasm.S
	$(LD) $(LDFLAGS) -N -e start -Ttext 0x7C00 -o bootblock.o bootasm.o bootmain.o
	$(OBJDUMP) -S bootblock.o > bootblock.asm
	$(OBJCOPY) -S -O binary -j .text bootblock.o bootblock
	perl scripts/sign.pl bootblock

entryother: arch/x86/boot/entryother.S
	$(CC) $(CFLAGS) -fno-pic -nostdinc -I. -c arch/x86/boot/entryother.S
	$(LD) $(LDFLAGS) -N -e start -Ttext 0x7000 -o bootblockother.o entryother.o
	$(OBJCOPY) -S -O binary -j .text bootblockother.o entryother
	$(OBJDUMP) -S bootblockother.o > entryother.asm

initcode: arch/x86/boot/initcode.S
	$(CC) $(CFLAGS) -nostdinc -I. -c arch/x86/boot/initcode.S
	$(LD) $(LDFLAGS) -N -e start -Ttext 0 -o initcode.out initcode.o
	$(OBJCOPY) -S -O binary initcode.out initcode
	$(OBJDUMP) -S initcode.o > initcode.asm

entry.o: arch/x86/boot/entry.S
	$(CC) $(CFLAGS) -c -o $@ arch/x86/boot/entry.S #$^

kernel.img: $(OBJS) entry.o entryother initcode kernel/kernel.ld
	$(LD) $(LDFLAGS) -T kernel/kernel.ld -o kernel.img entry.o $(OBJS) -b binary initcode entryother
	$(OBJDUMP) -S kernel.img > kernel.asm
	$(OBJDUMP) -t kernel.img | sed '1,/SYMBOL TABLE/d; s/ .* / /; /^$$/d' > kernel.sym

memide.o: drivers/ide/memide.c
	$(CC) $(CFLAGS) -c -o $@ $^

# kernelmemfs is a copy of kernel that maintains the
# disk image in memory instead of writing to a disk.
# This is not so useful for testing persistent storage or
# exploring disk buffering implementations, but it is
# great for testing the kernel on real hardware without
# needing a scratch disk.
MEMFSOBJS = $(filter-out ide.o,$(OBJS)) memide.o
kernelmemfs.img: $(MEMFSOBJS) entry.o entryother initcode fs.img
	$(LD) $(LDFLAGS) -Ttext 0x100000 -e main -o kernelmemfs.img entry.o  $(MEMFSOBJS) -b binary initcode entryother fs.img
	$(OBJDUMP) -S kernelmemfs.img > kernelmemfs.asm
	$(OBJDUMP) -t kernelmemfs.img | sed '1,/SYMBOL TABLE/d; s/ .* / /; /^$$/d' > kernelmemfs.sym

tags: $(OBJS) arch/x86/boot/entryother.S _init
	find . -name '*.[cS]' | xargs etags

vectors.S: scripts/vectors.pl
	perl scripts/vectors.pl > vectors.S

ULIB = usr/ulib/ulib.o usr/ulib/usys.o usr/ulib/printf.o usr/ulib/umalloc.o

_%: usr/%.o $(ULIB)
	$(LD) $(LDFLAGS) -N -e main -Ttext 0 -o $@ $^
	$(OBJDUMP) -S $@ > $*.asm
	$(OBJDUMP) -t $@ | sed '1,/SYMBOL TABLE/d; s/ .* / /; /^$$/d' > $*.sym

_forktest: usr/forktest.o $(ULIB)
	# forktest has less library code linked in - needs to be small
	# in order to be able to max out the proc table.
	$(LD) $(LDFLAGS) -N -e main -Ttext 0 -o _forktest usr/forktest.o usr/ulib/ulib.o usr/ulib/usys.o
	$(OBJDUMP) -S _forktest > forktest.asm

mkfs: scripts/mkfs.c include/fs.h
	gcc -Werror -Wall -o mkfs scripts/mkfs.c

# Prevent deletion of intermediate files, e.g. cat.o, after first build, so
# that disk image changes after first build are persistent until clean.  More
# details:
# http://www.gnu.org/software/make/manual/html_node/Chained-Rules.html
.PRECIOUS: %.o

UPROGS=\
	_cat\
	_echo\
	_forktest\
	_grep\
	_init\
	_kill\
	_ln\
	_ls\
	_mkdir\
	_rm\
	_sh\
	_stressfs\
	_usertests\
	_wc\
	_zombie\

fs.img: mkfs $(UPROGS)
	./mkfs fs.img $(UPROGS)

-include *.d

clean:
	find . -name "*.[od]" -or -name '*.asm' | xargs rm -f
	rm -f *.log *.ind *.ilg \
	*.sym vectors.S bootblock entryother \
	initcode initcode.out kernel.img xv6.img fs.img kernelmemfs.img mkfs \
	.gdbinit usr/*.[od] \
	$(UPROGS)

# run in emulators

bochs : fs.img xv6.img
	if [ ! -e .bochsrc ]; then ln -s dot-bochsrc .bochsrc; fi
	bochs -q

# try to generate a unique GDB port
GDBPORT = $(shell expr `id -u` % 5000 + 25000)
# QEMU's gdb stub command line changed in 0.11
QEMUGDB = $(shell if $(QEMU) -help | grep -q '^-gdb'; \
	then echo "-gdb tcp::$(GDBPORT)"; \
	else echo "-s -p $(GDBPORT)"; fi)
ifndef CPUS
CPUS := 2
endif
QEMUOPTS = -hdb fs.img xv6.img -smp $(CPUS) -m 512 $(QEMUEXTRA)

qemu: fs.img xv6.img
	$(QEMU) -serial mon:stdio $(QEMUOPTS)

qemu-memfs: xv6memfs.img
	$(QEMU) xv6memfs.img -smp $(CPUS)

qemu-nox: fs.img xv6.img
	$(QEMU) -nographic $(QEMUOPTS)

.gdbinit: .gdbinit.tmpl
	sed "s/localhost:1234/localhost:$(GDBPORT)/" < $^ > $@

qemu-gdb: fs.img xv6.img .gdbinit
	@echo "*** Now run 'gdb'." 1>&2
	$(QEMU) -serial mon:stdio $(QEMUOPTS) -S $(QEMUGDB)

qemu-nox-gdb: fs.img xv6.img .gdbinit
	@echo "*** Now run 'gdb'." 1>&2
	$(QEMU) -nographic $(QEMUOPTS) -S $(QEMUGDB)
