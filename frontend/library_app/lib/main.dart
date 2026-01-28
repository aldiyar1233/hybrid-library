import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'config/theme_manager.dart';
import 'services/auth_service.dart';
import 'services/logger_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'dart:math' as math;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Настройка системного UI
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  LoggerService.info('🚀 Запуск приложения Гибридная Библиотека');

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeManager(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeManager>(
      builder: (context, themeManager, child) {
        return MaterialApp(
          title: 'Гибридная Библиотека',
          debugShowCheckedModeBanner: false,
          theme: ThemeManager.lightTheme,
          darkTheme: ThemeManager.darkTheme,
          themeMode: themeManager.themeMode,
          home: const SplashScreen(),
        );
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {

  late AnimationController _mainController;
  late AnimationController _pulseController;
  late AnimationController _shimmerController;

  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _shimmerAnimation;

  final _authService = AuthService();

  @override
  void initState() {
    super.initState();

    // Основная анимация появления
    _mainController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // Анимация пульсации иконки
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    // Shimmer эффект
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.0, 0.8, curve: Curves.elasticOut),
    ));

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.15,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _shimmerAnimation = Tween<double>(
      begin: -2,
      end: 2,
    ).animate(_shimmerController);

    _mainController.forward();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(milliseconds: 2500));

    final isLoggedIn = await _authService.isLoggedIn();
    LoggerService.info('Проверка авторизации: ${isLoggedIn ? "авторизован" : "не авторизован"}');

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
          isLoggedIn ? const HomeScreen() : const LoginScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  void dispose() {
    _mainController.dispose();
    _pulseController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
              ? [
                  const Color(0xFF0F172A),
                  const Color(0xFF1E293B),
                  const Color(0xFF334155),
                ]
              : [
                  const Color(0xFF6366F1),
                  const Color(0xFF8B5CF6),
                  const Color(0xFFEC4899),
                ],
          ),
        ),
        child: Stack(
          children: [
            // Анимированные круги на фоне
            ...List.generate(3, (index) {
              return AnimatedBuilder(
                animation: _shimmerController,
                builder: (context, child) {
                  return Positioned(
                    left: -100 + (index * 150) + (_shimmerAnimation.value * 50),
                    top: 100 + (index * 200),
                    child: Opacity(
                      opacity: 0.1,
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  );
                },
              );
            }),

            // Основной контент
            Center(
              child: AnimatedBuilder(
                animation: _mainController,
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _fadeAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Иконка с пульсацией и свечением
                          AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _pulseAnimation.value,
                                child: Container(
                                  padding: const EdgeInsets.all(30),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withOpacity(0.15),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.white.withOpacity(0.3),
                                        blurRadius: 30 * _pulseAnimation.value,
                                        spreadRadius: 10 * _pulseAnimation.value,
                                      ),
                                    ],
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.white.withOpacity(0.3),
                                          Colors.white.withOpacity(0.1),
                                        ],
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.auto_stories_rounded,
                                      size: 80,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: 40),

                          // Текст с shimmer эффектом
                          AnimatedBuilder(
                            animation: _shimmerController,
                            builder: (context, child) {
                              return ShaderMask(
                                shaderCallback: (bounds) {
                                  return LinearGradient(
                                    colors: const [
                                      Colors.white54,
                                      Colors.white,
                                      Colors.white54,
                                    ],
                                    stops: const [0.0, 0.5, 1.0],
                                    begin: Alignment(_shimmerAnimation.value - 1, 0),
                                    end: Alignment(_shimmerAnimation.value, 0),
                                  ).createShader(bounds);
                                },
                                child: const Text(
                                  'Гибридная\nБиблиотека',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    height: 1.3,
                                    letterSpacing: 1,
                                  ),
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: 16),

                          // Подзаголовок
                          Text(
                            'Ваша цифровая библиотека',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white.withOpacity(0.8),
                              letterSpacing: 0.5,
                            ),
                          ),

                          const SizedBox(height: 60),

                          // Кастомный индикатор загрузки
                          SizedBox(
                            width: 50,
                            height: 50,
                            child: CustomPaint(
                              painter: _LoadingPainter(_shimmerController.value),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Версия внизу
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Text(
                  'v1.0.0',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Кастомный painter для крутого индикатора загрузки
class _LoadingPainter extends CustomPainter {
  final double progress;

  _LoadingPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Рисуем 3 вращающихся дуги
    for (int i = 0; i < 3; i++) {
      final startAngle = (progress * 2 * math.pi) + (i * 2 * math.pi / 3);
      final sweepAngle = math.pi * 0.6;

      paint.color = Colors.white.withOpacity(1 - (i * 0.3));

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - (i * 5)),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
