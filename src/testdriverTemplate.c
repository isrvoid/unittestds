#include <stdlib.h>
#include <string.h>
#include <stdio.h>

/* defines that control testdriver behaviour:
   TESTING_MAX_ERRORS - 0 for unlimited

   can also be specified as command line argument (higher priority than defines):
   -max_errors=n  */

// only to test this template
#ifdef _TESTDRIVER_DUMMY_PLUGIN
#include "testdriverDummyPlugin.c"
#endif

typedef struct {
    int (*func)(void);
    const char *funcName;
    const char *fileName;
} _testdriver_test_t;

typedef struct {
    const _testdriver_test_t *tests;
    size_t testCount;
    size_t maxErrors;
} _testdriver_run_param_t;

static _testdriver_run_param_t _testdriver_makeRunParam(int argc, char *argv[]);
static int _testdriver_run_tests(_testdriver_run_param_t param);

// testgen utility inserts generated code at following line
// @testdriver-plugin

int main(int argc, char *argv[]) {
    _testdriver_run_param_t param = _testdriver_makeRunParam(argc, argv);
    int error = _testdriver_run_tests(param);
    if (!error)
        printf("all succeeded\n");

    return error;
}

static _testdriver_run_param_t _testdriver_makeRunParam(int argc, char *argv[]) {
    _testdriver_run_param_t param = { 0 };
    const char *maxErrorsArg = getenv("TESTING_MAX_ERRORS");
    if (!maxErrorsArg)
        maxErrorsArg = "";

    if (argc > 1) {
        const char *maxErrorsOption = "-max_errors=";
        size_t maxErrorsOptionLength = strlen(maxErrorsOption);
        if (strncmp(argv[1], maxErrorsOption, maxErrorsOptionLength) == 0)
            maxErrorsArg = argv[1] + maxErrorsOptionLength;
    }

    param.maxErrors = strtoul(maxErrorsArg, NULL, 10);

    return param;
}

static int _testdriver_run_tests(_testdriver_run_param_t param) {
    size_t errorCount = 0;
    for (size_t i = 0; i < param.testCount; i++) {
        const _testdriver_test_t *test = param.tests + i;

        int error = test->func();
        if (!error)
            continue;

        errorCount++;
        if (error == -1)
            fprintf(stderr, "[FAIL] %s in %s\n", test->funcName, test->fileName);
        else
            fprintf(stderr, "[FAIL] %s in %s code: %d\n", test->funcName, test->fileName, error);

        if (errorCount == param.maxErrors)
            return -1;
    }

    return errorCount ? -1 : 0;
}

