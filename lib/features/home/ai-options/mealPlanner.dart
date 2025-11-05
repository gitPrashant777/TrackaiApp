import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart' as lucide;
import 'package:provider/provider.dart';
import 'package:trackai/core/themes/theme_provider.dart';
import 'package:trackai/features/home/ai-options/service/AIMealPlannerResults.dart' show AIMealPlannerResults;

// --- NEW IMPORTS ---
import 'dart:async';
// NOTE: Assuming this path is correct
import '../../settings/service/geminiservice.dart';
// If AppColors is not in core/constants, this might break. Assuming it is.
import 'package:trackai/core/constants/appcolors.dart';

// Import the new results screen

class AIMealPlanner extends StatefulWidget {
  const AIMealPlanner({Key? key}) : super(key: key);

  @override
  State<AIMealPlanner> createState() => _AIMealPlannerState();
}

class _AIMealPlannerState extends State<AIMealPlanner> {
  final PageController _pageController = PageController();
  final _formKey = GlobalKey<FormState>();
  final _feetController = TextEditingController();
  final _inchesController = TextEditingController();
  // --- CONTROLLERS ---
  final _ageController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _otherAllergiesController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _cuisineController = TextEditingController();
  final _healthConditionsController = TextEditingController();
  final _preferencesController = TextEditingController();

  // --- STATE VARIABLES ---
  int _currentPage = 0;
  bool _isGenerating = false;
  // NOTE: _isSaving and _mealPlan state is no longer needed here,
  // but keeping _mealPlan for temporary storage before navigation.
  Map<String, dynamic>? _mealPlan;
  final List<String> _heightUnits = ['cm', 'ft/in'];
  final List<String> _weightUnits = ['kg', 'lb'];
  String _selectedGender = '';
  String _selectedWeightUnit = 'kg';
  String _selectedHeightUnit = 'cm';
  String _selectedGoal = '';
  List<String> _selectedAllergies = [];
  String _selectedDays = '';
  String _selectedDietType = '';

  // --- OPTIONS ---
  final List<String> _genderOptions = ['Male', 'Female', 'Other'];
  final List<String> _goalOptions = [
    'Weight Loss',
    'Weight Gain',
    'Maintenance'
  ];
  final List<Map<String, String>> _allergyOptions = [
    {'id': 'gluten', 'label': 'Gluten'},
    {'id': 'dairy', 'label': 'Dairy'},
    {'id': 'nuts', 'label': 'Nuts'},
    {'id': 'eggs', 'label': 'Eggs'},
    {'id': 'soy', 'label': 'Soy'},
    {'id': 'seafood', 'label': 'Seafood'},
  ];
  final List<String> _dayOptions = [
    '3 Days',
    '5 Days',
    '7 Days',
    '14 Days',
    '30 Days'
  ];
  final List<String> _dietOptions = [


    'Vegetarian',
    'Vegan',
    'Keto',
    'Paleo',
    'Gluten-Free',
    'Dairy-Free',
    'No Specific Diet',
    'Non-Vegetarian',
  ];

  // --- TOTAL STEPS UPDATED ---
  // The original file had 10 steps, 0-9. The result page was at index 10.
  final int _totalSteps = 10; // Input steps 0-9

  @override
  void dispose() {
    _ageController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _otherAllergiesController.dispose();
    _caloriesController.dispose();
    _cuisineController.dispose();
    _healthConditionsController.dispose();
    _preferencesController.dispose();
    _pageController.dispose();
    _feetController.dispose();
    _inchesController.dispose();
    super.dispose();
  }

  void _showValidationSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
                Icons.warning_amber_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w500),
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
                    color: Colors.white, fontWeight: FontWeight.w500),
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

  void _nextPage() {
    // If we are on the last step, simply show the next page, which will be the loading page.
    if (_currentPage < _totalSteps) {
      if (_validateCurrentPage()) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        String message = _getValidationMessage();
        _showValidationSnackBar(message);
      }
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      // Clear meal plan state if navigating back from the loading screen/results flow
      if (_currentPage == _totalSteps) {
        _mealPlan = null;
        _isGenerating = false;
      }

      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  // --- UPDATED VALIDATION MESSAGE ---
  String _getValidationMessage() {
    switch (_currentPage) {
      case 5: // Calories
        return 'Please enter your target daily calorie goal';
      case 6: // Days
        return 'Please select the plan duration';
      case 7: // Diet Type
        return 'Please select your diet type';
      default:
        return 'Please complete this field';
    }
  }

  bool _validateCurrentPage() {
    switch (_currentPage) {
      case 0: // Gender
        return _selectedGender.isNotEmpty;

      case 1: // Age
      // Check for valid positive integer
        return _ageController.text.isNotEmpty && int.tryParse(_ageController.text) != null && int.parse(_ageController.text) > 0;

      case 2: // Weight
        final weightValue = double.tryParse(_weightController.text);
        // Check if value is valid (not null and greater than zero)
        return weightValue != null && weightValue > 0;

      case 3: // Height (Fixed Logic)
        if (_selectedHeightUnit.isEmpty) return false;

        if (_selectedHeightUnit == 'cm') {
          final heightCmValue = double.tryParse(_heightController.text);
          // Check if value is valid (not null and greater than zero)
          return heightCmValue != null && heightCmValue > 0;

        } else if (_selectedHeightUnit == 'ft/in') {
          final feet = int.tryParse(_feetController.text);
          final inches = double.tryParse(_inchesController.text);

          // Feet must be non-negative integer. Inches must be non-negative and less than 12.
          // We only require feet to be positive if inches is zero, otherwise any non-negative combination is fine.
          final bool areFeetValid = feet != null && feet >= 0;
          final bool areInchesValid = inches != null && inches >= 0 && inches < 12;

          // Ensure at least one value is positive to prevent 0ft 0in
          final bool isNonZero = (feet ?? 0) > 0 || (inches ?? 0) > 0;

          return areFeetValid && areInchesValid && isNonZero;
        }
        return false; // Should not be reached if unit is selected

      case 4: // Goal
        return _selectedGoal.isNotEmpty;

      case 5: // Calories
      // Check for valid positive integer
        return _caloriesController.text.isNotEmpty && int.tryParse(_caloriesController.text) != null && int.parse(_caloriesController.text) > 0;

      case 6: // Days
        return _selectedDays.isNotEmpty;

      case 7: // Diet Type
        return _selectedDietType.isNotEmpty;

      case 8: // Allergies (Always true as selection is optional, text input is optional)
      case 9: // Health Conditions (Always true as input is optional)
        return true;

      default:
        return true;
    }
  }

  // --- FIXED: Improved meal plan parser with better calorie extraction (KEPT) ---
  Map<String, dynamic> _parseMealPlanString(String planString) {
    final Map<String, dynamic> parsedPlan = {};
    final lines = planString.split('\n').map((l) => l.trim()).where((l) =>
    l.isNotEmpty);

    String currentDayKey = '';
    Map<String, dynamic>? currentDayMeals;
    Map<String, dynamic>? currentMeal;

    final dayRegex = RegExp(r'^\*\*(Day\s*\d+.*)\*\*');
    // Updated regex to capture meal type only
    final mealRegex = RegExp(
        r'^[\*-]\s*(Breakfast|Lunch|Dinner|Snacks)\s*[:\s-]*\s*(.*)',
        caseSensitive: false);
    final recipeLineRegex = RegExp(
        r'^\s*-\s*(Recipe|Instructions|Preparation)[:\s-]*\s*(.*)',
        caseSensitive: false);
    final simpleRecipeLineRegex = RegExp(r'^\s*-\s*(.*)');

    void saveCurrentMeal() {
      if (currentMeal != null && currentDayMeals != null) {
        String mealType = (currentMeal['type'] as String).toLowerCase();

        // --- EXTRACT CALORIES FROM MEAL NAME ---
        String mealName = currentMeal['name'];
        int calories = 0;

        // Look for calorie patterns in the meal name
        final caloriePattern = RegExp(
            r'\(approx\.\s*(\d+)\s*calories?\)', caseSensitive: false);
        final match = caloriePattern.firstMatch(mealName);

        if (match != null) {
          calories = int.tryParse(match.group(1)!) ?? 0;
          // Remove the calorie part from the meal name for cleaner display
          mealName = mealName
              .replaceAll(match.group(0)!, '')
              .replaceAll(':', '')
              .trim();
        }

        // If no calories found, use reasonable defaults
        if (calories == 0) {
          switch (mealType) {
            case 'breakfast':
              calories = 400;
              break;
            case 'lunch':
              calories = 600;
              break;
            case 'dinner':
              calories = 800;
              break;
            case 'snacks':
              calories = 200;
              break;
            default:
              calories = 500;
          }
        }

        currentDayMeals[mealType] = {
          'name': mealName,
          'calories': calories,
          'recipe': currentMeal['recipeLines'].join('\n'),
        };
      }
    }

    for (final line in lines) {
      final dayMatch = dayRegex.firstMatch(line);
      if (dayMatch != null) {
        if (currentDayKey.isNotEmpty && currentDayMeals != null) {
          saveCurrentMeal();
          parsedPlan[currentDayKey] = currentDayMeals;
        }

        currentDayKey = dayMatch.group(1)!.trim();
        currentDayMeals = {};
        currentMeal = null;
        continue;
      }

      if (currentDayKey.isEmpty) continue;

      final mealMatch = mealRegex.firstMatch(line);
      if (mealMatch != null) {
        saveCurrentMeal();

        currentMeal = {
          'type': mealMatch.group(1)!.trim(),
          'name': mealMatch.group(2)?.trim() ?? 'Meal',
          'recipeLines': <String>[],
        };

        continue;
      }

      final recipeMatch = recipeLineRegex.firstMatch(line);
      if (currentMeal != null && recipeMatch != null) {
        currentMeal['recipeLines'].add(recipeMatch.group(2)!.trim());
        continue;
      }

      final simpleRecipeMatch = simpleRecipeLineRegex.firstMatch(line);
      if (currentMeal != null && simpleRecipeMatch != null) {
        currentMeal['recipeLines'].add(simpleRecipeMatch.group(1)!.trim());
        continue;
      }

      if (currentMeal != null) {
        if (currentMeal['recipeLines'].isNotEmpty) {
          currentMeal['recipeLines'].last =
              currentMeal['recipeLines'].last + ' $line';
        } else if (currentMeal['name'].isNotEmpty) {
          currentMeal['recipeLines'].add(line);
        }
      }
    }

    if (currentDayKey.isNotEmpty && currentDayMeals != null) {
      saveCurrentMeal();
      parsedPlan[currentDayKey] = currentDayMeals;
    }

    // Calculate total calories for the day
    for (var dayKey in parsedPlan.keys) {
      int total = 0;
      final day = parsedPlan[dayKey] as Map<String, dynamic>;
      day.forEach((mealType, mealData) {
        if (mealData is Map && mealData.containsKey('calories')) {
          total += (mealData['calories'] as int);
        }
      });
      day['totalCalories'] = total;
    }

    return parsedPlan;
  }

  void _debugMealPlanParsing(String rawPlanString) {
    print('=== RAW MEAL PLAN STRING ===');
    print(rawPlanString);
    print('=== END RAW STRING ===');

    final parsed = _parseMealPlanString(rawPlanString);
    print('=== PARSED RESULT ===');
    print(parsed);
    print('=== END PARSED RESULT ===');
  }

  // --- UPDATED: _generateMealPlan (Calls GeminiService AND THEN NAVIGATES)
  Future<void> _generateMealPlan() async {
    // Navigate to the loading screen (Page Index 10)
    _pageController.animateToPage(_totalSteps, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);

    setState(() {
      _isGenerating = true;
      _mealPlan = null; // Clear previous plan
    });

    final Map<String, dynamic> userInput = {
      'age': _ageController.text,
      'gender': _selectedGender,
      'weight': _weightController.text,
      'weightUnit': _selectedWeightUnit,
      'height': _heightController.text,
      'heightUnit': _selectedHeightUnit,
      'goal': _selectedGoal,
      'allergies': _selectedAllergies,
      'otherAllergies': _otherAllergiesController.text,
      'healthConditions': _healthConditionsController.text,
      'calories': _caloriesController.text,
      'dietType': _selectedDietType,
      'days': _selectedDays,
      'mealPrep': '',
      'budget': '',
      'cuisine': _cuisineController.text,
      'preferences': _preferencesController.text,
    };

    try {
      // NOTE: Assuming this service method exists and returns the expected structure.
      final Map<String, dynamic> generatedPlan =
      await GeminiService.generateMealPlan(userInput: userInput)
          .timeout(const Duration(seconds: 60));

      final numDays = int.tryParse(_selectedDays.split(' ')[0]) ?? 7;
      final targetCalories = int.tryParse(_caloriesController.text) ?? 2000;

      final String rawMealPlanString = generatedPlan['mealPlan'] as String;
      _debugMealPlanParsing(rawMealPlanString);

      final Map<String, dynamic> parsedDays = _parseMealPlanString(
          rawMealPlanString);

      if (parsedDays.isEmpty) {
        throw Exception("AI plan structure could not be parsed.");
      }

      // Combine all parts into the final mealPlan map
      final Map<String, dynamic> finalMealPlan = {
        'planSummary': {
          'totalDays': numDays,
          'avgDailyCalories': targetCalories,
          'dietType': _selectedDietType,
          'generatedOn': DateTime.now().toString().split(' ')[0],
        },
        'groceryList': generatedPlan['groceryList'] as List<String>,
        'cookingGuide': generatedPlan['cookingGuide'] as String,
      };

      finalMealPlan.addAll(parsedDays);

      setState(() {
        _isGenerating = false;
        _mealPlan = finalMealPlan;
      });

      // --- SUCCESS: Navigate to the dedicated results screen ---
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AIMealPlannerResults(
            mealPlan: finalMealPlan,
            isDark: Provider.of<ThemeProvider>(context, listen: false).isDarkMode,
          ),
        ),
      ).then((_) {
        // When results screen pops, reset to first input page (or previous page)
        // Resetting to the first page is usually cleaner for AI generators
        _pageController.jumpToPage(0);
        setState(() => _currentPage = 0);
      });

    } on TimeoutException {
      _handleGenerationError(TimeoutException('The AI request timed out.'));
    } catch (e) {
      _handleGenerationError(e);
    }
  }

  // --- NEW: Error handler (MODIFIED to stop generation and show snackbar) ---
  void _handleGenerationError(Object e) {
    setState(() {
      _isGenerating = false;
    });

    if (mounted) {
      _showErrorSnackBar(e.toString().replaceFirst("Exception: ", ""));
      // Navigate back from the loading page to the last input page on error
      _previousPage();
    }
  }

  // NOTE: _savePlan method is REMOVED from this class.
  // The DayDetailsPage logic is KEPT as it is used by AIMealPlannerResults.

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDark = themeProvider.isDarkMode;
        return Scaffold(
          backgroundColor: isDark ? Colors.black : Colors.white,
          appBar: AppBar(
            backgroundColor: isDark ? Colors.black : Colors.white,
            elevation: 0,
            leading: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Icon(
                Icons.arrow_back_ios_new,
                color: isDark ? Colors.white : Colors.black,
                size: 20,
              ),
            ),
            title: Text(
              'AI Meal Planner',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            centerTitle: true,
          ),
          body: Column(
            children: [
              _buildProgressIndicator(isDark),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  children: [
                    _buildGenderPage(isDark),          // Index 0: Gender
                    _buildAgePage(isDark),             // Index 1: Age
                    _buildWeightPage(isDark),          // Index 2: Weight
                    _buildHeightPage(isDark),          // Index 3: Height
                    _buildGoalPage(isDark),            // Index 4: Goal
                    _buildCaloriesPage(isDark),        // Index 5: Calories (Required)
                    _buildDaysPage(isDark),            // Index 6: Days (Required)
                    _buildDietTypePage(isDark),        // Index 7: Diet Type (Required)
                    _buildAllergiesPage(isDark),       // Index 8: Allergies
                    _buildHealthConditionsPage(isDark), // Index 9: Health Conditions
                    // Index 10: Loading/Navigation Indicator
                    _buildLoadingScreen(isDark), // <--- NEW DEDICATED LOADING PAGE
                  ],
                ),
              ),
              // Show navigation buttons only during input steps (0 to 9)
              if (_currentPage < _totalSteps) _buildNavigationButtons(isDark),
            ],
          ),
        );
      },
    );
  }

  // Remaining helper methods (_buildProgressIndicator, _buildLoadingScreen, etc.)
  // are retained or modified as needed for the input flow.

  Widget _buildProgressIndicator(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_currentPage < _totalSteps)
            Row(
              children: List.generate(_totalSteps, (index) {
                return Expanded(
                  child: Container(
                    height: 3,
                    margin: EdgeInsets.only(right: index < _totalSteps - 1 ? 6 : 0),
                    decoration: BoxDecoration(
                      color: index <= _currentPage
                          ? (isDark ? Colors.white : Colors.black)
                          : (isDark ? Colors.grey[800] : Colors.grey[300]),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ),
          const SizedBox(height: 10),
          if (_currentPage < _totalSteps)
            Text(
              'Step ${_currentPage + 1} of $_totalSteps',
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLoadingScreen(bool isDark) {
    final Color primaryTextColor = isDark ? Colors.white : Colors.black;
    final Color secondaryTextColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;
    final Color spinnerColor = isDark ? Colors.white : Colors.black;

    // This is the dedicated loading page (index 10)
    return Container(
      color: isDark ? Colors.black : Colors.white,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SpinKitFadingCube(
              color: spinnerColor,
              size: 50.0,
            ),
            const SizedBox(height: 31),
            Text(
              'Track AI is making your customized \n meal plan...',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: primaryTextColor,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This may take a moment based on your selections.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: secondaryTextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionPage({
    required bool isDark,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Text(
            title,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 15,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          child,
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // Builder for single select options (dynamic 1- or 2-column layout)
  Widget _buildDynamicSelection({
    required List<String> options,
    required String selectedValue,
    required Function(String) onSelect,
    required bool isDark,
    bool showIcons = true,
  }) {
    // Determine if we need 2-column layout (if options > 4)
    final useTwoColumnLayout = options.length > 4;

    // Calculate width for 2-column layout if needed
    final screenWidth = MediaQuery.of(context).size.width;
    const double totalHorizontalSpacing = 24.0 * 2;
    const double itemSpacing = 12.0;
    final itemWidth = (screenWidth - totalHorizontalSpacing - itemSpacing) / 2;

    if (useTwoColumnLayout) {
      return Wrap(
        spacing: 12.0,
        runSpacing: 12.0,
        alignment: WrapAlignment.start,
        children: options.map((option) {
          return SizedBox(
            width: itemWidth,
            child: _buildSelectionCard(
              title: option,
              isSelected: selectedValue == option,
              onTap: () => onSelect(option),
              isDark: isDark,
              icon: Icons.check, // Dummy icon for compilation
              useCompactStyle: true,
            ),
          );
        }).toList(),
      );
    } else {
      // 1-column layout (default)
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: options.map((option) {
          IconData? icon;
          // Logic for Gender/Goal icons
          if (showIcons) {
            switch (option) {
              case 'Male': icon = Icons.male; break;
              case 'Female': icon = Icons.female; break;
              case 'Other': icon = Icons.transgender; break;
              case 'Weight Loss': icon = Icons.trending_down; break;
              case 'Weight Gain': icon = Icons.trending_up; break;
              case 'Maintenance': icon = Icons.sync; break;
              default: icon = Icons.check;
            }
          }
          return _buildSelectionCard(
            title: option,
            isSelected: selectedValue == option,
            onTap: () => onSelect(option),
            isDark: isDark,
            icon: icon,
            useCompactStyle: false,
          );
        }).toList(),
      );
    }
  }

  Widget _buildSelectionCard({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
    IconData? icon,
    bool useCompactStyle = false,
    bool isUnitSelector = false, // Added for Weight/Height Unit Pill Selector
  }) {
    Color selectedColor = isDark ? Colors.white : Colors.black;
    Color unselectedColor = isDark ? Colors.grey[900]! : Colors.grey[50]!;
    Color selectedTextColor = isDark ? Colors.black : Colors.white;
    Color unselectedTextColor = isDark ? Colors.white : Colors.black;
    Color borderColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;

    // --- Special handling for the compact Unit Selector Pill ---
    if (isUnitSelector) {
      return Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            height: 55, // Fixed height for pill feel
            decoration: BoxDecoration(
              color: isSelected ? selectedColor : Colors.transparent, // Only color the selected part
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? selectedTextColor : unselectedTextColor,
                ),
              ),
            ),
          ),
        ),
      );
    }

    // --- Standard 1-Col / 2-Col Selection Card ---
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: useCompactStyle ? EdgeInsets.zero : const EdgeInsets.only(bottom: 12),
        padding: useCompactStyle
            ? const EdgeInsets.symmetric(vertical: 16, horizontal: 10)
            : const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isSelected ? selectedColor : unselectedColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isSelected ? selectedColor : borderColor,
              width: isSelected ? 2 : 1
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null && !useCompactStyle)
              Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: Icon(icon,
                    color: isSelected ? selectedTextColor : unselectedTextColor,
                    size: 24
                ),
              ),
            Expanded(
              child: Text(title,
                  textAlign: useCompactStyle ? TextAlign.center : TextAlign.left,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? selectedTextColor : unselectedTextColor
                  )),
            ),
            if (isSelected)
              Icon(useCompactStyle ? Icons.check : Icons.check_circle,
                  color: selectedTextColor,
                  size: useCompactStyle ? 18 : 22
              ),
          ],
        ),
      ),
    );
  }

  // --- Page Widgets (0-9, 12) ---

  // NOTE: Swapped Gender and Age pages to match index order 0, 1 from original file
  // Page 0: Gender
  Widget _buildGenderPage(bool isDark) {
    return _buildQuestionPage(
      isDark: isDark,
      title: 'What\'s your gender?',
      subtitle: 'This provides more accurate recommendations (optional)',
      child: Column(
        children: _genderOptions.map((gender) {
          IconData icon;
          switch (gender) {
            case 'Male':
              icon = Icons.male;
              break;
            case 'Female':
              icon = Icons.female;
              break;
            default:
              icon = Icons.transgender;
          }
          return _buildSelectionCard(
            title: gender,
            isSelected: _selectedGender == gender,
            onTap: () {
              setState(() {
                _selectedGender = gender;
              });
            },
            isDark: isDark,
            icon: icon,
          );
        }).toList(),
      ),
    );
  }


  // Page 1: Age (Optional)
  Widget _buildAgePage(bool isDark) {
    return _buildQuestionPage(
      isDark: isDark,
      title: 'How old are you?',
      subtitle: 'Your age helps in tailoring the meal plan (optional)',
      child: _buildTextField(
        controller: _ageController,
        hint: 'e.g., 30',
        keyboardType: TextInputType.number,
        isDark: isDark,
      ),
    );
  }

  // Page 2: Weight (Unified Input)
  Widget _buildWeightPage(bool isDark) {
    final Color primaryTextColor = isDark ? Colors.white : Colors.black;

    return _buildQuestionPage(
      isDark: isDark,
      title: 'What is your weight?',
      subtitle: 'Select your preferred unit and enter your weight.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Weight Unit Selector (Pill Style)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[900] : Colors.grey[200],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: _weightUnits.map((option) =>
                  _buildSelectionCard(
                    title: option == 'kg' ? 'Kilograms (kg)' : 'Pounds (lb)',
                    isSelected: _selectedWeightUnit == option,
                    onTap: () => setState(() => _selectedWeightUnit = option),
                    isDark: isDark,
                    isUnitSelector: true, // Use the special unit pill style
                  )
              ).toList(),
            ),
          ),
          const SizedBox(height: 24),
          // Weight Input Field
          _buildTextField(
            controller: _weightController,
            hint: 'Enter weight in $_selectedWeightUnit',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            isDark: isDark,
            isNumeric: true,
          ),
        ],
      ),
    );
  }

  // Page 3: Height (Unified Input UI)
  Widget _buildHeightPage(bool isDark) {
    final Color primaryTextColor = isDark ? Colors.white : Colors.black;

    return _buildQuestionPage(
      isDark: isDark,
      title: 'What is your height?',
      subtitle: 'Used to calculate your nutritional needs (optional)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Height Unit Selector (Pill Style)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[900] : Colors.grey[200],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: _heightUnits.map((option) =>
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedHeightUnit = option;
                          _heightController.clear();
                          _feetController.clear();
                          _inchesController.clear();
                        });
                      },
                      child: Container(
                        height: 55,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: _selectedHeightUnit == option ? Colors.black : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            option == 'cm' ? 'Centimeters (cm)' : 'Feet/Inches (ft/in)',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: _selectedHeightUnit == option ? Colors.white : primaryTextColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
              ).toList(),
            ),
          ),
          const SizedBox(height: 24),

          // Height Input Field(s) (Conditional)
          _selectedHeightUnit == 'cm'
              ? _buildTextField(
            controller: _heightController,
            hint: 'Enter height in cm',
            keyboardType: TextInputType.number,
            isDark: isDark,
            isNumeric: true,
          )
              : Row(
            children: [
              Expanded(
                  child: _buildTextField(
                      controller: _feetController,
                      hint: 'Feet',
                      keyboardType: TextInputType.number,
                      isDark: isDark
                  )
              ),
              const SizedBox(width: 16),
              Expanded(
                  child: _buildTextField(
                      controller: _inchesController,
                      hint: 'Inches',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      isDark: isDark
                  )
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Page 4: Goal (Optional)
  Widget _buildGoalPage(bool isDark) {
    return _buildQuestionPage(
      isDark: isDark,
      title: 'Fitness goal?',
      subtitle: 'Select your primary fitness objective (optional)',
      child: _buildDynamicSelection( // <-- USE DYNAMIC SELECTION
        options: _goalOptions,
        selectedValue: _selectedGoal,
        onSelect: (val) => setState(() => _selectedGoal = val),
        isDark: isDark,
        showIcons: true,
      ),
    );
  }

  // Page 5: Calories (Required)
  Widget _buildCaloriesPage(bool isDark) {
    return _buildQuestionPage(
      isDark: isDark,
      title: 'Daily calorie goal?',
      subtitle: 'Enter your target daily calorie intake for the meal plan',
      child: _buildTextField(
        controller: _caloriesController,
        hint: 'e.g., 2000',
        keyboardType: TextInputType.number,
        isDark: isDark,
      ),
    );
  }

  // Page 6: Days (Required)
  Widget _buildDaysPage(bool isDark) {
    return _buildQuestionPage(
      isDark: isDark,
      title: 'Plan duration?',
      subtitle: 'How many days do you want your meal plan for?',
      child: _buildDynamicSelection( // <-- USE DYNAMIC SELECTION
        options: _dayOptions,
        selectedValue: _selectedDays,
        onSelect: (val) => setState(() => _selectedDays = val),
        isDark: isDark,
        showIcons: false,
      ),
    );
  }

  // Page 7: Diet Type (Required)
  Widget _buildDietTypePage(bool isDark) {
    return _buildQuestionPage(
      isDark: isDark,
      title: 'Diet preference?',
      subtitle: 'Choose your dietary preference or restriction',
      child: _buildDynamicSelection( // <-- USE DYNAMIC SELECTION
        options: _dietOptions,
        selectedValue: _selectedDietType,
        onSelect: (val) => setState(() => _selectedDietType = val),
        isDark: isDark,
        showIcons: false,
      ),
    );
  }

  // Page 8: Allergies (Optional)
  Widget _buildAllergiesPage(bool isDark) {
    return _buildQuestionPage(
      isDark: isDark,
      title: 'Any allergies?',
      subtitle: 'Select any allergies or intolerances (optional)',
      child: Column(
        children: [
          ..._allergyOptions.map((allergy) {
            final isSelected = _selectedAllergies.contains(allergy['label']!);
            return CheckboxListTile(
              title: Text(
                allergy['label']!,
                style: TextStyle(color: isDark ? Colors.white : Colors.black,
                    fontWeight: FontWeight.w500),
              ),
              value: isSelected,
              onChanged: (bool? value) {
                setState(() {
                  if (value == true) {
                    _selectedAllergies.add(allergy['label']!);
                  } else {
                    _selectedAllergies.remove(allergy['label']!);
                  }
                });
              },
              activeColor: isDark ? Colors.white : Colors.black,
              checkColor: isDark ? Colors.black : Colors.white,
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              tileColor: isDark ? Colors.grey[900] : Colors.grey[50],
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            );
          }).toList(),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _otherAllergiesController,
            hint: 'e.g., Shellfish, Peanuts',
            maxLines: 2,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  // Page 9: Health Conditions (Optional)
  Widget _buildHealthConditionsPage(bool isDark) {
    return _buildQuestionPage(
      isDark: isDark,
      title: 'Health conditions?',
      subtitle: 'Share any health conditions we should consider (optional)',
      child: _buildTextField(
        controller: _healthConditionsController,
        hint: 'e.g., Diabetes, High blood pressure',
        maxLines: 3,
        isDark: isDark,
      ),
    );
  }

  // NOTE: _buildResultsPage is REMOVED and replaced by external AIMealPlannerResults.

  // --- UPDATED: _buildNavigationButtons ---
  Widget _buildNavigationButtons(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? Colors.black : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.grey[900]! : Colors.grey[200]!,
          ),
        ),
      ),
      child: Row(
        children: [
          if (_currentPage > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _isGenerating ? null : _previousPage, // Disable during generation
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  side: BorderSide(
                    color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  backgroundColor: Colors.transparent,
                ),
                child: Text(
                  'Back',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          if (_currentPage > 0) const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _currentPage == _totalSteps - 1
                  ? (_isGenerating ? null : _generateMealPlan) // Call generate on last step
                  : (_isGenerating ? null : _nextPage), // Disable navigation during generation
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? Colors.white : Colors.black,
                foregroundColor: isDark ? Colors.black : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: _isGenerating
                  ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isDark ? Colors.black : Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Generating...',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: isDark ? Colors.black : Colors.white
                    ),
                  ),
                ],
              )
                  : Text(
                _currentPage == _totalSteps - 1 ? 'Generate Plan' : 'Continue',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required bool isDark,
    TextInputType? keyboardType,
    int maxLines = 1,
    bool isNumeric = false,
  }) {
    List<TextInputFormatter> formatters = [];
    if (keyboardType == TextInputType.number) {
      formatters.add(FilteringTextInputFormatter.digitsOnly);
    }
    if (isNumeric) {
      formatters.add(FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*')));
    }

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: TextStyle(
        color: isDark ? Colors.white : Colors.black,
        fontSize: 16,
      ),
      inputFormatters: formatters,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: isDark ? Colors.grey[600] : Colors.grey[400],
        ),
        filled: true,
        fillColor: isDark ? Colors.grey[900] : Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: isDark ? Colors.white : Colors.black,
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.all(20),
      ),
    );
  }

// NOTE: Helper methods like _buildSummaryItem, _getMealIcon, _buildMealCard,
// _buildExpansionTile, _buildGroceryList, _buildCookingGuide are REMOVED
// as they are now in AIMealPlannerResults or are unused.

}
// NOTE: DayDetailsPage is KEPT as it is used by the external AIMealPlannerResults page.

// --- UPDATED: Simple Day Details Page with Black & White Theme (KEPT) ---