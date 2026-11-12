QT += core gui qml quick quickcontrols2

CONFIG += c++17 release
TARGET = onesec
TEMPLATE = app

# The pause covers the screen as a layer-shell overlay, above the bar.
INCLUDEPATH += /usr/include/LayerShellQt
LIBS += -lLayerShellQtInterface

HEADERS += \
    src/appcatalog.h \
    src/config.h \
    src/pause.h \
    src/theme.h \
    src/translator.h

SOURCES += \
    src/main.cpp \
    src/appcatalog.cpp \
    src/config.cpp \
    src/pause.cpp \
    src/theme.cpp \
    src/translator.cpp

RESOURCES += src/resources.qrc
