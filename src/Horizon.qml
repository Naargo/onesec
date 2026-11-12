import QtQuick
import QtQuick.Shapes

// The breath, drawn as a navy horizon rising out of the bottom of the
// screen: a huge, gently curved body lit from its crest, a thin bright rim,
// and a soft halo of light above it. A second, dimmer layer sits behind and
// trails a little, for depth. Only `level` moves it, straight up and down,
// so the motion stays calm.
Item {
    id: horizon
    property real level: 0

    readonly property real w: width
    readonly property real h: height
    // Wider than the screen, so the curve is gentle.
    readonly property real radius: Math.max(w * 0.95, h * 1.1)
    readonly property real glow: h * 0.42

    // How far up the crest is, in pixels from the top of the screen.
    function crestY(l) { return h - l * h * 0.92 - h * 0.02 }

    // The far layer: larger, dimmer, a breath behind.
    Shape {
        id: far
        anchors.fill: parent
        opacity: 0.55
        property real cy: horizon.crestY(horizon.level * 0.9 + 0.04) + horizon.radius * 1.2
        property real r: horizon.radius * 1.2
        ShapePath {
            strokeWidth: -1
            fillGradient: RadialGradient {
                centerX: horizon.w / 2; centerY: far.cy; centerRadius: far.r + horizon.glow
                focalX: centerX; focalY: centerY
                GradientStop { position: 0.0; color: "#0d1a48" }
                GradientStop { position: far.r / (far.r + horizon.glow); color: "#1a2f73" }
                GradientStop { position: 1.0; color: "#001a2f73" }
            }
            PathAngleArc {
                centerX: horizon.w / 2; centerY: far.cy
                radiusX: far.r + horizon.glow; radiusY: far.r + horizon.glow
                startAngle: 0; sweepAngle: 360
            }
        }
    }

    // The near layer: halo, body and rim.
    Shape {
        id: near
        anchors.fill: parent
        property real cy: horizon.crestY(horizon.level) + horizon.radius
        property real r: horizon.radius

        // Halo: light spilling off the crest into the dark.
        ShapePath {
            strokeWidth: -1
            fillGradient: RadialGradient {
                centerX: horizon.w / 2; centerY: near.cy; centerRadius: near.r + horizon.glow
                focalX: centerX; focalY: centerY
                GradientStop { position: near.r / (near.r + horizon.glow) - 0.01; color: "#664f74e0" }
                GradientStop { position: near.r / (near.r + horizon.glow) + (1 - near.r / (near.r + horizon.glow)) * 0.35; color: "#1f3a5fd0" }
                GradientStop { position: 1.0; color: "#003a5fd0" }
            }
            PathAngleArc {
                centerX: horizon.w / 2; centerY: near.cy
                radiusX: near.r + horizon.glow; radiusY: near.r + horizon.glow
                startAngle: 0; sweepAngle: 360
            }
        }

        // Body, brightest just under the crest and deepening below.
        ShapePath {
            strokeWidth: 1.5
            strokeColor: "#8aa6f5"
            fillGradient: RadialGradient {
                centerX: horizon.w / 2; centerY: near.cy; centerRadius: near.r
                focalX: horizon.w / 2; focalY: near.cy - near.r * 0.96; focalRadius: 0
                GradientStop { position: 0.00; color: "#6f8ff0" }
                GradientStop { position: 0.10; color: "#3e60cf" }
                GradientStop { position: 0.32; color: "#1f3a8a" }
                GradientStop { position: 0.70; color: "#122660" }
                GradientStop { position: 1.00; color: "#0a1640" }
            }
            PathAngleArc {
                centerX: horizon.w / 2; centerY: near.cy
                radiusX: near.r; radiusY: near.r
                startAngle: 0; sweepAngle: 360
            }
        }
    }
}
