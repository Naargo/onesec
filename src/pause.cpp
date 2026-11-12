#include "pause.h"

#include "config.h"

QString luaQuote(const QString &text) {
    QString escaped = text;
    escaped.replace('\\', "\\\\").replace('"', "\\\"").replace('\n', "\\n");
    return '"' + escaped + '"';
}

Pause::Pause(Config &config, const QString &windowClass, bool preview, QObject *parent)
    : QObject(parent),
      m_windowClass(windowClass),
      m_appName(config.nameForClass(windowClass)),
      m_phrase(config.phrase()),
      m_breaths(config.breaths()),
      m_preview(preview) {
    // A preview isn't a real open, so it doesn't count.
    m_attempts = preview ? config.attemptsToday(windowClass) + 1 : config.recordAttempt(windowClass);
}

void Pause::continueToApp() {
    finish(QString("onesec_release(%1)").arg(luaQuote(m_windowClass)));
}

void Pause::dontOpen() {
    finish(QString("onesec_dismiss(%1)").arg(luaQuote(m_windowClass)));
}

void Pause::finish(const QString &luaCall) {
    if (m_done)
        return;
    m_done = true;
    if (!m_preview)
        tellHyprland(luaCall);
    emit finished();
}
