BUILDDIR := build

DFLAGS_T := -unittest
DFLAGS := -O -release -boundscheck=off

GENDSU_SRC := unittestds/gendsu.d util/commentBroom.d

default: $(BUILDDIR)/gendsu

$(BUILDDIR)/gendsu_t: $(GENDSU_SRC)
	@dmd $(DFLAGS_T) $^ -of$@

$(BUILDDIR)/gendsu: $(GENDSU_SRC)
	@dmd $(DFLAGS) $^ -of$@

clean:
	-@$(RM) $(wildcard $(BUILDDIR)/*)

.PHONY: clean
