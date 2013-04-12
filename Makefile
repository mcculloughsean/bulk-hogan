SRC = $(shell find src -name "*.coffee" -type f | sort)
LIB = $(SRC:src/%.coffee=lib/%.js)

COFFEE=node_modules/.bin/coffee

.PHONY : all build clean test
all: build

build: $(LIB)

lib:
	mkdir lib

lib/%.js: src/%.coffee lib
	dirname "$@" | xargs mkdir -p
	$(COFFEE) --js <"$<" >"$@"

clean :
	rm -rf lib
	rm -rf node_modules

test : build
	node lib/bulk_hogan.js
# ---

tag:
	git tag v`node -e "console.log(require('./package.json').version)"`
