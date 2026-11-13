#include "pause.h"

#include "config.h"

#include <QStandardPaths>

QString luaQuote(const QString &text) {
    QString escaped = text;
    escaped.replace('\\', "\\\\").replace('"', "\\\"").replace('\n', "\\n");
    return '"' + escaped + '"';
}

QString Pause::joinNames(const QStringList &names) {
    if (names.size() <= 1)
        return names.value(0);
    return tr("%1 and %2").arg(names.mid(0, names.size() - 1).join(", "), names.last());
}

Pause::Pause(Config &config, const QStringList &windowClasses, Kind kind, bool forSites, QObject *parent)
    : QObject(parent),
      m_windowClasses(windowClasses),
      m_forSites(forSites),
      m_phrase(config.phrase()),
      m_breaths(config.breaths()),
      m_kind(kind) {
    QStringList names;
    for (const auto &windowClass : windowClasses) {
        const auto name = config.nameForClass(windowClass);
        if (!names.contains(name))
            names.append(name);
    }
    m_appName = joinNames(names);

    if (forSites && !QStandardPaths::findExecutable("youlearn").isEmpty())
        for (const auto &site : windowClasses)
            if (isYouTube(site))
                m_offerYouLearn = true;

    // Only a real open counts. A preview isn't one, and windows that were
    // already open when OneSec came on weren't opened just now.
    const auto first = windowClasses.value(0);
    m_attempts = kind == Opening ? config.recordAttempt(first) : config.attemptsToday(first) + 1;
}

bool Pause::isYouTube(const QString &site) {
    for (const auto *domain : {"youtube.com", "youtu.be"})
        if (site == domain || site.endsWith(QString(".") + domain))
            return true;
    return false;
}

void Pause::openYouLearn() {
    finish("onesec_youlearn");
}

void Pause::continueToApp() {
    finish("onesec_release");
}

void Pause::dontOpen() {
    finish("onesec_dismiss");
}

void Pause::finish(const QString &function) {
    if (m_done)
        return;
    m_done = true;
    if (m_forSites) {
        m_result = function == "onesec_dismiss" ? Stopped : function == "onesec_youlearn" ? YouLearn : 0;
    } else if (m_kind != Preview) {
        QStringList arguments;
        for (const auto &windowClass : m_windowClasses)
            arguments.append(luaQuote(windowClass));
        tellHyprland(QString("%1(%2)").arg(function, arguments.join(", ")));
    }
    emit finished();
}
