.PHONY: clean

SHELL=/bin/bash

clean:
	@find . -type f -name '*.plan' -delete;  \
	find . -type d -name ".terraform" | xargs rm -rf  2>/dev/null;
