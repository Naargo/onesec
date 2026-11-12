#include "pause.h"

#include "config.h"

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

Pause::Pause(Config &config, const QStringList &windowClasses, Kind kind, QObject *parent)
    : QObject(parent),
      m_windowClasses(windowClasses),
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

    // Only a real open counts. A preview isn't one, and windows that were
    // already open when OneSec came on weren't opened just now.
    const auto first = windowClasses.value(0);
    m_attempts = kind == Opening ? config.recordAttempt(first) : config.attemptsToday(first) + 1;
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
    if (m_kind != Preview) {
        QStringList arguments;
        for (const auto &windowClass : m_windowClasses)
            arguments.append(luaQuote(windowClass));
        tellHyprland(QString("%1(%2)").arg(function, arguments.join(", ")));
    }
    emit finished();
}
