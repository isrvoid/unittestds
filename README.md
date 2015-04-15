## D style unit tests in C

Any "int foo(void)" function within UNITTEST block will be recognized as unit test.
Declaration should be omitted. A test fails if it returns non 0.
Helper macros reduce the amount of return statements to a single return 0; at the end.
```C
#ifdef UNITTEST
#include "unittestMacros.h"

int bar(void) {
    ASSERT(1);
    return 0;
}
#endif
```
The generator utility will add these to test runner.
Static functions with same signature are ignored.

Please bare with contrived multiply functions in the following example.
Its purpouse is to show simplicity of adding unit tests to your C code.
```C
#include "foo.h"

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
#include "unittestMacros.h"

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
A single unittestRunner.c will be generated. It must to be compiled and linked
with other source files previously passed to gendsu.
```bash
cc src/foo.c src/bar.c unittestRunner.c -DUNITTEST -o unittestRunner
```
If this succeeds, you can run the unittests by calling the newly created unittestRunner.

Unittests are guarded with preprocessor conditional
```C
#ifdef UNITTEST
```
Thats the reason we passed -DUNITTEST to the compiler previously.
UNITTEST must be defined somewhere, so that unittest functions are compiled as well.
