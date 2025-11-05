import 'package:flutter/material.dart';
import 'package:trackai/features/onboarding/alldone.dart';
import 'package:trackai/features/onboarding/dietpref.dart';
import 'package:trackai/features/onboarding/dob.dart';
import 'package:trackai/features/onboarding/genderselection.dart';
import 'package:trackai/features/onboarding/goalselection.dart';
import 'package:trackai/features/onboarding/heightweight.dart';
import 'package:trackai/features/onboarding/obcomplete.dart';
import 'package:trackai/features/onboarding/plan.dart';
import 'package:trackai/features/onboarding/service/observices.dart';
import 'package:trackai/features/onboarding/onboarding_data.dart'; // Make sure this path is correct
import 'package:trackai/features/onboarding/seturtarget.dart';
import 'package:trackai/features/onboarding/targetanalysis.dart';
import 'package:trackai/features/onboarding/track_long_term.dart';
import 'package:trackai/features/onboarding/workoutfrequency.dart';
import 'package:trackai/features/onboarding/otherapps.dart';
import 'package:trackai/features/onboarding/accomplishment.dart';
import 'package:trackai/features/onboarding/bmiresults.dart';
import 'package:trackai/features/home/homepage/homepage.dart';

class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({Key? key}) : super(key: key);

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  int _currentPageIndex = 0;
  bool _isLoading = false;

  // Onboarding data
  OnboardingData onboardingData = OnboardingData();

  List<Widget> _pages = [];
  int _totalPages = 12; // Updated for maintain weight (13 pages now)

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _initializePages();
    _animationController.forward();
  }

  void _initializePages() {
    _pages = [
      // Page 1: Gender Selection
      GenderSelectionPage(
        onNext: _nextPage,
        onDataUpdate: (data) => _updateData('gender', data),
      ),
      // Page 2: Workout Frequency
      WorkoutFrequencyPage(
        onNext: _nextPage,
        onBack: _previousPage,
        onDataUpdate: (data) => _updateData('workoutFrequency', data),
      ),
      // Page 3: Other Apps
      OtherAppsPage(
        onNext: _nextPage,
        onBack: _previousPage,
        onDataUpdate: (data) => _updateData('otherApps', data),
      ),
      // Page 4: Goal Selection
      GoalSelectionPage(
        onNext: _handleGoalSelectionNext,
        onBack: _previousPage,
        onDataUpdate: (data) => _updateData('goal', data),
      ),
      // Page 5: Long Term Results (for maintain weight)
      LongTermResultsPage(onNext: _nextPage, onBack: _previousPage),
      // Page 6: Accomplishment
      AccomplishmentPage(
        onNext: _nextPage,
        onBack: _previousPage,
        onDataUpdate: (data) => _updateData('accomplishment', data),
      ),
      // Page 7: Date of Birth
      DateOfBirthPage(
        onNext: _nextPage,
        onBack: _previousPage,
        onDataUpdate: (data) => _updateData('dateOfBirth', data),
      ),
      // Page 8: Height/Weight
      HeightWeightPage(
        onNext: _nextPage,
        onBack: _previousPage,
        onDataUpdate: _updateHeightWeightData,
        initialData: onboardingData.toMap(),
      ),
      // Page 9: BMI Results
      _buildBmiPage(),
      // Page 10: All Done
      AllDonePage(onComplete: _nextPage, onBack: _previousPage),
      // Page 11: Personalized Plan (NEW)
      PersonalizedPlanPage(
        onNext: _nextPage,
        onBack: _previousPage,
        onboardingData: onboardingData.toMap(),
      ),
      // Page 12: Onboarding Completion (NEW)
      OnboardingCompletionPage(
        onComplete: _completeOnboarding,
        onBack: _previousPage,
      ),
    ];
  }

  Widget _buildBmiPage() {
    return BmiResultsPage(
      onNext: _nextPage,
      onBack: _previousPage,
      onboardingData: onboardingData,
    );
  }

  void _handleGoalSelectionNext() {
    // Rebuild pages based on the selected goal
    _rebuildPagesAfterGoal();
    _nextPage();
  }

  void _rebuildPagesAfterGoal() {
    setState(() {
      String goal = onboardingData.goal;

      if (goal == 'lose_weight' || goal == 'gain_weight') {
        // For weight loss/gain goals - 15 pages total (added 2 new pages)
        _totalPages = 14;

        // Rebuild the entire pages list with target pages inserted after goal selection
        _pages = [
          // Page 1: Gender Selection
          GenderSelectionPage(
            onNext: _nextPage,
            onDataUpdate: (data) => _updateData('gender', data),
          ),
          // Page 2: Workout Frequency
          WorkoutFrequencyPage(
            onNext: _nextPage,
            onBack: _previousPage,
            onDataUpdate: (data) => _updateData('workoutFrequency', data),
          ),
          // Page 3: Other Apps
          OtherAppsPage(
            onNext: _nextPage,
            onBack: _previousPage,
            onDataUpdate: (data) => _updateData('otherApps', data),
          ),
          // Page 4: Goal Selection
          GoalSelectionPage(
            onNext: _handleGoalSelectionNext,
            onBack: _previousPage,
            onDataUpdate: (data) => _updateData('goal', data),
          ),
          // Page 5: Set Your Target (only for gain/lose weight)
          SetYourTargetPage(
            onNext: _nextPage,
            onBack: _previousPage,
            onDataUpdate: _updateTargetData,
            isMetric: onboardingData.isMetric,
            goal: goal,
          ),
          // Page 6: Target Analysis (only for gain/lose weight)
          TargetAnalysisPage(
            onNext: _nextPage,
            onBack: _previousPage,
            // --- FIXED ---
            // Read the correct amount based on the unit
            targetAmount: (onboardingData.targetUnit == 'kg'
                ? onboardingData.targetAmountKg
                : onboardingData.targetAmountLbs) ?? 0.0,
            targetUnit: onboardingData.targetUnit ?? 'kg',
            // --- END FIX ---
            targetTimeframe: onboardingData.targetTimeframe ?? 0,
            goal: goal,
          ),
          // Page 7: Long Term Results
          LongTermResultsPage(onNext: _nextPage, onBack: _previousPage),
          // Page 8: Accomplishment
          AccomplishmentPage(
            onNext: _nextPage,
            onBack: _previousPage,
            onDataUpdate: (data) => _updateData('accomplishment', data),
          ),
          // Page 9: Date of Birth
          DateOfBirthPage(
            onNext: _nextPage,
            onBack: _previousPage,
            onDataUpdate: (data) => _updateData('dateOfBirth', data),
          ),
          // Page 10: Height/Weight
          HeightWeightPage(
            onNext: _nextPage,
            onBack: _previousPage,
            onDataUpdate: _updateHeightWeightData,
            initialData: onboardingData.toMap(),
          ),
          // Page 11: BMI Results
          _buildBmiPage(),

          // Page 12: All Done (NOTE: Your page count was off, this is page 12)
          AllDonePage(onComplete: _nextPage, onBack: _previousPage),
          // Page 13: Personalized Plan (NEW)
          PersonalizedPlanPage(
            onNext: _nextPage,
            onBack: _previousPage,
            onboardingData: onboardingData.toMap(),
          ),
          // Page 14: Onboarding Completion (NEW)
          OnboardingCompletionPage(
            onComplete: _completeOnboarding,
            onBack: _previousPage,
          ),
        ];
      } else {
        // For maintain weight goal - 12 pages total
        _totalPages = 12;
        // Keep the original flow with new pages added at the end
        _initializePages();
      }
    });
  }

  void _updateData(String key, dynamic value) {
    setState(() {
      switch (key) {
        case 'gender':
          onboardingData.gender = value;
          break;
        case 'otherApps':
          onboardingData.otherApps = value;
          break;
        case 'workoutFrequency':
          onboardingData.workoutFrequency = value;
          break;
        case 'dateOfBirth':
          onboardingData.dateOfBirth = value;
          break;
        case 'goal':
          onboardingData.goal = value;
          break;
        case 'accomplishment':
          onboardingData.accomplishment = value;
          break;
      // --- REMOVED OLD FIELDS ---
        case 'desiredWeight':
          break;
        case 'goalPace':
          break;
      // --- END REMOVAL ---
        case 'dietPreference':
          onboardingData.dietPreference = value;
          break;
      }
    });
  }

  void _updateHeightWeightData(Map<String, dynamic> data) {
    print('Height/Weight data received: $data');
    setState(() {
      bool isMetric = data['isMetric'] ?? onboardingData.isMetric;
      onboardingData.isMetric = isMetric;

      if (isMetric) {
        // User entered Metric (cm/kg)
        double cm = data['heightCm']?.toDouble() ?? onboardingData.heightCm;
        double kg = data['weightKg']?.toDouble() ?? onboardingData.weightKg;

        double totalInches = cm / 2.54;
        onboardingData.heightFeet = (totalInches / 12).floor();
        onboardingData.heightInches = (totalInches % 12).round();
        onboardingData.weightLbs = kg * 2.20462;
      } else {
        // User entered Imperial (ft/in/lbs)
        onboardingData.heightFeet =
            data['heightFeet'] ?? onboardingData.heightFeet;
        onboardingData.heightInches =
            data['heightInches'] ?? onboardingData.heightInches;
        onboardingData.weightLbs =
            (data['weightLbs'] ?? onboardingData.weightLbs).toDouble();
      }

      // Update the BMI page with new data - calculate correct index
      int bmiPageIndex;
      if (onboardingData.goal == 'lose_weight' ||
          onboardingData.goal == 'gain_weight') {
        bmiPageIndex = 10; // Page 11 in 14-page flow
      } else {
        bmiPageIndex = 8; // Page 9 in 12-page flow
      }

      if (_pages.length > bmiPageIndex) {
        _pages[bmiPageIndex] = _buildBmiPage();
      }
    });
    print('Updated onboarding data: ${onboardingData.toMap()}');
  }

  //
  // --- BUG FIX: ASSIGN TO NEW FIELDS ---
  //
  void _updateTargetData(Map<String, dynamic> data) {
    setState(() {
      // Assign data to the correct fields on the onboardingData object
      onboardingData.targetAmountKg = data['targetAmountKg'];
      onboardingData.targetAmountLbs = data['targetAmountLbs'];
      onboardingData.targetUnit = data['targetUnit'];
      onboardingData.targetTimeframe = data['targetTimeframe'];
      onboardingData.targetPaceKg = data['targetPaceKg'];

      // Update the Target Analysis page (index 5)
      if (_pages.length > 5) {
        _pages[5] = TargetAnalysisPage(
          onNext: _nextPage,
          onBack: _previousPage,
          // Pass the correct amount for display based on the selected unit
          targetAmount: (onboardingData.targetUnit == 'kg'
              ? onboardingData.targetAmountKg
              : onboardingData.targetAmountLbs) ?? 0.0,
          targetUnit: onboardingData.targetUnit ?? 'kg',
          targetTimeframe: onboardingData.targetTimeframe ?? 0,
          goal: onboardingData.goal,
        );
      }
    });
  }

  void _nextPage() {
    if (_currentPageIndex < _pages.length - 1) {
      setState(() {
        _currentPageIndex++;
      });
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _previousPage() {
    if (_currentPageIndex > 0) {
      setState(() {
        _currentPageIndex--;
      });
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  Future<void> _completeOnboarding() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Save onboarding data to Firestore
      onboardingData.completedAt = DateTime.now();
      await OnboardingService.saveOnboardingData(onboardingData.toMap());

      if (mounted) {
        // AuthWrapper will automatically detect completion and show HomePage
        print('Onboarding completed - AuthWrapper will handle navigation');

        // Add a small delay for Firestore to update and trigger the stream
        await Future.delayed(const Duration(milliseconds: 500));

        // Force navigation to HomePage as a backup if stream doesn't trigger
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const HomePage()),
                (route) => false,
          );
        }
      }
    } catch (e) {
      print('Error completing onboarding: $e');
      if (mounted) {
        _showErrorSnackBar(
          'Failed to save your information. Please try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(color: Color(0xFFF8F9FA)),
        child: SafeArea(
          child: Stack(
            children: [
              // Progress indicator
              Positioned(
                top: 20,
                left: 24,
                right: 24,
                child: _buildProgressIndicator(),
              ),

              // Page view
              Positioned.fill(
                top: 80,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: _pages,
                  ),
                ),
              ),

              // Loading overlay
              if (_isLoading)
                Container(
                  color: Colors.black.withOpacity(0.7),
                  child: const Center(
                    child: CircularProgressIndicator(color: Color(0xFF4CAF50)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    // Recalculate total pages here in case it changed
    String goal = onboardingData.goal;
    _totalPages = (goal == 'lose_weight' || goal == 'gain_weight') ? 14 : 12;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Step ${_currentPageIndex + 1} / $_totalPages',
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '${((_currentPageIndex + 1) / _totalPages * 100).round()}%',
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: (_currentPageIndex + 1) / _totalPages,
          backgroundColor: const Color(0xFFE5E7EB),
          valueColor:
          const AlwaysStoppedAnimation<Color>(Color.fromARGB(255, 0, 0, 0)),
          borderRadius: BorderRadius.circular(4),
          minHeight: 6,
        ),
      ],
    );
  }
}