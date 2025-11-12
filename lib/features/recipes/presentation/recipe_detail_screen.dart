import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:trackai/core/constants/appcolors.dart';
import 'package:trackai/core/themes/theme_provider.dart';
import 'package:trackai/core/utils/snackbar_helper.dart';
import '../services/recipe_service.dart';
import 'package:share_plus/share_plus.dart';

class RecipeDetailScreen extends StatefulWidget {
  final String recipeId;

  const RecipeDetailScreen({
    Key? key,
    required this.recipeId,
  }) : super(key: key);

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  Map<String, dynamic>? recipe;
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadRecipe();
  }

  Future<void> _loadRecipe() async {
    try {
      final recipeData = await RecipeService.getRecipeById(widget.recipeId);
      if (recipeData != null) {
        // Increment view count
        RecipeService.incrementViews(widget.recipeId);

        setState(() {
          recipe = recipeData;
          isLoading = false;
        });
      } else {
        setState(() {
          error = 'Recipe not found';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
      SnackBarHelper.showError(context, e.toString());
    }
  }

  Future<void> _shareRecipe() async {
    if (recipe != null) {
      final String title = recipe!['title'] ?? 'Check out this recipe!';
      final String description = recipe!['description'] ?? 'I found a great recipe on TrackAI!';
      // TODO: You can add a link to your app or a web URL here
      await Share.share('$title\n\n$description');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDarkTheme = themeProvider.isDarkMode;

        return Scaffold(
          backgroundColor: AppColors.background(isDarkTheme),
          body: isLoading
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(Colors.orange),
                ),
                const SizedBox(height: 16),
                Text(
                  'Loading recipe details...',
                  style: TextStyle(
                    color: AppColors.textSecondary(isDarkTheme),
                  ),
                ),
              ],
            ),
          )
              : error != null
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Failed to load recipe',
                  style: TextStyle(
                    color: AppColors.textPrimary(isDarkTheme),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  error!,
                  style: TextStyle(
                    color: AppColors.textSecondary(isDarkTheme),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loadRecipe,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                  child: Text('Retry'),
                ),
              ],
            ),
          )
              : CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 300,
                pinned: true,
                backgroundColor: AppColors.background(isDarkTheme),
                elevation: 0,
                leading: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                actions: [
                  Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(Icons.share_outlined, color: Colors.white),
                      onPressed: _shareRecipe,
                    ),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (recipe!['highResImageUrl'] != null)
                        Image.network(
                          recipe!['highResImageUrl'],
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                    : null,
                                valueColor: AlwaysStoppedAnimation(Colors.orange),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return _buildImagePlaceholder();
                          },
                        )
                      else
                        _buildImagePlaceholder(),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: [0.0, 0.9],
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.7),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Container(
                  color: AppColors.background(isDarkTheme),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          recipe!['title'] ?? 'Untitled Recipe',
                          style: TextStyle(
                            color: AppColors.textPrimary(isDarkTheme),
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // *** MODIFIED: Recipe Stats Row ***
                        _buildRecipeStatsRow(isDarkTheme),
                        const SizedBox(height: 24),

                        if (recipe!['description']?.toString().trim().isNotEmpty == true) ...[
                          Text(
                            recipe!['description'],
                            style: TextStyle(
                              color: AppColors.textSecondary(isDarkTheme),
                              fontSize: 15,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                        _buildTagsSection(isDarkTheme),
                        const SizedBox(height: 32),
                        _buildIngredientsSection(isDarkTheme),
                        const SizedBox(height: 32),
                        _buildInstructionsSection(isDarkTheme),
                        const SizedBox(height: 32),
                        _buildNutritionSection(isDarkTheme),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- New & Updated Widgets ---

  Widget _buildImagePlaceholder() {
    return Container(
      color: Colors.orange.withOpacity(0.1),
      child: Center(
        child: Icon(Icons.restaurant_menu,
            size: 64, color: Colors.orange),
      ),
    );
  }

  // *** DELETED: Old helper widgets _buildStatLabel and _buildStatValue are no longer needed ***

  // *** NEW: Helper widget for the icon + text stat item ***
  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required Color iconColor,
    required bool isDarkTheme,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          color: iconColor,
          size: 28,
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: AppColors.textPrimary(isDarkTheme),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // *** MODIFIED: Re-written to use the new icon-based layout ***
  Widget _buildRecipeStatsRow(bool isDarkTheme) {
    // Safely get calories
    final int? calories = (recipe!['calories'] as num?)?.toInt();

    // Calculate total time
    final int prepTime = (recipe!['prepTime'] as num?)?.toInt() ?? 0;
    final int cookTime = (recipe!['cookTime'] as num?)?.toInt() ?? 0;
    final int totalTime = prepTime + cookTime;

    final String difficulty = recipe!['difficulty'] ?? 'Easy';
    final Color difficultyColor = _getDifficultyColor(difficulty);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16), // No horizontal padding needed
      decoration: BoxDecoration(
          color: AppColors.cardBackground(isDarkTheme),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderColor(isDarkTheme))
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround, // This spaces the 3 items evenly
        children: [
          _buildStatItem(
            icon: Icons.local_fire_department_outlined,
            value: calories != null ? '$calories kcal' : 'N/A',
            iconColor: Colors.orange,
            isDarkTheme: isDarkTheme,
          ),
          _buildStatItem(
            icon: Icons.timer_outlined,
            value: '$totalTime min',
            iconColor: Colors.blue,
            isDarkTheme: isDarkTheme,
          ),
          _buildStatItem(
            icon: Icons.restaurant_outlined, // <-- Chef hat icon
            value: difficulty,
            iconColor: difficultyColor,
            isDarkTheme: isDarkTheme,
          ),
        ],
      ),
    );
  }

  Widget _buildTagsSection(bool isDarkTheme) {
    // Assumes recipe['tags'] is a List<String>
    final tags = List<String>.from(recipe!['tags'] ?? []);
    if (tags.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: tags.map((tag) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.cardBackground(isDarkTheme),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.borderColor(isDarkTheme),
            ),
          ),
          child: Text(
            tag,
            style: TextStyle(
              color: AppColors.textSecondary(isDarkTheme),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildIngredientsSection(bool isDarkTheme) {
// *** MODIFIED ***: Ingredients are now a Map
    final ingredients = (recipe!['ingredients'] as Map<String, dynamic>?) ?? {};
    final servings = (recipe!['servings'] as num?)?.toInt() ?? 1;

    if (ingredients.isEmpty) return const SizedBox.shrink(); // Add this check
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ingredients',
                  style: TextStyle(
                    color: AppColors.textPrimary(isDarkTheme),
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'For $servings servings',
                  style: TextStyle(
                    color: AppColors.textSecondary(isDarkTheme),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        // *** MODIFIED ***: Iterate over Map entries
        ...ingredients.entries.map((entry) {
          final String name = entry.key;
          final String amount = entry.value.toString();

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 10.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    name, // Ingredient Name
                    style: TextStyle(
                      color: AppColors.textPrimary(isDarkTheme),
                      fontSize: 16,
                      fontWeight: FontWeight.w600, // Bolder name
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Text(
                  amount, // Ingredient Amount
                  style: TextStyle(
                    color: AppColors.textPrimary(isDarkTheme),
                    fontWeight: FontWeight.bold,// Lighter amount
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
        Divider(color: AppColors.borderColor(isDarkTheme), height: 32),
      ],
    );
  }

  Widget _buildInstructionsSection(bool isDarkTheme) {
    final instructions = List<String>.from(recipe!['instructions'] ?? []);
    final int prepTime = (recipe!['prepTime'] as num?)?.toInt() ?? 0;
    final int cookTime = (recipe!['cookTime'] as num?)?.toInt() ?? 0;
    final int totalTime = prepTime + cookTime;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Instructions',
          style: TextStyle(
            color: AppColors.textPrimary(isDarkTheme),
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Ready in $totalTime minutes',
          style: TextStyle(
            color: AppColors.textSecondary(isDarkTheme),
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 16),
        ...instructions.asMap().entries.map((entry) {
          final index = entry.key;
          final instruction = entry.value;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: Colors.orange.withOpacity(0.2),
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    instruction,
                    style: TextStyle(
                      color: AppColors.textPrimary(isDarkTheme),
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
        Divider(color: AppColors.borderColor(isDarkTheme), height: 32),
      ],
    );
  }

  Widget _buildDynamicNutritionRow(String label, String value, bool isDarkTheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.textPrimary(isDarkTheme),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: AppColors.textPrimary(isDarkTheme),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionSection(bool isDarkTheme) {
    final nutrition = recipe!['nutrition'] as Map<String, dynamic>?;
    if (nutrition == null || nutrition.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Nutrition Facts',
          style: TextStyle(
            color: AppColors.textPrimary(isDarkTheme),
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'For 1 serving',
          style: TextStyle(
            color: AppColors.textSecondary(isDarkTheme),
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 16),
        ...nutrition.entries.map((entry) {
          final String nutrientName = entry.key;
          final String nutrientValue = entry.value.toString();
          if (nutrientValue.isEmpty) return const SizedBox.shrink();

          return _buildDynamicNutritionRow(
            nutrientName,
            nutrientValue,
            isDarkTheme,
          );
        }).toList(),
        Divider(color: AppColors.borderColor(isDarkTheme), height: 32),
      ],
    );
  }

  Color _getDifficultyColor(String? difficulty) {
    switch (difficulty?.toLowerCase()) {
      case 'easy':
        return Colors.green;
      case 'medium':
        return Colors.orange;
      case 'hard':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}