import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:trackai/features/onboarding/service/observices.dart';
import 'package:trackai/features/settings/service/geminiservice.dart';
import 'package:trackai/features/settings/service/goalservice.dart';
import 'package:trackai/core/themes/theme_provider.dart';
import 'package:trackai/core/constants/appcolors.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart' as lucide;
import 'package:flutter_markdown/flutter_markdown.dart'; // <-- ADD THIS IMPORT

// --- HOMESCREEN COLORS (for light theme) ---
const Color kScaffoldBackground = Color(0xFFF8F8F8);
const Color kCardColor = Colors.white;
const Color kInputFillColor = Color(0xFFF8F9FA); // From kCardColor in homescreen
const Color kTextColor = Color(0xFF212529); // Colors.black87
const Color kTextSecondaryColor = Color(0xFF6C757D); // Colors.black54

// --- ACCENT COLORS (Inspired by Homescreen) ---
final Color kPrimaryAccentColor = Colors.blue[700]!;
final Color kPrimaryAccentColorDark = Colors.blue[300]!;
final Color kCalorieColor = Colors.orange[600]!;
final Color kProteinColor = Colors.amber[700]!;
final Color kCarbsColor = Colors.green[600]!;
final Color kFatColor = Colors.blue[400]!;
final Color kFiberColor = Colors.brown[400]!;
const Color kAIColor = Color(0xFF26A69A); // From Homescreen AI Lab

class AdjustGoalsPage extends StatefulWidget {
  const AdjustGoalsPage({Key? key}) : super(key: key);

  @override
  State<AdjustGoalsPage> createState() => _AdjustGoalsPageState();
}

class _AdjustGoalsPageState extends State<AdjustGoalsPage> {
  Map<String, dynamic>? _goalsData;
  bool _isLoading = false;
  bool _isCalculating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadExistingGoals();
  }

  Future<void> _loadExistingGoals() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final existingGoals = await GoalsService.getGoals();

      if (existingGoals != null) {
        setState(() {
          _goalsData = existingGoals;
          _isLoading = false;
        });
      } else {
        await _calculateGoals();
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load goals: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _calculateGoals() async {
    setState(() {
      _isCalculating = true;
      _error = null;
    });

    try {
      final onboardingData = await OnboardingService.getOnboardingData();

      if (onboardingData == null) {
        throw Exception('No onboarding data found. Please complete onboarding first.');
      }

      final calculatedGoals = await GeminiService.calculateNutritionGoals(
        onboardingData: onboardingData,
      );

      if (calculatedGoals == null) {
        throw Exception('Failed to calculate goals. Please try again.');
      }

      await GoalsService.saveGoals(calculatedGoals);

      setState(() {
        _goalsData = calculatedGoals;
        _isCalculating = false;
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Goals calculated and saved successfully!'),
            backgroundColor: AppColors.successColor,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isCalculating = false;
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _calculateGoalsWithCustomData(Map<String, dynamic> formData) async {
    setState(() {
      _isCalculating = true;
      _error = null;
    });

    try {
      final calculatedGoals = await GeminiService.calculateNutritionGoals(
        onboardingData: formData,
      );

      if (calculatedGoals == null) {
        throw Exception('Failed to calculate goals. Please try again.');
      }

      await GoalsService.saveGoals(calculatedGoals);

      setState(() {
        _goalsData = calculatedGoals;
        _isCalculating = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Goals recalculated and saved successfully!'),
            backgroundColor: AppColors.successColor,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isCalculating = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.errorColor,
          ),
        );
      }
    }
  }

  // --- MODIFIED: Navigate to full-screen page ---
  void _navigateToRecalculateScreen() async {
    // Navigate to the new full-screen page and wait for a result
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const RecalculateGoalsScreen(),
      ),
    );

    // If the user completed the form (result is not null), recalculate
    if (result != null && result is Map<String, dynamic>) {
      _calculateGoalsWithCustomData(result);
    }
  }

  // --- STYLES REFACTORED ---

  BoxDecoration _getCardDecoration(bool isDarkTheme) {
    if (isDarkTheme) {
      return BoxDecoration(
        color: AppColors.darkCardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey[800]!,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            spreadRadius: 0,
            offset: Offset(0, 2),
          ),
        ],
      );
    } else {
      // Light theme (like Homescreen)
      return BoxDecoration(
        color: kCardColor, // Colors.white
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
  }

  Color _primaryTextColor(bool isDarkTheme) {
    return isDarkTheme ? Colors.white : kTextColor;
  }

  Color _secondaryTextColor(bool isDarkTheme) {
    return isDarkTheme ? Colors.grey[400]! : kTextSecondaryColor;
  }

  Color _primaryIconColor(bool isDarkTheme) {
    return isDarkTheme ? Colors.white : kTextColor;
  }

  // --- END STYLES ---

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDarkTheme = themeProvider.isDarkMode;

        return Scaffold(
          backgroundColor: isDarkTheme ? AppColors.darkBackground : kScaffoldBackground, // Updated light bg
          appBar: AppBar(
            backgroundColor: isDarkTheme ? AppColors.darkCardBackground : kCardColor, // Updated light bg
            surfaceTintColor: Colors.transparent, // Prevents tint on scroll
            elevation: isDarkTheme ? 1 : 0, // Match homescreen (no elevation)
            scrolledUnderElevation: 1, // Add slight elevation on scroll
            shadowColor: Colors.grey.withOpacity(0.08),
            leading: IconButton(
              icon: Icon(
                lucide.LucideIcons.arrowLeft,
                color: _primaryIconColor(isDarkTheme), // Updated color
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Row(
              children: [
                Icon(
                  lucide.LucideIcons.target,
                  color: isDarkTheme ? Colors.white : kPrimaryAccentColor, // UPDATED: Color
                  size: 24,
                ),
                SizedBox(width: 12),
                Text(
                  'Your Daily Targets',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _primaryTextColor(isDarkTheme), // Updated color
                  ),
                ),
              ],
            ),
          ),
          body: _buildBody(isDarkTheme),
        );
      },
    );
  }

  Widget _buildBody(bool isDarkTheme) {
    if (_isLoading || _isCalculating) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: kPrimaryAccentColor, // UPDATED: Color
            ),
            const SizedBox(height: 16),
            Text(
              _isCalculating ? 'Calculating your goals...' : 'Loading goals...',
              style: TextStyle(
                color: _primaryTextColor(isDarkTheme),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: _getCardDecoration(isDarkTheme),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  lucide.LucideIcons.triangleAlert, // <-- FIXED TYPO HERE
                  size: 64,
                  color: AppColors.errorColor, // This is already colorful
                ),
                const SizedBox(height: 16),
                Text(
                  'Oops! Something went wrong',
                  style: TextStyle(
                    color: _primaryTextColor(isDarkTheme),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _secondaryTextColor(isDarkTheme),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _calculateGoals,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kTextColor, // Use kTextColor (black)
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 2,
                    ),
                    child: Text(
                      'Try Again',
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
        ),
      );
    }

    if (_goalsData == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: _getCardDecoration(isDarkTheme),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  lucide.LucideIcons.target,
                  size: 64,
                  color: isDarkTheme ? Colors.white : kPrimaryAccentColor, // UPDATED: Color
                ),
                const SizedBox(height: 16),
                Text(
                  'No goals found',
                  style: TextStyle(
                    color: _primaryTextColor(isDarkTheme),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Let\'s calculate your personalized nutrition goals',
                  style: TextStyle(
                    color: _secondaryTextColor(isDarkTheme),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _calculateGoals,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kTextColor,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 2,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(lucide.LucideIcons.sparkles),
                        SizedBox(width: 8),
                        Text(
                          'Calculate Goals',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Main content when data exists
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: _getCardDecoration(isDarkTheme),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      lucide.LucideIcons.target,
                      color: isDarkTheme ? Colors.white : kPrimaryAccentColor, // UPDATED: Color
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Your Daily Targets',
                      style: TextStyle(
                        color: _primaryTextColor(isDarkTheme),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'These are your AI-generated daily nutritional goals. You can recalculate them anytime.',
                  style: TextStyle(
                    color: _secondaryTextColor(isDarkTheme),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: _getCardDecoration(isDarkTheme),
            child: Column(
              children: [
                Icon(
                  lucide.LucideIcons.flame,
                  color: kCalorieColor, // UPDATED: Color
                  size: 32,
                ),
                const SizedBox(height: 8),
                Text(
                  'Calories',
                  style: TextStyle(
                    color: _secondaryTextColor(isDarkTheme),
                    fontSize: 14,
                  ),
                ),
                Text(
                  '${_goalsData!['calories']}',
                  style: TextStyle(
                    color: _primaryTextColor(isDarkTheme),
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'kcal',
                  style: TextStyle(
                    color: _secondaryTextColor(isDarkTheme),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMacroCard(
                  isDarkTheme,
                  lucide.LucideIcons.zap, // Homescreen uses zap for protein
                  'Protein',
                  '${_goalsData!['protein']}',
                  'g',
                  kProteinColor, // UPDATED: Color
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMacroCard(
                  isDarkTheme,
                  lucide.LucideIcons.wheat,
                  'Carbs',
                  '${_goalsData!['carbs']}',
                  'g',
                  kCarbsColor, // UPDATED: Color
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMacroCard(
                  isDarkTheme,
                  lucide.LucideIcons.droplet,
                  'Fat',
                  '${_goalsData!['fat']}',
                  'g',
                  kFatColor, // UPDATED: Color
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMacroCard(
                  isDarkTheme,
                  lucide.LucideIcons.leaf,
                  'Fiber',
                  '${_goalsData!['fiber']}',
                  'g',
                  kFiberColor, // UPDATED: Color
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: _getCardDecoration(isDarkTheme),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      lucide.LucideIcons.brain,
                      color: kAIColor, // UPDATED: Color
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'AI Explanation',
                      style: TextStyle(
                        color: _primaryTextColor(isDarkTheme),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Detailed breakdown of your personalized macro plan',
                  style: TextStyle(
                    color: _secondaryTextColor(isDarkTheme),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 20),
                // Inner explanation card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDarkTheme ? AppColors.darkBackground : kInputFillColor, // Use input fill
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDarkTheme ? Colors.grey[700]! : Colors.grey[200]!,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Daily Energy Needs:',
                        style: TextStyle(
                          color: _primaryTextColor(isDarkTheme),
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '• Your Basal Metabolic Rate (BMR) is approximately ${_goalsData!['bmr']} kcal, the energy your body needs at rest.',
                        style: TextStyle(
                          color: _secondaryTextColor(isDarkTheme),
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '• With your activity level, your Total Daily Energy Expenditure (TDEE) is about ${_goalsData!['tdee']} kcal to maintain your current weight.',
                        style: TextStyle(
                          color: _secondaryTextColor(isDarkTheme),
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Your Calorie Goal:',
                        style: TextStyle(
                          color: _primaryTextColor(isDarkTheme),
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '• Your target daily calorie intake is ${_goalsData!['calories']} kcal, a ${_goalsData!['calories'] > _goalsData!['tdee'] ? 'surplus' : 'deficit'} of ${(_goalsData!['calories'] - _goalsData!['tdee']).abs()} kcal ${_goalsData!['calories'] > _goalsData!['tdee'] ? 'above' : 'below'} your maintenance level.',
                        style: TextStyle(
                          color: _secondaryTextColor(isDarkTheme),
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Your Custom Macro Plan:',
                        style: TextStyle(
                          color: _primaryTextColor(isDarkTheme),
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '• Your macros are balanced to support your goals, prioritizing protein for muscle preservation/growth, carbs for energy, and fats for hormonal function, with sufficient fiber for health and digestion.',
                        style: TextStyle(
                          color: _secondaryTextColor(isDarkTheme),
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (_goalsData!['explanation'] != null && _goalsData!['explanation'].toString().isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Additional AI Insights:',
                              style: TextStyle(
                                color: _primaryTextColor(isDarkTheme),
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // --- THIS IS THE FIX ---
                            MarkdownBody(
                              data: _goalsData!['explanation'].toString(),
                              selectable: true, // Allows user to copy text
                              styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                                // Style for regular text
                                p: TextStyle(
                                  color: _secondaryTextColor(isDarkTheme),
                                  fontSize: 14,
                                  height: 1.5,
                                ),
                                // Style for bold text (like **Your Calorie Goal:**)
                                strong: TextStyle(
                                  color: _primaryTextColor(isDarkTheme),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14, // Ensure same size
                                  height: 1.5,
                                ),
                                // Style for bullet points
                                listBullet: TextStyle(
                                  color: _secondaryTextColor(isDarkTheme),
                                  fontSize: 14,
                                  height: 1.5,
                                ),
                              ),
                            ),
                            // --- END OF FIX ---
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isCalculating ? null : _navigateToRecalculateScreen, // MODIFIED
              style: ElevatedButton.styleFrom(
                backgroundColor: kTextColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 2,
              ),
              child: _isCalculating
                  ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Recalculating...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              )
                  : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(lucide.LucideIcons.sparkles),
                  SizedBox(width: 8),
                  Text(
                    'Recalculate Goals',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_goalsData!['calculatedAt'] != null)
            Center(
              child: Text(
                'Last updated: ${_formatDate(_goalsData!['calculatedAt'])}',
                style: TextStyle(
                  color: _secondaryTextColor(isDarkTheme),
                  fontSize: 12,
                ),
              ),
            ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // --- WIDGET UPDATED ---
  Widget _buildMacroCard(
      bool isDarkTheme,
      IconData icon,
      String label,
      String value,
      String unit,
      Color iconColor, // ADDED: Specific color for the icon
      ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _getCardDecoration(isDarkTheme),
      child: Column(
        children: [
          Icon(
            icon,
            color: iconColor, // UPDATED: Use specific color
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: _primaryTextColor(isDarkTheme),
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: _secondaryTextColor(isDarkTheme),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            unit,
            style: TextStyle(
              color: _secondaryTextColor(isDarkTheme),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

// ---
// --- NEW FULL-SCREEN PAGE (Replaces RecalculateGoalsDialog)
// ---
class RecalculateGoalsScreen extends StatefulWidget {
  const RecalculateGoalsScreen({Key? key}) : super(key: key);

  @override
  State<RecalculateGoalsScreen> createState() => _RecalculateGoalsScreenState();
}

class _RecalculateGoalsScreenState extends State<RecalculateGoalsScreen> {
  int _currentStep = 0;
  final PageController _pageController = PageController();

  // --- Black & White Theme Colors ---
  static const Color kBlack = Colors.black;
  static const Color kWhite = Colors.white;
  final Color kDarkBackground = Colors.grey[900]!;
  final Color kDarkCard = Color(0xFF2C2C2E);
  final Color kLightBackground = Colors.grey[100]!;
  final Color kLightCard = Colors.white;
  // ---

  // Form data
  int? _age;
  String? _gender;
  bool _isMetric = true;
  double? _weightKg;
  double? _weightLbs;
  int? _heightCm;
  int? _heightFeet;
  int? _heightInches;
  String? _workoutFrequency;
  String? _goal;

  final List<String> _workoutOptions = [
    'Light (1-3 days/wk)',
    'Moderate (3-5 days/wk)',
    'Active (6-7 days/wk)',
  ];

  final List<String> _goalOptions = [
    'Weight Loss',
    'Maintenance',
    'Weight Gain',
  ];

  // --- STYLES FOR B&W SCREEN ---
  Color _primaryTextColor(bool isDarkTheme) {
    return isDarkTheme ? kWhite : kBlack;
  }

  Color _secondaryTextColor(bool isDarkTheme) {
    return isDarkTheme ? Colors.grey[400]! : Colors.grey[600]!;
  }

  Color _primaryIconColor(bool isDarkTheme) {
    return isDarkTheme ? kWhite : kBlack;
  }

  Color _scaffoldBgColor(bool isDarkTheme) {
    return isDarkTheme ? kBlack : kLightBackground;
  }

  Color _cardBgColor(bool isDarkTheme) {
    return isDarkTheme ? kDarkBackground : kWhite;
  }

  Color _inputFillColor(bool isDarkTheme) {
    return isDarkTheme ? kDarkCard : kLightBackground;
  }

  Color _borderColor(bool isDarkTheme) {
    return isDarkTheme ? Colors.grey[700]! : Colors.grey[300]!;
  }
  // --- END B&W STYLES ---

  void _nextPage() {
    if (_canProceedFromStep(_currentStep)) {
      if (_currentStep < 2) {
        setState(() {
          _currentStep++;
        });
        _pageController.nextPage(
          duration: Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        _calculateGoals();
      }
    }
  }

  void _previousPage() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _pageController.previousPage(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  // MODIFIED: This now pops the screen with the form data as the result
  void _calculateGoals() {
    final formData = {
      'age': _age,
      'gender': _gender?.toLowerCase(),
      'isMetric': _isMetric,
      'weightKg': _weightKg,
      'weightLbs': _weightLbs,
      'heightCm': _heightCm,
      'heightFeet': _heightFeet,
      'heightInches': _heightInches,
      'workoutFrequency': _workoutFrequency,
      'goal': _goal?.toLowerCase().replaceAll(' ', '_'),
      'dateOfBirth': DateTime.now().subtract(Duration(days: (_age ?? 25) * 365)),
    };

    // Pop the screen and return the data
    Navigator.of(context).pop(formData);
  }

  bool _canProceedFromStep(int step) {
    switch (step) {
      case 0:
        return _age != null && _gender != null;
      case 1:
        if (_isMetric) {
          return _weightKg != null && _heightCm != null;
        } else {
          return _weightLbs != null && _heightFeet != null && _heightInches != null;
        }
      case 2:
        return _workoutFrequency != null && _goal != null;
      default:
        return false;
    }
  }

  Widget _buildInputField({
    required String label,
    required bool isDarkTheme,
    String? placeholder,
    TextInputType? keyboardType,
    required Function(String) onChanged,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _primaryTextColor(isDarkTheme),
          ),
        ),
        SizedBox(height: 8),
        TextFormField(
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: TextStyle(
            color: _primaryTextColor(isDarkTheme),
          ),
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: TextStyle(
              color: _secondaryTextColor(isDarkTheme),
            ),
            filled: true,
            fillColor: _inputFillColor(isDarkTheme),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: _borderColor(isDarkTheme),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: _borderColor(isDarkTheme),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: _primaryIconColor(isDarkTheme), // B&W focus color
                width: 2,
              ),
            ),
          ),
          onChanged: onChanged,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Provider.of<ThemeProvider>(context).isDarkMode;

    final String title = _currentStep == 0
        ? 'Personal Details'
        : _currentStep == 1
        ? 'Body Measurements'
        : 'Lifestyle & Goals';

    return Scaffold(
      backgroundColor: _scaffoldBgColor(isDarkTheme),
      appBar: AppBar(
        backgroundColor: _cardBgColor(isDarkTheme),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            lucide.LucideIcons.x, // Use X to close/discard
            color: _primaryIconColor(isDarkTheme),
          ),
          onPressed: () => Navigator.of(context).pop(), // Pop with no result
        ),
        title: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                color: _primaryTextColor(isDarkTheme),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Step ${_currentStep + 1} of 3',
              style: TextStyle(
                color: _secondaryTextColor(isDarkTheme),
                fontSize: 14,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(4.0),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: List.generate(3, (index) {
                return Expanded(
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: 4),
                    height: 4,
                    decoration: BoxDecoration(
                      color: index <= _currentStep
                          ? _primaryIconColor(isDarkTheme) // B&W progress
                          : (isDarkTheme ? Colors.grey[700]! : Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
      body: PageView(
        controller: _pageController,
        physics: NeverScrollableScrollPhysics(),
        children: [
          _buildPersonalDetailsPage(isDarkTheme),
          _buildPhysicalDetailsPage(isDarkTheme),
          _buildGoalsPage(isDarkTheme),
        ],
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 120), // More bottom padding
        color: _cardBgColor(isDarkTheme),
        child: Row(
          children: [
            if (_currentStep > 0)
              Expanded(
                child: OutlinedButton(
                  onPressed: _previousPage,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: _primaryIconColor(isDarkTheme),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Back',
                    style: TextStyle(
                      color: _primaryTextColor(isDarkTheme),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            if (_currentStep > 0) SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: _canProceedFromStep(_currentStep)
                    ? (_currentStep == 2 ? _calculateGoals : _nextPage)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryIconColor(isDarkTheme), // kBlack or kWhite
                  foregroundColor: _scaffoldBgColor(isDarkTheme), // kWhite or kBlack
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 2,
                ),
                child: Text(
                  _currentStep == 2 ? 'Calculate' : 'Next',
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

  // --- STYLED HELPER FOR SELECTION BUTTONS (B&W) ---
  Widget _buildSelectionButton({
    required bool isSelected,
    required bool isDarkTheme,
    required String text,
    required VoidCallback onTap,
  }) {
    Color bgColor;
    Color textColor;
    Color borderColor;

    if (isDarkTheme) {
      bgColor = isSelected ? kWhite : kDarkCard;
      textColor = isSelected ? kBlack : kWhite;
      borderColor = isSelected ? kWhite : Colors.grey[700]!;
    } else {
      // Light theme
      bgColor = isSelected ? kBlack : kLightCard;
      textColor = isSelected ? kWhite : kBlack;
      borderColor = isSelected ? kBlack : Colors.grey[300]!;
    }

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: borderColor,
              width: isSelected ? 2 : 1, // Bolder when selected
            ),
          ),
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
  // --- END STYLED HELPER ---

  Widget _buildPersonalDetailsPage(bool isDarkTheme) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInputField(
            label: 'Age',
            isDarkTheme: isDarkTheme,
            placeholder: 'Enter your age',
            keyboardType: TextInputType.number,
            onChanged: (value) {
              setState(() {
                _age = int.tryParse(value);
              });
            },
          ),
          SizedBox(height: 24),
          Text(
            'Gender',
            style: TextStyle(
              color: _primaryTextColor(isDarkTheme),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 12),
          Row(
            children: [
              _buildSelectionButton(
                isSelected: _gender == 'Male',
                isDarkTheme: isDarkTheme,
                text: 'Male',
                onTap: () {
                  setState(() {
                    _gender = 'Male';
                  });
                },
              ),
              SizedBox(width: 16),
              _buildSelectionButton(
                isSelected: _gender == 'Female',
                isDarkTheme: isDarkTheme,
                text: 'Female',
                onTap: () {
                  setState(() {
                    _gender = 'Female';
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPhysicalDetailsPage(bool isDarkTheme) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: _inputFillColor(isDarkTheme),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _borderColor(isDarkTheme),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _isMetric = true;
                        _weightLbs = null;
                        _heightFeet = null;
                        _heightInches = null;
                      });
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _isMetric
                            ? _primaryIconColor(isDarkTheme) // kBlack or kWhite
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Text(
                          'Metric (kg/cm)',
                          style: TextStyle(
                            color: _isMetric
                                ? _scaffoldBgColor(isDarkTheme) // kWhite or kBlack
                                : _primaryTextColor(isDarkTheme),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _isMetric = false;
                        _weightKg = null;
                        _heightCm = null;
                      });
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: !_isMetric
                            ? _primaryIconColor(isDarkTheme) // kBlack or kWhite
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Text(
                          'Imperial (lbs/ft)',
                          style: TextStyle(
                            color: !_isMetric
                                ? _scaffoldBgColor(isDarkTheme) // kWhite or kBlack
                                : _primaryTextColor(isDarkTheme),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 24),
          _buildInputField(
            label: _isMetric ? 'Weight (kg)' : 'Weight (lbs)',
            isDarkTheme: isDarkTheme,
            placeholder: _isMetric ? 'Enter weight in kg' : 'Enter weight in lbs',
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            onChanged: (value) {
              setState(() {
                if (_isMetric) {
                  _weightKg = double.tryParse(value);
                } else {
                  _weightLbs = double.tryParse(value);
                }
              });
            },
          ),
          SizedBox(height: 24),
          if (_isMetric)
            _buildInputField(
              label: 'Height (cm)',
              isDarkTheme: isDarkTheme,
              placeholder: 'Enter height in cm',
              keyboardType: TextInputType.number,
              onChanged: (value) {
                setState(() {
                  _heightCm = int.tryParse(value);
                });
              },
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Height (ft/in)',
                  style: TextStyle(
                    color: _primaryTextColor(isDarkTheme),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildInputField(
                        label: 'Feet',
                        isDarkTheme: isDarkTheme,
                        placeholder: 'e.g., 5',
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          setState(() {
                            _heightFeet = int.tryParse(value);
                          });
                        },
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: _buildInputField(
                        label: 'Inches',
                        isDarkTheme: isDarkTheme,
                        placeholder: 'e.g., 10',
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          setState(() {
                            _heightInches = int.tryParse(value);
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }

  // --- STYLED HELPER FOR LIST SELECTION BUTTONS (B&W) ---
  Widget _buildListSelectionButton({
    required bool isSelected,
    required bool isDarkTheme,
    required String text,
    required VoidCallback onTap,
  }) {
    Color bgColor;
    Color textColor;
    Color borderColor;
    Color iconColor;

    if (isDarkTheme) {
      bgColor = isSelected ? kWhite : kDarkCard;
      textColor = isSelected ? kBlack : kWhite;
      borderColor = isSelected ? kWhite : Colors.grey[700]!;
      iconColor = isSelected ? kBlack : Colors.grey[400]!;
    } else {
      // Light theme
      bgColor = isSelected ? kBlack : kLightCard;
      textColor = isSelected ? kWhite : kBlack;
      borderColor = isSelected ? kBlack : Colors.grey[300]!;
      iconColor = isSelected ? kWhite : Colors.grey[600]!;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 8),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: borderColor,
            width: isSelected ? 2 : 1, // Bolder when selected
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: iconColor,
              size: 20,
            ),
            SizedBox(width: 12),
            Text(
              text,
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
  // --- END STYLED HELPER ---

  Widget _buildGoalsPage(bool isDarkTheme) {
    return Padding(
      padding: EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Workout Frequency',
              style: TextStyle(
                color: _primaryTextColor(isDarkTheme),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 12),
            Column(
              children: _workoutOptions.map((option) {
                return _buildListSelectionButton(
                  isSelected: _workoutFrequency == option,
                  isDarkTheme: isDarkTheme,
                  text: option,
                  onTap: () {
                    setState(() {
                      _workoutFrequency = option;
                    });
                  },
                );
              }).toList(),
            ),
            SizedBox(height: 24),
            Text(
              'Primary Goal',
              style: TextStyle(
                color: _primaryTextColor(isDarkTheme),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 12),
            Column(
              children: _goalOptions.map((option) {
                return _buildListSelectionButton(
                  isSelected: _goal == option,
                  isDarkTheme: isDarkTheme,
                  text: option,
                  onTap: () {
                    setState(() {
                      _goal = option;
                    });
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}