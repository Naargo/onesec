#include <QFile>
#include <QSignalSpy>
#include <QTemporaryDir>
#include <QtTest>

#include "appcatalog.h"
#include "config.h"
#include "pause.h"

static void write(const QString &path, const QByteArray &data) {
    QFile file(path);
    QVERIFY(file.open(QIODevice::WriteOnly));
    file.write(data);
}

static QVariantMap app(const QString &id, const QString &name, const QStringList &classes) {
    return {{"id", id}, {"name", name}, {"icon", id}, {"classes", classes}};
}

class OneSecTests : public QObject {
    Q_OBJECT

private slots:
    void initTestCase() {
        // Never touch the real Hyprland session from the tests.
        qputenv("ONESEC_NO_HYPRLAND", "1");
    }

    void settingsSurviveARestart() {
        QTemporaryDir config, state;
        {
            Config c(config.path(), state.path());
            QVERIFY(!c.enabled());
            c.setEnabled(true);
            c.setBreaths(3);
            c.setGraceMinutes(10);
            c.setPhrase("Slow down");
            c.setWatched(app("YouTube", "YouTube", {"brave-youtube.com__-Default", "YouTube"}), true);
        }
        Config c(config.path(), state.path());
        QVERIFY(c.enabled());
        QCOMPARE(c.breaths(), 3);
        QCOMPARE(c.graceMinutes(), 10);
        QCOMPARE(c.phrase(), QString("Slow down"));
        QVERIFY(c.isWatched("YouTube"));
        QCOMPARE(c.nameForClass("brave-youtube.com__-Default"), QString("YouTube"));
    }

    void valuesStayInRange() {
        QTemporaryDir config, state;
        Config c(config.path(), state.path());
        c.setBreaths(40);
        QCOMPARE(c.breaths(), 5);
        c.setGraceMinutes(-3);
        QCOMPARE(c.graceMinutes(), 0);
        c.setPhrase("   ");
        QCOMPARE(c.phrase(), Config::defaultPhrase());
    }

    void unwatchingRemovesTheApp() {
        QTemporaryDir config, state;
        Config c(config.path(), state.path());
        c.setWatched(app("a", "A", {"a"}), true);
        c.setWatched(app("b", "B", {"b", "a"}), true);
        QCOMPARE(c.watchedClasses(), QStringList({"a", "b"}));
        c.setWatched(app("a", "A", {"a"}), false);
        QVERIFY(!c.isWatched("a"));
        QCOMPARE(c.watchedClasses(), QStringList({"b", "a"}));
    }

    void hyprStateIsLuaTheHookCanLoad() {
        QTemporaryDir config, state;
        Config c(config.path(), state.path());
        c.setCommand("/usr/bin/onesec");
        c.setWatched(app("odd", "Odd", {"we\"ird\\class"}), true);
        c.setEnabled(true);
        const QString lua = c.hyprState();
        QVERIFY(lua.contains("enabled = true"));
        QVERIFY(lua.contains("\"we\\\"ird\\\\class\""));
        QVERIFY(lua.contains("grace = 300"));
        QVERIFY(lua.contains("command = \"/usr/bin/onesec\""));
        QVERIFY(QFile::exists(c.hyprStateFile()));
    }

    void countsBelongToTheAppAndResetEachDay() {
        QTemporaryDir config, state;
        Config c(config.path(), state.path());
        c.setWatched(app("discord", "Discord", {"discord", "chrome-discord.com__-Default"}), true);
        const QDate monday(2026, 11, 9);
        QCOMPARE(c.recordAttempt("discord", monday), 1);
        QCOMPARE(c.recordAttempt("chrome-discord.com__-Default", monday), 2);
        QCOMPARE(c.attemptsToday("discord", monday), 2);
        QCOMPARE(c.pausesToday(monday), 2);
        QCOMPARE(c.recordAttempt("discord", monday.addDays(1)), 1);
        QCOMPARE(c.pausesToday(monday), 0);
    }

    void aPreviewDoesNotCount() {
        QTemporaryDir config, state;
        Config c(config.path(), state.path());
        Pause preview(c, "YouTube", true);
        QCOMPARE(preview.attempts(), 1);
        QCOMPARE(c.attemptsToday("YouTube"), 0);
        Pause real(c, "YouTube", false);
        QCOMPARE(real.attempts(), 1);
        QCOMPARE(c.attemptsToday("YouTube"), 1);
    }

    void aPauseAnswersOnce() {
        QTemporaryDir config, state;
        Config c(config.path(), state.path());
        Pause pause(c, "YouTube", false);
        QSignalSpy finished(&pause, &Pause::finished);
        pause.dontOpen();
        pause.continueToApp();
        QCOMPARE(finished.count(), 1);
    }

    void desktopFilesBecomeApps() {
        QTemporaryDir dir;
        write(dir.filePath("YouTube.desktop"),
              "[Desktop Entry]\nType=Application\nName=YouTube\nIcon=/icons/yt.png\n"
              "StartupWMClass=brave-youtube.com__-Default\n\n[Desktop Action new]\nName=New window\n");
        write(dir.filePath("hidden.desktop"), "[Desktop Entry]\nType=Application\nName=Hidden\nNoDisplay=true\n");
        write(dir.filePath("link.desktop"), "[Desktop Entry]\nType=Link\nName=A link\n");
        write(dir.filePath("alacritty.desktop"), "[Desktop Entry]\nType=Application\nName=Alacritty\nIcon=Alacritty\n");

        const auto apps = AppCatalog({dir.path()}).apps();
        QCOMPARE(apps.size(), 2);
        const auto first = apps[0].toMap();
        QCOMPARE(first.value("name").toString(), QString("Alacritty"));
        QCOMPARE(first.value("classes").toStringList(), QStringList({"alacritty"}));
        const auto youtube = apps[1].toMap();
        QCOMPARE(youtube.value("name").toString(), QString("YouTube"));
        QCOMPARE(youtube.value("classes").toStringList(), QStringList({"brave-youtube.com__-Default", "YouTube"}));
    }

    void aUserFileHidesTheSystemOne() {
        QTemporaryDir user, system;
        write(user.filePath("foot.desktop"), "[Desktop Entry]\nType=Application\nName=Foot\nHidden=true\n");
        write(system.filePath("foot.desktop"), "[Desktop Entry]\nType=Application\nName=Foot\n");
        QCOMPARE(AppCatalog({user.path(), system.path()}).apps().size(), 0);
    }
};

QTEST_GUILESS_MAIN(OneSecTests)
#include "onesec_tests.moc"
