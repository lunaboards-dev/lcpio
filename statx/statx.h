#define _GNU_SOURCE
#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <string.h>
//#include <linux/stat.h>
//#include <linux/fcntl.h>
#include <errno.h>

__attribute__((visibility("default"))) int luaopen_statx(lua_State * L);