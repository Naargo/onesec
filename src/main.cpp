// onesec: a breathing pause in front of the apps you pick, for Omarchy.
//
//   onesec                 open the settings
//   onesec toggle [on|off] turn OneSec on or off (Super + `)
//   onesec status          print "on" or "off"
//   onesec pause <class>   the pause, started by hypr/onesec.lua
//   onesec preview         the pause as it will look, with nothing behind it

#include <QCoreApplication>
#include <QGuiApplication>
#include <QIcon>
#include <QProcess>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickImageProvider>
#include <QQuickStyle>
#include <QQuickWindow>
#include <QTimer>
#include <QUrl>
#include <LayerShellQt/window.h>
#include <cstdio>
#include <cstring>

#include "appcatalog.h"
#include "config.h"
#include "pause.h"
#include "theme.h"
#include "translator.h"

static const char *Version = "0.1.0";

// App icons by the name in their .desktop file, from the icon theme, or by
// path for the web apps that point at their own PNG.
class IconProvider : public QQuickImageProvider {
public:
    IconProvider() : QQuickImageProvider(QQuickImageProvider::Pixmap) {}

    QPixmap requestPixmap(const QString &id, QSize *size, const QSize &requested) override {
        const QString name = QUrl::fromPercentEncoding(id.toUtf8());
        const QSize wanted = requested.isValid() ? requested : QSize(64, 64);
        const QIcon icon = name.startsWith('/') ? QIcon(name) : QIcon::fromTheme(name);
        const QPixmap pixmap = icon.pixmap(wanted);
        if (size)
            *size = pixmap.size();
        return pixmap;
    }
};

// Qt only finds app icons when it knows the desktop's icon theme, which
// Omarchy sets through GNOME's settings rather than anything Qt reads.
static void useDesktopIconTheme() {
    QProcess gsettings;
    gsettings.start("gsettings", {"get", "org.gnome.desktop.interface", "icon-theme"});
    if (gsettings.waitForFinished(1000) && gsettings.exitCode() == 0) {
        QString name = QString::fromUtf8(gsettings.readAllStandardOutput()).trimmed();
        name.remove('\'');
        if (!name.isEmpty())
            QIcon::setThemeName(name);
    }
    QIcon::setFallbackThemeName("hicolor");
}

static void notify(const QString &title, const QString &body) {
    QProcess::startDetached("notify-send", {"-a", "OneSec", "-i", "onesec", "-t", "2500",
                                            "-h", "string:x-canonical-private-synchronous:onesec", title, body});
}

static int toggle(int argc, char *argv[]) {
    QCoreApplication app(argc, argv);
    Translator translator;
    app.installTranslator(&translator);
    Config config;

    bool on = !config.enabled();
    if (argc >= 3 && std::strcmp(argv[2], "on") == 0)
        on = true;
    else if (argc >= 3 && std::strcmp(argv[2], "off") == 0)
        on = false;
    config.setEnabled(on);

    if (!on) {
        // A pause on screen right now has nothing left to guard.
        QProcess::execute("pkill", {"-f", "^\\S*onesec pause "});
    }

    if (!config.hookLoaded())
        notify(QCoreApplication::translate("main", "OneSec isn't loaded in Hyprland"),
               QCoreApplication::translate("main", "Open OneSec to see how to load it."));
    else if (on)
        notify(QCoreApplication::translate("main", "OneSec is on"),
               config.watchedClasses().isEmpty()
                   ? QCoreApplication::translate("main", "No apps picked yet. Open OneSec to pick some.")
                   : QCoreApplication::translate("main", "Your picked apps open after a breath."));
    else
        notify(QCoreApplication::translate("main", "OneSec is off"),
               QCoreApplication::translate("main", "Apps open right away."));
    return 0;
}

static int status(int argc, char *argv[]) {
    QCoreApplication app(argc, argv);
    qputenv("ONESEC_NO_HYPRLAND", "1");
    Config config;
    fprintf(stdout, "%s\n", config.enabled() ? "on" : "off");
    return 0;
}

// ONESEC_GRAB="a.png@1500,b.png@9000" saves the window at those moments and
// then quits. It's how the README screenshots are made, offscreen, without
// touching the desktop.
static void grabWhenAsked(QQuickWindow *window) {
    const QString spec = qEnvironmentVariable("ONESEC_GRAB");
    if (spec.isEmpty())
        return;
    int last = 0;
    for (const auto &part : spec.split(',', Qt::SkipEmptyParts)) {
        const auto file = part.section('@', 0, 0);
        const int at = part.section('@', 1, 1).toInt();
        last = qMax(last, at);
        QTimer::singleShot(at, window, [window, file] { window->grabWindow().save(file); });
    }
    QTimer::singleShot(last + 100, qApp, &QCoreApplication::quit);
}

static int runPause(QGuiApplication &app, Translator &translator, const QString &windowClass, bool preview) {
    Theme theme;
    Config config;
    QString shownClass = windowClass;
    if (preview && shownClass.isEmpty()) {
        const auto classes = config.watchedClasses();
        shownClass = classes.isEmpty() ? QString("YouTube") : classes.first();
    }
    Pause pause(config, shownClass, preview);

    QQmlApplicationEngine engine;
    QObject::connect(&translator, &Translator::changed, &engine, &QQmlEngine::retranslate);
    engine.rootContext()->setContextProperty("theme", &theme);
    engine.rootContext()->setContextProperty("session", &pause);
    engine.load(QUrl("qrc:/Pause.qml"));
    if (engine.rootObjects().isEmpty()) {
        // Without the screen there's no choice to make; let the app through
        // rather than stranding its window.
        pause.continueToApp();
        return 1;
    }
    auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().first());

    // Above everything, the bar included, with the keyboard to itself, on
    // the screen you're looking at.
    if (QGuiApplication::platformName() == "wayland")
        if (auto *layer = LayerShellQt::Window::get(window)) {
        layer->setLayer(LayerShellQt::Window::LayerOverlay);
        layer->setAnchors(LayerShellQt::Window::Anchors(LayerShellQt::Window::AnchorTop | LayerShellQt::Window::AnchorBottom
                                                        | LayerShellQt::Window::AnchorLeft | LayerShellQt::Window::AnchorRight));
        layer->setExclusiveZone(-1);
        layer->setKeyboardInteractivity(LayerShellQt::Window::KeyboardInteractivityExclusive);
        layer->setScope("onesec");
    }
    window->show();
    grabWhenAsked(window);
    return app.exec();
}

int main(int argc, char *argv[]) {
    const QString command = argc >= 2 ? QString::fromLocal8Bit(argv[1]) : QString("open");

    if (command == "toggle")
        return toggle(argc, argv);
    if (command == "status")
        return status(argc, argv);
    if (command == "--version" || command == "version") {
        fprintf(stdout, "onesec %s\n", Version);
        return 0;
    }
    if (command == "pause" && argc < 3) {
        fprintf(stderr, "usage: onesec pause <window-class>\n");
        return 1;
    }
    if (command != "open" && command != "pause" && command != "preview") {
        fprintf(stderr, "usage: onesec [open | toggle [on|off] | status | pause <class> | preview]\n");
        return 1;
    }

    QGuiApplication app(argc, argv);
    app.setApplicationName("onesec");
    app.setApplicationVersion(Version);
    // Matches the window to onesec.desktop, so the compositor (Wayland
    // app_id) and the launcher pick up the installed icon.
    app.setDesktopFileName("onesec");
    QQuickStyle::setStyle("Material");

    // Installed before anything is translated, and every qsTr() binding is
    // re-evaluated when the Omarchy language changes.
    Translator translator;
    app.installTranslator(&translator);

    if (command == "pause" || command == "preview")
        return runPause(app, translator, argc >= 3 ? QString::fromLocal8Bit(argv[2]) : QString(), command == "preview");

    useDesktopIconTheme();
    app.setWindowIcon(QIcon::fromTheme("onesec"));

    Theme theme;
    Config config;
    AppCatalog catalog;

    QQmlApplicationEngine engine;
    QObject::connect(&translator, &Translator::changed, &engine, &QQmlEngine::retranslate);
    engine.addImageProvider("icon", new IconProvider);
    engine.rootContext()->setContextProperty("translator", &translator);
    engine.rootContext()->setContextProperty("theme", &theme);
    engine.rootContext()->setContextProperty("config", &config);
    engine.rootContext()->setContextProperty("catalog", &catalog);
    engine.load(QUrl("qrc:/Main.qml"));
    if (engine.rootObjects().isEmpty())
        return 1;
    grabWhenAsked(qobject_cast<QQuickWindow *>(engine.rootObjects().first()));
    return app.exec();
}
