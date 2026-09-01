import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'pages/dashboard.dart';
import 'pages/report.dart';
import 'pages/settings.dart';
import 'pages/special.dart';
import 'services/db_helper.dart';
import 'services/prefs.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PrefsService.init();
  await DBHelper().warmUp();
  // Lock orientation to portrait for simple Android app
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]).then((_) {
    runApp(const MyApp());
  });
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: PrefsService.themeMode,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'Food Expense',
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          themeMode: mode,
          home: const Home(),
        );
      },
    );
  }
}

class Home extends StatefulWidget {
  const Home({Key? key}) : super(key: key);

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  final _specialKey = GlobalKey<SpecialPageState>();
  final _reportKey = GlobalKey<ReportPageState>();
  late final List<Widget> _pages;

  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pages = [
      const DashboardPage(),
      ReportPage(key: _reportKey),
      SpecialPage(key: _specialKey),
      const SettingsPage(),
    ];
    _pageController = PageController(initialPage: _selectedIndex);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      DBHelper().backupToDownloads();
    }
  }

  void _onTap(int idx) {
    if (idx == 1) _reportKey.currentState?.reload();
    if (idx == 2) _specialKey.currentState?.reload();
    _pageController.animateToPage(idx,
        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  void _onPageChanged(int i) {
    if (i == 1) _reportKey.currentState?.reload();
    if (i == 2) _specialKey.currentState?.reload();
    setState(() => _selectedIndex = i);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        children: _pages,
        onPageChanged: _onPageChanged,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onTap,
        selectedItemColor: Theme.of(context).colorScheme.secondary,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.table_chart), label: 'Report'),
          BottomNavigationBarItem(icon: Icon(Icons.star_outline), label: 'Special'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
