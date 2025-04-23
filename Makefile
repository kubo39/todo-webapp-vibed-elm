.PHONY: all

all: build-all

build-all: build-backend build-frontend

build-frontend:
	make -C frontend build

lint-frontend:
	make -C frontend lint

build-backend:
	make -C backend build

run-backend:
	make -C backend run

lint-backend:
	make -C backend lint

test-backend:
	make -C backend test

clean: clean-backend

clean-backend:
	make -C backend clean
