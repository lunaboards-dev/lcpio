#include "statx.h"

#define pushfield(name, field) /*lua_pushstring(L, name);*/ lua_pushinteger(L, field); lua_setfield(L, -2, name); // lua_settable(L, -3);
void push_ts(lua_State * L, char * name, struct statx_timestamp * ts) {
    lua_newtable(L);
    pushfield("tv_sec", ts->tv_sec);
    pushfield("tv_nsec", ts->tv_nsec);
    //lua_settable(L, -3);
    lua_setfield(L, -2, name);
}

int l_statx(lua_State * L) {
    const char * path_name = luaL_checkstring(L, 1);
    char no_link = lua_toboolean(L, 2);
    struct statx buf;
    if (statx(AT_FDCWD, path_name, no_link ? AT_SYMLINK_NOFOLLOW : 0, STATX_ALL, &buf)) {
        lua_pushnil(L);
        int er = errno;
        lua_pushstring(L, strerror(er));
        lua_pushinteger(L, er);
        return 3;
    }
    lua_newtable(L);
    pushfield("stx_mask", buf.stx_mask);
    pushfield("stx_blksize", buf.stx_blksize);
    pushfield("stx_attributes", buf.stx_attributes);
    pushfield("stx_nlink", buf.stx_nlink);
    pushfield("stx_uid", buf.stx_uid);
    pushfield("stx_gid", buf.stx_gid);
    pushfield("stx_mode", buf.stx_mode);
    pushfield("stx_ino", buf.stx_ino);
    pushfield("stx_size", buf.stx_size);
    pushfield("stx_blocks", buf.stx_blocks);
    pushfield("stx_attributes_mask", buf.stx_attributes_mask);
    push_ts(L, "stx_atime", &buf.stx_atime);
    push_ts(L, "stx_btime", &buf.stx_btime);
    push_ts(L, "stx_ctime", &buf.stx_ctime);
    push_ts(L, "stx_mtime", &buf.stx_mtime);
    pushfield("stx_rdev_major", buf.stx_rdev_major);
    pushfield("stx_rdev_minor", buf.stx_rdev_minor);
    pushfield("stx_dev_major", buf.stx_dev_major);
    pushfield("stx_dev_minor", buf.stx_dev_minor);
    pushfield("stx_mnt_id", buf.stx_mnt_id);
    return 1;
}

int luaopen_statx(lua_State * L) {
    lua_pushcfunction(L, l_statx);
    return 1;
}