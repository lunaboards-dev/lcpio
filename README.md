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
* [x] Extensions
	* [x] Extended metadata
	* [x] Extended file data
	* [x] Tagging
* [ ] Formats
	* [x] binary cpio (`-Hbin`)
	* [x] old ascii format (`-Hodc`)
	* [x] new ascii format (`-Hnewc`) 
	* [ ] CRC ascii format (`-Hcrc`)
	* [ ] TAR (`-Htar`)
	* [ ] USTAR (`-Hustar`)
* [ ] Backends
	* [x] LuaFileSystem
	* [x] luaposix
	* [ ] OpenComputers
