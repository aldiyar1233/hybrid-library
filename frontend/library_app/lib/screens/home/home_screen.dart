import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme_manager.dart';
import '../../services/auth_service.dart';
import '../../services/logger_service.dart';
import '../../models/user.dart';
import '../books/book_list_screen.dart';
import '../reservations/my_reservations_screen.dart';
import '../admin/admin_panel_screen.dart';
import '../admin/manage_books_screen.dart';
import '../auth/login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final _authService = AuthService();
  User? _currentUser;
  int _selectedIndex = 0;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _loadUser();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final user = await _authService.getCurrentUser();
    setState(() => _currentUser = user);
    LoggerService.info('Пользователь загружен: ${user?.username}');
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
    LoggerService.userAction('Навигация', {'tab_index': index});
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Выход из аккаунта'),
        content: const Text('Вы уверены, что хотите выйти?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Выйти'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      LoggerService.info('Выход из аккаунта: ${_currentUser?.username}');
      await _authService.logout();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final List<Widget> screens = [
      const BookListScreen(),
      const MyReservationsScreen(),
    ];
    
    if (_currentUser!.isAdminUser) {
      screens.add(const AdminPanelScreen());
      screens.add(const ManageBooksScreen());
    }

    final List<BottomNavigationBarItem> bottomNavItems = [
      const BottomNavigationBarItem(
        icon: Icon(Icons.book_outlined),
        activeIcon: Icon(Icons.book),
        label: 'Книги',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.bookmark_border),
        activeIcon: Icon(Icons.bookmark),
        label: 'Мои брони',
      ),
    ];
    
    if (_currentUser!.isAdminUser) {
      bottomNavItems.addAll([
        const BottomNavigationBarItem(
          icon: Icon(Icons.admin_panel_settings_outlined),
          activeIcon: Icon(Icons.admin_panel_settings),
          label: 'Админ',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.library_add_outlined),
          activeIcon: Icon(Icons.library_add),
          label: 'Управление',
        ),
      ]);
    }

    final themeManager = Provider.of<ThemeManager>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(_getAppBarTitle()),
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        actions: [
          // Переключатель темы
          IconButton(
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) {
                return RotationTransition(
                  turns: animation,
                  child: FadeTransition(opacity: animation, child: child),
                );
              },
              child: Icon(
                isDark ? Icons.light_mode : Icons.dark_mode,
                key: ValueKey(isDark),
              ),
            ),
            onPressed: () {
              themeManager.toggleTheme();
              LoggerService.userAction('Смена темы');
            },
            tooltip: isDark ? 'Светлая тема' : 'Темная тема',
          ),
        ],
      ),
      drawer: _buildDrawer(isDark),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: screens[_selectedIndex],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          selectedItemColor: Theme.of(context).primaryColor,
          unselectedItemColor: isDark ? Colors.grey[500] : Colors.grey[600],
          items: bottomNavItems,
          elevation: 0,
          backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
        ),
      ),
    );
  }

  Widget _buildDrawer(bool isDark) {
    return Drawer(
      backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).primaryColor,
                  Theme.of(context).primaryColor.withOpacity(0.7),
                ],
              ),
            ),
            accountName: Text(
              '${_currentUser!.firstName ?? ''} ${_currentUser!.lastName ?? ''}'.trim().isEmpty
                  ? _currentUser!.username
                  : '${_currentUser!.firstName ?? ''} ${_currentUser!.lastName ?? ''}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            accountEmail: Text(_currentUser!.email),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                _currentUser!.username[0].toUpperCase(),
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.book),
            title: const Text('Каталог книг'),
            selected: _selectedIndex == 0,
            selectedTileColor: Theme.of(context).primaryColor.withOpacity(0.1),
            onTap: () {
              setState(() => _selectedIndex = 0);
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.bookmark),
            title: const Text('Мои бронирования'),
            selected: _selectedIndex == 1,
            selectedTileColor: Theme.of(context).primaryColor.withOpacity(0.1),
            onTap: () {
              setState(() => _selectedIndex = 1);
              Navigator.pop(context);
            },
          ),
          if (_currentUser!.isAdminUser) ...[
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Администрирование',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.admin_panel_settings),
              title: const Text('Управление бронями'),
              selected: _selectedIndex == 2,
              selectedTileColor: Theme.of(context).primaryColor.withOpacity(0.1),
              onTap: () {
                setState(() => _selectedIndex = 2);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.library_add),
              title: const Text('Управление книгами'),
              selected: _selectedIndex == 3,
              selectedTileColor: Theme.of(context).primaryColor.withOpacity(0.1),
              onTap: () {
                setState(() => _selectedIndex = 3);
                Navigator.pop(context);
              },
            ),
          ],
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Выйти', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(context);
              _logout();
            },
          ),
        ],
      ),
    );
  }

  String _getAppBarTitle() {
    switch (_selectedIndex) {
      case 0:
        return 'Каталог книг';
      case 1:
        return 'Мои бронирования';
      case 2:
        return 'Управление бронями';
      case 3:
        return 'Управление книгами';
      default:
        return 'Гибридная Библиотека';
    }
  }
}