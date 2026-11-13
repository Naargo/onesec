#pragma once

#include <QObject>
#include <QStringList>

class Config;

// One pause, in front of one or more apps. Their windows wait on a hidden
// workspace (hypr/onesec.lua put them there) until the person chooses: going
// on brings them back, not going on closes them. Websites work the same way
// through the browser extension. Usually the windows are
// just opening; when OneSec is turned on they may be windows that were
// already open. A preview has no windows behind it.
class Pause : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString appName READ appName CONSTANT)
    Q_PROPERTY(QString phrase READ phrase CONSTANT)
    Q_PROPERTY(int breaths READ breaths CONSTANT)
    Q_PROPERTY(int attempts READ attempts CONSTANT)
    Q_PROPERTY(bool preview READ preview CONSTANT)
    Q_PROPERTY(bool alreadyOpen READ alreadyOpen CONSTANT)
    Q_PROPERTY(bool offerYouLearn READ offerYouLearn CONSTANT)

public:
    enum Kind { Opening, AlreadyOpen, Preview };

    // With forSites, the targets are websites the browser extension is
    // holding, not window classes: the choice comes back as the exit code
    // (see result()) instead of going to Hyprland.
    Pause(Config &config, const QStringList &targets, Kind kind, bool forSites = false, QObject *parent = nullptr);

    // For websites: 0 to go on, Stopped to close the tabs, YouLearn to close
    // them and open YouLearn instead.
    static constexpr int Stopped = 3;
    static constexpr int YouLearn = 4;
    int result() const { return m_result; }

    QString appName() const { return m_appName; }
    QString phrase() const { return m_phrase; }
    int breaths() const { return m_breaths; }
    int attempts() const { return m_attempts; }
    bool preview() const { return m_kind == Preview; }
    bool alreadyOpen() const { return m_kind == AlreadyOpen; }

    // YouTube's pause offers YouLearn, when it's installed, as the better
    // way in: study instead of scroll.
    bool offerYouLearn() const { return m_offerYouLearn; }
    static bool isYouTube(const QString &site);

    Q_INVOKABLE void continueToApp();
    Q_INVOKABLE void openYouLearn();
    Q_INVOKABLE void dontOpen();

    // "YouTube", "YouTube and Discord", "YouTube, Discord and X".
    static QString joinNames(const QStringList &names);

signals:
    void finished();

private:
    void finish(const QString &function);

    QStringList m_windowClasses;
    bool m_forSites = false;
    bool m_offerYouLearn = false;
    int m_result = 0;
    QString m_appName;
    QString m_phrase;
    int m_breaths = 1;
    int m_attempts = 0;
    Kind m_kind = Opening;
    bool m_done = false;
};

// Lua string literal for a value passed to hypr/onesec.lua.
QString luaQuote(const QString &text);
