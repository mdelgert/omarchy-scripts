import QtQuick
import qs.Ui

// Bar icon that opens the scripts menu. Deliberately stateless, same shape
// as Omarchy's own menu widget — see omarchy-recipes' BarWidget.qml for the
// fuller explanation of why this stays a doorway, not a status monitor.
BarWidget {
  id: root
  moduleName: "io.github.mdelgert.omarchy-scripts"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    // Nerd Font terminal glyph, U+F120. Verify this renders in your Nerd
    // Font before trusting it — some plausible-looking codepoints render
    // blank; render to an image (e.g. with `magick`) to check, rather than
    // trusting the codepoint by inspection.
    text: "\uf120"
    tooltipText: "Scripts"

    onPressed: function(mouseButton) {
      if (!root.bar) return
      if (mouseButton !== Qt.LeftButton) return
      root.bar.run("omarchy-shell shell toggle io.github.mdelgert.omarchy-scripts '{}'")
    }
  }
}
