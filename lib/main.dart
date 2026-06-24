import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/contacts_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/import_screen.dart';
import 'screens/preview_screen.dart';
import 'screens/report_screen.dart';
import 'screens/send_screen.dart';
import 'screens/settings_screen.dart';
import 'services/local_db_service.dart';
import 'theme/brand_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalDbService.instance.init();
  runApp(const SmsSenderApp());
}

class SmsSenderApp extends StatelessWidget {
  const SmsSenderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ارسال پیامک محلی',
      debugShowCheckedModeBanner: false,
      locale: const Locale('fa', 'IR'),
      supportedLocales: const [Locale('fa', 'IR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: buildSmsSenderTheme(),
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: RootShell(),
      ),
    );
  }
}

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;
  static const _screens = [
    DashboardScreen(),
    ImportScreen(),
    ContactsScreen(),
    PreviewScreen(),
    SendScreen(),
    ReportScreen(),
    SettingsScreen(),
  ];
  static const _destinations = [
    _AppDestination(icon: Icons.dashboard, label: 'داشبورد'),
    _AppDestination(icon: Icons.upload_file, label: 'ورود'),
    _AppDestination(icon: Icons.contacts, label: 'مخاطبین'),
    _AppDestination(icon: Icons.preview, label: 'پیش‌نمایش'),
    _AppDestination(icon: Icons.send, label: 'ارسال'),
    _AppDestination(icon: Icons.assessment, label: 'گزارش'),
    _AppDestination(icon: Icons.settings, label: 'تنظیمات'),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail = constraints.maxWidth >= 720;
        if (useRail) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: _index,
                  onDestinationSelected: (value) {
                    setState(() => _index = value);
                  },
                  labelType: NavigationRailLabelType.all,
                  destinations: [
                    for (final destination in _destinations)
                      NavigationRailDestination(
                        icon: Icon(destination.icon),
                        selectedIcon: Icon(destination.icon),
                        label: Text(destination.label),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: _screens[_index]),
              ],
            ),
          );
        }

        return Scaffold(
          body: _screens[_index],
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            height: 72,
            labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
            onDestinationSelected: (value) => setState(() => _index = value),
            destinations: [
              for (final destination in _destinations)
                NavigationDestination(
                  icon: Icon(destination.icon),
                  selectedIcon: Icon(destination.icon),
                  label: destination.label,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _AppDestination {
  const _AppDestination({required this.icon, required this.label});

  final IconData icon;
  final String label;
}
