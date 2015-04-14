#include <stdlib.h>
#include <string.h>
#include <stdio.h>

/* #defines affecting unittest-runner behaviour
   UNITTEST_MAX_ERRORS - 0 for unlimited

   can also be specified as CLA (higher priority than defines):
   -max_errors=n  */

typedef struct {
    int (*ptr)(void);
    const char *name;
    const char *file;
} _unittest_func_t;

typedef struct {
    const _unittest_func_t *functions;
    size_t functionCount;
    size_t maxErrors;
} _unittest_run_param_t;

static _unittest_run_param_t _unittest_makeRunParam(int argc, char *argv[]);
static int _unittest_run(_unittest_run_param_t r);

// dsunittest utility inserts generated code at following line
// @unittest_plugin

int main(int argc, char *argv[]) {
    _unittest_run_param_t r = _unittest_makeRunParam(argc, argv);
    int error = _unittest_run(r);
    if (!error)
        printf("%u succeeded\n", _UNITTEST_COUNT);

    return error;
}

static _unittest_run_param_t _unittest_makeRunParam(int argc, char *argv[]) {
    _unittest_run_param_t r = { 0 };
    const char *maxErrorsArg = getenv("UNITTEST_MAX_ERRORS");
    if (!maxErrorsArg)
        maxErrorsArg = "";

    if (argc > 1) {
        const char *maxErrorsOption = "-max_errors=";
        size_t maxErrorsOptionLength = strlen(maxErrorsOption);
        const char *currentArg = argv[1];
        if (strncmp(currentArg, maxErrorsOption, maxErrorsOptionLength) == 0)
            maxErrorsArg = currentArg + maxErrorsOptionLength;
    }

    r.maxErrors = strtoul(maxErrorsArg, NULL, 10);

    return r;
}

static int _unittest_run(_unittest_run_param_t r) {
    size_t errorCount = 0;
    for (size_t i = 0; i < r.functionCount; i++) {
        const _unittest_func_t *func = r.functions + i;

        int error = func->ptr();
        if (!error)
            continue;

        errorCount++;
        if (error == -1)
            fprintf(stderr, "[FAIL] %s in %s\n", func->name, func->file);
        else
            fprintf(stderr, "[FAIL] %s in %s code: %d\n", func->name, func->file, error);

        if (errorCount == r.maxErrors)
            return -1;
    }

    return errorCount ? -1 : 0;
}

