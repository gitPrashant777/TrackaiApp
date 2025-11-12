import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:trackai/core/constants/appcolors.dart';
import 'package:trackai/core/services/auth_services.dart';
import 'package:trackai/core/services/streak_service.dart';
import 'package:trackai/core/themes/theme_provider.dart';
import 'package:trackai/features/analytics/analyticsscreen.dart';
import 'package:trackai/features/home/homepage/desc%20and%20scan/food_desc.dart';
import 'package:trackai/features/home/presentation/homescreen.dart';
import 'package:trackai/features/settings/service/cam_Screen.dart';
import 'package:trackai/features/settings/presentation/settingsscreen.dart';
import 'package:trackai/features/tracker/trackerscreen.dart';
import 'package:trackai/features/admin/services/announcement_notification_service.dart';
import 'package:trackai/core/routes/routes.dart';

import '../../../library/presentation/library_screen.dart';
import 'desc and scan/LabelAnalysisScreen.dart';
import 'desc and scan/nutrition_scanner.dart';
import 'log/daily_log_provider.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  int currentIndex = 0;
  late PageController _pageController;
  late AnimationController _fabAnimationController;
  late AnimationController _fabExpandController;
  late Animation<double> _fabAnimation;
  late Animation<double> _fabExpandAnimation;
  late Animation<Offset> _fabSlideAnimation1;
  late Animation<Offset> _fabSlideAnimation2;

  late Animation<Offset> _fabSlideAnimation3;

  late Animation<double> _fabRotationAnimation;
  bool _isFabExpanded = false;
  bool _patternBackgroundEnabled = false;
  late List<Widget> _pages;

  int _currentStreak = 0;
  int _longestStreak = 0;
  bool _isLoadingStreak = true;

  final List<BottomNavItem> _navItems = [
    BottomNavItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home,
      label: 'Home',
    ),
    BottomNavItem(
      icon: Icons.track_changes_outlined,
      activeIcon: Icons.track_changes,
      label: 'Trackers',
    ),
    BottomNavItem(
      icon: Icons.library_books_outlined,
      activeIcon: Icons.library_books,
      label: 'Library',
    ),
    BottomNavItem(
      icon: Icons.analytics_outlined,
      activeIcon: Icons.analytics,
      label: 'Analytics',
    ),
    BottomNavItem(
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings,
      label: 'Settings',
    ),
  ];

  @override
  void initState() {
    super.initState();

    // --- UPDATED: Combined initialization logic ---
    _initializeUserData();
    // ---------------------------------------------

    _pages = [
      const Homescreen(),
      const Trackerscreen(),
      const LibraryScreen(),
      const AnalyticsScreen(),
      Settingsscreen(
        onPatternBackgroundChanged: _savePatternPreference,
        patternBackgroundEnabled: _patternBackgroundEnabled,
      ),
    ];

    _loadPreferences();
    _pageController = PageController(initialPage: currentIndex);
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fabExpandController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _fabAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fabAnimationController, curve: Curves.easeOut),
    );
    _fabExpandAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fabExpandController, curve: Curves.easeOutBack),
    );

    _fabSlideAnimation1 =
        Tween<Offset>(
          begin: const Offset(1.2, 0.0),
          end: const Offset(0.0, 0.0),
        ).animate(
          CurvedAnimation(
            parent: _fabExpandController,
            curve: const Interval(0.0, 0.7, curve: Curves.easeOutBack),
          ),
        );

    _fabSlideAnimation2 =
        Tween<Offset>(
          begin: const Offset(1.2, 0.0),
          end: const Offset(0.0, 0.0),
        ).animate(
          CurvedAnimation(
            parent: _fabExpandController,
            curve: const Interval(0.2, 0.9, curve: Curves.easeOutBack),
          ),
        );
    _fabSlideAnimation3 = Tween<Offset>(
      begin: const Offset(0.4, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _fabExpandController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    ));

    _fabRotationAnimation = Tween<double>(begin: 0.0, end: 0.125).animate(
      CurvedAnimation(parent: _fabExpandController, curve: Curves.easeInOut),
    );

    _fabAnimationController.forward();
  }

  // --- UPDATED: Combined method to fix streak race condition ---
  Future<void> _initializeUserData() async {
    // 1. Record the login first and get the result
    // --- MODIFIED: Capture the return value ---
    final int? newStreak = await StreakService.recordDailyLogin();

    // 2. NOW load streak data (for app bar)
    await _loadStreakData();

    // 3. Load daily log
    if (mounted) {
      Provider.of<DailyLogProvider>(context, listen: false)
          .loadEntriesForDate(DateTime.now());
    }

    // 4. --- ADDED: Show popup if a new streak was recorded ---
    if (newStreak != null && newStreak >=1 && mounted) {
      // Wait a tiny bit for the UI to be ready
      await Future.delayed(const Duration(milliseconds: 500));
      _showStreakWelcomePopup(newStreak);
    }
    // --------------------------------------------------------
  }
  // --------------------------------------------------------

  void _loadPreferences() async {
    setState(() {
      _patternBackgroundEnabled = false;
    });
  }

  void _savePatternPreference(bool enabled) async {
    setState(() {
      _patternBackgroundEnabled = enabled;
    });
  }

  Future<File?> _pickImageForAnalysis(BuildContext context) async {
    final ImagePicker picker = ImagePicker();
    File? imageFile;

    // Show the source selection dialog
    final ImageSource? source = await showDialog<ImageSource>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Image Source'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );

    if (source == null) return null; // User cancelled the dialog

    // Pick the image
    try {
      final XFile? xFile = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (xFile != null) {
        imageFile = File(xFile.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }

    return imageFile;
  }

  Future<void> _loadStreakData() async {
    // This method now runs *after* recordDailyLogin()
    try {
      if (!mounted) return;
      setState(() => _isLoadingStreak = true);

      final currentStreak = await StreakService.getCurrentStreakCount();
      final longestStreak = await StreakService.getLongestStreak();

      if (!mounted) return;
      setState(() {
        _currentStreak = currentStreak;
        _longestStreak = longestStreak;
        _isLoadingStreak = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingStreak = false;
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fabAnimationController.dispose();
    _fabExpandController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    if (index != currentIndex) {
      setState(() => currentIndex = index);
      if ((index - _pageController.page!.round()).abs() == 1) {
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOutCubic,
        );
      } else {
        _pageController.jumpToPage(index);
      }
      HapticFeedback.lightImpact();
    }
  }

  void _onPageChanged(int index) {
    setState(() => currentIndex = index);
  }

  void _toggleFabExpansion() {
    setState(() => _isFabExpanded = !_isFabExpanded);
    if (_isFabExpanded) {
      _fabExpandController.forward();
    } else {
      _fabExpandController.reverse();
    }
    HapticFeedback.lightImpact();
  }

// In _HomePageState, replace the old methods with these:

  void _onDescribeFood() async {
    _toggleFabExpansion(); // Close the FAB
    final File? imageFile = await _pickImageForAnalysis(context);

    if (imageFile != null && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => FoodDescriptionScreen(imageFile: imageFile),
        ),
      );
    }
  }

  void _onScanNutrition() async {
    _toggleFabExpansion(); // Close the FAB
    final File? imageFile = await _pickImageForAnalysis(context);

    if (imageFile != null && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => NutritionScannerScreen(imageFile: imageFile),
        ),
      );
    }
  }

  // NEW METHOD
  void _onScanLabel() async {
    _toggleFabExpansion(); // Close the FAB
    final File? imageFile = await _pickImageForAnalysis(context);

    if (imageFile != null && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => LabelAnalysisScreen(imageFile: imageFile),
        ),
      );
    }
  }

  Future<void> _handleLogout() async {
    try {
      context.read<DailyLogProvider>().clearLog();
      await FirebaseService.signOut();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logout failed: $e'),
            backgroundColor: AppColors.errorColor,
          ),
        );
      }
    }
  }

// --- NEW: Streak Welcome Popup (UPDATED per your request) ---
  void _showStreakWelcomePopup(int streakCount) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          // --- CHANGED: Set to white ---
          backgroundColor: Colors.grey[100],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          // --- CHANGED: Reduced padding ---
          contentPadding: const EdgeInsets.all(20),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Stars (Kept yellow for accent)

              // --- CHANGED: Reduced height ---
              const SizedBox(height: 6),
              // Fire Icon (Kept orange)
              Icon(
                Icons.local_fire_department_rounded,
                color: Colors.orange[400],
                size: 80,
              ),
              // --- CHANGED: Reduced height ---
              const SizedBox(height: 12),
              // Streak Number
              Text(
                '$streakCount',
                style: TextStyle(
                  // --- CHANGED: Set to black ---
                  color: Colors.black87,
                  fontSize: 72,
                  fontWeight: FontWeight.bold,
                ),
              ),
              // "Day streak" text (Kept orange)
              Text(
                'Day streak',
                style: TextStyle(
                  color: Colors.orange[400],
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              // --- CHANGED: Reduced height ---
              const SizedBox(height: 20),
              // Static Week
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                    .map((day) => Column(
                  children: [
                    Text(day,
                        style: TextStyle(
                          // --- CHANGED: Darker grey for light bg ---
                          color: Colors.grey[700],
                          fontSize: 14,
                        )),
                    const SizedBox(height: 4),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        // --- CHANGED: Lighter grey for light bg ---
                        color: Colors.grey[300],
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ))
                    .toList(),
              ),
              // --- CHANGED: Reduced height ---
              const SizedBox(height: 20),
              // Message
              Text(
                "You're on a $streakCount-day streak! Keep it going! 🔥",
                textAlign: TextAlign.center,
                style: TextStyle(
                  // --- CHANGED: Darker grey for light bg ---
                  color: Colors.grey[700],
                  fontSize: 16,
                ),
              ),
              // --- CHANGED: Reduced height ---
              const SizedBox(height: 20),
              // Continue Button
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  // --- CHANGED: Set to cyan ---
                  backgroundColor: Colors.cyan[600],
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Continue',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  void _showStreakDialog(bool isDark, double font(double size)) {
    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
            backgroundColor: AppColors.cardBackground(isDark),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: AppColors.primary(isDark).withOpacity(0.2),
                width: 1,
              ),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.local_fire_department,
                  // --- CHANGED: A consistent orange color for the title icon ---
                  color: Colors.orange[600],
                  size: font(0.06),
                ),
                const SizedBox(width: 8),
                Text(
                  'Streak Stats',
                  style: TextStyle(
                    color: AppColors.textPrimary(isDark),
                    fontWeight: FontWeight.bold,
                    fontSize: font(0.05),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // --- UPDATED: This call now passes a Color AND isDark ---
                _buildStreakStatRow(
                  'Current Streak',
                  '$_currentStreak days',
                  Icons.whatshot,
                  Colors.orange[600]!, // <-- The color for the "Current Streak" icon
                  isDark,               // <-- Pass isDark for the text
                  font,
                ),
                const SizedBox(height: 16),
                // --- UPDATED: This call now passes a Color AND isDark ---
                _buildStreakStatRow(
                  'Longest Streak',
                  '$_longestStreak days',
                  Icons.emoji_events,
                  Colors.yellow[700]!, // <-- The color for the "Longest Streak" icon
                  isDark,              // <-- Pass isDark for the text
                  font,
                ),
                const SizedBox(height: 16),
                Text(
                  'Keep logging in daily to maintain your streak!',
                  style: TextStyle(
                    color: AppColors.textSecondary(isDark),
                    fontSize: font(0.035),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Close',
                  style: TextStyle(
                    // --- CHANGED: Use a more standard "action" color ---
                    color: isDark ? Colors.blue[300] : Colors.blue[600],
                    fontSize: font(0.04),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
    );
  }
  // --- UPDATED: This function now takes a 'Color' for the icon ---
  Widget _buildStreakStatRow(String title,
      String value,
      IconData icon,
      Color iconColor, // <-- CHANGED: This now accepts a Color
      bool isDark,      // <-- ADDED: Pass isDark for text colors
      double Function(double) font,) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, color: iconColor, size: font(0.045)), // <-- USES iconColor
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: AppColors.textSecondary(isDark), // Uses isDark
                fontSize: font(0.04),
              ),
            ),
          ],
        ),
        Text(
          value,
          style: TextStyle(
            color: AppColors.textPrimary(isDark), // Uses isDark
            fontSize: font(0.045),
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery
        .of(context)
        .size
        .width;
    final screenHeight = MediaQuery
        .of(context)
        .size
        .height;

    double font(double size) => screenWidth * size;
    double space(double h) => screenHeight * h;

    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDark = themeProvider.isDarkMode;

        return Scaffold(
          extendBody: false,
          backgroundColor: AppColors.background(isDark),
          appBar: _buildAppBar(isDark, themeProvider, font),
          body: Container(
            decoration: BoxDecoration(
              gradient: AppColors.backgroundLinearGradient(isDark),
            ),
            child: Stack(
              children: [
                if (_patternBackgroundEnabled)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: PatternBackgroundPainter(
                          color: isDark
                              ? Colors.white.withOpacity(0.12)
                              : Colors.black.withOpacity(0.08),
                        ),
                      ),
                    ),
                  ),
                PageView(
                  controller: _pageController,
                  onPageChanged: _onPageChanged,
                  children: _pages.map((page) {
                    if (page is Settingsscreen) {
                      return Settingsscreen(
                        onPatternBackgroundChanged: _savePatternPreference,
                        patternBackgroundEnabled: _patternBackgroundEnabled,
                      );
                    }
                    return page;
                  }).toList(),
                ),
              ],
            ),
          ),
          bottomNavigationBar: _buildBottomNavigationBar(isDark, font),
          floatingActionButton: _buildExpandableFAB(isDark, font),
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark,
      ThemeProvider themeProvider,
      double Function(double) font,) {
    return AppBar(
      automaticallyImplyLeading: false,
      elevation: 0,
      backgroundColor: Colors.transparent,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: AppColors.backgroundLinearGradient(isDark),
          boxShadow: [
            BoxShadow(
              color: (isDark ? AppColors.black : AppColors.lightGrey)
                  .withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      ),
      title: Row(
        children: [
          const SizedBox(width: 12), // Keeps your original padding

          // --- ADDED IMAGE ---
          SizedBox(
            width: 25,
            height: 25,
            child: Image.asset(
              'assets/images/main.jpg', // Corrected path
              fit: BoxFit.contain, // Prevents stretching
            ),
          ),
          // --- ADDED SPACING ---
          const SizedBox(width: 8),

          // --- YOUR EXISTING TEXT ---
          ShaderMask(
            shaderCallback: (bounds) =>
                AppColors.appBarGradient.createShader(bounds),
            child: Text(
              'TrackAI',
              style: TextStyle(
                fontSize: font(0.06),
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.white : AppColors.black,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
      actions: [
        // Announcements bell icon with unseen count
        StreamBuilder<int>(
          stream: AnnouncementNotificationService
              .getUnseenAnnouncementsCountStream(),
          builder: (context, snapshot) {
            final unseenCount = snapshot.data ?? 0;

            return GestureDetector(
              onTap: () =>
                  Navigator.pushNamed(context, AppRoutes.announcements),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground(isDark).withOpacity(0.8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.darkPrimary.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  child: Stack(
                    children: [
                      Icon(
                        Icons.notifications_outlined,
                        color: isDark ? Colors.white : Colors.black,
                        size: font(0.06),
                      ),
                      if (unseenCount > 0)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: unseenCount > 9 ? 4 : 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppColors.cardBackground(isDark),
                                width: 1,
                              ),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              unseenCount > 99 ? '99+' : unseenCount.toString(),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: font(0.020),
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),

        // Streak stats (fire icon)
        GestureDetector(
          onTap: () => _showStreakDialog(isDark, font),
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: AppColors.cardBackground(isDark).withOpacity(0.8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.darkPrimary.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: _isLoadingStreak
                ? Container(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: font(0.04),
                height: font(0.04),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                ),
              ),
            )
                : Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.local_fire_department,
                    color: Colors.red,
                    size: font(0.06),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _currentStreak > 99
                        ? '99+'
                        : _currentStreak.toString(),
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontSize: font(0.04),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Container(
        //   margin: const EdgeInsets.only(right: 12),
        //   decoration: BoxDecoration(
        //     color: AppColors.cardBackground(isDark).withOpacity(0.8),
        //     borderRadius: BorderRadius.circular(52),
        //     border: Border.all(
        //       color: AppColors.primary(isDark).withOpacity(0.3),
        //       width: 1,
        //     ),
        //   ),
        //   child: SizedBox(
        //     width: font(0.1),
        //     height: font(0.1),
        //     child: IconButton(
        //       onPressed: () {
        //         HapticFeedback.lightImpact();
        //         themeProvider.toggleTheme();
        //       },
        //       icon: Icon(
        //         isDark ? Icons.light_mode : Icons.dark_mode,
        //         color: AppColors.primary(isDark),
        //         size: font(0.05),
        //       ),
        //       iconSize: font(0.05),
        //       padding: EdgeInsets.zero,
        //       constraints: const BoxConstraints(),
        //     ),
        //   ),
        // ),
      ],
    );
  }

  Widget _buildBottomNavigationBar(bool isDark, double Function(double) font) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground(isDark),
        boxShadow: [
          BoxShadow(
            color: (isDark ? AppColors.black : AppColors.lightGrey).withOpacity(
              0.1,
            ),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.black,
        selectedFontSize: font(0.035),
        unselectedFontSize: font(0.035),
        items: _navItems.map((item) {
          final isSelected = _navItems.indexOf(item) == currentIndex;
          return BottomNavigationBarItem(
            icon: Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Icon(
                isSelected ? item.activeIcon : item.icon,
                size: font(0.07),
              ),
            ),
            label: item.label,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildExpandableFAB(bool isDark, double Function(double) font) {
    return AnimatedBuilder(
      animation: _fabExpandController,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.bottomRight,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (_fabExpandController.value > 0.0)
                  SlideTransition(
                    position: _fabSlideAnimation2,
                    child: FadeTransition(
                      opacity: _fabExpandAnimation,
                      child: GestureDetector(
                        onTap: _onScanNutrition,
                        child: Container(
                          margin: const EdgeInsets.only(right: 16, bottom: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.cardBackground(isDark)
                                      .withOpacity(0.95),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.black.withOpacity(0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  'Scan Nutrition',
                                  style: TextStyle(
                                    color: AppColors.textPrimary(isDark),
                                    fontSize: font(0.035),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: AppColors.cardBackground(isDark)
                                      .withOpacity(0.95),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.black.withOpacity(0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.qr_code_scanner,
                                  color: const Color(0xFF26A69A),
                                  size: font(0.05),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                if (_fabExpandController.value > 0.0)
                  SlideTransition(
                    position: _fabSlideAnimation1,
                    child: FadeTransition(
                      opacity: _fabExpandAnimation,
                      child: GestureDetector(
                        onTap: _onScanLabel,
                        child: Container(
                          margin: const EdgeInsets.only(right: 16, bottom: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.cardBackground(isDark)
                                      .withOpacity(0.95),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.black.withOpacity(0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  'Scan Label',
                                  style: TextStyle(
                                    color: AppColors.textPrimary(isDark),
                                    fontSize: font(0.035),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: AppColors.cardBackground(isDark)
                                      .withOpacity(0.95),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.black.withOpacity(0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.document_scanner_outlined,
                                  color: const Color(0xFF26A69A),
                                  size: font(0.05),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                if (_fabExpandController.value > 0.0)
                  SlideTransition(
                    position: _fabSlideAnimation1,
                    child: FadeTransition(
                      opacity: _fabExpandAnimation,
                      child: GestureDetector(
                        onTap: _onDescribeFood,
                        child: Container(
                          margin: const EdgeInsets.only(right: 16, bottom: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.cardBackground(isDark)
                                      .withOpacity(0.95),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.black.withOpacity(0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  'Describe Food',
                                  style: TextStyle(
                                    color: AppColors.textPrimary(isDark),
                                    fontSize: font(0.035),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: AppColors.cardBackground(isDark)
                                      .withOpacity(0.95),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.black.withOpacity(0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.restaurant_menu,
                                  color: const Color(0xFF26A69A),
                                  size: font(0.05),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                AnimatedBuilder(
                  animation: _fabAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _fabAnimation.value,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8, right: 16),
                        child: FloatingActionButton(
                          heroTag: "main_fab",
                          onPressed: _toggleFabExpansion,
                          backgroundColor: AppColors.primary(isDark),
                          child: AnimatedBuilder(
                            animation: _fabRotationAnimation,
                            builder: (context, child) {
                              return Transform.rotate(
                                angle: _fabRotationAnimation.value * 2 *
                                    3.14159,
                                child: Icon(
                                  Icons.add,
                                  color: AppColors.textPrimary(isDark),
                                  size: font(0.07),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class PatternBackgroundPainter extends CustomPainter {
  final Color color;
  PatternBackgroundPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    const spacing = 25.0;
    const dotRadius = 1.0;
    for (double x = spacing; x < size.width; x += spacing) {
      for (double y = spacing; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), dotRadius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class BottomNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  BottomNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}