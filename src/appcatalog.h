#pragma once

#include <QObject>
#include <QStringList>
#include <QVariantList>

// The apps in the launcher, read from their .desktop files, so OneSec offers
// the same list Super + Space does. Each is {id, name, icon, classes}: the
// window classes are what Hyprland reports for the app's windows, which is
// usually the .desktop file's name and sometimes its StartupWMClass (web
// apps, Electron apps).
class AppCatalog : public QObject {
    Q_OBJECT

public:
    // Empty means the standard XDG application directories.
    explicit AppCatalog(const QStringList &directories = {}, QObject *parent = nullptr);

    Q_INVOKABLE QVariantList apps() const;

    static QVariantMap readDesktopFile(const QString &path);

private:
    QStringList m_directories;
};
