import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:trackai/core/constants/appcolors.dart';
import 'package:trackai/core/themes/theme_provider.dart';
import '../services/recipe_service.dart';
import 'recipe_detail_screen.dart';

class RecipeLibraryScreen extends StatefulWidget {
  const RecipeLibraryScreen({Key? key}) : super(key: key);

  @override
  State<RecipeLibraryScreen> createState() => _RecipeLibraryScreenState();
}

class _RecipeLibraryScreenState extends State<RecipeLibraryScreen> {
  // Filter for top chips
  String _selectedCategory = 'All';
  // NEW: Filter for bottom sheet
  String _selectedDifficultyFilter = 'All';

  final List<String> _categories = [
    'All',
    'Appetizers',
    'Main Course',
    'Desserts',
    'Breakfast',
    'Salads',
    'Soups',
    'Beverages',
    'Snacks',
  ];

  // NEW: List for difficulty filter
  final List<String> _difficulties = ['All', 'Easy', 'Medium', 'Hard'];

  // Icons are no longer used for chips, but kept here in case you want to revert
  final Map<String, IconData> _categoryIcons = {
    'All': Icons.apps_outlined,
    'Appetizers': Icons.tapas_outlined,
    'Main Course': Icons.restaurant_menu_outlined,
    'Desserts': Icons.cake_outlined,
    'Breakfast': Icons.free_breakfast_outlined,
    'Salads': Icons.eco_outlined,
    'Soups': Icons.soup_kitchen_outlined,
    'Beverages': Icons.local_bar_outlined,
    'Snacks': Icons.fastfood_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDarkTheme = themeProvider.isDarkMode;
        final screenWidth = MediaQuery.of(context).size.width;

        return Scaffold(
          backgroundColor: AppColors.background(isDarkTheme),
          body: SafeArea(
            child: Column(
              children: [
                // Header with working filter icon
                _buildHeader(isDarkTheme, screenWidth, context),

                // Filter chips (now text-only and smaller)
                _buildFilterChips(isDarkTheme),

                // Recipes (ListView)
                Expanded(
                  child: StreamBuilder<List<Map<String, dynamic>>>(
                    stream: RecipeService.getRecipesStream(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return _buildLoadingState(isDarkTheme);
                      }

                      if (snapshot.hasError) {
                        return _buildErrorState(isDarkTheme, context);
                      }

                      final allRecipes = snapshot.data ?? [];

                      // UPDATED: Filtering logic now checks both category and difficulty
                      final recipes = allRecipes.where((r) {
                        // 1. Check Category
                        final category = (r['category'] as String?)?.toLowerCase();
                        final selectedCat = _selectedCategory.toLowerCase();
                        bool categoryMatch = false;

                        if (selectedCat == 'all') {
                          categoryMatch = true;
                        } else if (selectedCat == 'snacks') {
                          categoryMatch = (category == 'snack' || category == 'snacks');
                        } else {
                          categoryMatch = (category == selectedCat);
                        }

                        // 2. Check Difficulty
                        final difficulty = (r['difficulty'] as String?)?.toLowerCase();
                        final selectedDiff = _selectedDifficultyFilter.toLowerCase();
                        bool difficultyMatch = false;

                        if (selectedDiff == 'all') {
                          difficultyMatch = true;
                        } else {
                          difficultyMatch = (difficulty == selectedDiff);
                        }

                        // 3. Return true only if both match
                        return categoryMatch && difficultyMatch;
                      }).toList();


                      if (recipes.isEmpty) {
                        return _buildEmptyState(isDarkTheme, context);
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: recipes.length,
                        itemBuilder: (context, index) {
                          final recipe = recipes[index];
                          // *** MODIFIED ***: Using the updated card
                          return _buildFullWidthRecipeCard(
                            context,
                            recipe,
                            isDarkTheme,
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- UI Components ---

  // UPDATED: IconButton now calls _showFilterBottomSheet
  Widget _buildHeader(bool isDarkTheme, double screenWidth, BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Recipes',
            style: TextStyle(
              color: AppColors.textPrimary(isDarkTheme),
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.tune_outlined, color: AppColors.textPrimary(isDarkTheme)),
                onPressed: () {
                  // NEW: Call the filter bottom sheet
                  _showFilterBottomSheet(context, isDarkTheme);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // UPDATED: Now text-only chips and shorter height
  Widget _buildFilterChips(bool isDarkTheme) {
    return SizedBox(
      height: 50, // Reduced height
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = _selectedCategory == category;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            // UPDATED: Using new text-only chip
            child: _buildTextChip(
              category,
              isSelected,
              isDarkTheme,
                  () {
                setState(() {
                  _selectedCategory = category;
                });
              },
            ),
          );
        },
      ),
    );
  }

  // UPDATED: Replaced _buildChip with a text-only version
  Widget _buildTextChip(String label, bool isSelected, bool isDarkTheme, Function() onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // Adjusted padding
        decoration: BoxDecoration(
          color: isSelected ? Colors.orange : AppColors.cardBackground(isDarkTheme),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.orange : AppColors.borderColor(isDarkTheme),
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: Colors.orange.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ] : [
            BoxShadow(
              color: Colors.black.withOpacity(isDarkTheme ? 0.2 : 0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Center( // Center the text
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : AppColors.textPrimary(isDarkTheme),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              fontSize: 13, // Slightly larger font
            ),
          ),
        ),
      ),
    );
  }


  // ####################################################################
  // ### *** MODIFIED WIDGET *** ###
  // ####################################################################

  // *** MODIFIED ***: Restored the image to show Image, Title, Time, and Calories.
  Widget _buildFullWidthRecipeCard(BuildContext context, Map<String, dynamic> recipe, bool isDarkTheme) {
    final String? imageUrl = recipe['cardImageUrl'] ?? recipe['imageUrl']; // <-- RESTORED
    final int totalTime = (recipe['prepTime'] ?? 0) + (recipe['cookTime'] ?? 0);
    final int? calories = (recipe['calories'] as num?)?.toInt();

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RecipeDetailScreen(recipeId: recipe['id']),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.cardBackground(isDarkTheme),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDarkTheme ? 0.2 : 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          // *** MODIFIED ***: Child is now a Column containing the Stack (image) and Padding (text)
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Image Section (RESTORED) ---
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: imageUrl != null
                          ? Image.network(
                        imageUrl,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const Center(child: CircularProgressIndicator(color: Colors.orange));
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return _buildImagePlaceholder();
                        },
                      )
                          : _buildImagePlaceholder(),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.35),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.star_border,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
              // --- End Image Section ---

              // --- Info Section (Unchanged, just placed within the Column) ---
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Row for Title and Time
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        Expanded(
                          child: Text(
                            recipe['title'] ?? 'Untitled Recipe',
                            style: TextStyle(
                              color: AppColors.textPrimary(isDarkTheme),
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Time
                        Text(
                          "${totalTime} min",
                          style: TextStyle(
                            color: AppColors.textSecondary(isDarkTheme),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                        ),
                      ],
                    ),

                    // Show Calories if they exist
                    if (calories != null) ...[
                      const SizedBox(height: 12), // Spacing
                      Row(
                        children: [
                          Icon(
                            Icons.local_fire_department_outlined, // Calories icon
                            color: AppColors.textSecondary(isDarkTheme),
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "$calories kcal",
                            style: TextStyle(
                              color: AppColors.textSecondary(isDarkTheme),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- NEW: Filter Bottom Sheet Method ---

  void _showFilterBottomSheet(BuildContext context, bool isDarkTheme) {
    // Use StatefulBuilder to manage the state of the chips *inside* the sheet
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background(isDarkTheme),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext sheetContext) {
        // This temporary variable holds the state *before* applying
        String tempSelectedDifficulty = _selectedDifficultyFilter;

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Filter Recipes',
                        style: TextStyle(
                          color: AppColors.textPrimary(isDarkTheme),
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        color: AppColors.textSecondary(isDarkTheme),
                        onPressed: () => Navigator.pop(sheetContext),
                      )
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Difficulty',
                    style: TextStyle(
                      color: AppColors.textPrimary(isDarkTheme),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Use Wrap for responsive chips
                  Wrap(
                    spacing: 10.0,
                    runSpacing: 10.0,
                    children: _difficulties.map((difficulty) {
                      final isSelected = tempSelectedDifficulty == difficulty;
                      return ChoiceChip(
                        label: Text(difficulty),
                        selected: isSelected,
                        onSelected: (bool selected) {
                          if (selected) {
                            // Update the *sheet's* state
                            setSheetState(() {
                              tempSelectedDifficulty = difficulty;
                            });
                          }
                        },
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : AppColors.textPrimary(isDarkTheme),
                          fontWeight: FontWeight.w500,
                        ),
                        selectedColor: Colors.orange,
                        backgroundColor: AppColors.cardBackground(isDarkTheme),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: isSelected ? Colors.orange : AppColors.borderColor(isDarkTheme),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 32),
                  // Apply Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        // Apply the filter to the main screen
                        setState(() {
                          _selectedDifficultyFilter = tempSelectedDifficulty;
                        });
                        Navigator.pop(sheetContext); // Close the sheet
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Apply Filters',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }


  // --- Utility Widgets (Unchanged) ---

  Widget _buildLoadingState(bool isDarkTheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 60,
            height: 60,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(Colors.orange),
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Loading Recipes...',
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

  Widget _buildErrorState(bool isDarkTheme, BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.red.withOpacity(0.3),
                ),
              ),
              child: const Icon(Icons.error_outline, size: 48, color: Colors.red),
            ),
            const SizedBox(height: 16),
            Text(
              'Oops! Something went wrong',
              style: TextStyle(
                color: AppColors.textPrimary(isDarkTheme),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {});
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDarkTheme, BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.orange.withOpacity(0.3),
                ),
              ),
              child: const Icon(
                Icons.restaurant_menu,
                size: 48,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Recipes Found',
              style: TextStyle(
                color: AppColors.textPrimary(isDarkTheme),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your filters or adding a new recipe.',
              style: TextStyle(
                color: AppColors.textSecondary(isDarkTheme),
                fontSize: 14,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: Colors.orange.withOpacity(0.1),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.restaurant_menu, size: 32, color: Colors.orange),
            ),
            const SizedBox(height: 8),
            const Text(
              'No Image',
              style: TextStyle(
                color: Colors.orange,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}