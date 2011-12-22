#define EV_STANDALONE /* keeps ev from requiring config.h */

#ifdef _WIN32
#define EV_SELECT_IS_WINSOCKET 1
#define FD_SETSIZE 512
#endif

#include "../libev/ev.h"