CWARNINGS := -Wall -Wextra -pedantic -Wshadow -Wpointer-arith -Wcast-align \
	-Wwrite-strings -Wmissing-prototypes -Wmissing-declarations \
	-Wredundant-decls -Wnested-externs -Winline -Wno-long-long \
	-Wuninitialized -Wconversion -Wstrict-prototypes
CFLAGS := -std=c11 -O3 $(CWARNINGS)

BUILDDIR := build

DFLAGS_T := -unittest
DFLAGS := -O -release -boundscheck=off

GENDSU_SRC := gendsu/gendsu.d util/commentBroom.d

$(BUILDDIR)/gendsu_t: $(GENDSU_SRC)
	@dmd $(DFLAGS_T) $^ -of$@

$(BUILDDIR)/gendsu: $(GENDSU_SRC)
	@dmd $(DFLAGS) $^ -of$@

$(BUILDDIR)/dummyTestdriver: src/testdriverTemplate.c src/testdriverDummyPlugin.c
	@$(CC) $(CFLAGS) -D_TESTDRIVER_DUMMY_PLUGIN $< -o $@

gendsu_t: $(BUILDDIR)/gendsu_t

gendsu: $(BUILDDIR)/gendsu

dummyTestdriver: $(BUILDDIR)/dummyTestdriver

clean:
	-@$(RM) $(wildcard $(BUILDDIR)/*)

.PHONY: clean
