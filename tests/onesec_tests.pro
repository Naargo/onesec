QT += core gui testlib
CONFIG += c++17 testcase
TARGET = onesec_tests
TEMPLATE = app

INCLUDEPATH += ../src

HEADERS += ../src/config.h ../src/appcatalog.h ../src/pause.h
SOURCES += onesec_tests.cpp ../src/config.cpp ../src/appcatalog.cpp ../src/pause.cpp
