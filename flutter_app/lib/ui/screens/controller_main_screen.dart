import 'package:flutter/material.dart';
import '../../constants/app_theme.dart';
import 'game_history_screen.dart';
import 'scoreboard_screen.dart';
import 'trophy_room_screen.dart';
import 'var_station_screen.dart';

class ControllerMainScreen extends StatefulWidget {
  const ControllerMainScreen({super.key});

  @override
  State<ControllerMainScreen> createState() => _ControllerMainScreenState();
}

class _ControllerMainScreenState extends State<ControllerMainScreen> {
  int _currentIndex = 0;

  final List<Widget> _tabs = const [
    VarStationScreen(),
    ScoreboardScreen(),
    TrophyRoomScreen(),
    GameHistoryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _tabs,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: JokarzColors.surface,
          border: const Border(
            top: BorderSide(color: JokarzColors.cardBorder, width: 1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(120),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          backgroundColor: JokarzColors.surface,
          selectedItemColor: JokarzColors.gold,
          unselectedItemColor: JokarzColors.textMuted,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.sports),
              activeIcon: Icon(Icons.sports, color: JokarzColors.gold),
              label: 'VAR Station',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.table_chart),
              activeIcon: Icon(Icons.table_chart, color: JokarzColors.gold),
              label: 'Scoreboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.emoji_events),
              activeIcon: Icon(Icons.emoji_events, color: JokarzColors.gold),
              label: 'Trophies',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history),
              activeIcon: Icon(Icons.history, color: JokarzColors.gold),
              label: 'History',
            ),
          ],
        ),
      ),
    );
  }
}
