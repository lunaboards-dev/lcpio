# lcpio - Lua cpio

WARNING: Very indev, very feature incomplete.

This utility aims to be a lua reimplementation of the cpio utility, with new features.

## TODO
* [ ] I/O
    * [x] Basic write support
    * [ ] Basic read support
    * [ ] Tape I/O support
    * [ ] SSH I/O support
    * [ ] Compressed I/O support
* [ ] Options
    * [ ] Strip leading slashes
    * [ ] Keep leading slashes
    * [ ] Block size
* [ ] Extensions
    * [x] Extended metadata
    * [ ] Extended file data
    * [ ] Tagging
* [ ] Formats
    * [x] binary cpio (`-Hbin`)
    * [ ] old ascii format (`-Hodc`)
    * [ ] new ascii format (`-Hnewc`) 
    * [ ] CRC ascii format (`-Hcrc`)
    * [ ] TAR (`-Htar`)
    * [ ] USTAR (`-Hustar`)
* [ ] Backends
    * [ ] LuaFileSystem
    * [ ] luaposix