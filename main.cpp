#include <QCommandLineParser>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QTimer>

int main(int argc, char *argv[])
{
    // The race needs the render thread to advance animators on its own.
    qputenv("QSG_RENDER_LOOP", "threaded");

    QGuiApplication app(argc, argv);

    QCommandLineParser parser;
    parser.addHelpOption();
    QCommandLineOption mode("mode", "uniform (bug), number or xanimator (controls)", "mode", "uniform");
    QCommandLineOption seconds("seconds", "Quit after this many seconds", "seconds", "30");
    parser.addOption(mode);
    parser.addOption(seconds);
    parser.process(app);

    QQmlApplicationEngine engine;
    engine.setInitialProperties({{"mode", parser.value(mode)}});
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed, &app,
                     [] { QCoreApplication::exit(2); }, Qt::QueuedConnection);
    engine.loadFromModule("rig", "Main");

    QTimer::singleShot(parser.value(seconds).toInt() * 1000, &app, &QCoreApplication::quit);
    return app.exec();
}
