import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:trackai/core/constants/appcolors.dart';
import 'package:trackai/core/routes/routes.dart';
import 'package:trackai/core/themes/theme_provider.dart';
import 'package:trackai/core/services/streak_service.dart';
import 'package:trackai/features/settings/service/goalservice.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart' as lucide;
import 'package:intl/intl.dart';
import '../homepage/log/daily_log_provider.dart';
import '../homepage/log/food_log_entry.dart';
import 'meal_detail_screen.dart';

const Color kBackgroundColor = Colors.white;
const Color kCardColor = Color(0xFFF8F9FA);
const Color kCardColorDarker = Color(0xFFE9ECEF);
const Color kTextColor = Color(0xFF212529);
const Color kTextSecondaryColor = Color(0xFF6C757D);
const Color kAccentColor = Color(0xFF131212);
const Color kSuccessColor = Color(0xFF28A745);
const Color kWarningColor = Color(0xFFFFC107);
const Color kDangerColor = Color(0xFFDC3545);

class Homescreen extends StatefulWidget {
  const Homescreen({super.key});

  @override
  State<Homescreen> createState() => _HomescreenState();
}

class _HomescreenState extends State<Homescreen> {
  DateTime _currentDate = DateTime.now();

  // Firebase data
  Map<String, dynamic>? _goalsData;
  bool _isLoadingGoals = true;
  String? _goalsError;

  // --- NEW: State for streak calendar ---
  Map<String, bool> _streakData = {};
  bool _isLoadingStreakData = true;
  // ------------------------------------

  // --- NEW: State for collapsible list ---
  bool _showAllEntries = false;
  // ------------------------------------

  DateTime? _accountCreationDate;

  @override
  void initState() {
    super.initState();
    _loadGoalsData();
    _loadAccountCreationDate();
    // --- ADDED: Load streak data for the initial week ---
    _loadStreakDataForWeek(_getWeekDates(DateTime.now()));
  }

  Future<void> _loadGoalsData() async {
    try {
      setState(() {
        _isLoadingGoals = true;
        _goalsError = null;
      });

      final goalsData = await GoalsService.getGoals();

      if (mounted) {
        setState(() {
          _goalsData = goalsData;
          _isLoadingGoals = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _goalsError = e.toString();
          _isLoadingGoals = false;
        });
      }
    }
  }

  // --- NEW: Method to fetch streak data for the calendar ---
  Future<void> _loadStreakDataForWeek(List<DateTime> weekDates) async {
    if (weekDates.isEmpty) return;
    setState(() => _isLoadingStreakData = true);
    try {
      // NEW
      final data = await StreakService.getStreakDataForRange(
        weekDates.first.subtract(const Duration(days: 1)), // <-- Fetch one day earlier
        weekDates.last,
      );
      if (mounted) {
        setState(() {
          _streakData = data;
          _isLoadingStreakData = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingStreakData = false);
      }
      print("Error loading week streak data: $e");
    }
  }

  Future<void> _loadAccountCreationDate() async {
    try {
      _accountCreationDate = await StreakService.getAccountCreationDate();
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      _accountCreationDate = DateTime.now();
    }
  }

  // --- UPDATED: Now re-fetches streak data for the new week ---
  void _navigateToWeek(int direction) {
    setState(() {
      _currentDate = _currentDate.add(Duration(days: 7 * direction));
      // Re-fetch data for the new week
      _loadStreakDataForWeek(_getWeekDates(_currentDate));
    });
  }

  List<DateTime> _getWeekDates(DateTime date) {
    // Assuming week starts on Monday (weekday == 1)
    final startOfWeek = date.subtract(Duration(days: date.weekday - 1));
    return List.generate(7, (index) => startOfWeek.add(Duration(days: index)));
  }

  BoxDecoration _getCardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.grey.withOpacity(0.08),
          blurRadius: 10,
          spreadRadius: 0,
          offset: Offset(0, 2),
        ),
      ],
    );
  }

  void _handleAILabAction(String action) {
    switch (action) {
      case 'body-analyzer':
        Navigator.pushNamed(context, AppRoutes.bodyAnalyzer);
        break;
      case 'smart-gymkit':
        Navigator.pushNamed(context, AppRoutes.smartGymkit);
        break;
      case 'calorie_calc':
        Navigator.pushNamed(context, AppRoutes.calorieCalculator);
        break;
      case 'meal_planner':
        Navigator.pushNamed(context, AppRoutes.mealPlanner);
        break;
      case 'recipe_generator':
        Navigator.pushNamed(context, AppRoutes.recipeGenerator);
        break;
      default:
        _showSnackBar('Feature coming soon!');
        break;
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final weekDates = _getWeekDates(_currentDate);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.04,
            vertical: screenHeight * 0.02,
          ),
          child: Consumer<DailyLogProvider>(
            builder: (context, logProvider, child) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- UPDATED: Pass streak data to calendar ---
                  _buildWeekCalendar(
                      screenWidth, screenHeight, weekDates, _streakData),
                  SizedBox(height: screenHeight * 0.03),

                  _buildMainContentPage(logProvider),

                  SizedBox(height: screenHeight * 0.03),

                  _buildRecentlyEaten(logProvider, screenWidth, screenHeight),

                  SizedBox(height: screenHeight * 0.03),

                  _buildFullAILabSection(),
                  SizedBox(height: screenHeight * 0.03),

                  _buildWellnessTipsSection(),
                  SizedBox(height: screenHeight * 0.04),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // --- WIDGET UPDATED: To accept streak data and show colors ---
  Widget _buildWeekCalendar(
      double screenWidth,
      double screenHeight,
      List<DateTime> weekDates,
      Map<String, bool> streakData, // <-- ADDED
      ) {
    return Container(
      padding: EdgeInsets.all(screenWidth * 0.04),
      decoration: _getCardDecoration(),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: weekDates.asMap().entries.map((entry) {
          final date = entry.value;
          // --- UPDATED: Weekday letters to match your new logic (Mon-Sun) ---
          final dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
          final dayLetter = dayLetters[entry.key];

          final today = DateTime.now();
          final isToday = date.day == today.day &&
              date.month == today.month &&
              date.year == today.year;

          // --- ADDED: Check streak data ---
          final dateString = StreakService.formatDateStatic(date);
          final bool isActive = streakData[dateString] ?? false;
// --- ADD THESE 3 LINES ---
          final prevDate = date.subtract(const Duration(days: 1));
          final prevDateString = StreakService.formatDateStatic(prevDate);
          final bool prevDayWasActive = streakData[prevDateString] ?? false;
// --- END OF ADDITION ---
          return Column(
            children: [
              // --- UPDATED: Use new _buildDayCircle widget ---
              _buildDayCircle(
                date: date,
                dayLetter: dayLetter,
                isActive: isActive,
                prevDayWasActive: prevDayWasActive, // <-- PASS THE NEW VALUE HERE
                isToday: isToday,
                size: screenWidth * 0.1,
              ),
              SizedBox(height: screenHeight * 0.008),
              // Date number - bold if today
              Text(
                '${date.day}',
                style: TextStyle(
                  color: isToday ? Colors.black87 : Colors.black54,
                  fontSize: screenWidth * 0.035,
                  fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
  Widget _buildDayCircle({
    required DateTime date,
    required String dayLetter,
    required bool isActive,
    required bool prevDayWasActive, // <-- ADD THIS PARAMETER
    required bool isToday,
    required double size,
  }) {
    final now = DateTime.now();
    // A day is in the past if it's before today (ignoring time)
    final isPast = date.isBefore(DateTime(now.year, now.month, now.day));

    Color circleColor;
    Color textColor;
    BoxBorder? border;
    Widget? painterChild;

    if (isActive) {
      // GREEN: Active streak day
      // --- MODIFIED: Added .withOpacity(0.8) ---
      circleColor = Colors.green[700]!.withOpacity(0.5);
      textColor = Colors.white;
    } else if (isPast && !isToday) {
      // RED: Missed day in the past
      // --- MODIFIED: Added .withOpacity(0.8) ---
      circleColor = Colors.red[700]!.withOpacity(0.5);
      textColor = Colors.white;
    } else {
      // GREY DOTTED: Today or future, not yet active
      circleColor = Colors.transparent;
      textColor = Colors.black87;
      painterChild = CustomPaint(
        painter: DashedCirclePainter(
          // --- MODIFIED: Added .withOpacity(0.8) ---
          color: Colors.grey[400]!.withOpacity(0.8),
          strokeWidth: 1.5,
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: circleColor,
        shape: BoxShape.circle,
        border: border,
      ),
      child: Stack(
        children: [
          if (painterChild != null)
            Positioned.fill(child: painterChild),
          Center(
            child: Text(
              dayLetter,
              style: TextStyle(
                color: textColor,
                fontSize: size * 0.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
  // Main Content Page
  Widget _buildMainContentPage(DailyLogProvider logProvider) {
    // <-- UPDATED
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    if (_isLoadingGoals) {
      return Container(
        padding: EdgeInsets.all(screenWidth * 0.1),
        decoration: _getCardDecoration(),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_goalsError != null || _goalsData == null) {
      return Container(
        padding: EdgeInsets.all(screenWidth * 0.05),
        decoration: _getCardDecoration(),
        child: Column(
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            const Text('Set Your Daily Targets',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.adjustGoals),
              child: const Text('Set Goals'),
            ),
          ],
        ),
      );
    }

    // --- START: NEW CALCULATION LOGIC ---
    // Get Firebase Goals
    final goalCalories = (_goalsData!['calories'] ?? 0).toDouble();
    final goalProtein = (_goalsData!['protein'] ?? 0).toDouble();
    final goalCarbs = (_goalsData!['carbs'] ?? 0).toDouble();
    final goalFat = (_goalsData!['fat'] ?? 0).toDouble();
    final goalFiber = (_goalsData!['fiber'] ?? 0).toDouble();

    // Get Consumed Totals from Provider
    final consumedCalories =
    (logProvider.consumedTotals['calories'] ?? 0).toDouble();
    final consumedProtein =
    (logProvider.consumedTotals['protein'] ?? 0).toDouble();
    final consumedCarbs =
    (logProvider.consumedTotals['carbs'] ?? 0).toDouble();
    final consumedFat = (logProvider.consumedTotals['fat'] ?? 0).toDouble();
    final consumedFiber = (logProvider.consumedTotals['fiber'] ?? 0).toDouble();

    // Calculate "Left" (and prevent negative numbers)
    final caloriesLeft =
    (goalCalories - consumedCalories).clamp(0, goalCalories);
    final proteinLeft = (goalProtein - consumedProtein).clamp(0, goalProtein);
    final carbsLeft = (goalCarbs - consumedCarbs).clamp(0, goalCarbs);
    final fatLeft = (goalFat - consumedFat).clamp(0, goalFat);
    final fiberLeft = (goalFiber - consumedFiber).clamp(0, goalFiber);

    // Calculate Progress (0.0 to 1.0), handle division by zero
    final caloriesProgress = goalCalories == 0
        ? 0.0
        : (consumedCalories / goalCalories).clamp(0.0, 1.0);
    final proteinProgress = goalProtein == 0
        ? 0.0
        : (consumedProtein / goalProtein).clamp(0.0, 1.0);
    final carbsProgress = goalCarbs == 0
        ? 0.0
        : (consumedCarbs / goalCarbs).clamp(0.0, 1.0);
    final fatProgress =
    goalFat == 0 ? 0.0 : (consumedFat / goalFat).clamp(0.0, 1.0);
    final fiberProgress =
    goalFiber == 0 ? 0.0 : (consumedFiber / goalFiber).clamp(0.0, 1.0);
    // --- END: NEW CALCULATION LOGIC ---

    return Column(
      children: [
        // Large Calories Card
        Container(
          padding: EdgeInsets.all(screenWidth * 0.06),
          decoration: _getCardDecoration(),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${caloriesLeft.toInt()}', // <-- UPDATED
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: screenWidth * 0.13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Calories left',
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: screenWidth * 0.04,
                    ),
                  ),
                ],
              ),
              // UPDATED ICON CONTAINER
              _buildProgressRing(
                // <-- UPDATED
                progress: caloriesProgress,
                size: screenWidth * 0.25,
                icon: lucide.LucideIcons.flame,
                color: Colors.black, // Your theme's calorie color
              ),
            ],
          ),
        ),

        SizedBox(height: screenHeight * 0.025),

        // Three Macro Cards
        Row(
          children: [
            Expanded(
              child: Container(
                padding: EdgeInsets.all(screenWidth * 0.04),
                decoration: _getCardDecoration(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${proteinLeft.toInt()}g', // <-- UPDATED
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: screenWidth * 0.055,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.008),
                    Text(
                      'Protein left',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black54,
                        fontSize: screenWidth * 0.032,
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.015),
                    // UPDATED ICON CONTAINER
                    _buildProgressRing(
                      // <-- UPDATED
                      progress: proteinProgress,
                      size: screenWidth * 0.15,
                      icon: lucide.LucideIcons.zap,
                      color: Colors.orange,
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(width: screenWidth * 0.03),
            Expanded(
              child: Container(
                padding: EdgeInsets.all(screenWidth * 0.04),
                decoration: _getCardDecoration(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${carbsLeft.toInt()}g', // <-- UPDATED
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: screenWidth * 0.055,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.008),
                    Text(
                      'Carbs left',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black54,
                        fontSize: screenWidth * 0.032,
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.015),
                    // UPDATED ICON CONTAINER
                    _buildProgressRing(
                      // <-- UPDATED
                      progress: carbsProgress,
                      size: screenWidth * 0.15,
                      icon: lucide.LucideIcons.wheat,
                      color: Colors.green,
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(width: screenWidth * 0.03),
            Expanded(
              child: Container(
                padding: EdgeInsets.all(screenWidth * 0.04),
                decoration: _getCardDecoration(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${fatLeft.toInt()}g', // <-- UPDATED
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: screenWidth * 0.055,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.008),
                    Text(
                      'Fats left',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black54,
                        fontSize: screenWidth * 0.032,
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.015),
                    // UPDATED ICON CONTAINER
                    _buildProgressRing(
                      // <-- UPDATED
                      progress: fatProgress,
                      size: screenWidth * 0.15,
                      icon: lucide.LucideIcons.droplet,
                      color: Colors.blue,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        // Fiber Section
        SizedBox(height: screenHeight * 0.025),
        // UPDATED Call
        _buildFiberSection(fiberLeft.toInt(), fiberProgress, fiberLeft <= 0),
      ],
    );
  }

// Fiber Widget
  Widget _buildFiberSection(
      int fiberLeft, // <-- Added
      double fiberProgress, // <-- Added
      bool isTargetComplete, // <-- Added
      ) {
    final sw = MediaQuery.of(context).size.width;
    return Container(
      padding: EdgeInsets.all(sw * 0.04),
      decoration: _getCardDecoration(),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Fiber Remaining",
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: sw * 0.04,
                  fontWeight: FontWeight.w600,
                ),
              ),
              // --- UPDATED LOGIC ---
              if (isTargetComplete)
                Row(
                  children: [
                    Icon(Icons.check_circle,
                        color: Colors.green, size: sw * 0.06),
                    SizedBox(width: sw * 0.02),
                    Text(
                      "Target Complete!",
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: sw * 0.05,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      "$fiberLeft", // <-- UPDATED to use the argument
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: sw * 0.08,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: sw * 0.008),
                    Text(
                      "g",
                      style: TextStyle(
                        color: Colors.black54,
                        fontSize: sw * 0.03,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              // --- END UPDATED LOGIC ---
            ],
          ),
          // --- UPDATED ICON CONTAINER TO USE PROGRESS RING ---
          _buildProgressRing(
            progress: fiberProgress, // <-- UPDATED
            size: sw * 0.15,
            icon: lucide.LucideIcons.leaf,
            color: Colors.amber, // Fiber color (adjust if needed)
          ),
        ],
      ),
    );
  }

  // --- WIDGET UPDATED ---
  Widget _buildRecentlyEaten(
      DailyLogProvider logProvider, double sw, double sh) {
    final entries = logProvider.entries;

    if (entries.isEmpty) {
      // Don't show anything if the log is empty
      return const SizedBox.shrink();
    }

    // Determine how many items to show
    final itemsToShow =
    _showAllEntries ? entries.length : (entries.isNotEmpty ? 1 : 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Recently Eaten",
          style: TextStyle(
              color: Colors.black,
              fontSize: sw * 0.045,
              fontWeight: FontWeight.w600),
        ),
        SizedBox(height: sh * 0.02),
        Container(
          decoration: _getCardDecoration(),
          child: Column(
            // <-- Wrap ListView in Column
            children: [
              ListView.builder(
                itemCount: itemsToShow, // Use calculated item count
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                itemBuilder: (context, index) {
                  final entry = entries[index];

                  // Determine if the border should be hidden
                  bool hideBorder;
                  if (_showAllEntries) {
                    // If showing all, hide border only on the very last item
                    hideBorder = (index == entries.length - 1);
                  } else {
                    // If not showing all
                    if (entries.length > 1) {
                      // And there are more entries, DON'T hide border
                      // (so the "Show More" button has a line above it)
                      hideBorder = false;
                    } else {
                      // It's the only entry, so hide the border
                      hideBorder = true;
                    }
                  }

                  return _buildLogEntryCard(entry, sw, sh, hideBorder);
                },
              ),

              // "Show More" Button
              if (entries.length > 1)
                InkWell(
                  onTap: () {
                    setState(() {
                      _showAllEntries = !_showAllEntries;
                    });
                  },
                  // Add splash effect
                  borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(16)),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(sw * 0.04),
                    child: Text(
                      _showAllEntries
                          ? 'Show Less'
                          : 'Show All (${entries.length - 1} more)',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black, // Use theme color
                        fontSize: sw * 0.038,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // --- END OF UPDATED WIDGET ---

  Widget _buildProgressRing({
    required double progress,
    required double size,
    required IconData icon,
    required Color color,
  }) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background ring
          CircularProgressIndicator(
            value: 1.0, // Full circle
            strokeWidth: size * 0.1, // Responsive stroke
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[300]!),
          ),
          // Foreground progress ring
          CircularProgressIndicator(
            value: progress,
            strokeWidth: size * 0.1,
            backgroundColor: Colors.transparent,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            strokeCap: StrokeCap.round, // Makes the ends rounded
          ),
          // Icon in the center
          Center(
            child: Icon(
              icon,
              // Icon color changes when target is hit
              color: progress > 0.99 ? color : color,
              size: size * 0.5, // Responsive icon
            ),
          ),
        ],
      ),
    );
  }
  // ---

  // --- UPDATED: Parameter changed from 'isLast' to 'hideBorder' ---
  Widget _buildLogEntryCard(
      FoodLogEntry entry, double sw, double sh, bool hideBorder) {
    // --- WRAP with GestureDetector ---
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact(); // Add feedback on tap
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                MealDetailScreen(entry: entry), // Pass the entry
          ),
        );
        // -----------------------------
      },
      // Make sure the tap hits the whole area
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.all(sw * 0.04),
        decoration: BoxDecoration(
          // Use hideBorder to control the border
          border: hideBorder
              ? null
              : Border(
            bottom: BorderSide(color: Colors.grey[200]!, width: 1),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    entry.name,
                    style: TextStyle(
                        color: Colors.black,
                        fontSize: sw * 0.04,
                        fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  DateFormat('hh:mm a')
                      .format(entry.timestamp), // e.g., 05:43 PM
                  style:
                  TextStyle(color: Colors.grey[600], fontSize: sw * 0.03),
                ),
              ],
            ),
            SizedBox(height: sh * 0.01),
            Row(
              children: [
                Icon(lucide.LucideIcons.flame,
                    color: Colors.black, size: sw * 0.045),
                SizedBox(width: sw * 0.01),
                Text(
                  '${entry.calories} calories',
                  style: TextStyle(color: Colors.black54, fontSize: sw * 0.035),
                ),
              ],
            ),
            SizedBox(height: sh * 0.015),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                _buildMacroIcon(lucide.LucideIcons.zap, Colors.amber,
                    '${entry.protein}g', sw),
                SizedBox(width: sw * 0.04),
                _buildMacroIcon(lucide.LucideIcons.wheat, Colors.green,
                    '${entry.carbs}g', sw),
                SizedBox(width: sw * 0.04),
                _buildMacroIcon(lucide.LucideIcons.droplet, Colors.blue,
                    '${entry.fat}g', sw),
                SizedBox(width: sw * 0.04),
                _buildMacroIcon(lucide.LucideIcons.leaf, Colors.orange,
                    '${entry.fiber}g', sw),
              ],
            ),
          ],
        ),
      ),
    );
    // --- END OF GestureDetector WRAP ---
  }

// Helper for the small macro icons in the log card
  Widget _buildMacroIcon(IconData icon, Color color, String text, double sw) {
    return Row(
      children: [
        Icon(icon, color: color, size: sw * 0.035),
        SizedBox(width: sw * 0.01),
        Text(
          text,
          style: TextStyle(color: Colors.black54, fontSize: sw * 0.035),
        ),
      ],
    );
  }

  // AI Lab Section with FIXED EQUAL HEIGHT CARDS
  Widget _buildFullAILabSection() {
    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;
    final cardHeight = sh * 0.17; // Fixed height for all cards

    return Container(
      padding: EdgeInsets.all(sw * 0.05),
      decoration: _getCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(lucide.LucideIcons.sparkles,
                  color: Colors.black, size: sw * 0.06),
              SizedBox(width: sw * 0.03),
              Expanded(
                child: Text(
                  "AI Lab Quick Actions",
                  style: TextStyle(
                      color: Colors.black87,
                      fontSize: sw * 0.045,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          SizedBox(height: sh * 0.01),
          Text(
            "Launch powerful AI assistance with a single tap.",
            style: TextStyle(color: Colors.black54, fontSize: sw * 0.035),
          ),
          SizedBox(height: sh * 0.025),

          // --- MODIFIED CALL: Added isFullWidth: true ---
          _aiLabCard(
              "Body Composition Analyzer",
              "Get 18 detailed body composition metrics.",
              lucide.LucideIcons.personStanding,
              "body-analyzer",
              cardHeight,
              sw,
              sh,
              isFullWidth: true), // <-- MODIFIED
          SizedBox(height: sh * 0.02),

          // Row 1
          Row(
            children: [
              Expanded(
                  child: _aiLabCard(
                      "AI Workout Planner",
                      "Your gym companion.",
                      lucide.LucideIcons.activity,
                      "smart-gymkit",
                      cardHeight,
                      sw,
                      sh)),
              SizedBox(width: sw * 0.03),
              Expanded(
                  child: _aiLabCard(
                      "Calorie Burn Calc",
                      "Estimate burned calories.",
                      lucide.LucideIcons.flame,
                      "calorie_calc",
                      cardHeight,
                      sw,
                      sh)),
            ],
          ),
          SizedBox(height: sh * 0.02),

          // Row 2
          Row(
            children: [
              Expanded(
                  child: _aiLabCard(
                      "AI Meal Planner",
                      "Get tailored meal plans.",
                      lucide.LucideIcons.utensilsCrossed,
                      "meal_planner",
                      cardHeight,
                      sw,
                      sh)),
              SizedBox(width: sw * 0.03),
              Expanded(
                  child: _aiLabCard(
                      "AI Recipe Generator",
                      "Create recipes instantly.",
                      lucide.LucideIcons.chefHat,
                      "recipe_generator",
                      cardHeight,
                      sw,
                      sh)),
            ],
          ),
          SizedBox(height: sh * 0.02),

          // Row 3 - Coming Soon
          Row(
            children: [
              Expanded(
                  child: _comingSoonCard(
                      "AI Nutrition Coach",
                      "Smart nutrition guidance.",
                      lucide.LucideIcons.brain,
                      cardHeight,
                      sw,
                      sh)),
              SizedBox(width: sw * 0.03),
              Expanded(
                  child: _comingSoonCard(
                      "AI Fitness Tracker",
                      "Intelligent workout tracking.",
                      lucide.LucideIcons.trophy,
                      cardHeight,
                      sw,
                      sh)),
            ],
          ),
        ],
      ),
    );
  }

  // --- WIDGET MODIFIED ---
  Widget _aiLabCard(String title, String desc, IconData icon, String action,
      double height, double sw, double sh,
      {bool isFullWidth = false}) {
    // <-- MODIFIED
    return GestureDetector(
      onTap: () => _handleAILabAction(action),
      child: Container(
        width: isFullWidth ? double.infinity : null, // <-- MODIFIED
        height: height,
        padding: EdgeInsets.all(sw * 0.04),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // --- MODIFIED: Icon wrapped in styled Container ---
            Container(
              padding: EdgeInsets.all(sw * 0.03),
              decoration: BoxDecoration(
                color: Colors.grey[200]!,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.grey[300]!,
                  width: 1,
                ),
              ),
              child: Icon(
                icon,
                color: Colors.black, // <-- MODIFIED
                size: sw * 0.06, // <-- MODIFIED
              ),
            ),
            // --- END MODIFICATION ---
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: Colors.black87,
                        fontSize: sw * 0.038,
                        fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                SizedBox(height: sh * 0.003),
                Text(desc,
                    style:
                    TextStyle(color: Colors.black54, fontSize: sw * 0.03),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ],
        ),
      ),
    );
  }

// --- ADD THIS HELPER WIDGET ---
// (Adapted from nutrition_scanner.dart)
  Widget _buildNutrientCard(
      String title,
      String value,
      String unit,
      IconData icon,
      Color iconColor,
      ) {
    return Container(
      decoration: BoxDecoration(
        color: kCardColorDarker,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: kTextColor,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: kTextColor,
                  ),
                ),
                const SizedBox(width: 2),
                Text(
                  unit,
                  style: const TextStyle(
                    fontSize: 10,
                    color: kTextSecondaryColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showMealDetailsDialog(FoodLogEntry entry) {
    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            top: sh * 0.1,
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            constraints: BoxConstraints(maxHeight: sh * 0.8),
            padding: EdgeInsets.all(sw * 0.05),
            decoration: BoxDecoration(
              // --- USE LIGHT THEME CONSISTENTLY ---
              color: Colors.grey[100], // Changed to light grey
              // -----------------------------------
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header (Adjusted for light theme)
                  Row(
                    children: [
                      Icon(Icons.restaurant_menu,
                          color: Colors.grey[700], size: sw * 0.06), // Darker icon
                      SizedBox(width: sw * 0.02),
                      Text(
                        'Meal Details',
                        style: TextStyle(
                          fontSize: sw * 0.055,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87, // Darker text
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: sh * 0.01),
                  // Food Name (Adjusted for light theme)
                  Text(
                    entry.name,
                    style: TextStyle(
                      fontSize: sw * 0.04,
                      color: Colors.black54, // Secondary text color
                    ),
                  ),
                  SizedBox(height: sh * 0.03),
                  if (entry.imagePath != null) ...[
                    Center(
                      // Center the image
                      child: ClipRRect(
                        // Add rounded corners
                        borderRadius: BorderRadius.circular(12.0),
                        child: Image.file(
                          File(entry
                              .imagePath!), // Create a File object from the path
                          height: sh * 0.2, // Set a fixed height
                          width: double.infinity, // Take full width
                          fit: BoxFit.cover, // Cover the area
                          // Add error handling for missing files
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: sh * 0.2,
                              color: Colors.grey[300],
                              child:
                              const Center(child: Text('Image not found')),
                            );
                          },
                        ),
                      ),
                    ),
                    SizedBox(height: sh * 0.03), // Add space after the image
                  ],
                  // --- END IMAGE DISPLAY ---
                  // Calories Display
                  Center(
                    child: Column(
                      children: [
                        Icon(lucide.LucideIcons.flame,
                            color: Colors.cyan, size: sw * 0.07),
                        SizedBox(height: sh * 0.01),
                        Text(
                          '${entry.calories}',
                          style: TextStyle(
                            fontSize: sw * 0.12,
                            fontWeight: FontWeight.bold,
                            color: Colors.cyan,
                          ),
                        ),
                        Text(
                          'kcal',
                          style: TextStyle(
                            fontSize: sw * 0.04,
                            color: Colors.grey[600], // Adjusted color
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: sh * 0.03),

                  // Macro Grid
                  Row(
                    children: [
                      Expanded(
                        child: _buildNutrientCard(
                          // Ensure this uses light theme styles
                          'Protein',
                          '${entry.protein}',
                          'g',
                          lucide.LucideIcons.zap,
                          Colors.amber,
                        ),
                      ),
                      SizedBox(width: sw * 0.03),
                      Expanded(
                        child: _buildNutrientCard(
                          // Ensure this uses light theme styles
                          'Carbs',
                          '${entry.carbs}',
                          'g',
                          lucide.LucideIcons.wheat,
                          Colors.green,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: sh * 0.02),
                  Row(
                    children: [
                      Expanded(
                        child: _buildNutrientCard(
                          // Ensure this uses light theme styles
                          'Fat',
                          '${entry.fat}',
                          'g',
                          lucide.LucideIcons.droplet,
                          Colors.blue,
                        ),
                      ),
                      SizedBox(width: sw * 0.03),
                      Expanded(
                        child: _buildNutrientCard(
                          // Ensure this uses light theme styles
                          'Fiber',
                          '${entry.fiber}',
                          'g',
                          lucide.LucideIcons.leaf,
                          Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: sh * 0.03), // Space before health score

                  // --- ADD CONDITIONAL HEALTH SCORE CARD ---
                  if (entry.healthScore != null) ...[
                    Container(
                      padding: EdgeInsets.all(sw * 0.04),
                      decoration: BoxDecoration(
                        // Inner card decoration
                        color: const Color(0xFFE9ECEF), // Slightly darker bg
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(children: [
                                Icon(Icons.favorite,
                                    color: Colors.red[400], size: sw * 0.05),
                                SizedBox(width: sw * 0.02),
                                Text(
                                  'Health Score',
                                  style: TextStyle(
                                    fontSize: sw * 0.045,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ]),
                              Text(
                                '${entry.healthScore}/10',
                                style: TextStyle(
                                  fontSize: sw * 0.04,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: sh * 0.015),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: (entry.healthScore ?? 0) / 10.0,
                              backgroundColor: Colors.grey[300],
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  _getHealthScoreColor(entry.healthScore ?? 0)),
                              minHeight: 10,
                            ),
                          ),
                          if (entry.healthDescription != null &&
                              entry.healthDescription!.isNotEmpty) ...[
                            SizedBox(height: sh * 0.015),
                            Text(
                              entry.healthDescription!,
                              style: TextStyle(
                                fontSize: sw * 0.035,
                                color: Colors.black54, // Secondary text
                                height: 1.4,
                              ),
                            ),
                          ]
                        ],
                      ),
                    ),
                    SizedBox(height: sh * 0.04), // Space after health score
                  ],
                  // --- END HEALTH SCORE CARD ---

                  // Close Button (Adjusted for light theme)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close,
                          color: Colors.white), // White icon on black button
                      label: const Text('Close',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold) // White text
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                        Colors.black87, // Dark button for contrast
                        padding: EdgeInsets.symmetric(vertical: sh * 0.018),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: sh * 0.02), // Bottom padding
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Add this helper inside _HomescreenState
  Color _getHealthScoreColor(int score) {
    // Using the colors defined in nutrition_scanner.dart
    const Color kSuccessColor = Color(0xFF28A745);
    const Color kWarningColor = Color(0xFFFFC107);
    const Color kDangerColor = Color(0xFFDC3545);

    if (score >= 8) return kSuccessColor;
    if (score >= 5) return kWarningColor;
    return kDangerColor;
  }

// --- END OF METHOD ---
  // --- WIDGET MODIFIED ---
  Widget _comingSoonCard(String title, String desc, IconData icon, double height,
      double sw, double sh) {
    return GestureDetector(
      onTap: () => _showSnackBar('Feature coming soon!'),
      child: Container(
        height: height,
        padding: EdgeInsets.all(sw * 0.04),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // --- MODIFIED: Icon wrapped and "SOON" badge moved ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(sw * 0.03),
                  decoration: BoxDecoration(
                    color: Colors.grey[200]!,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.grey[300]!,
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: Colors.grey[500], // Kept grey for "disabled"
                    size: sw * 0.06, // Matched size
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: sw * 0.02, vertical: sw * 0.01),
                  decoration: BoxDecoration(
                      color: Colors.orange[100],
                      borderRadius: BorderRadius.circular(12)),
                  child: Text("SOON",
                      style: TextStyle(
                          color: Colors.orange[700],
                          fontSize: sw * 0.028,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            // --- END MODIFICATION ---
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: sw * 0.038,
                        fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                SizedBox(height: sh * 0.003),
                Text(desc,
                    style:
                    TextStyle(color: Colors.grey[500], fontSize: sw * 0.03),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Wellness Tips
  Widget _buildWellnessTipsSection() {
    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;
    return Container(
      padding: EdgeInsets.all(sw * 0.05),
      decoration: _getCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(lucide.LucideIcons.lightbulb,
                  color: Colors.amber, size: sw * 0.06),
              SizedBox(width: sw * 0.03),
              Text("Wellness Tips",
                  style: TextStyle(
                      color: Colors.black87,
                      fontSize: sw * 0.045,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          SizedBox(height: sh * 0.02),
          _tip("Aim for 7-9 hours of sleep per night.", sw),
          SizedBox(height: sh * 0.015),
          _tip("Stay hydrated with at least 8 glasses of water daily.", sw),
          SizedBox(height: sh * 0.015),
          _tip("Exercise at least 30 minutes a day to boost energy.", sw),
        ],
      ),
    );
  }

  Widget _tip(String text, double sw) {
    return Container(
      padding: EdgeInsets.all(sw * 0.03),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!, width: 1),
      ),
      child: Row(
        children: [
          Icon(lucide.LucideIcons.check, size: sw * 0.04, color: Colors.green),
          SizedBox(width: sw * 0.03),
          Expanded(
              child: Text(text,
                  style:
                  TextStyle(color: Colors.black54, fontSize: sw * 0.033))),
        ],
      ),
    );
  }
}

// Custom painter for dashed circle border
class DashedCirclePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  DashedCirclePainter({
    required this.color,
    this.strokeWidth = 2.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    const dashWidth = 3.0;
    const dashSpace = 3.0;

    double currentAngle = 0;
    const totalAngle = 2 * 3.14159;

    while (currentAngle < totalAngle) {
      final startAngle = currentAngle;
      final endAngle = (currentAngle + dashWidth / radius).clamp(0.0, totalAngle);

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        endAngle - startAngle,
        false,
        paint,
      );

      currentAngle = endAngle + dashSpace / radius;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}