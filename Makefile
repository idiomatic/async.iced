PACKAGE = asyncjs
NODEJS = $(if $(shell test -f /usr/bin/nodejs && echo "true"),nodejs,node)
CWD := $(shell pwd)
NODEUNIT = $(CWD)/node_modules/nodeunit/bin/nodeunit
ICED = $(CWD)/node_modules/iced-coffee-script/bin/iced
UGLIFY = $(CWD)/node_modules/uglify-js/bin/uglifyjs
NODELINT = $(CWD)/node_modules/nodelint/nodelint

BUILDDIR = dist

all: clean test build

build: $(wildcard  lib/*.js)
	mkdir -p $(BUILDDIR)
	$(ICED) -sp lib/async.iced > $(BUILDDIR)/async.js
	$(UGLIFY) $(BUILDDIR)/async.js > $(BUILDDIR)/async.min.js

test:
	$(NODEUNIT) test

clean:
	rm -rf $(BUILDDIR)

lint:
	$(NODELINT) --config nodelint.cfg lib/async.js

.PHONY: test build all
