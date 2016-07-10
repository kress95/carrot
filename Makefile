PLATFORM = unknown

ifeq ($(OS),Windows_NT)
    ifeq ($(PROCESSOR_ARCHITECTURE),AMD64)
        PLATFORM = win32-x64
    endif

    ifeq ($(PROCESSOR_ARCHITECTURE),x86)
        PLATFORM = win32-x86
    endif
else
    UNAME_S := $(shell uname -s)

    ifeq ($(UNAME_S),Linux)
        UNAME_P := $(shell uname -p)

    	ifeq ($(UNAME_P),x86_64)
            PLATFORM = linux-x64
    	else
            PLATFORM = linux-x86
	    endif
    endif

    ifeq ($(UNAME_S),Darwin)
        PLATFORM = osx
    endif
endif

LUA_DIR = ./vendor/luajit/$(PLATFORM)/*

help:
	@echo ""
	@echo "Usable Rules:"
	@echo "  $ make       -> builds everything without debug information"
	@echo "  $ make help  -> shows this message"
	@echo "  $ make debug -> builds everything with debug information"
	@echo "  $ make tests -> run tests, returns test result"
	@echo "  $ make test  -> run specified on FILE variable"
	@echo "  $ make run   -> builds with debug information and run the game"
	@echo "  $ make dist  -> packs up the game for distribution"
	@echo "  $ make clean -> deletes built files"
	@echo ""
	@echo "Define the target platform using the PLATFORM variable."
	@echo ""
	@echo "Supported PLATFORM values (by default):"
	@echo "    win32-x86 win32-x64 linux-x86 linux-x64"
	@echo ""
	@echo "Till next time :)"

./lua:
	cp -r $(LUA_DIR) ./

dirs:
	mkdir -p ./dist
	mkdir -p ./proj

tests:
	$(LUA) "./vendor/lua-lisp/test.lua"

test:

run:

dist:

clean:
	rm -rf ./dist

default:

.PHONY: help debug tests test run dist dirs clean lisp
