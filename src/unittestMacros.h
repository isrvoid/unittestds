
#define ASSERT(COND) if (!(COND)) return -1
// _WEC - With Error Code
#define ASSERT_WEC(COND, EC) if (!(COND)) return (EC) ? (EC) : -1
