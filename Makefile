#CWARNINGS := -Wall -Wextra -pedantic -Wshadow -Wpointer-arith -Wcast-align \
	-Wwrite-strings -Wmissing-prototypes -Wmissing-declarations \
	-Wredundant-decls -Wnested-externs -Winline -Wno-long-long \
	-Wuninitialized -Wconversion -Wstrict-prototypes
#CWARNINGS := -Weverything
#CC := clang
CFLAGS := -std=c11 -O3 $(CWARNINGS)

BUILDDIR := build

DFLAGS_T := -unittest
DFLAGS := -O -release -boundscheck=off

GENDSU_SRC := dsunittest/gendsu.d util/commentBroom.d

default: $(BUILDDIR)/gendsu

$(BUILDDIR)/gendsu_t: $(GENDSU_SRC)
	@dmd $(DFLAGS_T) $^ -of$@

$(BUILDDIR)/gendsu: $(GENDSU_SRC)
	@dmd $(DFLAGS) $^ -of$@

$(BUILDDIR)/dummyRunner: src/unittestRunnerTemplate.c src/dummyPlugin.c
	@$(CC) $(CFLAGS) -D_UNITTEST_DUMMY_PLUGIN $< -o $@

clean:
	-@$(RM) $(wildcard $(BUILDDIR)/*)

.PHONY: clean
