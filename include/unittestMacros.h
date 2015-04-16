#ifndef _UNITTEST_MACROS
#define _UNITTEST_MACROS

#ifdef ASSERT
#undef ASSERT
#endif

#define ASSERT(COND) if (!(COND)) return -1
// _WEC - With Error Code
#define ASSERT_WEC(COND, EC) if (!(COND)) return (EC) ? (EC) : -1

#endif
