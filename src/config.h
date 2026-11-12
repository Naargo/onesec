#pragma once

#include <QDate>
#include <QObject>
#include <QStringList>
#include <QVariantList>

// Everything OneSec remembers: whether it's on, which apps get a pause, how
// the pause goes, and how many times each app was opened today.
//
// config.json holds the settings. Hyprland can't read JSON, so every save
// also writes hypr.lua, a plain Lua table the hook in hypr/onesec.lua loads,
// and asks Hyprland to reload it.
class Config : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool enabled READ enabled WRITE setEnabled NOTIFY changed)
    Q_PROPERTY(QVariantList apps READ apps NOTIFY changed)
    Q_PROPERTY(QStringList sites READ sites NOTIFY changed)
    Q_PROPERTY(int breaths READ breaths WRITE setBreaths NOTIFY changed)
    Q_PROPERTY(QString phrase READ phrase WRITE setPhrase NOTIFY changed)
    Q_PROPERTY(int graceMinutes READ graceMinutes WRITE setGraceMinutes NOTIFY changed)
    Q_PROPERTY(int pausesToday READ pausesToday NOTIFY countsChanged)
    Q_PROPERTY(bool hookLoaded READ hookLoaded NOTIFY changed)

public:
    // Empty directories mean the real ones under ~/.config and ~/.local/state.
    explicit Config(const QString &configDirectory = {}, const QString &stateDirectory = {},
                    QObject *parent = nullptr);

    static QString defaultPhrase();

    bool enabled() const { return m_enabled; }
    QVariantList apps() const { return m_apps; }
    int breaths() const { return m_breaths; }
    QString phrase() const { return m_phrase; }
    int graceMinutes() const { return m_graceMinutes; }

    // False when Hyprland answered that it doesn't know onesec_sync(): the
    // hook in hypr/onesec.lua isn't loaded, so nothing would get paused.
    bool hookLoaded() const { return m_hookLoaded; }

    // Shows the pause as it will look, with nothing behind it.
    Q_INVOKABLE void tryPause() const;

    void setEnabled(bool enabled);
    void setBreaths(int breaths);
    void setPhrase(const QString &phrase);
    void setGraceMinutes(int minutes);

    // An app is {id, name, icon, classes}. Its window classes are what the
    // Hyprland hook matches; the id is the .desktop file it came from.
    Q_INVOKABLE bool isWatched(const QString &id) const;
    Q_INVOKABLE void setWatched(const QVariantMap &app, bool watched);

    // Websites get the pause too, through the browser extension. Each is a
    // bare domain ("youtube.com") that also covers its subdomains.
    QStringList sites() const { return m_sites; }
    // "https://www.YouTube.com/watch?v=1" -> "youtube.com"; empty if it
    // isn't a usable domain.
    static QString normalizeSite(const QString &text);
    // False when the text isn't a domain or the site is already there.
    Q_INVOKABLE bool addSite(const QString &text);
    Q_INVOKABLE void removeSite(const QString &site);

    // Every window class the hook should hold back, without duplicates.
    QStringList watchedClasses() const;
    // The name to show for a window class, or the class itself if no
    // watched app claims it.
    QString nameForClass(const QString &windowClass) const;

    // Counts one more open of the app behind this class today, and returns
    // the new count. Counts reset when the day changes.
    int recordAttempt(const QString &windowClass, const QDate &today = QDate::currentDate());
    int attemptsToday(const QString &windowClass, const QDate &today = QDate::currentDate()) const;
    int pausesToday(const QDate &today = QDate::currentDate()) const;

    // The Lua table hypr/onesec.lua loads.
    QString hyprState() const;

    QString command() const;
    void setCommand(const QString &command) { m_command = command; }

    QString configFile() const;
    QString hyprStateFile() const;

    void reload();

signals:
    void changed();
    void countsChanged();

private:
    void save();
    void saveCounts();
    void loadCounts();
    QString keyForClass(const QString &windowClass) const;

    QString m_configDirectory;
    QString m_stateDirectory;
    bool m_enabled = false;
    QVariantList m_apps;
    QStringList m_sites;
    int m_breaths = 1;
    QString m_phrase;
    int m_graceMinutes = 5;
    QDate m_countsDay;
    QVariantMap m_counts;
    QString m_command;
    bool m_hookLoaded = true;
};

// Hyprland calls into hypr/onesec.lua by evaluating Lua through hyprctl.
// Without Hyprland there is nothing to tell, which counts as success; false
// means Hyprland is there but the call failed.
bool tellHyprland(const QString &luaCall);
