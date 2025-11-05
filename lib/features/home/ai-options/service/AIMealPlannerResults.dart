import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart' as lucide;

import '../../../settings/service/geminiservice.dart';
import '../mealPlanner.dart';
class AIMealPlannerResults extends StatefulWidget {
  final Map<String, dynamic> mealPlan;
  final bool isDark;

  const AIMealPlannerResults({
    Key? key,
    required this.mealPlan,
    required this.isDark,
  }) : super(key: key);

  @override
  State<AIMealPlannerResults> createState() => _AIMealPlannerResultsState();
}

class _AIMealPlannerResultsState extends State<AIMealPlannerResults> {
  bool _isSaving = false;

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.black,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.black,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _savePlan() async {
    if (widget.mealPlan.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      // NOTE: Assuming this service method exists
      await GeminiService.saveMealPlan(widget.mealPlan);
      _showSuccessSnackBar('Meal plan saved successfully!');
    } catch (e) {
      _showErrorSnackBar('Failed to save plan: ${e.toString()}');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Widget _buildSummaryItem(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpansionTile({
    required bool isDark,
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
        ),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        iconColor: isDark ? Colors.white : Colors.black,
        collapsedIconColor: isDark ? Colors.grey[400] : Colors.grey[600],
        shape: const Border(),
        title: Row(
          children: [
            Icon(
              icon,
              color: isDark ? Colors.white : Colors.black,
              size: 22,
            ),
            const SizedBox(width: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
        children: children,
      ),
    );
  }

  Widget _buildGroceryList(List<String> groceryList, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: groceryList.map((item) {
          bool isHeader = item.startsWith('**') && item.endsWith('**');
          return Padding(
            padding: EdgeInsets.only(
              top: isHeader ? 12 : 6,
              left: isHeader ? 0 : 16,
            ),
            child: Text(
              isHeader ? item.replaceAll('**', '') : '• $item',
              style: TextStyle(
                color: isHeader
                    ? (isDark ? Colors.white : Colors.black)
                    : (isDark ? Colors.grey[300] : Colors.grey[700]),
                fontSize: isHeader ? 16 : 14,
                fontWeight: isHeader ? FontWeight.w600 : FontWeight.w400,
                height: 1.5,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCookingGuide(String cookingGuide, bool isDark) {
    final primaryTextColor = isDark ? Colors.white : Colors.black;
    final secondaryTextColor = isDark ? Colors.grey[400] : Colors.grey[600];
    final cardBg = isDark ? Colors.grey[800] : Colors.grey[100];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
      margin: const EdgeInsets.only(top: 10, bottom: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Chef\'s Tips for Meal Prep',
            style: TextStyle(
              color: primaryTextColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          SelectableText(
            cookingGuide.trim(),
            style: TextStyle(
              color: secondaryTextColor,
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.mealPlan['planSummary'] as Map<String, dynamic>;
    final groceryList = widget.mealPlan['groceryList'] as List<String>? ??
        ['No grocery list generated.'];
    final cookingGuide = widget.mealPlan['cookingGuide'] as String? ??
        'No cooking guide generated.';

    return Scaffold(
      backgroundColor: widget.isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: widget.isDark ? Colors.black : Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: widget.isDark ? Colors.white : Colors.black,
            size: 20,
          ),
        ),
        title: Text(
          'Your Meal Plan',
          style: TextStyle(
            color: widget.isDark ? Colors.white : Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header in Black Box
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Meal Plan',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your personalized ${summary['totalDays']}-day meal plan is ready!',
                    textAlign: TextAlign.start,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Colors.white,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 2. Action Buttons (Save/New Plan)
            Wrap(
              spacing: 16,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                SizedBox(
                  width: 100,
                  child: OutlinedButton.icon(
                    onPressed: _isSaving ? null : _savePlan,
                    icon: _isSaving
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                        : const Icon(lucide.LucideIcons.save),
                    label: Text(_isSaving ? 'Saving...' : 'Save Plan'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(
                        color: widget.isDark ? Colors.grey[800]! : Colors.grey[300]!,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      foregroundColor: widget.isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                SizedBox(
                  width: 100,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context); // Go back to planner
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('New Plan'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.isDark ? Colors.white : Colors.black,
                      foregroundColor: widget.isDark ? Colors.black : Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // 3. Plan Summary with Black Border
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: widget.isDark ? Colors.grey[900] : Colors.grey[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.black,
                  width: 2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Plan Summary',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: widget.isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSummaryItem(
                    'Duration',
                    '${summary['totalDays']} Days',
                    widget.isDark,
                  ),
                  _buildSummaryItem(
                    'Daily Calories',
                    '${summary['avgDailyCalories']} kcal',
                    widget.isDark,
                  ),
                  _buildSummaryItem(
                    'Diet Type',
                    summary['dietType'],
                    widget.isDark,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 4. Daily Meal Plans (Clickable Cards)
            Text(
              'Daily Meal Plans',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: widget.isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 16),
            ...(widget.mealPlan.entries
                .where((entry) => entry.key.startsWith('Day'))
                .map((entry) {
              final dayName = entry.key;
              final dayMeals = entry.value as Map<String, dynamic>;

              // Check for our fallback placeholder
              final bool isPlaceholder = dayMeals['breakfast']?['name'] ==
                  'Plan Generation Failed';

              if (isPlaceholder) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: widget.isDark ? Colors.grey[900] : Colors.grey[50],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: widget.isDark ? Colors.grey[800]! : Colors.grey[200]!,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Plan Generation Error',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SelectableText(
                        dayMeals['breakfast']['recipe'],
                        style: TextStyle(
                          fontSize: 14,
                          color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                );
              }

              // Success: Render clickable day card
              final int totalCalories = dayMeals['totalCalories'] as int? ?? 0;

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DayDetailsPage(
                        dayData: {
                          'day': dayName,
                          'meals': dayMeals,
                          'totalCalories': totalCalories,
                        },
                        isDark: widget.isDark,
                      ),
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: widget.isDark ? Colors.grey[900] : Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: widget.isDark ? Colors.grey[800]! : Colors.grey[300]!,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.restaurant,
                        color: widget.isDark ? Colors.white : Colors.black,
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
                                color: widget.isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$totalCalories kcal',
                              style: TextStyle(
                                fontSize: 14,
                                color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
                        size: 16,
                      ),
                    ],
                  ),
                ),
              );
            }).toList()),
            const SizedBox(height: 24),

            // 5. Grocery List
            _buildExpansionTile(
              isDark: widget.isDark,
              icon: Icons.shopping_cart_outlined,
              title: 'Grocery List',
              children: [
                _buildGroceryList(groceryList, widget.isDark),
              ],
            ),
            const SizedBox(height: 12),

            // 6. Cooking Guide
            _buildExpansionTile(
              isDark: widget.isDark,
              icon: Icons.soup_kitchen_outlined,
              title: 'Cooking Guide',
              children: [
                _buildCookingGuide(cookingGuide, widget.isDark),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
// --- UPDATED: Simple Day Details Page with Black & White Theme ---
class DayDetailsPage extends StatelessWidget {
  final Map<String, dynamic> dayData;
  final bool isDark;

  const DayDetailsPage({Key? key, required this.dayData, required this.isDark}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final dayName = dayData['day'] ?? 'Day';
    final dayMeals = dayData['meals'] as Map<String, dynamic>;
    final totalCalories = dayData['totalCalories'] as int? ?? 0;

    final textColor = isDark ? Colors.white : Colors.black;
    final backgroundColor = isDark ? Colors.black : Colors.white;
    final cardColor = Colors.grey[100];

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
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
                  // Meal Type Header (outside the grey box)
                  Text(
                    mealType.toUpperCase(),
                    style: TextStyle(
                      fontSize: 20, // 2x bigger
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Grey Box with meal details
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.all(16),
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