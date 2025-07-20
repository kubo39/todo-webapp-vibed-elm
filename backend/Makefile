.PHONY: all

all: build

build:
	@if [ -f /.dockerenv ]; then \
		echo "Building inside Docker container..."; \
		dub build --config=application; \
	else \
		echo "Building outside Docker container..."; \
		dub build --config=local; \
	fi

fetch:
	dub fetch

run:
	dub run

lint:
	dub lint

test:
	dub test --config=unittest

clean:
	dub clean
