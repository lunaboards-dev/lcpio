if svar.get("PLATFORM") == "posix" then
	config {
		LCPIO_ENABLE_SSH = true,
		--LCPIO_STATX = true, -- not yet
		LCPIO_COLORED_LOGGING = true,
		LCPIO_ENABLE_METADATA = true,
		LCPIO_UID_GID_LOOKUP = true
	}
end
