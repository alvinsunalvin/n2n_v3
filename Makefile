N2N_MAJOR=3
N2N_MINOR=0
N2N_VERSION=$(N2N_MAJOR).$(N2N_MINOR)
N2N_OSNAME=$(shell uname -p)

########

CC=gcc
DEBUG?=-g3
#OPTIMIZATION?=-O2
WARN?=-Wall -Wshadow -Wpointer-arith -Wmissing-declarations -Wnested-externs

#Ultrasparc64 users experiencing SIGBUS should try the following gcc options
#(thanks to Robert Gibbon)
PLATOPTS_SPARC64=-mcpu=ultrasparc -pipe -fomit-frame-pointer -ffast-math -finline-functions -fweb -frename-registers -mapp-regs

N2N_DEFINES=
N2N_OBJS_OPT=
LIBS_EDGE_OPT=
LIBS_SN_OPT=

N2N_OPTION_AES?="yes"
#N2N_OPTION_AES=no

ifeq ($(N2N_OPTION_AES), "yes")
    N2N_DEFINES+="-DN2N_HAVE_AES"
    LIBS_EDGE_OPT+=-lcrypto
endif

ifeq ($(SNM), yes)
    N2N_DEFINES+="-DN2N_MULTIPLE_SUPERNODES"
endif

CFLAGS+=$(DEBUG) $(OPTIMIZATION) $(WARN) $(OPTIONS) $(PLATOPTS) $(N2N_DEFINES)

INSTALL=install
MKDIR=mkdir -p

INSTALL_PROG=$(INSTALL) -m755
INSTALL_DOC=$(INSTALL) -m644


# DESTDIR set in debian make system
PREFIX?=$(DESTDIR)/usr
#BINDIR=$(PREFIX)/bin
SBINDIR=$(PREFIX)/sbin
MANDIR?=$(PREFIX)/share/man
MAN1DIR=$(MANDIR)/man1
MAN7DIR=$(MANDIR)/man7
MAN8DIR=$(MANDIR)/man8

N2N_LIB=n2n.a
N2N_OBJS=n2n.o n2n_net.o n2n_keyfile.o n2n_list.o n2n_log.o n2n_utils.o n2n_wire.o minilzo.o twofish.o \
         transform_null.o transform_tf.o transform_aes.o
         
XNIX_OBJS=tuntap_freebsd.o tuntap_netbsd.o tuntap_linux.o tuntap_osx.o version.o
         
WIN32_DIR=win32
WIN32_OBJS=$(WIN32_DIR)/wintap.o $(WIN32_DIR)/version-msvc.o

ifeq ($(shell uname -o), Cygwin)
	N2N_OBJS+=$(WIN32_OBJS)
	CFLAGS+="-DWIN32"
	CFLAGS+="-D__USE_W32_SOCKETS"
	LIBS_EDGE_OPT+=-lws2_32
	LIBS_SN_OPT+=-lws2_32
else
	N2N_OBJS+=$(XNIX_OBJS)
endif

ifeq ($(SNM), yes)
N2N_OBJS+=sn_multiple.o
endif

LIBS_EDGE+=$(LIBS_EDGE_OPT)
LIBS_SN+=$(LIBS_SN_OPT)

#For OpenSolaris (Solaris too?)
ifeq ($(shell uname), SunOS)
LIBS_EDGE+=-lsocket -lnsl
LIBS_SN+=-lsocket -lnsl
endif

APPS=edge
APPS+=supernode

DOCS=edge.8.gz supernode.1.gz n2n_v$(N2N_VERSION).gz

all: $(APPS) $(DOCS)

edge: edge.c edge.h edge_mgmt.c edge_mgmt.h $(N2N_LIB) n2n_wire.h n2n.h Makefile
	$(CC) $(CFLAGS) edge.c edge_mgmt.c $(N2N_LIB) $(LIBS_EDGE) -o edge

test: test.c $(N2N_LIB) n2n_wire.h n2n.h Makefile
	$(CC) $(CFLAGS) test.c $(N2N_LIB) $(LIBS_EDGE) -o test

supernode: sn.c sn.h $(N2N_LIB) n2n.h Makefile
	$(CC) $(CFLAGS) sn.c $(N2N_LIB) $(LIBS_SN) -o supernode

benchmark: benchmark.c $(N2N_LIB) n2n_wire.h n2n.h Makefile
	$(CC) $(CFLAGS) benchmark.c $(N2N_LIB) $(LIBS_SN) -o benchmark

ifeq ($(SNM), yes)
test_snm: sn_multiple_test.c $(N2N_LIB) n2n.h Makefile
	$(CC) $(CFLAGS) sn_multiple_test.c $(N2N_LIB) $(LIBS_SN) -o test_snm
endif

.c.o: n2n.h n2n_keyfile.h n2n_transforms.h n2n_wire.h twofish.h Makefile
	$(CC) $(CFLAGS) -c $< -o $@

%.gz : %
	gzip -c $< > $@

$(N2N_LIB): $(N2N_OBJS)
	ar rcs $(N2N_LIB) $(N2N_OBJS)
#	$(RANLIB) $@

version.o: Makefile
	$(CC) $(CFLAGS) -DN2N_VERSION='"$(N2N_VERSION)"' -DN2N_OSNAME='"$(N2N_OSNAME)"' -c version.c

clean:
	rm -rf $(N2N_OBJS) $(N2N_LIB) $(APPS) $(DOCS) test *.dSYM *~

install: edge supernode edge.8.gz supernode.1.gz n2n_v$(N2N_VERSION).gz
	echo "MANDIR=$(MANDIR)"
	$(MKDIR) $(SBINDIR) $(MAN1DIR) $(MAN7DIR) $(MAN8DIR)
	$(INSTALL_PROG) supernode $(SBINDIR)/
	$(INSTALL_PROG) edge $(SBINDIR)/
	$(INSTALL_DOC) edge.8.gz $(MAN8DIR)/
	$(INSTALL_DOC) supernode.1.gz $(MAN1DIR)/
	$(INSTALL_DOC) n2n_v$(N2N_VERSION).gz $(MAN7DIR)/
