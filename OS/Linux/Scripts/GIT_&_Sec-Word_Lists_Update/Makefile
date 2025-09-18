.PHONY: install uninstall test lint run

install:
\tsudo ./install.sh

uninstall:
\tsudo ./uninstall.sh

test:
\tbash tests/smoke_test.sh

lint:
\tshellcheck bin/update-wordlists.sh || true

run:
\tsudo ./bin/update-wordlists.sh
