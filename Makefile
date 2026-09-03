.PHONY: test lint-qml check plugin validate demo

# Qt tools are not on PATH on a stock Arch/Omarchy install.
QT_BIN ?= /usr/lib/qt6/bin
# The Omarchy shell exports `qs.*` from its own tree; qmllint needs a directory
# where that tree is reachable as `qs`.
OMARCHY_PATH ?= /usr/share/omarchy
# Built outside the repository on purpose: Omarchy refuses a plugin folder that
# contains a symlink, and this tree must stay directly installable.
QML_IMPORTS := $(shell mktemp -d -u /tmp/omarchy-scripts-qml.XXXXXX 2>/dev/null || echo /tmp/omarchy-scripts-qml)

test:
	PYTHONPATH=src python3 -m unittest discover -s tests -v

$(QML_IMPORTS)/qs:
	mkdir -p $(QML_IMPORTS)
	ln -sfn $(OMARCHY_PATH)/shell $(QML_IMPORTS)/qs

lint-qml: $(QML_IMPORTS)/qs
	$(QT_BIN)/qmllint -I $(QML_IMPORTS) omarchy-plugin/*.qml

check: test validate

validate:
	./bin/omarchy-scripts validate

plugin:
	./omarchy-plugin/install.sh

demo:
	./bin/omarchy-scripts run hostname-info
	./bin/omarchy-scripts run greet-user --param name=World --param shout=true
