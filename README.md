## D style unit tests in C
`void` functions returning `int` within `UNITTEST` conditional will be recognized as unittest.
Test fails if it returns non `0`. Helper macros reduce the amount of return statements
to a single `return 0;` at the end.
```C
#ifdef UNITTEST
int tryFooInitWithValidArgument(void) {
    ASSERT(!foo_init(42));
    return 0;
}

int fooInitShouldFailOnLTZero() {
    ASSERT(foo_init(-1));
    return 0;
}
#endif
```
Declarations should be omitted - they are added to the unittest runner automatically.
Static functions are ignored.

Please bare with contrived multiply functions in the following example.
Its purpouse is to show simplicity of adding unittests to your C code.
```C
#include "foo.h"
#include "unittestMacros.h"

// private helper
static int multiplyByTwo(int x);

// interface implementation (declared in foo.h)
int foo_multiplyByFour(int x) {
    return multiplyByTwo(multiplyByTwo(x));
}

static int multiplyByTwo(int x) {
    return x + x;
}

#ifdef UNITTEST
int testMultiplyByTwo(void) {
    // not even static functions are safe from being tested
    ASSERT(multiplyByTwo(2) == 4);
    ASSERT(multiplyByTwo(0) == 0);
    ASSERT(multiplyByTwo(-1) == -2);
    return 0;
}

int testMultiplyByFour(void) {
    ASSERT(foo_multiplyByFour(2) == 8);
    ASSERT(foo_multiplyByFour(0) == 0);
    ASSERT(foo_multiplyByFour(-1) == -4);
    return 0;
}
#endif
```
Tests don't necessarily have to be in the same file as implementation
(loosing access to static members and functions).
There can by any number of UNITTEST regions scattered through a source file.

#### Installation
D compiler is required.
Download it from
http://dlang.org/download.html
or search for "dmd" with the package manager of your favorite GNU/Linux distribution.
```make
make gendsu
```
Add gendsu to PATH.

unittestMacros.h is not required, but handy for writing unittests -
copy it to your include directory.

#### How to use
Call gendsu giving it files containing unittests.
```bash
gendsu src/foo.c src/bar.c
```
A single `unittestRunner.c` will be generated (name can be set with `-offilename`).
It must to be compiled and linked with other source files previously passed to gendsu.
```bash
cc src/foo.c src/bar.c unittestRunner.c -DUNITTEST -o unittestRunner
```
If this succeeds, you can run the unittests by calling the newly created unittestRunner.

Unittests are guarded with preprocessor conditional
```C
#ifdef UNITTEST
```
Thats the reason we've passed -DUNITTEST to the compiler previously.
UNITTEST has to be defined somewhere, so that unittest functions are compiled as well.

#### Notes
Requiring #endif as exclusive terminator of a UNITTEST block is a conscious choice.
Allowing #elif and #else as additional terminators could leave room for ambiguity,
where unittests end. #ifdef UNITTEST and #endif should rather be seen as borrowed
keywords. They serve as a switch for ignoring unittest functions in a release build
and spare artificial tags like
```C
// @unittest
...
// @unittest_end
```
Nesting of additional precompiler conditionals within a UNITTEST block is allowed.
However, they can't prevent a function from being added to the unittest runner - 
all functions with eligible signature are added.

Those choices are tiled towards simplicity, parsing speed
and avoidance of superfluous checks that are covered by the compiler.
If gendsu produces incorrect output, the source couldn't have been compiled anyway.

##### TODO
- output line number of failed test to allow for automatic jumping to it
- run tests in multiple threads
