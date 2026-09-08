// The island itself: a pill that grows into a panel.
//
// One rounded rectangle owns the whole animation. Width, height and corner
// radius all interpolate on the same curve, so the shape reads as one object
// stretching rather than a pill being swapped for a panel. The clock is a
// single item throughout — closed it sits dead centre, open it rides to the
// top-left corner — which is what sells the transition.

import QtQuick
import Quickshell
import qs.Commons

Item {
  id: root

  required property var bar
  required property var hub
  required property bool open
  required property string screenName


  signal toggleRequested()
  signal closeRequested()

  readonly property int pad: 18
  readonly property int headerHeight: 34
  readonly property int footerHeight: 34
  readonly property int gap: 12

  implicitWidth: width
  implicitHeight: height

  width: open ? bar.expandedWidth : Math.max(96, collapsedRow.implicitWidth + 26)
  height: open ? bar.expandedHeight : bar.collapsedHeight

  // 260ms with a gentle overshoot on the way out and none on the way back:
  // opening should feel like the panel arrives, closing like it gets out of
  // the way. Width and height share the curve so corners stay square to each
  // other mid-flight.
  Behavior on width {
    NumberAnimation { duration: 280; easing.type: root.open ? Easing.OutBack : Easing.OutCubic; easing.overshoot: 0.7 }
  }
  Behavior on height {
    NumberAnimation { duration: 280; easing.type: root.open ? Easing.OutBack : Easing.OutCubic; easing.overshoot: 0.7 }
  }

  Rectangle {
    id: shell

    anchors.fill: parent
    color: bar.islandBackground
    // Closed it is a true pill; open, a soft-cornered panel. Interpolating the
    // radius rather than switching it keeps the silhouette continuous.
    radius: root.open ? 26 : height / 2
    antialiasing: true

    Behavior on radius { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }

    // A single hairline, no heavier than the rest of the shell's chrome.
    border.width: 1
    border.color: Qt.rgba(bar.foreground.r, bar.foreground.g, bar.foreground.b, 0.10)
  }

  // ------------------------------------------------------------------ clock
  //
  // Deliberately not inside either content block: it is the one element that
  // survives the transition, so it is positioned against the island itself and
  // simply animates from centre to corner.
  Item {
    id: clock

    width: clockRow.implicitWidth
    height: clockRow.implicitHeight

    x: root.open ? root.pad : (root.width - width) / 2
    y: root.open ? root.pad : (root.height - height) / 2

    Behavior on x { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
    Behavior on y { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }

    Row {
      id: clockRow
      spacing: 8

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: hub.timeText
        color: bar.foreground
        font.family: bar.fontFamily
        font.pixelSize: root.open ? 27 : 13
        font.weight: root.open ? Font.DemiBold : Font.Medium
        Behavior on font.pixelSize { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
      }

      // A quiet failure dot, the only thing the closed pill ever says beyond
      // the time. Anything louder belongs behind the click.
      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: 6; height: 6; radius: 3
        color: bar.urgent
        visible: !root.open && hub.failedCount > 0
      }
    }
  }

  // --------------------------------------------------------- closed content
  Row {
    id: collapsedRow
    anchors.centerIn: parent
    spacing: 8
    opacity: 0
    // Never drawn: it exists so the closed pill can size itself to the clock
    // without measuring the clock item, which is busy animating.
    Text {
      text: hub.timeText
      font.family: bar.fontFamily
      font.pixelSize: 13
      font.weight: Font.Medium
    }
  }

  // ----------------------------------------------------------- open content
  Loader {
    id: bodyLoader

    anchors.fill: parent
    active: root.open || body.opacity > 0.01
    sourceComponent: bodyComponent
  }

  // Named so the Loader's `active` guard above can watch the fade out and keep
  // the tree alive until it finishes.
  QtObject {
    id: body
    property real opacity: root.open ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: root.open ? 220 : 120; easing.type: Easing.OutCubic } }
  }

  Component {
    id: bodyComponent

    Item {
      anchors.fill: parent
      opacity: body.opacity
      // Content that is fading out must not keep swallowing clicks.
      enabled: root.open

      IslandBody {
        anchors.fill: parent
        bar: root.bar
        hub: root.hub
        island: root
        screenName: root.screenName
        onCloseRequested: root.closeRequested()
      }
    }
  }

  // ------------------------------------------------------------ interaction
  //
  // Only the closed pill toggles on click. Once open, clicks inside the panel
  // belong to the cards; closing is Esc, the close button, or a click outside.
  MouseArea {
    anchors.fill: parent
    enabled: !root.open
    cursorShape: Qt.PointingHandCursor
    onClicked: root.toggleRequested()
  }

  // A closed pill lifts very slightly under the pointer — enough to read as
  // pressable, not enough to become another moving part.
  HoverHandler {
    id: hover
    enabled: !root.open
  }
  scale: (!root.open && hover.hovered) ? 1.04 : 1.0
  Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
}
