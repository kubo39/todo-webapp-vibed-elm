.PHONY: all

all: build

build:
	elm make src/Main.elm
	mv index.html ../public/index.html

lint:
	npx elm-review

install-linter:
	npm install
