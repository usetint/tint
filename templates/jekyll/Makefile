.PHONY: all install

all:
	jekyll build

install:
	rm -rf "$(PREFIX)"/*
	cp -r _site/* "$(PREFIX)"
