// lib/features/home/homepage/desc and scan/nutrition_scanner.dart

import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart' as lucide;
import 'package:trackai/core/routes/routes.dart';
import 'package:trackai/features/home/homepage/desc%20and%20scan/gemini.dart';
import 'package:provider/provider.dart';
import '../log/daily_log_provider.dart';
import '../log/food_log_entry.dart';

// --- ADD THESE IMPORTS ---
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
// -------------------------

// --- Updated Color Scheme ---
const Color kBackgroundColor = Colors.white;
const Color kCardColor = Color(0xFFF8F9FA);
const Color kCardColorDarker = Color(0xFFE9ECEF);
const Color kTextColor = Color(0xFF212529);
const Color kTextSecondaryColor = Color(0xFF6C757D);
const Color kAccentColor = Color(0xFF131212);
const Color kSuccessColor = Color(0xFF28A745);
const Color kWarningColor = Color(0xFFFFC107);
const Color kDangerColor = Color(0xFFDC3545);
// -----------------------------------------

class NutritionScannerScreen extends StatefulWidget {
  final File? imageFile;
  const NutritionScannerScreen({Key? key, this.imageFile}) : super(key: key);

  @override
  State<NutritionScannerScreen> createState() => _NutritionScannerScreenState();
}

class _NutritionScannerScreenState extends State<NutritionScannerScreen>
    with TickerProviderStateMixin {
  File? _selectedImage;
  bool _isAnalyzing = false;
  bool _isNotFoodLabel = false;
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  final ImagePicker _picker = ImagePicker();
  final Gemini _gemini = Gemini();

  // --- NEW Data Structure (Matches Web Flow) ---
  Map<String, dynamic>? _nutritionData; // Holds Step 2 (Nutrition) results
  List<Map<String, dynamic>> _editableIngredients = []; // Holds Step 1 (Ingredients) results
  String _dishName = 'Nutrition Scanner'; // Holds Step 1 (Dish Name)
  // ---

  bool _showCameraInterface = true;
  int _currentTab = 0; // 0: Overview, 1: Detailed Analysis, 2: Ingredients

  // Form controllers for adding ingredients
  final _formKey = GlobalKey<FormState>();
  final _ingredientNameController = TextEditingController();
  final _ingredientWeightController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));
    if (widget.imageFile != null) {
      setState(() {
        _selectedImage = widget.imageFile;
        _showCameraInterface = false; // Bypass the selector
      });

      // Call analysis after the first frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _analyzeFoodImage();
      });
    }
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    _ingredientNameController.dispose();
    _ingredientWeightController.dispose();
    super.dispose();
  }

  BoxDecoration _getCardDecoration({bool elevated = true}) {
    return BoxDecoration(
      color: kCardColor,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: Colors.grey[300]!,
        width: 1.0,
      ),
      boxShadow: elevated
          ? [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ]
          : null,
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _isNotFoodLabel = false;
          _nutritionData = null;
          _editableIngredients = [];
          _showCameraInterface = false;
          _currentTab = 0;
          _dishName = 'Nutrition Scanner'; // Reset dish name
        });

        HapticFeedback.lightImpact();
        await _analyzeFoodImage();
      }
    } catch (e) {
      _showErrorSnackBar('Failed to pick image: $e');
    }
  }

  // --- THIS FUNCTION IS NOW THE 2-STEP FLOW ---
  Future<void> _analyzeFoodImage() async {
    if (_selectedImage == null) return;

    setState(() {
      _isAnalyzing = true;
      _isNotFoodLabel = false;
      _nutritionData = null;
      _editableIngredients = [];
    });

    try {
      // --- STEP 1: IDENTIFY INGREDIENTS (from identify-ingredients.ts) ---
      final ingredientResult =
      await _gemini.describeFoodFromImage(_selectedImage!);
      final ingredientJson = json.decode(ingredientResult);

      if (ingredientJson['isFoodItem'] != true) {
        setState(() {
          _isAnalyzing = false;
          _isNotFoodLabel = true;
          _showErrorSnackBar(
              ingredientJson['nonFoodDescription'] ?? 'No food was detected.');
        });
        return;
      }

      // Save Step 1 results to state
      final List<Map<String, dynamic>> ingredients =
      List<Map<String, dynamic>>.from(ingredientJson['ingredients'] ?? []);

      setState(() {
        _editableIngredients = ingredients;
        _dishName = ingredientJson['dishName'] ?? 'Scanned Meal';
      });

      // --- STEP 2: CALCULATE NUTRITION (from calculate-nutrition-from-ingredients.ts) ---
      if (ingredients.isNotEmpty) {
        await _calculateNutrition(ingredients, isRecalculating: false);
      } else {
        // No ingredients found, stop loading and show error
        setState(() {
          _isAnalyzing = false;
          _isNotFoodLabel = true;
          _showErrorSnackBar(
              'AI could not identify any ingredients in this image.');
        });
      }
    } catch (e) {
      setState(() {
        _isAnalyzing = false;
      });
      _showErrorSnackBar('Analysis failed: $e');
    }
  }

  // --- THIS IS THE "RECALCULATE" (STEP 2) LOGIC ---
  Future<void> _calculateNutrition(List<Map<String, dynamic>> ingredients,
      {bool isRecalculating = true}) async {
    if (ingredients.isEmpty) {
      _showErrorSnackBar('No ingredients to analyze.');
      setState(() => _isAnalyzing = false); // Stop loading if no ingredients
      return;
    }

    // Set loading state
    setState(() {
      _currentTab = 0; // Go back to overview
      _isAnalyzing = true;
    });
    // Reset animations if it's a recalculation
    if (isRecalculating) {
      _slideController.reset();
      _fadeController.reset();
    }

    // --- FIX: Declare nutritionResult outside the try block ---
    String nutritionResult = '{}';
    // ---

    try {
      // Call the Step 2 function
      nutritionResult = // Assign to the outer variable
      await _gemini.describeFoodFromIngredients(ingredients);
      final nutritionJson = json.decode(nutritionResult);

      setState(() {
        _nutritionData = nutritionJson; // Save nutrition data
        _isAnalyzing = false;
      });

      // Show the new results
      _fadeController.forward();
      _slideController.forward();
      HapticFeedback.mediumImpact();
    } catch (parseError) {
      setState(() {
        _isAnalyzing = false;
      });
      // --- FIX: Now this variable is accessible ---
      print('Raw API Response (Invalid JSON): $nutritionResult');
      _showErrorSnackBar(
          'Analysis failed. The AI response was not in the correct format.');
    }
  }

  // ⛔️ This function is no longer needed
  // void _parseFoodResponse(Map<String, dynamic> jsonData) { ... }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: kDangerColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _resetAnalysis() {
    setState(() {
      _selectedImage = null;
      _isNotFoodLabel = false;
      _nutritionData = null;
      _editableIngredients = [];
      _showCameraInterface = true;
      _currentTab = 0;
      _dishName = 'Nutrition Scanner';
    });
    _slideController.reset();
    _fadeController.reset();
  }

  void _setCurrentTab(int tab) {
    setState(() {
      _currentTab = tab;
    });
    HapticFeedback.lightImpact();
  }

  // --- Ingredient Management ---
  void _removeIngredient(int index) {
    setState(() {
      _editableIngredients.removeAt(index);
    });
    HapticFeedback.mediumImpact();
  }

  void _showAddIngredientDialog() {
    _ingredientNameController.clear();
    _ingredientWeightController.clear();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: kBackgroundColor,
          surfaceTintColor: kBackgroundColor,
          title:
          const Text('Add Ingredient', style: TextStyle(color: kTextColor)),
          content: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _ingredientNameController,
                  style: const TextStyle(color: kTextColor),
                  decoration: InputDecoration(
                    labelText: 'Ingredient Name',
                    labelStyle: const TextStyle(color: kTextSecondaryColor),
                    filled: true,
                    fillColor: kCardColorDarker,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: kAccentColor),
                    ),
                  ),
                  validator: (value) =>
                  (value == null || value.isEmpty) ? 'Cannot be empty' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _ingredientWeightController,
                  style: const TextStyle(color: kTextColor),
                  decoration: InputDecoration(
                    labelText: 'Weight (g)',
                    labelStyle: const TextStyle(color: kTextSecondaryColor),
                    filled: true,
                    fillColor: kCardColorDarker,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: kAccentColor),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Cannot be empty';
                    if (int.tryParse(value) == null) return 'Must be a number';
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(color: kTextSecondaryColor)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kAccentColor,
                foregroundColor: Colors.white,
              ),
              onPressed: _addIngredient,
              child: const Text('Add', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _addIngredient() {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _editableIngredients.add({
          'name': _ingredientNameController.text,
          // This MUST match the web schema: 'weightGrams'
          'weightGrams': int.parse(_ingredientWeightController.text),
        });
      });
      Navigator.pop(context);
      HapticFeedback.lightImpact();
    }
  }

  // ✅ --- ADD THIS NEW FUNCTION ---
  // This replaces the Firebase Storage function
  Future<String?> _saveImageLocally(File imageFile, String entryId) async {
    try {
      // 1. Get the app's permanent documents directory
      final directory = await getApplicationDocumentsDirectory();

      // 2. Create a unique file name
      final fileExtension = p.extension(imageFile.path); // e.g., '.jpg'
      final newFileName = '$entryId$fileExtension';

      // 3. Create the new, permanent path
      final newPath = p.join(directory.path, newFileName);

      // 4. Copy the temporary file to the new permanent path
      final newFile = await imageFile.copy(newPath);

      // 5. Return the permanent path to be saved in Firestore
      return newFile.path;
    } catch (e) {
      print("Error saving image locally: $e");
      return null;
    }
  }

  // --- THIS WIDGET IS UPDATED ---
  // lib/features/home/homepage/desc and scan/nutrition_scanner.dart

// ... (keep all other code, including imports)

  // --- THIS WIDGET IS UPDATED ---
  Widget _buildNutritionalEstimate() {
    if (_nutritionData == null) return const SizedBox();

    // Read from the new JSON structure (Step 2)
    final breakdown = _nutritionData!['estimatedNutrition'] ?? {};

    // --- ✅ FIX: Calculate total weight from the state list ---
    // This ensures the weight always matches the user's edits from the
    // "Refine Ingredients" tab and ignores any 'estimatedWeightGrams'
    // value that might come back from the AI's recalculation.
    final int estimatedWeight = _editableIngredients.fold(
        0, (sum, item) => sum + (item['weightGrams'] as num? ?? 0).toInt());
    // --- END FIX ---

    final calories = (breakdown['calories'] as num?)?.toInt() ?? 0;
    final protein = (breakdown['protein'] as num?)?.toInt() ?? 0;
    final carbsData = breakdown['carbohydrates'] ?? {};
    final fatData = breakdown['fat'] ?? {};
    final carbs = (carbsData['total'] as num?)?.toInt() ?? 0;
    final fiber = (carbsData['fiber'] as num?)?.toInt() ?? 0;
    final fat = (fatData['total'] as num?)?.toInt() ?? 0;

    return Container(
      decoration: _getCardDecoration(),
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Nutritional Estimate',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: kTextColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            // This now uses the correct local calculation
            'Estimated Weight: ~${estimatedWeight}g',
            style: const TextStyle(
              fontSize: 15,
              color: kTextSecondaryColor,
            ),
          ),
          const SizedBox(height: 20),
          // Calories card
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24),
            width: double.infinity,
            decoration: BoxDecoration(
              color: kCardColorDarker,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.local_fire_department,
                      color: kAccentColor,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      "Calories",
                      style: TextStyle(
                        color: kTextSecondaryColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '$calories',
                  style: const TextStyle(
                    fontSize: 52,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const Text(
                  'kcal',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Nutrient Cards
          Row(
            children: [
              Expanded(
                child: _buildNutrientCard(
                  'Protein',
                  '$protein', // Updated variable
                  'g',
                  lucide.LucideIcons.zap,
                  Colors.amber,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildNutrientCard(
                  'Carbs',
                  '$carbs', // Updated variable
                  'g',
                  lucide.LucideIcons.wheat,
                  kSuccessColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildNutrientCard(
                  'Fat',
                  '$fat', // Updated variable
                  'g',
                  lucide.LucideIcons.droplet,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildNutrientCard(
                  'Fiber',
                  '$fiber', // Updated variable
                  'g',
                  Icons.eco,
                  const Color(0xFFE37F4A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Log meal button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              // --- ⬇️ THIS IS THE UPDATED BUTTON LOGIC ⬇️ ---
              onPressed: () async {
                if (_nutritionData == null || _selectedImage == null) return;

                // Show a loading indicator
                setState(() {
                  _isAnalyzing = true;
                });

                final logProvider = context.read<DailyLogProvider>();
                // Read from new structure
                final breakdown = _nutritionData!['estimatedNutrition'] ?? {};
                final healthScore =
                    (breakdown['healthScore'] as num?)?.toInt() ?? 0;
                final healthDescription =
                breakdown['healthScoreExplanation'] as String?;
                final carbsData = breakdown['carbohydrates'] ?? {};
                final fatData = breakdown['fat'] ?? {};

                final entryId = DateTime.now().millisecondsSinceEpoch.toString();

                // --- 1. SAVE THE IMAGE LOCALLY ---
                final localImagePath =
                await _saveImageLocally(_selectedImage!, entryId);

                final entry = FoodLogEntry(
                  id: entryId,
                  name: _dishName, // Use the state variable
                  calories: (breakdown['calories'] as num?)?.toInt() ?? 0,
                  protein: (breakdown['protein'] as num?)?.toInt() ?? 0,
                  carbs: (carbsData['total'] as num?)?.toInt() ?? 0,
                  fat: (fatData['total'] as num?)?.toInt() ?? 0,
                  fiber: (carbsData['fiber'] as num?)?.toInt() ?? 0,
                  timestamp: DateTime.now(),
                  healthScore: healthScore,
                  healthDescription: healthDescription,
                  // --- 2. SAVE THE NEW PERMANENT LOCAL PATH ---
                  imagePath: localImagePath,
                );

                // --- 3. SAVE TO FIRESTORE (Provider handles this) ---
                await logProvider.addEntry(entry);

                // Hide loading
                setState(() {
                  _isAnalyzing = false;
                });

                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${entry.name} logged!'),
                    backgroundColor: Colors.green,
                  ),
                );
                Navigator.pop(context);
              },
              // --- ⬆️ END OF UPDATED BUTTON LOGIC ⬆️ ---
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyan,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.add_circle, size: 20),
              label: const Text(
                'Log This Meal',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

// ... (paste the rest of the original file from _buildNutrientCard onwards)+
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

  // --- THIS WIDGET IS UPDATED ---
  Widget _buildHealthScore() {
    if (_nutritionData == null) return const SizedBox();

    // Read from new structure
    final breakdown = _nutritionData!['estimatedNutrition'] ?? {};
    final healthScore = (breakdown['healthScore'] as num?) ?? 8;
    final healthDescription =
        breakdown['healthScoreExplanation'] ?? 'Healthy food item';

    return Container(
      decoration: _getCardDecoration(),
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(Icons.favorite, color: Colors.red[400], size: 20),
              const SizedBox(width: 8),
              const Text(
                'Health Score',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const Spacer(),
              Text(
                '${healthScore.toInt()}/10',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Health Score Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: healthScore.toDouble() / 10.0,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                  _getHealthScoreColor(healthScore.toInt())),
              minHeight: 12,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            healthDescription,
            style: const TextStyle(
              fontSize: 15,
              color: kTextSecondaryColor,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          // Tab Buttons
          LayoutBuilder(
            builder: (context, constraints) {
              return Row(
                children: [
                  Expanded(
                    child:
                    _buildTabButton('Refine Ingredients', 2, Icons.edit),
                  ),
                  SizedBox(
                    width: 10,
                  ),
                  Expanded(
                    child: _buildTabButton(
                        'Detailed Analysis', 1, Icons.bar_chart),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String text, int tabIndex, IconData icon) {
    bool isActive = _currentTab == tabIndex;
    return ElevatedButton(
      onPressed: () => _setCurrentTab(tabIndex),
      style: ElevatedButton.styleFrom(
        backgroundColor: isActive ? kAccentColor : kCardColorDarker,
        foregroundColor: isActive ? Colors.white : kTextColor,
        padding:
        const EdgeInsets.symmetric(vertical: 12, horizontal: 8), // Reduced padding
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isActive ? kAccentColor : Colors.grey[300]!,
            width: 1,
          ),
        ),
        elevation: 0,
        minimumSize: Size.zero, // Removes default minimum size constraint
        tapTargetSize:
        MaterialTapTargetSize.shrinkWrap, // Removes extra padding
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min, // Shrink to content size
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6), // Reduced spacing
          Flexible(
            // Prevents text overflow
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13, // Slightly reduced font size
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
              overflow: TextOverflow.ellipsis, // Handle long text
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  Color _getHealthScoreColor(int score) {
    if (score >= 8) return kSuccessColor;
    if (score >= 5) return kWarningColor;
    return kDangerColor;
  }

  // --- THIS WIDGET IS UPDATED ---
  Widget _buildDescriptionSection() {
    if (_nutritionData == null) return const SizedBox();

    // Get ingredient names from the state
    final ingredientNames =
    _editableIngredients.map((ing) => ing['name'] as String? ?? '').join(', ');

    // Get analysis from Step 2 data
    final analysis =
    (_nutritionData!['detailedAnalysis'] as List<dynamic>? ?? [])
        .map((item) => item['analysis'] as String? ?? '')
        .join(' ');

    return Container(
      decoration: _getCardDecoration(),
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Description',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: kTextColor,
            ),
          ),
          const SizedBox(height: 16),
          // Identified Ingredients
          RichText(
            text: TextSpan(
              style: const TextStyle(
                fontSize: 15,
                color: kTextColor,
                height: 1.4,
              ),
              children: [
                const TextSpan(
                  text: 'Identified as: ',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(
                  text: ingredientNames.isNotEmpty
                      ? ingredientNames
                      : 'Various food items',
                  style: const TextStyle(color: kTextSecondaryColor),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Divider(color: Color(0xFFE9ECEF)),
          const SizedBox(height: 16),
          // Analysis
          const Text(
            'Analysis',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600, color: kTextColor),
          ),
          const SizedBox(height: 12),
          Text(
            analysis.isNotEmpty
                ? analysis
                : 'No detailed analysis was provided.',
            style: const TextStyle(
              fontSize: 15,
              color: kTextSecondaryColor,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // --- THIS WIDGET IS UPDATED ---
  Widget _buildDetailedAnalysis() {
    if (_nutritionData == null) return const SizedBox();

    // Read benefits from new structure
    final benefits = _nutritionData!['detailedAnalysis'] as List<dynamic>? ?? [];

    return Container(
      decoration: _getCardDecoration(),
      padding: const EdgeInsets.all(17),
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ⛔️ REMOVED _buildDescriptionSection() from here
          // It is now correctly shown only on Tab 0
          const Text(
            'Detailed Analysis',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: kTextColor,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Health Benefits',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: kTextColor,
            ),
          ),
          const SizedBox(height: 16),
          if (benefits.isEmpty)
            const Text(
              'No detailed health benefits were provided by the analysis.',
              style: TextStyle(color: kTextSecondaryColor),
            )
          else
            ...benefits.map((benefit) {
              final String ingredient = benefit['ingredient'] ?? 'Unknown';
              // Use the 'analysis' key from the new prompt
              final String text = benefit['analysis'] ?? 'No description.';
              return Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: _buildHealthBenefit(ingredient, text),
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildHealthBenefit(String ingredient, String benefit) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardColorDarker,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.eco, color: kSuccessColor, size: 18),
              const SizedBox(width: 8),
              Text(
                '$ingredient:',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: kTextColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            benefit,
            style: const TextStyle(
              fontSize: 14,
              color: kTextSecondaryColor,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // --- THIS WIDGET IS UPDATED ---
  Widget _buildIngredientsSection() {
    // This widget now only depends on _editableIngredients
    if (_editableIngredients.isEmpty && _nutritionData == null) {
      return const SizedBox();
    }

    int totalWeight = _editableIngredients.fold(
        0, (sum, item) => sum + (item['weightGrams'] as num? ?? 0).toInt());

    return Container(
      decoration: _getCardDecoration(),
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ingredient Approval',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: kTextColor,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Adjust the AI\'s estimates for a more accurate result. Add or remove items as needed.',
            style: TextStyle(
              fontSize: 15,
              color: kTextSecondaryColor,
            ),
          ),
          const SizedBox(height: 16),
          // AI Tip
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kAccentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kAccentColor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline, color: kAccentColor, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'AI Tip: I can only see what\'s on top! Consider adding hidden ingredients like sauces or oils.',
                    style: TextStyle(
                      fontSize: 14,
                      color: kAccentColor,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // List of ingredients
          ..._editableIngredients.asMap().entries.map((entry) {
            final index = entry.key;
            final ingredient = entry.value;
            return _buildIngredientItem(ingredient, index);
          }).toList(),
          const SizedBox(height: 20),
          // Add Ingredient Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _showAddIngredientDialog,
              style: OutlinedButton.styleFrom(
                foregroundColor: kAccentColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: BorderSide(color: kAccentColor),
              ),
              icon: const Icon(Icons.add, size: 20),
              label: const Text('Add Ingredient'),
            ),
          ),
          const SizedBox(height: 20),
          // Total Weight
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kCardColorDarker,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Est. Weight:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: kTextColor,
                  ),
                ),
                Text(
                  '${totalWeight}g',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: kTextColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Back to Results Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _setCurrentTab(0),
              style: ElevatedButton.styleFrom(
                backgroundColor: kAccentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Back to Results',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // --- THIS BUTTON IS UPDATED ---
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              // Calls the new Step 2 function
              onPressed: () => _calculateNutrition(_editableIngredients),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.calculate_outlined, size: 20),
              label: const Text(
                'Recalculate Nutrition',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // ⛔️ This function is no longer needed
  // Future<void> _recalculateNutrition() async { ... }

  // --- THIS WIDGET IS UPDATED ---
  Widget _buildIngredientItem(Map<String, dynamic> ingredient, int index) {
    // Reads the new key 'weightGrams'
    final String name = ingredient['name'] ?? 'Unknown';
    // Handle both 'weight_g' (from your old dialog) and 'weightGrams' (from AI)
    final int weight =
        (ingredient['weightGrams'] ?? ingredient['weight_g'] as num?)
            ?.toInt() ??
            0;

    return Container(
      padding: const EdgeInsets.all(16.0),
      margin: const EdgeInsets.only(bottom: 12.0),
      decoration:
      _getCardDecoration(), // Use the app's existing light card style
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Title and Delete Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.apple, color: kSuccessColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Ingredient #${index + 1}',
                    style: const TextStyle(
                      color: kTextColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: Icon(Icons.delete, color: kDangerColor, size: 20),
                onPressed: () => _removeIngredient(index),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Bottom Row: Name and Weight Fields
          Row(
            children: [
              // Name Field
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Name',
                      style:
                      TextStyle(color: kTextSecondaryColor, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                        color: kCardColorDarker,
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: Text(
                        name,
                        style:
                        const TextStyle(color: kTextColor, fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Weight Field
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Weight (g)',
                      style:
                      TextStyle(color: kTextSecondaryColor, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                        color: kCardColorDarker,
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: Text(
                        weight.toString(),
                        style:
                        const TextStyle(color: kTextColor, fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- THIS WIDGET IS UPDATED ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: kBackgroundColor,
        scrolledUnderElevation: 1,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: kTextColor),
        ),
        title: Text(
          _isAnalyzing ? 'Analyzing...' : _dishName, // Use state variable
          style: const TextStyle(
            color: kTextColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _selectedImage == null && _showCameraInterface
          ? _buildImageSelector()
          : _buildAnalysisView(),
    );
  }

  Widget _buildImageSelector() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth > 600;

        return Column(
          children: [
            // Camera Preview Section
            Expanded(
              flex: isTablet ? 6 : 7,
              child: Container(
                color: Colors.black,
                child: Center(
                  // NOTE: Replace this placeholder with your CameraPreview widget
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.photo_camera,
                        size: isTablet ? 80 : 64,
                        color: kTextSecondaryColor,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Ready to Scan Food',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: isTablet ? 24 : 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Point camera at your food',
                        style: TextStyle(
                          color: kTextSecondaryColor,
                          fontSize: isTablet ? 16 : 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Action Buttons Section
            Expanded(
              flex: isTablet ? 4 : 3,
              child: Container(
                color: kBackgroundColor,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 32.0 : 16.0,
                    vertical: isTablet ? 24.0 : 16.0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: _buildHorizontalActionButton(
                          icon: Icons.qr_code_scanner,
                          title: 'Scan Food',
                          onTap: () => _pickImage(ImageSource.camera),
                          isTablet: isTablet,
                          color: Colors.black,
                        ),
                      ),
                      SizedBox(width: isTablet ? 24 : 12),
                      Expanded(
                        child: _buildHorizontalActionButton(
                          icon: Icons.document_scanner_outlined,
                          title: 'Scan Label',
                          onTap: () => _pickImage(ImageSource.camera),
                          isTablet: isTablet,
                          color: Colors.black,
                        ),
                      ),
                      SizedBox(width: isTablet ? 24 : 12),
                      Expanded(
                        child: _buildHorizontalActionButton(
                          icon: Icons.image_search,
                          title: 'Gallery',
                          onTap: () => _pickImage(ImageSource.gallery),
                          isTablet: isTablet,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHorizontalActionButton(
      {required IconData icon,
        required String title,
        required VoidCallback onTap,
        required bool isTablet,
        Color color = Colors.black}) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          height: 100,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.grey[300]!,
              width: 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: isTablet ? 36 : 28),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: isTablet ? 15 : 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnalysisView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Food Image
          if (_selectedImage != null)
            Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(_selectedImage!, fit: BoxFit.cover),
              ),
            ),
          const SizedBox(height: 24),
          if (_isAnalyzing) ...[
            _buildLoadingWidget(),
          ] else if (_nutritionData != null) ...[
            _buildFoodResults()
          ] else if (_isNotFoodLabel) ...[
            _buildNotLabelWidget()
          ] else ...[
            // This case can happen if Step 1 succeeds but Step 2 fails
            _buildNotLabelWidget(
                message:
                'Could not calculate nutrition. Please try again or refine the ingredients.')
          ],
        ],
      ),
    );
  }

  // --- THIS WIDGET IS UPDATED ---
  Widget _buildFoodResults() {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            _buildNutritionalEstimate(),
            _buildHealthScore(),
            if (_currentTab == 0) ...[
              _buildDescriptionSection(),
            ] else if (_currentTab == 1) ...[
              _buildDetailedAnalysis(),
            ] else if (_currentTab == 2) ...[
              _buildIngredientsSection(),
            ],
            if (_currentTab != 2)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 8, bottom: 24),
                child: ElevatedButton(
                  onPressed: () {
                    // Reset analysis to go back to camera
                    _resetAnalysis();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey[300]!),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Scan Another Food',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: _getCardDecoration(),
      child: const Column(
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(kAccentColor),
            strokeWidth: 3,
          ),
          SizedBox(height: 24),
          Text(
            'Analyzing food image...',
            style: TextStyle(
              fontSize: 16,
              color: kTextColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'This may take a few seconds',
            style: TextStyle(
              fontSize: 14,
              color: kTextSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotLabelWidget(
      {String message =
      'No food was detected. Please take a clear photo of your meal.'}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: _getCardDecoration(),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kWarningColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.warning_amber_rounded,
              size: 48,
              color: kWarningColor,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Analysis Failed',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: kTextColor,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              color: kTextSecondaryColor,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                _resetAnalysis(); // Go back to camera
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kAccentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Try Again',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}