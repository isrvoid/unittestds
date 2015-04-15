BUILDDIR := build

DFLAGS_T := -unittest -JrunnerTemplate
DFLAGS := -O -release -boundscheck=off -JrunnerTemplate

GENDSU_SRC := unittestds/gendsu.d util/commentBroom.d

default: $(BUILDDIR)/gendsu

$(BUILDDIR)/gendsu_t: $(GENDSU_SRC)
	@dmd $(DFLAGS_T) $^ -of$@

$(BUILDDIR)/gendsu: $(GENDSU_SRC)
	@dmd $(DFLAGS) $^ -of$@

clean:
	-@$(RM) $(wildcard $(BUILDDIR)/*)

.PHONY: clean
