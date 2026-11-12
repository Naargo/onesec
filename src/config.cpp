#include "config.h"

#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcess>
#include <QSaveFile>
#include <QStandardPaths>

Config::Config(const QString &configDirectory, const QString &stateDirectory, QObject *parent)
    : QObject(parent),
      m_configDirectory(configDirectory.isEmpty() ? QDir::homePath() + "/.config/onesec" : configDirectory),
      m_stateDirectory(stateDirectory.isEmpty() ? QDir::homePath() + "/.local/state/onesec" : stateDirectory),
      m_phrase(defaultPhrase()) {
    reload();
}

QString Config::defaultPhrase() {
    return tr("It's time to take a deep breath");
}

// The binary the hook starts for a pause: this one, so a build run straight
// from the project works the same as the installed package.
QString Config::command() const {
    if (!m_command.isEmpty())
        return m_command;
    return QCoreApplication::instance() ? QCoreApplication::applicationFilePath() : QString("onesec");
}

QString Config::configFile() const { return m_configDirectory + "/config.json"; }
QString Config::hyprStateFile() const { return m_stateDirectory + "/hypr.lua"; }

void Config::reload() {
    QFile file(configFile());
    if (file.open(QIODevice::ReadOnly)) {
        const auto object = QJsonDocument::fromJson(file.readAll()).object();
        m_enabled = object.value("enabled").toBool(false);
        m_apps = object.value("apps").toArray().toVariantList();
        m_breaths = qBound(1, object.value("breaths").toInt(1), 5);
        m_phrase = object.value("phrase").toString().trimmed();
        if (m_phrase.isEmpty())
            m_phrase = defaultPhrase();
        m_graceMinutes = qBound(0, object.value("graceMinutes").toInt(5), 60);
    }
    loadCounts();
    m_hookLoaded = tellHyprland("onesec_sync()");
    emit changed();
    emit countsChanged();
}

// Written beside the target and renamed, so a crash never leaves half a file.
static bool writeAtomically(const QString &path, const QByteArray &data) {
    QDir().mkpath(QFileInfo(path).absolutePath());
    QSaveFile file(path);
    if (!file.open(QIODevice::WriteOnly))
        return false;
    file.write(data);
    return file.commit();
}

void Config::save() {
    QJsonObject object{
        {"enabled", m_enabled},
        {"apps", QJsonArray::fromVariantList(m_apps)},
        {"breaths", m_breaths},
        {"phrase", m_phrase == defaultPhrase() ? QString() : m_phrase},
        {"graceMinutes", m_graceMinutes},
    };
    if (!writeAtomically(configFile(), QJsonDocument(object).toJson()))
        qWarning("onesec: couldn't save %s", qPrintable(configFile()));
    if (!writeAtomically(hyprStateFile(), hyprState().toUtf8()))
        qWarning("onesec: couldn't save %s", qPrintable(hyprStateFile()));
    m_hookLoaded = tellHyprland("onesec_sync()");
    emit changed();
}

void Config::tryPause() const {
    QProcess::startDetached(command(), {"preview"});
}

void Config::setEnabled(bool enabled) {
    if (enabled == m_enabled)
        return;
    m_enabled = enabled;
    save();
}

void Config::setBreaths(int breaths) {
    breaths = qBound(1, breaths, 5);
    if (breaths == m_breaths)
        return;
    m_breaths = breaths;
    save();
}

void Config::setPhrase(const QString &phrase) {
    const auto trimmed = phrase.trimmed().isEmpty() ? defaultPhrase() : phrase.trimmed();
    if (trimmed == m_phrase)
        return;
    m_phrase = trimmed;
    save();
}

void Config::setGraceMinutes(int minutes) {
    minutes = qBound(0, minutes, 60);
    if (minutes == m_graceMinutes)
        return;
    m_graceMinutes = minutes;
    save();
}

bool Config::isWatched(const QString &id) const {
    for (const auto &app : m_apps)
        if (app.toMap().value("id").toString() == id)
            return true;
    return false;
}

void Config::setWatched(const QVariantMap &app, bool watched) {
    const auto id = app.value("id").toString();
    if (id.isEmpty() || watched == isWatched(id))
        return;
    if (watched) {
        QVariantMap kept;
        for (const auto *key : {"id", "name", "icon", "classes"})
            kept.insert(key, app.value(key));
        m_apps.append(kept);
    } else {
        for (int i = 0; i < m_apps.size(); ++i)
            if (m_apps[i].toMap().value("id").toString() == id) {
                m_apps.removeAt(i);
                break;
            }
    }
    save();
}

QStringList Config::watchedClasses() const {
    QStringList classes;
    for (const auto &app : m_apps)
        for (const auto &windowClass : app.toMap().value("classes").toStringList())
            if (!windowClass.isEmpty() && !classes.contains(windowClass))
                classes.append(windowClass);
    return classes;
}

QString Config::nameForClass(const QString &windowClass) const {
    for (const auto &app : m_apps) {
        const auto map = app.toMap();
        if (map.value("classes").toStringList().contains(windowClass))
            return map.value("name").toString();
    }
    return windowClass;
}

// Counts belong to the app, not the class, so an app with two window classes
// still counts as one.
QString Config::keyForClass(const QString &windowClass) const {
    for (const auto &app : m_apps) {
        const auto map = app.toMap();
        if (map.value("classes").toStringList().contains(windowClass))
            return map.value("id").toString();
    }
    return windowClass;
}

void Config::loadCounts() {
    m_counts.clear();
    m_countsDay = {};
    QFile file(m_stateDirectory + "/counts.json");
    if (!file.open(QIODevice::ReadOnly))
        return;
    const auto object = QJsonDocument::fromJson(file.readAll()).object();
    m_countsDay = QDate::fromString(object.value("day").toString(), Qt::ISODate);
    m_counts = object.value("counts").toObject().toVariantMap();
}

void Config::saveCounts() {
    const QJsonObject object{{"day", m_countsDay.toString(Qt::ISODate)},
                             {"counts", QJsonObject::fromVariantMap(m_counts)}};
    writeAtomically(m_stateDirectory + "/counts.json", QJsonDocument(object).toJson());
}

int Config::recordAttempt(const QString &windowClass, const QDate &today) {
    // Another process (the settings window, a second pause) may have counted
    // since this one started, so read before adding.
    loadCounts();
    if (m_countsDay != today) {
        m_countsDay = today;
        m_counts.clear();
    }
    const auto key = keyForClass(windowClass);
    const int count = m_counts.value(key).toInt() + 1;
    m_counts.insert(key, count);
    saveCounts();
    emit countsChanged();
    return count;
}

int Config::attemptsToday(const QString &windowClass, const QDate &today) const {
    return m_countsDay == today ? m_counts.value(keyForClass(windowClass)).toInt() : 0;
}

int Config::pausesToday(const QDate &today) const {
    if (m_countsDay != today)
        return 0;
    int total = 0;
    for (const auto &count : m_counts)
        total += count.toInt();
    return total;
}

static QString luaString(const QString &text) {
    QString escaped = text;
    escaped.replace('\\', "\\\\").replace('"', "\\\"").replace('\n', "\\n");
    return '"' + escaped + '"';
}

QString Config::hyprState() const {
    QStringList classes;
    for (const auto &windowClass : watchedClasses())
        classes.append(luaString(windowClass));
    return QString("-- Written by OneSec. Edit settings in the OneSec app, not here.\n"
                   "return {\n"
                   "  enabled = %1,\n"
                   "  classes = { %2 },\n"
                   "  grace = %3,\n"
                   "  command = %4,\n"
                   "}\n")
        .arg(m_enabled ? "true" : "false", classes.join(", "))
        .arg(m_graceMinutes * 60)
        .arg(luaString(command()));
}

bool tellHyprland(const QString &luaCall) {
    if (qEnvironmentVariableIsEmpty("HYPRLAND_INSTANCE_SIGNATURE") || qEnvironmentVariableIsSet("ONESEC_NO_HYPRLAND"))
        return true;
    const auto hyprctl = QStandardPaths::findExecutable("hyprctl");
    if (hyprctl.isEmpty())
        return true;
    QProcess process;
    process.start(hyprctl, {"dispatch", luaCall});
    if (!process.waitForFinished(2000))
        return false;
    return process.exitCode() == 0 && process.readAllStandardOutput().trimmed() == "ok";
}
