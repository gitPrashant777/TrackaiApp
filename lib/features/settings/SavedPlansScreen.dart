import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:trackai/core/constants/appcolors.dart';
import 'package:trackai/core/themes/theme_provider.dart';
import 'package:trackai/features/home/ai-options/service/workout_planner_service.dart';
import 'package:trackai/features/settings/service/geminiservice.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart' as lucide;

class SavedPlansScreen extends StatefulWidget {
  const SavedPlansScreen({Key? key}) : super(key: key);

  @override
  State<SavedPlansScreen> createState() => _SavedPlansScreenState();
}

class _SavedPlansScreenState extends State<SavedPlansScreen> {
  List<Map<String, dynamic>> _savedPlansList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllSavedPlans();
  }

  /// Fetch single workout plan and convert it to a list
  Future<List<Map<String, dynamic>>> _getSavedWorkoutPlansList() async {
    final singlePlan = await WorkoutPlannerService.getSavedWorkoutPlan();
    if (singlePlan != null) {
      singlePlan['planType'] = 'workout';
      return [singlePlan];
    }
    return [];
  }

  /// Load all saved plans (Workout + Meal)
  Future<void> _loadAllSavedPlans() async {
    setState(() => _isLoading = true);

    try {
      List<Map<String, dynamic>> fetchedPlans = [];

      // Fetch workout plans
      final workoutPlans = await _getSavedWorkoutPlansList();
      fetchedPlans.addAll(workoutPlans);

      // Fetch meal plans
      final mealPlans = await GeminiService.getSavedMealPlansList();
      fetchedPlans.addAll(mealPlans);

      // Optional: Sort by save date (newest first)
      fetchedPlans.sort((a, b) {
        final dateA = a['savedAt'] as DateTime? ?? DateTime(1900);
        final dateB = b['savedAt'] as DateTime? ?? DateTime(1900);
        return dateB.compareTo(dateA);
      });

      setState(() => _savedPlansList = fetchedPlans);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading saved plans: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// --- WIDGETS FOR WORKOUT PLAN DISPLAY ---

  // NEW: Clickable workout day card
  Widget _buildWorkoutDayCard(Map<String, dynamic> dayData, bool isDark) {
    final bool isRestDay = (dayData['activity'] ?? '').toLowerCase().contains('rest') || (dayData['details'] as List? ?? []).isEmpty;
    final exercises = dayData['details'] as List?;
    final exerciseCount = exercises?.length ?? 0;

    Color backgroundColor = isDark ? Colors.grey[800]! : Colors.grey[100]!;
    String dayName = dayData['day'] ?? 'Day';
    String activity = dayData['activity'] ?? 'Workout';

    final bool isTappable = !isRestDay || (exercises?.isNotEmpty ?? false);

    void navigateToDayDetails() {
      if (isTappable) {
        Navigator.push(
          context,
          MaterialPageRoute(
            // Navigate to the new page copied from smartGymkit.dart
            builder: (context) => _SavedWorkoutDayDetailsPage(dayData: dayData, isDark: isDark),
          ),
        );
      }
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isTappable ? navigateToDayDetails : null,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Day title - Big font
                Text(
                  dayName + ":",
                  style: TextStyle(
                    fontSize: 18, // Big font
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black, // Dark color
                  ),
                ),
                const SizedBox(height: 4),
                // Exercise name and count in one line
                Row(
                  children: [
                    // Exercise name
                    Text(
                      isRestDay ? 'Rest Day' : activity,
                      style: TextStyle(
                        fontSize: 14, // Small font
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Vertical divider
                    Container(
                      width: 1,
                      height: 14,
                      color: isDark ? Colors.grey[600] : Colors.grey[400],
                    ),
                    const SizedBox(width: 8),
                    // Exercise count
                    Text(
                      '$exerciseCount ${exerciseCount == 1 ? 'exercise' : 'exercises'}',
                      style: TextStyle(
                        fontSize: 14, // Small font
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    const Spacer(),
                    // Arrow icon for tappable days
                    if (isTappable)
                      Icon(
                        Icons.arrow_forward_ios,
                        color: isDark ? Colors.white : Colors.black,
                        size: 16,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  Widget _buildWorkoutPlanDisplay(bool isDark, Map<String, dynamic> plan) {
    // Safely cast schedule and tips
    final schedule = plan['weeklySchedule'] as List<dynamic>?;
    final tips = plan['generalTips'] as List<dynamic>?;

    // --- MODIFIED: Removed the outer Container ---
    return Column( // Directly return the Column
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(lucide.LucideIcons.dumbbell, size: 24, color: AppColors.black),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                plan['planTitle'] ?? 'Saved Workout Plan',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary(isDark)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          plan['introduction'] ?? 'Your personalized workout plan.',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary(isDark)),
        ),
        const SizedBox(height: 24),
        Text(
          'Workout Schedule',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary(isDark)),
        ),
        const SizedBox(height: 12),
        if (schedule != null && schedule.isNotEmpty)
        // UPDATED: Call the new card widget
          ...schedule.map((dayData) => _buildWorkoutDayCard(dayData as Map<String, dynamic>, isDark)).toList()
        else
          Text('No schedule provided.', style: TextStyle(color: AppColors.textSecondary(isDark))),
        if (tips != null && tips.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            'Helpful Tips',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary(isDark)),
          ),
          const SizedBox(height: 12),
          ...tips.map((tip) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
            title: Text(tip.toString(), style: TextStyle(color: AppColors.textSecondary(isDark), fontSize: 15)),
          )).toList(),
        ],
      ],
    );
  }
  /// --- WIDGET FOR MEAL PLAN DISPLAY ---
  Widget _buildMealPlanDisplay(bool isDark, Map<String, dynamic> plan) {
    final summary = plan['planSummary'] as Map<String, dynamic>?;
    final dailyPlans = plan.entries.where((e) => e.key.toLowerCase().startsWith('day')).toList();

    // FIX: Safely extract and cast the List<dynamic> from Firestore to List<String>
    final dynamic rawGroceryList = plan['groceryList'];
    final groceryList = rawGroceryList != null ? List<String>.from(rawGroceryList) : null;

    // --- MODIFIED: REMOVED THE OUTER CONTAINER ---
    return Column( // Directly return the Column content
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Retained the header for each meal plan block
        Row(
          children: [
            Icon(Icons.restaurant, size: 24, color: AppColors.black),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                plan['planTitle'] ?? 'Saved Meal Plan',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary(isDark)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          plan['introduction'] ?? 'A ${summary?['totalDays'] ?? 'N/A'} day meal plan.',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary(isDark)),
        ),
        const SizedBox(height: 24),
        // Plan Details
        Text('Plan Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary(isDark))),
        const SizedBox(height: 12),
        if (summary != null) ...[
          _buildDetailRow('Diet Type', summary['dietType'] ?? 'N/A', isDark),
          _buildDetailRow('Duration', '${summary['totalDays'] ?? 'N/A'} Days', isDark),
          _buildDetailRow('Avg. Calories', '${summary['avgDailyCalories'] ?? 'N/A'} kcal', isDark),
        ],
        const SizedBox(height: 24),
        // Daily Meals
        Text('Daily Meal Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary(isDark))),
        const SizedBox(height: 12),

        if (dailyPlans.isNotEmpty)
          ...() {
            final sortedDailyPlans = dailyPlans.toList()
              ..sort((a, b) {
                final aNum = int.tryParse(a.key.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                final bNum = int.tryParse(b.key.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                return aNum.compareTo(bNum);
              });

            return sortedDailyPlans.map((entry) {
              final dayName = entry.key;
              final dayMeals = entry.value as Map<String, dynamic>;
              final totalCalories = dayMeals['totalCalories'] as int? ?? 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: _buildMealDayCard(isDark, dayName, dayMeals, totalCalories),
              );
            }).toList();
          }(),

        if (groceryList != null && groceryList.isNotEmpty) ...[
          const SizedBox(height: 24),
          TextButton.icon(
            onPressed: () => _showGroceryListDialog(context, isDark, groceryList),
            icon: Icon(Icons.shopping_cart, size: 20, color: AppColors.textPrimary(isDark)),
            label: Text('View Grocery List', style: TextStyle(color: AppColors.textPrimary(isDark), fontWeight: FontWeight.w600)),
          ),
        ],
      ],
    );
  }
  // Parameter is now correctly typed List<String>
  void _showGroceryListDialog(BuildContext context, bool isDark, List<String> groceryList) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.cardBackground(isDark),
        title: Text('Consolidated Grocery List', style: TextStyle(color: AppColors.textPrimary(isDark))),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: groceryList.map((item) {
              final isHeader = item.startsWith('**') && item.endsWith('**');
              return Padding(
                padding: EdgeInsets.only(top: isHeader ? 8 : 4, left: isHeader ? 0 : 16),
                child: Text(
                  isHeader ? item.replaceAll('**', '') : '• $item',
                  style: TextStyle(
                    color: isHeader ? AppColors.black : AppColors.textSecondary(isDark),
                    fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
                    fontSize: 15,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: TextStyle(color: AppColors.black)),
          ),
        ],
      ),
    );
  }

  // NEW: Clickable meal day card
  Widget _buildMealDayCard(bool isDark, String dayName, Map<String, dynamic> dayMeals, int totalCalories) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            // Navigate to the new page copied from AIMealPlannerResults.dart
            builder: (context) => _SavedMealDayDetailsPage(
              dayData: {
                'day': dayName,
                'meals': dayMeals,
                'totalCalories': totalCalories,
              },
              isDark: isDark,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.restaurant,
              color: isDark ? Colors.white : Colors.black,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dayName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$totalCalories kcal',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$label:', style: TextStyle(color: AppColors.textSecondary(isDark), fontSize: 16)),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.right,
                style: TextStyle(color: AppColors.textPrimary(isDark), fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  /// --- BUILD METHOD (Refactored for Tabs) ---
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    final workoutPlans = _savedPlansList.where((p) => p['planType'] == 'workout').toList();
    final mealPlans = _savedPlansList.where((p) => p['planType'] == 'meal').toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background(isDark),
        appBar: AppBar(
          backgroundColor: AppColors.background(isDark),
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: AppColors.textPrimary(isDark)),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text('Saved AI Plans',
              style: TextStyle(color: AppColors.textPrimary(isDark), fontSize: 20, fontWeight: FontWeight.bold)),
          centerTitle: true,
          bottom: TabBar(
            indicatorColor: AppColors.black,
            labelColor: AppColors.textPrimary(isDark),
            unselectedLabelColor: AppColors.textDisabled(isDark),
            labelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            unselectedLabelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            tabs: const [
              Tab(text: 'Workouts'),
              Tab(text: 'Meal Plans'),
            ],
          ),
        ),
        body: _isLoading
            ? Center(child: CircularProgressIndicator(color: AppColors.black))
            : TabBarView(
          children: [
            _buildWorkoutTab(context, isDark, workoutPlans),
            _buildMealTab(context, isDark, mealPlans),
          ],
        ),
      ),
    );
  }

  /// --- NEW TAB BUILDER WIDGETS ---

  Widget _buildWorkoutTab(BuildContext context, bool isDark, List<Map<String, dynamic>> plans) {
    if (plans.isEmpty) {
      return _buildEmptyTabMessage(
        'No Workout Plans Saved',
        'Generate a new workout plan and save it to view it here.',
        isDark,
        lucide.LucideIcons.dumbbell,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      itemCount: plans.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        return _buildWorkoutPlanDisplay(isDark, plans[index]);
      },
    );
  }

  Widget _buildMealTab(BuildContext context, bool isDark, List<Map<String, dynamic>> plans) {
    if (plans.isEmpty) {
      return _buildEmptyTabMessage(
        'No Meal Plans Saved',
        'Generate a new meal plan and save it to view it here.',
        isDark,
        Icons.restaurant,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      itemCount: plans.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        return _buildMealPlanDisplay(isDark, plans[index]);
      },
    );
  }

  /// --- REVISED EMPTY MESSAGE WIDGET (Replaces _buildEmptyCategoryMessage) ---

  Widget _buildEmptyTabMessage(String title, String subtitle, bool isDark, IconData icon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 60, color: AppColors.textDisabled(isDark)),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textSecondary(isDark)),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textDisabled(isDark), fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------------------
// COPIED FROM AIMealPlannerResults.dart
// RENAMED to _SavedMealDayDetailsPage
// MODIFIED: Removed grey box, changed title color
// -------------------------------------------------------------------------
class _SavedMealDayDetailsPage extends StatelessWidget {
  final Map<String, dynamic> dayData;
  final bool isDark;

  const _SavedMealDayDetailsPage(
      {Key? key, required this.dayData, required this.isDark})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final dayName = dayData['day'] ?? 'Day';
    final dayMeals = dayData['meals'] as Map<String, dynamic>;
    final totalCalories = dayData['totalCalories'] as int? ?? 0;

    final textColor = isDark ? Colors.white : Colors.black;
    final backgroundColor = isDark ? Colors.black : Colors.white;
    // final cardColor = Colors.grey[100]; // No longer needed

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '',
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Day Header
            Text(
              dayName,
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),

            Text(
              'Total calories : $totalCalories ',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            // Meals List
            ...['breakfast', 'lunch', 'dinner', 'snacks'].map((mealType) {
              if (!dayMeals.containsKey(mealType)) {
                return const SizedBox.shrink();
              }
              final meal = dayMeals[mealType] as Map<String, dynamic>;
              final mealName = meal['name'] ?? 'Meal';
              final calories = meal['calories'] as int? ?? 0;
              final recipe = meal['recipe'] ?? '';

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- FIX 1: Meal Type Header color changed to grey ---
                  Text(
                    mealType.toUpperCase(),
                    style: TextStyle(
                      fontSize: 20, // 2x bigger
                      fontWeight: FontWeight.bold,
                      color: Colors.grey, // <-- MODIFIED
                    ),
                  ),
                  const SizedBox(height: 12),

                  // --- FIX 2: Removed decoration from Container ---
                  Container(
                    width: double.infinity,
                    // decoration: BoxDecoration( // <-- REMOVED
                    //   color: cardColor,
                    //   borderRadius: BorderRadius.circular(8),
                    // ),
                    padding: const EdgeInsets.all(
                        16), // Kept padding for spacing
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Meal Name with Calories (with bullet point)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '• ',
                              style: TextStyle(
                                fontSize: 40,
                                color: textColor,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                '(approx. $calories calories): $mealName',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: textColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),

                        // Recipe (with bullet point)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '• ',
                              style: TextStyle(
                                fontSize: 40,
                                color: textColor,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'Recipe: $recipe',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: textColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------------------
// COPIED FROM smartGymkit.dart
// RENAMED to _SavedWorkoutDayDetailsPage and _SavedWorkoutExerciseDetailsPage
// -------------------------------------------------------------------------
class _SavedExercise {
  final String name;
  final String instruction;

  _SavedExercise({required this.name, required this.instruction});
}

// -------------------------------------------------------------------------
// New Page 1: Day Details (Shows list of exercises for a selected day)
// -------------------------------------------------------------------------
class _SavedWorkoutDayDetailsPage extends StatelessWidget {
  final Map<String, dynamic> dayData;
  final bool isDark;

  const _SavedWorkoutDayDetailsPage({Key? key, required this.dayData, required this.isDark}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final exercises = (dayData['details'] as List?)
        ?.map((e) => _SavedExercise(name: e['name'] ?? 'N/A', instruction: e['instruction'] ?? ''))
        .toList() ??
        [];
    final dayName = dayData['day'] ?? 'Workout Day';
    final activity = dayData['activity'] ?? 'Details';

    final primaryColor = isDark ? Colors.white : Colors.black;
    final secondaryColor = isDark ? Colors.grey[400] : Colors.grey[600];
    final backgroundColor = isDark ? Colors.black : Colors.white;
    final cardColor = isDark ? Colors.grey[900] : Colors.grey[50];

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: primaryColor),
        title: const Text(''), // Empty app bar title
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Day Title and Dumbbell Icon in same row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    dayName.toUpperCase(),
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: 40,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                Icon(
                  Icons.fitness_center,
                  color: primaryColor,
                  size: 80,
                ),
              ],
            ),
            const SizedBox(height: 2),

            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Text(
                activity,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  height: 1.1,
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Exercise Count
            Text(
              '${exercises.length} ${exercises.length == 1 ? 'exercise' : 'exercises'}',
              style: TextStyle(
                color: primaryColor,
                fontSize: 21,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),

            // Exercises List
            if (exercises.isNotEmpty)
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: exercises.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) => _buildSavedExerciseItem(
                  context,
                  exercises[index],
                  isDark,
                  primaryColor,
                  secondaryColor!,
                  cardColor!,
                ),
              )
            else
              Center(
                child: Text(
                    'No detailed exercises available for this session.',
                    style: TextStyle(color: secondaryColor)
                ),
              )
          ],
        ),
      ),
    );
  }
}

Widget _buildSavedExerciseItem(
    BuildContext context,
    _SavedExercise exercise,
    bool isDark,
    Color primaryColor,
    Color secondaryColor,
    Color cardColor,
    ) {
  // Get first letter for the avatar
  final firstLetter = exercise.name.isNotEmpty ? exercise.name[0].toUpperCase() : '?';

  return GestureDetector(
    onTap: () {
      // Navigate to Exercise Details Page
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => _SavedWorkoutExerciseDetailsPage(exercise: exercise, isDark: isDark),
        ),
      );
    },
    child: Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Black Rounded Square with first letter
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                firstLetter,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          const SizedBox(width: 16),

          // Exercise Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise.name,
                  style: TextStyle(
                    color: primaryColor,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                if (exercise.instruction.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    exercise.instruction,
                    style: TextStyle(
                      color: secondaryColor,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),

          // Chevron Icon
          Icon(
            Icons.chevron_right,
            color: secondaryColor,
            size: 20,
          ),
        ],
      ),
    ),
  );
}


// -------------------------------------------------------------------------
// Exercise Details Page (MODIFIED to remove AI Tips)
// -------------------------------------------------------------------------
class _SavedWorkoutExerciseDetailsPage extends StatefulWidget {
  final _SavedExercise exercise;
  final bool isDark;

  const _SavedWorkoutExerciseDetailsPage({Key? key, required this.exercise, required this.isDark}) : super(key: key);

  @override
  State<_SavedWorkoutExerciseDetailsPage> createState() => _SavedWorkoutExerciseDetailsPageState();
}

class _SavedWorkoutExerciseDetailsPageState extends State<_SavedWorkoutExerciseDetailsPage> {

  // REMOVED: AI Tip loading logic

  Widget _buildSection({
    required String title,
    required Widget content,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: widget.isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          content,
        ],
      ),
    );
  }

  Widget _buildNumberedItem(String text, int number) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$number.',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: widget.isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: widget.isDark ? Colors.white : Colors.black,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // REMOVED: _buildPreparationContent() widget

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: widget.isDark ? Colors.black : Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(
            color: widget.isDark ? Colors.white : Colors.black),
        title: Text(
          widget.exercise.name,
          style: TextStyle(
            fontSize: 16,
            color: widget.isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Exercise Header
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: widget.isDark ? Colors.white : Colors.black,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        widget.exercise.name.isNotEmpty ? widget.exercise.name[0].toUpperCase() : '?',
                        style: TextStyle(
                          fontSize: 16,
                          color: widget.isDark ? Colors.black : Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.exercise.name,
                          style: TextStyle(
                            fontSize: 16,
                            color: widget.isDark ? Colors.white : Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '3 Sets x 3 reps',
                          style: TextStyle(
                            fontSize: 14,
                            color: widget.isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Instructions Section with Grey Background
            _buildSection(
              title: 'Instructions',
              content: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: widget.isDark ? Colors.grey[900] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.exercise.instruction.isNotEmpty
                      ? widget.exercise.instruction
                      : 'No specific instructions available for this exercise.',
                  style: TextStyle(
                    fontSize: 14,
                    color: widget.isDark ? Colors.white : Colors.black,
                    height: 1.4,
                  ),
                ),
              ),
            ),

            // REMOVED: Preparation Section

            // Execution Section - Only one point
            _buildSection(
              title: 'Execution',
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildNumberedItem(
                    'Exhale on Exertion: Exhaling during the hard part (lifting/pushing) helps stabilize your core and generates more power.',
                    1,
                  ),
                  _buildNumberedItem(
                    'Inhale on Return: Inhaling during the easy part (lowering/returning to start) prepares your body for the next rep.Inhale on Return: Inhaling during the easy part (lowering/returning to start) prepares your body for the next rep.',
                    2,
                  ),
                ],
              ),
            ),

            // General Tips Section - Added back with three points
            _buildSection(
              title: 'General Tips',
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildNumberedItem(
                    'Warm-up before each workout with light cardio and dynamic stretching.',
                    1,
                  ),
                  _buildNumberedItem(
                    'Cool-down after each workout with static stretching, holding each stretch for 20-30 seconds.',
                    2,
                  ),
                  _buildNumberedItem(
                    'Stay hydrated by drinking plenty of water throughout the day and listen to your body.',
                    3,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}