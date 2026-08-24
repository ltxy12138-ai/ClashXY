import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clashxy/app/dashboard_shell.dart';
import 'package:clashxy/l10n/app_localizations.dart';

void main() {
  testWidgets('Windows navigation shell exposes Chinese Clash pages', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('zh'),
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: DashboardShell(
          location: '/home',
          child: Center(child: Text('Home content')),
        ),
      ),
    );

    expect(find.text('首页'), findsOneWidget);
    expect(find.text('代理'), findsOneWidget);
    expect(find.text('配置'), findsOneWidget);
    expect(find.text('连接'), findsOneWidget);
    expect(find.text('2S-UI'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
    expect(find.text('Home content'), findsOneWidget);
  });

  testWidgets('navigation shell switches to English from generated locales', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: DashboardShell(
          location: '/home',
          child: Center(child: Text('Page content')),
        ),
      ),
    );

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Proxies'), findsOneWidget);
    expect(find.text('Profiles'), findsOneWidget);
    expect(find.text('Connections'), findsOneWidget);
    expect(find.text('2S-UI'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}
