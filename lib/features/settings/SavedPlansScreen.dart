// saved_plans_screen.dart

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

  Widget _buildCollapsibleDayTile(Map<String, dynamic> dayData, bool isDark) {
    final bool isRestDay = (dayData['activity'] ?? '').toLowerCase().contains('rest');
    // Safely cast exercises, assuming contents are dynamic but containers are lists
    final exercises = dayData['details'] as List<dynamic>?;

    Color iconColor = isRestDay ? Colors.green : AppColors.black;
    Color tileColor = isDark ? AppColors.cardBackground(isDark) : AppColors.white;
    Color titleColor = AppColors.textPrimary(isDark);
    Color subtitleColor = AppColors.textSecondary(isDark);

    IconData leadingIcon = isRestDay ? lucide.LucideIcons.bed : lucide.LucideIcons.dumbbell;
    String subtitleText = isRestDay ? 'Recovery Day' : (dayData['activity'] ?? 'Full Workout');

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.borderColor(isDark), width: 1.0),
      ),
      color: tileColor,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          dayData['day'] ?? 'Unknown Day',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: titleColor),
        ),
        subtitle: Text(
          subtitleText,
          style: TextStyle(
            color: subtitleColor,
            fontStyle: isRestDay ? FontStyle.italic : FontStyle.normal,
          ),
        ),
        leading: Icon(leadingIcon, color: iconColor),
        children: [
          Divider(height: 1, color: AppColors.borderColor(isDark)),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: exercises != null && exercises.isNotEmpty
                  ? exercises.map<Widget>((exercise) {
                final instruction = exercise['instruction'] ?? 'No specific instructions provided.';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(color: subtitleColor, fontSize: 15, height: 1.6),
                      children: [
                        TextSpan(
                          text: '${exercise['name'] ?? "Exercise"}: ',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: titleColor,
                            fontSize: 16,
                          ),
                        ),
                        TextSpan(text: instruction),
                      ],
                    ),
                  ),
                );
              }).toList()
                  : [
                Text(
                  isRestDay
                      ? 'Ensure you focus on mobility, stretching, or light cardio to aid muscle recovery.'
                      : 'No detailed exercises available for this session.',
                  style: TextStyle(color: subtitleColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutPlanDisplay(bool isDark, Map<String, dynamic> plan) {
    // Safely cast schedule and tips
    final schedule = plan['weeklySchedule'] as List<dynamic>?;
    final tips = plan['generalTips'] as List<dynamic>?;

    return Container(
      padding: const EdgeInsets.all(16),
      // Removed bottom margin to be handled by the ListView
      decoration: BoxDecoration(
        color: AppColors.cardBackground(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor(isDark)),
      ),
      child: Column(
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
            ...schedule.map((dayData) => _buildCollapsibleDayTile(dayData as Map<String, dynamic>, isDark)).toList()
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
      ),
    );
  }

  /// --- WIDGET FOR MEAL PLAN DISPLAY ---
  Widget _buildMealPlanDisplay(bool isDark, Map<String, dynamic> plan) {
    final summary = plan['planSummary'] as Map<String, dynamic>?;
    final dailyPlans = plan.entries.where((e) => e.key.toLowerCase().startsWith('day')).toList();

    // FIX: Safely extract and cast the List<dynamic> from Firestore to List<String>
    final dynamic rawGroceryList = plan['groceryList'];
    final groceryList = rawGroceryList != null ? List<String>.from(rawGroceryList) : null;


    return Container(
      padding: const EdgeInsets.all(16),
      // Removed bottom margin to be handled by the ListView
      decoration: BoxDecoration(
        color: AppColors.cardBackground(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor(isDark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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

          // --- CORRECTED SORTING LOGIC (One single, clean block) ---
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
                  child: _buildMealDayExpansionTile(isDark, dayName, dayMeals, totalCalories),
                );
              }).toList();
            }(), // Self-executing function ends here



          if (groceryList != null && groceryList.isNotEmpty) ...[
            const SizedBox(height: 24),
            TextButton.icon(
              // Passed the correctly typed List<String>
              onPressed: () => _showGroceryListDialog(context, isDark, groceryList),
              icon: Icon(Icons.shopping_cart, size: 20, color: AppColors.textPrimary(isDark)),
              label: Text('View Grocery List', style: TextStyle(color: AppColors.textPrimary(isDark), fontWeight: FontWeight.w600)),
            ),
          ],
        ],
      ),
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

  Widget _buildMealDayExpansionTile(bool isDark, String dayName, Map<String, dynamic> dayMeals, int totalCalories) {
    Color titleColor = AppColors.textPrimary(isDark);
    Color subtitleColor = AppColors.textSecondary(isDark);

    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
      collapsedBackgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(dayName, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: titleColor)),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: AppColors.black, borderRadius: BorderRadius.circular(20)),
        child: Text('$totalCalories kcal', style: TextStyle(color: AppColors.white, fontSize: 12, fontWeight: FontWeight.w600)),
      ),
      children: [
        Divider(height: 1, color: AppColors.borderColor(isDark)),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: ['breakfast', 'lunch', 'dinner', 'snacks'].map((mealType) {
              if (!dayMeals.containsKey(mealType) || dayMeals[mealType] is! Map<String, dynamic>) return const SizedBox.shrink();
              final meal = dayMeals[mealType] as Map<String, dynamic>;
              final mealName = meal['name'] ?? 'Meal';
              final recipe = meal['recipe'] ?? 'No recipe provided.';
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${mealType.toUpperCase()}: $mealName (${meal['calories'] as int? ?? 0} kcal)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: titleColor)),
                    const SizedBox(height: 4),
                    Text(recipe, style: TextStyle(fontSize: 13, color: subtitleColor, height: 1.4)),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
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