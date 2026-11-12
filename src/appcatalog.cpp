#include "appcatalog.h"

#include <QCollator>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QSet>
#include <QStandardPaths>
#include <algorithm>

AppCatalog::AppCatalog(const QStringList &directories, QObject *parent)
    : QObject(parent),
      m_directories(directories.isEmpty()
                        ? QStandardPaths::standardLocations(QStandardPaths::ApplicationsLocation)
                        : directories) {}

// Only the [Desktop Entry] group counts; actions further down have their own
// Name and Exec lines that would otherwise overwrite the app's.
QVariantMap AppCatalog::readDesktopFile(const QString &path) {
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
        return {};

    QHash<QString, QString> entry;
    bool inEntry = false;
    while (!file.atEnd()) {
        const QString line = QString::fromUtf8(file.readLine()).trimmed();
        if (line.startsWith('[')) {
            inEntry = line == "[Desktop Entry]";
            continue;
        }
        const int equals = line.indexOf('=');
        if (!inEntry || line.startsWith('#') || equals < 1)
            continue;
        entry.insert(line.left(equals).trimmed(), line.mid(equals + 1).trimmed());
    }

    if (entry.value("Type") != "Application" || entry.value("NoDisplay") == "true"
        || entry.value("Hidden") == "true" || entry.value("Name").isEmpty())
        return {};

    const QString id = QFileInfo(path).completeBaseName();
    QStringList classes{id};
    const QString wmClass = entry.value("StartupWMClass");
    if (!wmClass.isEmpty() && wmClass != id)
        classes.prepend(wmClass);

    return {{"id", id}, {"name", entry.value("Name")}, {"icon", entry.value("Icon")}, {"classes", classes}};
}

QVariantList AppCatalog::apps() const {
    QSet<QString> seen;
    QList<QVariantMap> found;
    // Earlier directories win: a file in ~/.local/share/applications
    // overrides the system one with the same name, as it does in the launcher.
    for (const auto &directory : m_directories) {
        const auto files = QDir(directory).entryInfoList({"*.desktop"}, QDir::Files | QDir::Readable);
        for (const auto &info : files) {
            const QString id = info.completeBaseName();
            if (seen.contains(id))
                continue;
            seen.insert(id);
            const auto app = readDesktopFile(info.absoluteFilePath());
            if (!app.isEmpty() && id != "onesec")
                found.append(app);
        }
    }

    QCollator collator;
    collator.setCaseSensitivity(Qt::CaseInsensitive);
    std::sort(found.begin(), found.end(), [&](const QVariantMap &a, const QVariantMap &b) {
        return collator.compare(a.value("name").toString(), b.value("name").toString()) < 0;
    });

    QVariantList list;
    for (const auto &app : found)
        list.append(app);
    return list;
}
