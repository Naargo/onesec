#pragma once

#include <QObject>

class Config;

// One pause, in front of one app. The app's window waits on a hidden
// workspace (hypr/onesec.lua put it there) until the person chooses: going
// on brings it back, not opening closes it. A preview has no window behind it.
class Pause : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString appName READ appName CONSTANT)
    Q_PROPERTY(QString phrase READ phrase CONSTANT)
    Q_PROPERTY(int breaths READ breaths CONSTANT)
    Q_PROPERTY(int attempts READ attempts CONSTANT)
    Q_PROPERTY(bool preview READ preview CONSTANT)

public:
    Pause(Config &config, const QString &windowClass, bool preview, QObject *parent = nullptr);

    QString appName() const { return m_appName; }
    QString phrase() const { return m_phrase; }
    int breaths() const { return m_breaths; }
    int attempts() const { return m_attempts; }
    bool preview() const { return m_preview; }

    Q_INVOKABLE void continueToApp();
    Q_INVOKABLE void dontOpen();

signals:
    void finished();

private:
    void finish(const QString &luaCall);

    QString m_windowClass;
    QString m_appName;
    QString m_phrase;
    int m_breaths = 1;
    int m_attempts = 0;
    bool m_preview = false;
    bool m_done = false;
};

// Lua string literal for a value passed to hypr/onesec.lua.
QString luaQuote(const QString &text);
