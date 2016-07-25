#==============================================================================
# OS DETECTION
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

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

#==============================================================================

#==============================================================================
# VARIABLES
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

LUA = ./luajit
LUA_DIR = ./vendor/luajit/$(PLATFORM)/*
SDL_DIR = ./vendor/sdl2/$(PLATFORM)/*
LISP = "./lua/lisp/lisp.lua"

CARROT_IN  = $(shell find lua/carrot -name "*.s2" -type f | sort)
CARROT_OUT = $(CARROT_IN:%.s2=%.lua)

GAME_IN  = $(shell find lua/game -name "*.s2" -type f | sort)
GAME_OUT = $(GAME_IN:%.s2=%.lua)

#==============================================================================

#==============================================================================
# INTERNALS
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

lua/carrot/%.lua: lua/carrot/%.s2
	mkdir -p $(dir $@)
	$(LUA) $(LISP) "$<" clean > $@

lua/game/%.lua: lua/game/%.s2
	mkdir -p $(dir $@)
	$(LUA) $(LISP) "$<" clean > $@


lisp: $(CARROT_OUT) $(GAME_OUT)
	mkdir -p $(dir $@)
	$(LUA) $(LISP) "" > $@

# copies luajit and sdl to root, the rule name is used
./lua/jit:
	cp -r $(LUA_DIR) ./
	cp -r $(SDL_DIR) ./

# creates the folder used to build the distribution
./dist:
	mkdir -p ./dist

# just a good name for calling the function that copies needed files
initialize: ./lua/jit

# starts repl
repl:
	$(LUA)

build: lisp

.SILENT: lisp

# declare rules that are not files
.PHONY: initialize help debug tests test run dist dirs clean repl lisp build

#==============================================================================

#==============================================================================
# USER INTERFACE
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# builds everything without debug information
default: build

# shows help information
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

# builds everything with debug information
debug:

# run tests, returns test result
tests: initialize

# run specified on FILE variable
test:

# builds with debug information and run the game
run:

# distribution rule
dist: ./dist

# deletes built files
clean:
	rm -rf ./dist ./lua/jit
	rm ./*.dll ./*.exe
	rm -f ./luajit

#==============================================================================
