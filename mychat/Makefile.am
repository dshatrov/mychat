COMMON_CFLAGS =			\
	-Wno-long-long -Wall	\
	$(THIS_CFLAGS)

if !PLATFORM_WIN32
    COMMON_CFLAGS += -pthread
    # For backtraces
    COMMON_CFLAGS += -rdynamic
endif

AM_CFLAGS   += -std=gnu99 $(COMMON_CFLAGS)
AM_CXXFLAGS += $(COMMON_CFLAGS)

INCLUDES = -I$(top_srcdir)

mychatdir = $(libdir)/moment-1.0
mychat_LTLIBRARIES = libmoment-mychat-1.0.la
libmoment_mychat_1_0_la_SOURCES =	\
	mychat.cpp

libmoment_mychat_1_0_la_LDFLAGS = -no-undefined -version-info "0:0:0"
libmoment_mychat_1_0_la_LIBADD = $(THIS_LIBS)

