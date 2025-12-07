SHELL=/usr/bin/env bash
# This may need to be changed, based on the output of `arduino-cli board list`.
# Need permission to access this device, you may need to `sudo usermod -a -G dialout <username>`.
SERIAL=/dev/ttyUSB0
# This should be in sync with whatever you set in the sketch via `Serial.begin(xxx);` (if you set it at all).
BAUDRATE=115200
FQBN=esp8266:esp8266:d1_mini

VERBOSE=

ROOT_DIR:=$(shell pwd)
SKETCH_NAME:=$(shell basename $(ROOT_DIR))

COMPILER_CPP_EXTRA_FLAGS:=$(shell test -e $(ROOT_DIR)/compiler.cpp.extra_flags && cat $(ROOT_DIR)/compiler.cpp.extra_flags)

GIT_VERSION:=$(shell git rev-parse HEAD)
GIT_VERSION_SHORT:=$(shell git rev-parse --short HEAD)
GIT_DIRTY:=$(shell git diff --no-ext-diff --quiet || echo "*")
GIT_ADDED:=$(shell git diff --no-ext-diff --cached --quiet || echo "+")

_ARDUINO_ROOT_DIR=/tmp/arduino/
_ARDUINO_PROJECT_DIR=$(_ARDUINO_ROOT_DIR)/$(SKETCH_NAME)
_ARDUINO_BUILD_DIR=$(_ARDUINO_PROJECT_DIR)/build/$(SKETCH_NAME)
_ARDUINO_OUTPUT_DIR=$(_ARDUINO_PROJECT_DIR)/bin/$(SKETCH_NAME)

.PHONY: all compile upload monitor clean

all: compile upload

check-permissions:
	@echo Checking if $(SERIAL) exists
	test -e $(SERIAL)
	@echo Checking permissions for $(SERIAL)
	groups | grep $$(stat $(SERIAL) --format '%G') || test $$(stat $(SERIAL) --format '%a' | cut -b 3) = 6

# commonhfile.fqfn needs to be set because it needs to be in a writable directory
compile:
	arduino-cli compile "$(VERBOSE)" \
	--fqbn "$(FQBN)" \
	--build-property "compiler.cpp.extra_flags=$(COMPILER_CPP_EXTRA_FLAGS) -DSKETCH_NAME=\"$(SKETCH_NAME)\" -DGIT_VERSION=\"$(GIT_VERSION)$(GIT_DIRTY)$(GIT_ADDED)\" -DGIT_VERSION_SHORT=\"$(GIT_VERSION_SHORT)$(GIT_DIRTY)$(GIT_ADDED)\"" \
	--build-property "commonhfile.fqfn=$(_ARDUINO_BUILD_DIR)/CommonHFile.h" \
	--build-path "$(_ARDUINO_BUILD_DIR)" \
	--output-dir "$(_ARDUINO_OUTPUT_DIR)"

upload: check-permissions
	[ -e $(SERIAL) ] && \
	arduino-cli upload \
	--fqbn "$(FQBN)" \
	--input-dir "$(_ARDUINO_OUTPUT_DIR)" \
        -p "$(SERIAL)" \
        -v || \
	{ echo "==> $(SERIAL) is not available"; exit 1; }

# Monitor the serial output.
# The --imap option maps '\n' to '\r\n' so newlines are newlines.
monitor: check-permissions
	picocom -b $(BAUDRATE) --imap lfcrlf $(SERIAL)

clean:
	rm -rf "$(_ARDUINO_OUTPUT_DIR)"
	rm -rf "$(_ARDUINO_BUILD_DIR)"
