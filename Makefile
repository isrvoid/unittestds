CWARNINGS := -Wall -Wextra -pedantic -Wshadow -Wpointer-arith -Wcast-align \
	-Wwrite-strings -Wmissing-prototypes -Wmissing-declarations \
	-Wredundant-decls -Wnested-externs -Winline -Wno-long-long \
	-Wuninitialized -Wconversion -Wstrict-prototypes
CFLAGS := -std=c11 -O3 $(CWARNINGS)

DFLAGS_T := -unittest
DFLAGS := -O -release -boundscheck=off

GENDSU_SRC := gendsu/gendsu.d util/commentBroom.d

gendsu_t: $(GENDSU_SRC)
	@dmd $(DFLAGS_T) $^ -of$@

gendsu: $(GENDSU_SRC)
	@dmd $(DFLAGS) $^ -of$@

dummyTestdriver: src/testdriverTemplate.c src/testdriverDummyPlugin.c
	@$(CC) $(CFLAGS) -D_TESTDRIVER_DUMMY_PLUGIN $< -o $@

clean:
	-@$(RM) $(wildcard *.o *_t.o *_t gendsu dummyTestdriver)

.PHONY: clean
