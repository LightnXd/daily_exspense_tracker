import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'pages/dashboard.dart';
import 'pages/report.dart';
import 'pages/special.dart';
import 'services/prefs.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PrefsService.init();
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

class _HomeState extends State<Home> {
  int _selectedIndex = 0;
  static const _pages = [
    DashboardPage(),
    ReportPage(),
    SpecialPage(),
  ];

  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTap(int idx) => _pageController.animateToPage(idx, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        children: _pages,
        onPageChanged: (i) => setState(() => _selectedIndex = i),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onTap,
        selectedItemColor: Theme.of(context).colorScheme.secondary,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.table_chart), label: 'Report'),
          BottomNavigationBarItem(icon: Icon(Icons.star_outline), label: 'Special'),
        ],
      ),
    );
  }
}
