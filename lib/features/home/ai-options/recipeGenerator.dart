// REMOVED: import 'dart:math'; (No longer needed)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:trackai/core/constants/appcolors.dart';
import 'package:trackai/core/themes/theme_provider.dart';
import 'package:trackai/features/home/ai-options/service/recipe_results_screen.dart';

// ADDED: Import for the Gemini Service
import 'package:trackai/features/settings/service/geminiservice.dart';

class AIRecipeGenerator extends StatefulWidget {
  const AIRecipeGenerator({Key? key}) : super(key: key);

  @override
  State<AIRecipeGenerator> createState() => _AIRecipeGeneratorState();
}

class _AIRecipeGeneratorState extends State<AIRecipeGenerator> {
  final PageController _pageController = PageController();
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _ingredientsController = TextEditingController();
  final _restrictionsController = TextEditingController();
  final _cuisineController = TextEditingController();

  // State variables
  int _currentPage = 0;
  String _selectedCuisine = '';
  String _selectedMealType = '';
  bool _isGenerating = false;
  // REMOVED: _generatedRecipe (No longer needed here, passed directly to next screen)

  // Options
  final List<String> _displayCuisineOptions = [
    'Italian',
    'Mexican',
    'Chinese',
    'Indian',
    'Thai',
    'Japanese',
    'Mediterranean',
    'American',
  ];

  final List<String> _mealTypeOptions = [
    'Any',
    'Breakfast',
    'Lunch',
    'Dinner',
    'Snack',
    'Dessert',
  ];

  // Total input steps
  final int _totalInputSteps = 4;

  @override
  void dispose() {
    _ingredientsController.dispose();
    _restrictionsController.dispose();
    _pageController.dispose();
    _cuisineController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _totalInputSteps) {
      if (_currentPage == 0) {
        _selectedCuisine = _cuisineController.text.trim();
      }

      if (_validateCurrentPage()) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        _showValidationSnackBar('Please complete this step to continue.');
      }
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  bool _validateCurrentPage() {
    switch (_currentPage) {
      case 0:
        return _selectedMealType.isNotEmpty;
      case 1:
        return _selectedCuisine.isNotEmpty;
      case 2:
        return _ingredientsController.text.isNotEmpty;
      case 3:
        return true;
      default:
        return true;
    }
  }

  void _showValidationSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  // --- THIS IS THE REFACTORED FUNCTION ---
  Future<void> _generateRecipe() async {
    if (!_validateCurrentPage()) {
      _showValidationSnackBar('Please complete all required steps.');
      return;
    }

    setState(() {
      _isGenerating = true;
    });

    try {
      // 1. Create the input map for the Gemini Service
      final userInput = {
        'ingredients': _ingredientsController.text.trim(),
        'cuisine': _selectedCuisine,
        'mealType': _selectedMealType,
        'restrictions': _restrictionsController.text.trim(),
      };

      // 2. Call the Gemini Service to generate the recipe
      // This returns the full recipe map from the API
      final Map<String, dynamic> recipe =
      await GeminiService.generateRecipe(userInput: userInput);

      // 3. Navigate to the results screen with the API-generated recipe
      // The service also adds 'generatedOn' and 'userInput' keys,
      // which RecipeResultsScreen will just ignore, which is fine.
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RecipeResultsScreen(
              recipe: recipe,
              onNewRecipe: _resetForm,
            ),
          ),
        );
      }

      setState(() {
        _isGenerating = false;
      });
    } catch (e) {
      setState(() {
        _isGenerating = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating recipe: ${e.toString().replaceFirst("Exception: ", "")}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _resetForm() {
    setState(() {
      _currentPage = 0;
      // _generatedRecipe = null; // No longer needed
      _ingredientsController.clear();
      _restrictionsController.clear();
      _cuisineController.clear();
      _selectedCuisine = '';
      _selectedMealType = '';
    });
    _pageController.jumpToPage(0);
  }



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
              'AI Recipe Generator',
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
                    _buildMealTypePage(isDark),
                    _buildCuisinePage(isDark),
                    _buildIngredientsPage(isDark),
                    _buildRestrictionsPage(isDark),
                  ],
                ),
              ),
              _buildNavigationButtons(isDark),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProgressIndicator(bool isDark) {
    int totalSteps = _totalInputSteps;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(totalSteps, (index) {
              return Expanded(
                child: Container(
                  height: 3,
                  margin: EdgeInsets.only(right: index < totalSteps - 1 ? 6 : 0),
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
          Text(
            'Step ${_currentPage + 1} of $totalSteps',
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

  Widget _buildIngredientsPage(bool isDark) {
    return _buildQuestionPage(
      isDark: isDark,
      title: 'What ingredients do you have?',
      subtitle: 'List the main ingredients you want to use, separated by commas',
      child: _buildTextField(
        controller: _ingredientsController,
        hint: 'e.g., chicken, rice, onions, tomatoes',
        maxLines: 4,
        isDark: isDark,
      ),
    );
  }

  Widget _buildCuisinePage(bool isDark) {
    final screenWidth = MediaQuery.of(context).size.width;
    const double totalHorizontalSpacing = 24.0 * 2;
    const double itemSpacing = 12.0;
    final itemWidth = (screenWidth - totalHorizontalSpacing - itemSpacing) / 2;

    return _buildQuestionPage(
      isDark: isDark,
      title: 'What Cuisine Type?',
      subtitle: 'Select your preferred cuisine style.',
      child: Wrap(
        spacing: 12.0,
        runSpacing: 12.0,
        alignment: WrapAlignment.start,
        children: _displayCuisineOptions.map((cuisine) {
          return SizedBox(
            width: itemWidth,
            child: _buildSelectionCard(
              title: cuisine,
              isSelected: _selectedCuisine == cuisine,
              onTap: () {
                setState(() {
                  _selectedCuisine = cuisine;
                  _cuisineController.text = cuisine;
                });
              },
              isDark: isDark,
              icon: Icons.restaurant_menu,
              useCompactStyle: true,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMealTypePage(bool isDark) {
    final screenWidth = MediaQuery.of(context).size.width;
    const double totalHorizontalSpacing = 24.0 * 2;
    const double itemSpacing = 12.0;
    final itemWidth = (screenWidth - totalHorizontalSpacing - itemSpacing) / 2;

    return _buildQuestionPage(
      isDark: isDark,
      title: 'What meal type?',
      subtitle: 'Choose the type of dish you want to make.',
      child: Wrap(
        spacing: 12.0,
        runSpacing: 12.0,
        alignment: WrapAlignment.start,
        children: _mealTypeOptions.map((mealType) {
          return SizedBox(
            width: itemWidth,
            child: _buildSelectionCard(
              title: mealType,
              isSelected: _selectedMealType == mealType,
              onTap: () {
                setState(() {
                  _selectedMealType = mealType;
                });
              },
              isDark: isDark,
              icon: Icons.dining,
              useCompactStyle: true,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRestrictionsPage(bool isDark) {
    return _buildQuestionPage(
      isDark: isDark,
      title: 'Any restrictions?',
      subtitle: 'Share any dietary restrictions or allergies (optional)',
      child: _buildTextField(
        controller: _restrictionsController,
        hint: 'e.g., vegetarian, gluten-free, nut allergy',
        maxLines: 3,
        isDark: isDark,
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
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.left,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.left,
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

  Widget _buildSelectionCard({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
    required IconData icon,
    bool useCompactStyle = false,
  }) {
    Color selectedColor = isDark ? Colors.white : Colors.black;
    Color unselectedColor = isDark ? Colors.grey[900]! : Colors.grey[50]!;
    Color selectedTextColor = isDark ? Colors.black : Colors.white;
    Color unselectedTextColor = isDark ? Colors.white : Colors.black;
    Color borderColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected ? selectedColor : unselectedColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? selectedColor : borderColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? selectedTextColor : unselectedTextColor,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check,
                color: selectedTextColor,
                size: 18,
              ),
          ],
        ),
      ),
    );
  }

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
                onPressed: _previousPage,
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
              onPressed: _currentPage == _totalInputSteps - 1
                  ? (_isGenerating ? null : _generateRecipe)
                  : _nextPage,
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
                  const Text('Generating...'),
                ],
              )
                  : Text(
                _currentPage == _totalInputSteps - 1 ? 'Generate Recipe' : 'Continue',
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
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: TextStyle(
        color: isDark ? Colors.white : Colors.black,
        fontSize: 16,
      ),
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
}