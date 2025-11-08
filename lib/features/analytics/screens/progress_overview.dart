// Fixed analytics_provider.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:math' as math;
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:trackai/core/constants/appcolors.dart';
// Make sure this import path is correct for your project if AnalyticsProvider is in its own file
// import 'package:trackai/features/analytics/analytics_provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart' as lucide;

class AnalyticsProvider extends ChangeNotifier {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  String? get _currentUserId => _auth.currentUser?.uid;
  Color bmiStatusColor = Colors.grey;
  String bmiStatusLabel = "";

  // Private fields for BMI
  double? _currentBMI;
  String _heightUnit = 'Centimeters (cm)';
  String _weightUnit = 'Kilograms (kg)';
  final TextEditingController _heightCmController = TextEditingController();
  final TextEditingController _heightFeetController = TextEditingController();
  final TextEditingController _heightInchesController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();

  List<String> _selectedTrackers = [];
  String _selectedTimeframe = 'This Week';
  String _selectedAnalyticsType = 'Dashboard & Summary';
  Map<String, dynamic> _dashboardConfig = {};
  String _overallSummary = '';
  bool _isLoadingSummary = false;
  bool _isLoadingCorrelations = false;
  Map<String, List<Map<String, dynamic>>> _trackerData = {};
  List<Map<String, dynamic>> _correlationResults = [];
  Map<String, dynamic> _progressData = {};
  Map<String, dynamic> _periodData = {};

  // Period tracking - FIXED STATE MANAGEMENT
  bool _isLoggingPeriod = false;
  DateTime? _selectedPeriodDate;
  List<String> _selectedSymptoms = [];
  bool _isLoadingPeriodData = false;
  String? _cachedInsights; // Cache insights to prevent unnecessary regeneration
  DateTime? _lastInsightsUpdate; // Track when insights were last generated

  // Getters
  List<String> get selectedTrackers => _selectedTrackers;
  String get selectedTimeframe => _selectedTimeframe;
  String get selectedAnalyticsType => _selectedAnalyticsType;
  Map<String, dynamic> get dashboardConfig => _dashboardConfig;
  String get overallSummary => _overallSummary;
  bool get isLoadingSummary => _isLoadingSummary;
  bool get isLoadingCorrelations => _isLoadingCorrelations;
  Map<String, List<Map<String, dynamic>>> get trackerData => _trackerData;
  List<Map<String, dynamic>> get correlationResults => _correlationResults;
  Map<String, dynamic> get progressData => _progressData;
  Map<String, dynamic> get periodData => _periodData;
  bool get isLoggingPeriod => _isLoggingPeriod;
  bool get isLoadingPeriodData => _isLoadingPeriodData;
  DateTime? get selectedPeriodDate => _selectedPeriodDate;
  List<String> get selectedSymptoms => _selectedSymptoms;

  // BMI Getters (Used the existing private fields and their getters)
  double? get currentBMI => _currentBMI;
  String get heightUnit => _heightUnit;
  String get weightUnit => _weightUnit;
  TextEditingController get heightCmController => _heightCmController;
  TextEditingController get heightFeetController => _heightFeetController;
  TextEditingController get heightInchesController => _heightInchesController;
  TextEditingController get weightController => _weightController;

  final List<String> availableTrackers = [
    'Sleep Tracker',
    'Mood Tracker',
    'Meditation Tracker',
    'Expense Tracker',
    'Savings Tracker',
    'Alcohol Tracker',
    'Study Time Tracker',
    'Mental Well-being Tracker',
    'Workout Tracker',
    'Weight Tracker',
    'Menstrual Cycle',
  ];

  final List<String> analyticsTypes = [
    'Dashboard & Summary',
    'Progress Overview',
  ];

  final List<String> timeframes = [
    'This Week',
    'Last Week',
    'This Month',
    'Last Month',
    'Last 3 Months',
    'Last 6 Months',
  ];

  final List<String> periodSymptoms = [
    'Cramps',
    'Bloating',
    'Headache',
    'Mood swings',
    'Fatigue',
    'Back pain',
    'Breast tenderness',
    'Food cravings',
    'Acne',
    'Nausea',
  ];

  void setSelectedAnalyticsType(String type) {
    _selectedAnalyticsType = type;
    notifyListeners();

    switch (type) {
      case 'Dashboard & Summary':
        if (_selectedTrackers.isNotEmpty) {
          loadTrackerData();
          generateOverallSummary();
        }
        break;
      case 'Correlation Labs':
      // Don't auto-load for correlation labs, let user select trackers
        break;
      case 'Progress Overview':
        if (_selectedTrackers.isNotEmpty) {
          loadTrackerData().then((_) => loadProgressData());
        }
        break;
      case 'Period Cycle':
        loadPeriodData();
        break;
    }
  }

  void setSelectedTimeframe(String timeframe) {
    _selectedTimeframe = timeframe;
    // Clear cached insights when timeframe changes
    _cachedInsights = null;
    notifyListeners();
    if (_selectedTrackers.isNotEmpty) {
      loadTrackerData();
    }
  }

  // Consolidated BMI calculation logic, keeping the full implementation
  // and removing the duplicate basic one from the original code.
  Future<double?> calculateBMIForCmAndKg() async {
    try {
      double heightInMeters;
      double weightInKg;

      // Only supporting cm and kg units as in your image
      final heightCm = double.tryParse(heightCmController.text);
      final weight = double.tryParse(weightController.text);

      if (heightCm == null || heightCm <= 0 || weight == null || weight <= 0) {
        return null;
      }
      heightInMeters = heightCm / 100;
      weightInKg = weight;

      final bmi = weightInKg / (heightInMeters * heightInMeters);
      _currentBMI = bmi; // Use the private field

      // Update label and color according to BMI category
      if (bmi < 18.5) {
        bmiStatusLabel = "Underweight";
        bmiStatusColor = Colors.blue;
      } else if (bmi < 25) {
        bmiStatusLabel = "Healthy";
        bmiStatusColor = Colors.green;
      } else if (bmi < 30) {
        bmiStatusLabel = "Overweight";
        bmiStatusColor = Colors.orange;
      } else {
        bmiStatusLabel = "Obese";
        bmiStatusColor = Colors.red;
      }
      notifyListeners();
      return bmi;
    } catch (e) {
      debugPrint("Error calculating BMI: $e");
      return null;
    }
  }

  void toggleTrackerSelection(String tracker) {
    if (_selectedTrackers.contains(tracker)) {
      _selectedTrackers.remove(tracker);
    } else {
      _selectedTrackers.add(tracker);
    }
    _saveDashboardConfig();
    notifyListeners();
  }

  DateTime _getTimeframeStartDate(String timeframe) {
    final now = DateTime.now();
    switch (timeframe) {
      case 'This Week':
        return now.subtract(Duration(days: now.weekday - 1));
      case 'Last Week':
        return now.subtract(Duration(days: now.weekday + 6));
      case 'This Month':
        return DateTime(now.year, now.month, 1);
      case 'Last Month':
        final lastMonth = DateTime(now.year, now.month - 1, 1);
        return lastMonth;
      case 'Last 3 Months':
        return DateTime(now.year, now.month - 3, now.day);
      case 'Last 6 Months':
        return DateTime(now.year, now.month - 6, now.day);
      default:
        return now.subtract(Duration(days: 7));
    }
  }

  Future<void> loadDashboardConfig() async {
    if (_currentUserId == null) return;

    try {
      final doc = await _firestore
          .collection('users')
          .doc(_currentUserId)
          .collection('analytics_data')
          .doc('dashboard_config')
          .get();

      if (doc.exists) {
        _dashboardConfig = doc.data() ?? {};
        _selectedTrackers = List<String>.from(
          _dashboardConfig['selectedTrackers'] ?? [],
        );
        if (_selectedTrackers.isNotEmpty) {
          await loadTrackerData();
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading dashboard config: $e');
    }
  }

  Future<void> _saveDashboardConfig() async {
    if (_currentUserId == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(_currentUserId)
          .collection('analytics_data')
          .doc('dashboard_config')
          .set({
        'selectedTrackers': _selectedTrackers,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error saving dashboard config: $e');
    }
  }

  Future<void> loadTrackerData() async {
    if (_currentUserId == null || _selectedTrackers.isEmpty) return;

    try {
      final Map<String, List<Map<String, dynamic>>> data = {};
      final startDate = _getTimeframeStartDate(_selectedTimeframe);

      for (String tracker in _selectedTrackers) {
        final trackerId = _getTrackerIdFromName(tracker);
        // *** MODIFICATION ***
        // Use 'nutrition' as the ID if that's what's saved from scan screens
        // Or ensure your 'food_log_entry' saves to a tracker named 'nutrition'
        // For this example, I'll assume 'nutrition' is the ID for nutrition logs.
        // We will modify _getTrackerEntries to fetch 'nutrition' logs
        final entries = await _getTrackerEntries(trackerId, startDate);
        data[tracker] = entries;
        debugPrint('Loaded ${entries.length} entries for $tracker');
      }

      _trackerData = data;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading tracker data: $e');
    }
  }

  Future<void> generateOverallSummary() async {
    if (_trackerData.isEmpty) return;

    _isLoadingSummary = true;
    notifyListeners();

    try {
      final geminiApiKey = dotenv.env['GEMINI_API_KEY'];
      if (geminiApiKey == null || geminiApiKey.isEmpty) {
        throw Exception('Gemini API key not found in .env file');
      }

      final model = GenerativeModel(model: 'gemini-pro', apiKey: geminiApiKey);

      final prompt = _buildSummaryPrompt();
      final response = await model.generateContent([Content.text(prompt)]);

      _overallSummary = response.text ?? 'Unable to generate summary';
    } catch (e) {
      _overallSummary = 'Error generating summary: ${e.toString()}';
      debugPrint('Error generating summary: $e');
    }

    _isLoadingSummary = false;
    notifyListeners();
  }

  String _buildSummaryPrompt() {
    final buffer = StringBuffer();
    buffer.writeln(
      'Analyze the following tracking data and provide 3 concise insights in this format:',
    );
    buffer.writeln('1. One positive trend or achievement');
    buffer.writeln('2. One area that needs attention or improvement');
    buffer.writeln('3. One actionable recommendation');
    buffer.writeln('Keep each insight to 2 sentences maximum.\n');

    _trackerData.forEach((tracker, entries) {
      if (entries.isNotEmpty) {
        buffer.writeln(
          '$tracker (${entries.length} entries in ${_selectedTimeframe.toLowerCase()}):',
        );

        // Calculate basic stats
        final values = entries
            .map((e) => double.tryParse(e['value']?.toString() ?? '0') ?? 0.0)
            .where((v) => v > 0)
            .toList();

        if (values.isNotEmpty) {
          final avg = values.reduce((a, b) => a + b) / values.length;
          final min = values.reduce((a, b) => a < b ? a : b);
          final max = values.reduce((a, b) => a > b ? a : b);
          buffer.writeln(
            '  Average: ${avg.toStringAsFixed(1)}, Range: $min - $max',
          );
        }

        // Show recent entries
        for (int i = 0; i < entries.length && i < 3; i++) {
          final entry = entries[i];
          final date = DateTime.tryParse(entry['timestamp'] ?? '');
          final dateStr = date != null ? '${date.month}/${date.day}' : 'Recent';
          buffer.writeln('  $dateStr: ${entry['value'] ?? 'N/A'}');
        }
        buffer.writeln();
      }
    });

    return buffer.toString();
  }

// In AnalyticsProvider class

  Future<List<Map<String, dynamic>>> _getTrackerEntries(
      String trackerId,
      DateTime startDate,
      ) async {
    try {
      String collectionName = 'entries'; // Default
      String docId = trackerId; // Default

      if (trackerId == 'nutrition') {
        docId = 'nutrition';
        collectionName = 'entries'; // This matches your daily_log_provider
      } else if (trackerId == 'menstrual') {
        docId = 'menstrual';
        collectionName = 'entries';
      }

      Query query = _firestore
          .collection('users')
          .doc(_currentUserId)
          .collection('tracking')
          .doc(docId)
          .collection(collectionName)
          .where(
        'timestamp',
        isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
      )
          .orderBy('timestamp', descending: true)
          .limit(100);

      final querySnapshot = await query.get();
      if (trackerId == 'nutrition') {
        print(
            '--- AnalyticsProvider: Found ${querySnapshot.docs.length} nutrition documents in Firestore for this timeframe.');
      }
      return querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['timestamp'] is Timestamp) {
          // ✅ --- THIS IS THE FIX ---
          data['timestamp'] =
              (data['timestamp'] as Timestamp).toDate().toIso8601String(); // Was .toIso8061String()
          // --- END OF FIX ---
        }
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      debugPrint('Error getting tracker entries for $trackerId: $e');
      if (trackerId == 'nutrition') {
        debugPrint(
            "COULD NOT FIND 'nutrition' ENTRIES. MAKE SURE YOU ARE SAVING FOOD LOGS TO FIRESTORE: /users/<uid>/tracking/nutrition/entries");
      }
      return [];
    }
  }
  String _getTrackerIdFromName(String trackerName) {
    final Map<String, String> trackerMap = {
      'Sleep Tracker': 'sleep',
      'Mood Tracker': 'mood',
      'Meditation Tracker': 'meditation',
      'Expense Tracker': 'expense',
      'Savings Tracker': 'savings',
      'Alcohol Tracker': 'alcohol',
      'Study Time Tracker': 'study',
      'Mental Well-being Tracker': 'mental_wellbeing',
      'Workout Tracker': 'workout',
      'Weight Tracker': 'weight',
      'Menstrual Cycle': 'menstrual',
      // We add Nutrition here
      'Nutrition': 'nutrition',
    };
    return trackerMap[trackerName] ??
        trackerName.toLowerCase().replaceAll(' ', '_');
  }

  Future<void> analyzeCorrelations() async {
    if (_selectedTrackers.length < 2) {
      debugPrint('Need at least 2 trackers for correlation analysis');
      return;
    }

    _isLoadingCorrelations = true;
    _correlationResults.clear();
    notifyListeners();

    try {
      debugPrint(
        'Starting correlation analysis with ${_selectedTrackers.length} trackers',
      );

      // Make sure we have fresh data
      await loadTrackerData();

      final List<Map<String, dynamic>> correlations = [];

      for (int i = 0; i < _selectedTrackers.length; i++) {
        for (int j = i + 1; j < _selectedTrackers.length; j++) {
          final tracker1 = _selectedTrackers[i];
          final tracker2 = _selectedTrackers[j];

          final data1 = _trackerData[tracker1] ?? [];
          final data2 = _trackerData[tracker2] ?? [];

          debugPrint(
            'Analyzing correlation between $tracker1 (${data1.length} entries) and $tracker2 (${data2.length} entries)',
          );

          if (data1.isNotEmpty && data2.isNotEmpty) {
            final correlation = _calculateCorrelation(data1, data2);
            debugPrint('Calculated correlation: $correlation');

            // Calculate stats and common dates for the correlation results
            final commonDates = _findCommonDates(data1, data2);
            final stats1 = _calculateTrackerStats(data1);
            final stats2 = _calculateTrackerStats(data2);

            // Generate AI insights for this correlation
            final insight = await _generateCorrelationInsight(
              tracker1,
              tracker2,
              correlation,
              data1,
              data2,
            );

            correlations.add({
              'tracker1': tracker1,
              'tracker2': tracker2,
              'correlation': correlation,
              'strength': _getCorrelationStrength(correlation),
              'insight': insight,
              'dataPoints': commonDates['count'],
              'trend': '${stats1['trend']} vs ${stats2['trend']}',
            });
          }
        }
      }

      _correlationResults = correlations;
      debugPrint('Generated ${correlations.length} correlation results');
    } catch (e) {
      debugPrint('Error analyzing correlations: $e');
    }

    _isLoadingCorrelations = false;
    notifyListeners();
  }

  Future<String> _generateCorrelationInsight(
      String tracker1,
      String tracker2,
      double correlation,
      List<Map<String, dynamic>> data1,
      List<Map<String, dynamic>> data2,
      ) async {
    try {
      final geminiApiKey = dotenv.env['GEMINI_API_KEY'];
      if (geminiApiKey == null || geminiApiKey.isEmpty) {
        return _getDefaultCorrelationInsight(tracker1, tracker2, correlation);
      }

      final model = GenerativeModel(model: 'gemini-pro', apiKey: geminiApiKey);

      final strength = _getCorrelationStrength(correlation);
      final direction = correlation > 0 ? 'positive' : 'negative';
      final commonDates = _findCommonDates(data1, data2);

      // Calculate basic statistics for both trackers
      final stats1 = _calculateTrackerStats(data1);
      final stats2 = _calculateTrackerStats(data2);

      final prompt = '''
I need you to analyze the correlation between two health/lifestyle trackers and provide detailed, actionable insights.

TRACKER ANALYSIS:
Tracker 1: $tracker1
- Entries: ${data1.length}
- Average: ${stats1['average']?.toStringAsFixed(2)}
- Range: ${stats1['min']} - ${stats1['max']}
- Recent trend: ${stats1['trend']}

Tracker 2: $tracker2  
- Entries: ${data2.length}
- Average: ${stats2['average']?.toStringAsFixed(2)}
- Range: ${stats2['min']} - ${stats2['max']}
- Recent trend: ${stats2['trend']}

CORRELATION ANALYSIS:
- Correlation coefficient: ${correlation.toStringAsFixed(3)}
- Strength: $strength
- Direction: $direction
- Data points used: ${commonDates['count']}
- Timeframe: ${_selectedTimeframe}

REQUESTED INSIGHT FORMAT:
Please provide a comprehensive analysis with these sections:

1. **Relationship Interpretation**: Explain what this correlation might mean in practical terms for these specific trackers. Consider common physiological or psychological connections.

2. **Actionable Recommendations**: Provide 2-3 specific, practical suggestions the user could implement based on this relationship. Make them concrete and measurable.

3. **Potential Caveats**: Mention any limitations or considerations about this correlation (sample size, timeframe, external factors).

4. **Monitoring Suggestions**: Suggest how the user could track this relationship going forward and what to look for.

Keep the tone professional yet accessible, and focus on practical wellness applications. Each section should be 2-3 sentences maximum.
''';

      final response = await model.generateContent([Content.text(prompt)]);
      return response.text ??
          _getDefaultCorrelationInsight(tracker1, tracker2, correlation);
    } catch (e) {
      debugPrint('Error generating correlation insight: $e');
      return _getDefaultCorrelationInsight(tracker1, tracker2, correlation);
    }
  }

  Map<String, dynamic> _findCommonDates(
      List<Map<String, dynamic>> data1,
      List<Map<String, dynamic>> data2,
      ) {
    final Map<String, double> values1 = {};
    final Map<String, double> values2 = {};

    for (var entry in data1) {
      final date = entry['timestamp']?.toString().split('T')[0];
      final value = double.tryParse(entry['value']?.toString() ?? '0') ?? 0.0;
      if (date != null && value > 0) {
        values1[date] = value;
      }
    }

    for (var entry in data2) {
      final date = entry['timestamp']?.toString().split('T')[0];
      final value = double.tryParse(entry['value']?.toString() ?? '0') ?? 0.0;
      if (date != null && value > 0) {
        values2[date] = value;
      }
    }

    final commonDates = values1.keys.toSet().intersection(values2.keys.toSet());

    return {'dates': commonDates.toList(), 'count': commonDates.length};
  }

  Map<String, dynamic> _calculateTrackerStats(List<Map<String, dynamic>> data) {
    if (data.isEmpty) {
      return {'average': 0, 'min': 0, 'max': 0, 'trend': 'Insufficient data'};
    }

    final values = data
        .map((e) => double.tryParse(e['value']?.toString() ?? '0') ?? 0.0)
        .where((v) => v > 0)
        .toList();

    if (values.isEmpty) {
      return {'average': 0, 'min': 0, 'max': 0, 'trend': 'No valid values'};
    }

    final avg = values.reduce((a, b) => a + b) / values.length;
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);

    String trend = 'Stable';
    if (values.length >= 4) {
      final half = (values.length / 2).floor();
      final firstHalfAvg =
          values.sublist(0, half).reduce((a, b) => a + b) / half;
      final secondHalfAvg =
          values.sublist(half).reduce((a, b) => a + b) / (values.length - half);

      if (secondHalfAvg > firstHalfAvg * 1.1)
        trend = 'Increasing';
      else if (secondHalfAvg < firstHalfAvg * 0.9) trend = 'Decreasing';
    }

    return {'average': avg, 'min': min, 'max': max, 'trend': trend};
  }

  String _getDefaultCorrelationInsight(
      String tracker1,
      String tracker2,
      double correlation,
      ) {
    final strength = _getCorrelationStrength(correlation);
    final direction = correlation > 0 ? 'positive' : 'negative';
    return '$strength $direction correlation detected between $tracker1 and $tracker2. Consider how changes in one might affect the other.';
  }

  double _calculateCorrelation(
      List<Map<String, dynamic>> data1,
      List<Map<String, dynamic>> data2,
      ) {
    try {
      final Map<String, double> values1 = {};
      final Map<String, double> values2 = {};

      for (var entry in data1) {
        final date = entry['timestamp']?.toString().split('T')[0];
        final value = double.tryParse(entry['value']?.toString() ?? '0') ?? 0.0;
        if (date != null && value > 0) {
          values1[date] = value;
        }
      }

      for (var entry in data2) {
        final date = entry['timestamp']?.toString().split('T')[0];
        final value = double.tryParse(entry['value']?.toString() ?? '0') ?? 0.0;
        if (date != null && value > 0) {
          values2[date] = value;
        }
      }

      final commonDates =
      values1.keys.toSet().intersection(values2.keys.toSet()).toList();

      debugPrint('Found ${commonDates.length} common dates for correlation');

      if (commonDates.length < 2) return 0.0;

      final List<double> x = commonDates.map((date) => values1[date]!).toList();
      final List<double> y = commonDates.map((date) => values2[date]!).toList();

      if (x.isEmpty || y.isEmpty) return 0.0;

      final double meanX = x.reduce((a, b) => a + b) / x.length;
      final double meanY = y.reduce((a, b) => a + b) / y.length;

      double numerator = 0.0;
      double sumSqX = 0.0;
      double sumSqY = 0.0;

      for (int i = 0; i < x.length; i++) {
        final diffX = x[i] - meanX;
        final diffY = y[i] - meanY;
        numerator += diffX * diffY;
        sumSqX += diffX * diffX;
        sumSqY += diffY * diffY;
      }

      final denominator = math.sqrt(sumSqX * sumSqY);
      final correlation = denominator > 0 ? numerator / denominator : 0.0;

      return correlation.clamp(-1.0, 1.0);
    } catch (e) {
      debugPrint('Error calculating correlation: $e');
      return 0.0;
    }
  }

  String _getCorrelationStrength(double correlation) {
    final abs = correlation.abs();
    if (abs >= 0.7) return 'Strong';
    if (abs >= 0.4) return 'Moderate';
    if (abs >= 0.2) return 'Weak';
    return 'Very Weak';
  }

  Future<void> loadProgressData() async {
    try {
      final Map<String, dynamic> progress = {};

      for (String tracker in _selectedTrackers) {
        final trackerId = _getTrackerIdFromName(tracker);

        final thisWeekStart = DateTime.now().subtract(
          Duration(days: DateTime.now().weekday - 1),
        );
        final lastWeekStart = thisWeekStart.subtract(Duration(days: 7));

        final allEntries = await _getTrackerEntries(
          trackerId,
          lastWeekStart.subtract(Duration(days: 30)),
        );

        final thisWeekData = allEntries.where((entry) {
          final date = DateTime.tryParse(entry['timestamp'] ?? '');
          return date != null && date.isAfter(thisWeekStart);
        }).toList();

        final lastWeekData = allEntries.where((entry) {
          final date = DateTime.tryParse(entry['timestamp'] ?? '');
          return date != null &&
              date.isAfter(lastWeekStart) &&
              date.isBefore(thisWeekStart);
        }).toList();

        if (allEntries.isNotEmpty) {
          progress[tracker] = {
            'thisWeek': thisWeekData,
            'lastWeek': lastWeekData,
            'total': allEntries.length,
            'average': _calculateAverage(allEntries),
            'thisWeekAvg': _calculateAverage(thisWeekData),
            'lastWeekAvg': _calculateAverage(lastWeekData),
          };
        }
      }

      _progressData = progress;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading progress data: $e');
    }
  }

  double _calculateAverage(List<Map<String, dynamic>> entries) {
    if (entries.isEmpty) return 0.0;

    final values = entries
        .map((e) => double.tryParse(e['value']?.toString() ?? '0') ?? 0.0)
        .where((v) => v > 0)
        .toList();

    return values.isEmpty
        ? 0.0
        : values.reduce((a, b) => a + b) / values.length;
  }

  // FIXED PERIOD TRACKING METHODS
  void setSelectedPeriodDate(DateTime? date) {
    _selectedPeriodDate = date;
    notifyListeners();
  }

  void toggleSymptom(String symptom) {
    if (_selectedSymptoms.contains(symptom)) {
      _selectedSymptoms.remove(symptom);
    } else {
      _selectedSymptoms.add(symptom);
    }
    // Clear cached insights when symptoms change
    _cachedInsights = null;
    notifyListeners();
  }

  // COMPLETELY REWRITTEN LOG PERIOD ENTRY METHOD
  Future<void> logPeriodEntry() async {
    if (_currentUserId == null || _selectedPeriodDate == null) {
      debugPrint('Cannot log period: missing user ID or date');
      return;
    }

    // Prevent multiple simultaneous operations
    if (_isLoggingPeriod) {
      debugPrint('Already logging period entry, skipping');
      return;
    }

    _isLoggingPeriod = true;
    notifyListeners();

    try {
      debugPrint('Starting to log period entry for date: $_selectedPeriodDate');

      // Calculate cycle day based on previous entries
      final previousEntries = await _getTrackerEntries(
        'menstrual',
        DateTime.now().subtract(Duration(days: 365)),
      );

      int cycleDay = 1;
      String phase = 'Menstrual';

      if (previousEntries.isNotEmpty) {
        // Find the most recent period start
        final periodStartEntries = previousEntries
            .where((entry) => entry['value'] == 'Period Start')
            .toList();

        if (periodStartEntries.isNotEmpty) {
          // Sort by timestamp to get the most recent
          periodStartEntries.sort((a, b) {
            final dateA =
                DateTime.tryParse(a['timestamp'] ?? '') ?? DateTime.now();
            final dateB =
                DateTime.tryParse(b['timestamp'] ?? '') ?? DateTime.now();
            return dateB.compareTo(dateA); // Most recent first
          });

          final lastPeriodEntry = periodStartEntries.first;
          final lastDate = DateTime.tryParse(lastPeriodEntry['timestamp'] ?? '');

          if (lastDate != null) {
            cycleDay = _selectedPeriodDate!.difference(lastDate).inDays + 1;
            phase = _getCyclePhase(cycleDay);
            debugPrint('Calculated cycle day: $cycleDay, phase: $phase');
          }
        }
      }

      // Create the new entry
      final entryData = {
        'timestamp': Timestamp.fromDate(_selectedPeriodDate!),
        'value': 'Period Start',
        'symptoms': List.from(_selectedSymptoms), // Create a copy
        'cycleDay': cycleDay,
        'phase': phase,
        'createdAt': FieldValue.serverTimestamp(),
      };

      debugPrint('Adding entry to Firestore: $entryData');

      // Add to Firestore
      final docRef = await _firestore
          .collection('users')
          .doc(_currentUserId)
          .collection('tracking')
          .doc('menstrual')
          .collection('entries')
          .add(entryData);

      debugPrint('Successfully added period entry with ID: ${docRef.id}');

      // CRITICAL: Clear form state BEFORE reloading data
      // Removed unused local variables tempDate and tempSymptoms
      _selectedPeriodDate = null;
      _selectedSymptoms.clear();
      _cachedInsights = null; // Force insights regeneration
      _lastInsightsUpdate = null;

      debugPrint(
          'Cleared form state - Date: $_selectedPeriodDate, Symptoms: $_selectedSymptoms');

      // Reset loading state BEFORE reload to prevent UI issues
      _isLoggingPeriod = false;
      notifyListeners(); // Notify immediately so UI updates

      // Now reload the period data with fresh insights
      await loadPeriodData(forceRefresh: true);

      debugPrint('Period entry logging completed successfully');
    } catch (e) {
      debugPrint('Error logging period entry: $e');
      // Reset loading state on error
      _isLoggingPeriod = false;
      notifyListeners();
      rethrow; // Re-throw so UI can handle the error
    }
  }

  // IMPROVED LOAD PERIOD DATA WITH FORCED REFRESH OPTION
  Future<void> loadPeriodData({bool forceRefresh = false}) async {
    // Prevent multiple simultaneous loads
    if (_isLoadingPeriodData && !forceRefresh) {
      debugPrint('Already loading period data, skipping');
      return;
    }

    _isLoadingPeriodData = true;
    if (forceRefresh) {
      _cachedInsights = null;
      _lastInsightsUpdate = null;
    }
    notifyListeners();

    try {
      debugPrint('Loading period data...');

      final entries = await _getTrackerEntries(
        'menstrual',
        DateTime.now().subtract(Duration(days: 365)),
      );

      debugPrint('Retrieved ${entries.length} menstrual entries');

      final Map<String, dynamic> periodAnalysis = {};

      if (entries.isNotEmpty) {
        // Analyze period cycle data
        final cycles = _analyzeMenstrualCycles(entries);
        periodAnalysis['cycles'] = cycles;
        periodAnalysis['averageCycleLength'] =
            _calculateAverageCycleLength(cycles);
        periodAnalysis['nextPredictedPeriod'] = _predictNextPeriod(cycles);
        periodAnalysis['recentEntries'] = entries.take(10).toList();

        debugPrint(
            'Analysis complete - Cycles: ${cycles.length}, Avg length: ${periodAnalysis['averageCycleLength']}');

        // Only generate new insights if we don't have cached ones or if forced refresh
        if (_cachedInsights == null || forceRefresh) {
          debugPrint('Generating fresh period insights...');
          final insights = await _generatePeriodInsights(entries, cycles);
          _cachedInsights = insights;
          _lastInsightsUpdate = DateTime.now();
          periodAnalysis['insights'] = insights;
        } else {
          debugPrint('Using cached period insights');
          periodAnalysis['insights'] = _cachedInsights;
        }
      } else {
        periodAnalysis['cycles'] = [];
        periodAnalysis['averageCycleLength'] = 28.0;
        periodAnalysis['nextPredictedPeriod'] = null;
        periodAnalysis['recentEntries'] = [];
        periodAnalysis['insights'] =
        'Start logging your cycle to get personalized insights about your menstrual health.';
      }

      _periodData = periodAnalysis;
      debugPrint('Period data loaded successfully');
    } catch (e) {
      debugPrint('Error loading period data: $e');
    }

    _isLoadingPeriodData = false;
    notifyListeners();
  }

  // OPTIMIZED INSIGHTS GENERATION WITH CACHING
  Future<String> _generatePeriodInsights(
      List<Map<String, dynamic>> entries,
      List<Map<String, dynamic>> cycles,
      ) async {
    // Check if we have recent cached insights (within 1 hour)
    if (_cachedInsights != null && _lastInsightsUpdate != null) {
      final hoursSinceUpdate =
          DateTime.now().difference(_lastInsightsUpdate!).inHours;
      if (hoursSinceUpdate < 1) {
        debugPrint(
            'Using cached insights (generated ${hoursSinceUpdate} hours ago)');
        return _cachedInsights!;
      }
    }

    try {
      final geminiApiKey = dotenv.env['GEMINI_API_KEY'];
      if (geminiApiKey == null || geminiApiKey.isEmpty) {
        return _generateDetailedOfflineInsights(entries, cycles);
      }

      final model = GenerativeModel(model: 'gemini-pro', apiKey: geminiApiKey);

      final averageLength = _calculateAverageCycleLength(cycles);
      final symptomCounts = <String, int>{};
      final phaseCounts = <String, int>{};
      final recentDates = <DateTime>[];

      for (var entry in entries) {
        final symptoms = List<String>.from(entry['symptoms'] ?? []);
        for (var symptom in symptoms) {
          symptomCounts[symptom] = (symptomCounts[symptom] ?? 0) + 1;
        }

        final date = DateTime.tryParse(entry['timestamp'] ?? '');
        if (date != null) recentDates.add(date);
      }

      for (var cycle in cycles) {
        final phase = cycle['phase'] ?? 'Unknown';
        phaseCounts[phase] = (phaseCounts[phase] ?? 0) + 1;
      }

      recentDates.sort((a, b) => b.compareTo(a));
      final trackingDays = recentDates.isNotEmpty
          ? DateTime.now().difference(recentDates.last).inDays
          : 0;

      final topSymptoms = symptomCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final prompt = '''
As a women's health AI assistant, analyze this detailed menstrual cycle data and provide comprehensive, personalized insights:

**CYCLE DATA ANALYSIS:**
• Total period entries logged: ${entries.length}
• Tracking duration: $trackingDays days
• Average cycle length: ${averageLength.toStringAsFixed(1)} days
• Cycle phases tracked: ${phaseCounts.keys.join(', ')}

**SYMPTOM PATTERNS:**
${topSymptoms.take(5).map((e) => '• ${e.key}: ${e.value} occurrences').join('\n')}

**RECENT TRACKING BEHAVIOR:**
• Most recent entry: ${recentDates.isNotEmpty ? recentDates.first.toString().split(' ')[0] : 'None'}
• Consistency: ${entries.length >= 3 ? 'Good tracking habits' : 'Building tracking routine'}

**REQUESTED ANALYSIS:**
Please provide a comprehensive response covering:

1. **Cycle Health Assessment** (2-3 sentences):
   - Evaluate cycle regularity and what it indicates about hormonal health
   - Compare to healthy ranges and note any patterns

2. **Symptom Pattern Insights** (2-3 sentences):
   - Analyze most common symptoms and their timing
   - Provide specific management strategies for top symptoms

3. **Personalized Recommendations** (3-4 actionable points):
   - Lifestyle adjustments based on cycle patterns
   - Tracking improvements to gather better insights
   - Phase-specific optimization tips
   - When to consult healthcare providers

4. **Future Predictions & Goals** (2 sentences):
   - What patterns to watch for with continued tracking
   - Timeline for more reliable cycle predictions

Keep the tone supportive, educational, and medically appropriate. Focus on actionable insights that empower better cycle management. Use specific data points from the analysis above.
''';

      final response = await model.generateContent([Content.text(prompt)]);
      final insights =
          response.text ?? _generateDetailedOfflineInsights(entries, cycles);

      // Cache the insights
      _cachedInsights = insights;
      _lastInsightsUpdate = DateTime.now();

      return insights;
    } catch (e) {
      debugPrint('Error generating period insights: $e');
      return _generateDetailedOfflineInsights(entries, cycles);
    }
  }

  String _generateDetailedOfflineInsights(
      List<Map<String, dynamic>> entries,
      List<Map<String, dynamic>> cycles,
      ) {
    final insights = StringBuffer();
    final averageLength = _calculateAverageCycleLength(cycles);
    final symptomCounts = <String, int>{};
    final dates = <DateTime>[];

    for (var entry in entries) {
      final symptoms = List<String>.from(entry['symptoms'] ?? []);
      for (var symptom in symptoms) {
        symptomCounts[symptom] = (symptomCounts[symptom] ?? 0) + 1;
      }

      final date = DateTime.tryParse(entry['timestamp'] ?? '');
      if (date != null) dates.add(date);
    }

    dates.sort();
    final trackingDays =
    dates.isNotEmpty ? dates.last.difference(dates.first).inDays : 0;
    final topSymptoms = symptomCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Cycle Health Assessment
    insights.writeln('**CYCLE HEALTH ASSESSMENT**');
    if (entries.length >= 3) {
      if (averageLength >= 21 && averageLength <= 35) {
        insights.writeln(
            'Your ${averageLength.toStringAsFixed(0)}-day cycle falls within the healthy range (21-35 days), indicating balanced hormonal function. ');
      } else if (averageLength < 21) {
        insights.writeln(
            'Your ${averageLength.toStringAsFixed(0)}-day cycle is shorter than typical. Continue tracking for 2-3 cycles to establish your personal pattern. ');
      } else {
        insights.writeln(
            'Your ${averageLength.toStringAsFixed(0)}-day cycle is longer than average, which can be normal but worth monitoring. ');
      }
      insights.writeln(
          'With ${entries.length} entries over $trackingDays days, you\'re building valuable data about your body\'s patterns.\n');
    } else {
      insights.writeln(
          'You\'re just starting your cycle tracking journey! Each entry helps build a clearer picture of your hormonal patterns and cycle regularity.\n');
    }

    // Symptom Analysis
    insights.writeln('**SYMPTOM INSIGHTS**');
    if (topSymptoms.isNotEmpty) {
      final mainSymptom = topSymptoms.first;
      insights.writeln(
          'Your most common symptom is ${mainSymptom.key} (${mainSymptom.value} times logged). ');

      // Symptom-specific advice
      switch (mainSymptom.key.toLowerCase()) {
        case 'cramps':
          insights.writeln(
              'For cramp management: try heat therapy, magnesium supplements, gentle yoga, and anti-inflammatory foods like ginger and leafy greens.');
          break;
        case 'mood swings':
          insights.writeln(
              'For mood balance: maintain stable blood sugar with regular meals, prioritize sleep, and consider stress-reduction techniques during your luteal phase.');
          break;
        case 'bloating':
          insights.writeln(
              'For bloating relief: reduce sodium intake 5-7 days before your period, stay hydrated, and include potassium-rich foods like bananas and spinach.');
          break;
        case 'fatigue':
          insights.writeln(
              'For energy support: ensure adequate iron and B-vitamin intake, maintain consistent sleep schedules, and consider lighter exercise during low-energy phases.');
          break;
        case 'headache':
          insights.writeln(
              'For headache prevention: track triggers like dehydration or hormonal drops, maintain consistent sleep, and consider magnesium supplementation.');
          break;
        default:
          insights.writeln(
              'Track when this symptom occurs in your cycle to identify patterns and develop targeted management strategies.');
      }

      if (topSymptoms.length > 1) {
        insights.writeln(
            ' You also frequently experience ${topSymptoms[1].key}, suggesting a pattern worth discussing with your healthcare provider.\n');
      } else {
        insights.writeln('\n');
      }
    } else {
      insights.writeln(
          'No symptoms logged yet. Consider tracking common symptoms like cramps, mood changes, or energy levels to gain deeper insights into your cycle patterns.\n');
    }

    // Personalized Recommendations
    insights.writeln('**PERSONALIZED RECOMMENDATIONS**');
    insights.writeln(
        '• **Continue Consistent Tracking**: Log periods and symptoms for at least 3 cycles to establish reliable patterns and predictions.');

    if (entries.length < 5) {
      insights.writeln(
          '• **Expand Symptom Tracking**: Include mood, energy levels, sleep quality, and appetite changes to understand your body\'s full cycle story.');
    }

    insights.writeln(
        '• **Lifestyle Optimization**: Plan important events around your high-energy phases (follicular/ovulation) and schedule self-care during your luteal phase.');

    if (symptomCounts.isNotEmpty) {
      insights.writeln(
          '• **Symptom Management**: Create a personalized toolkit based on your tracked symptoms - keep remedies ready before symptoms typically appear.');
    }

    if (averageLength < 21 || averageLength > 35) {
      insights.writeln(
          '• **Healthcare Consultation**: Consider discussing your cycle length with a healthcare provider to rule out any underlying conditions.');
    }

    // Future Predictions
    insights.writeln('\n**FUTURE TRACKING GOALS**');
    if (entries.length < 10) {
      insights.writeln(
          'With ${10 - entries.length} more entries, you\'ll have enough data for reliable period predictions and personalized health insights. ');
      insights.writeln(
          'By tracking for 3-6 months, you\'ll identify seasonal patterns, stress impacts, and optimize your lifestyle around your natural rhythms.');
    } else {
      insights.writeln(
          'You have excellent tracking data! Focus on identifying how external factors (stress, diet, exercise) influence your cycle patterns. ');
      insights.writeln(
          'Continue monitoring to detect any changes that might indicate hormonal shifts or health changes worth discussing with your doctor.');
    }

    return insights.toString();
  }

  List<Map<String, dynamic>> _analyzeMenstrualCycles(
      List<Map<String, dynamic>> entries,
      ) {
    final cycles = <Map<String, dynamic>>[];

    // Sort entries by date (oldest first) for proper cycle calculation
    entries.sort((a, b) {
      final dateA = DateTime.tryParse(a['timestamp'] ?? '') ?? DateTime.now();
      final dateB = DateTime.tryParse(b['timestamp'] ?? '') ?? DateTime.now();
      return dateA.compareTo(dateB);
    });

    DateTime? lastPeriodStart;

    for (var entry in entries) {
      final entryDate = DateTime.tryParse(entry['timestamp'] ?? '');
      if (entryDate == null) continue;

      int cycleDay = 1;
      if (entry['value'] == 'Period Start') {
        lastPeriodStart = entryDate;
        cycleDay = 1;
      } else if (lastPeriodStart != null) {
        cycleDay = entryDate.difference(lastPeriodStart).inDays + 1;
      }

      cycles.add({
        'date': entry['timestamp'],
        'cycleDay': cycleDay,
        'phase': _getCyclePhase(cycleDay),
        'symptoms': entry['symptoms'] ?? [],
        'value': entry['value'],
      });
    }

    return cycles;
  }

  String _getCyclePhase(int cycleDay) {
    if (cycleDay >= 1 && cycleDay <= 7) return 'Menstrual';
    if (cycleDay >= 8 && cycleDay <= 13) return 'Follicular';
    if (cycleDay >= 14 && cycleDay <= 16) return 'Ovulation';
    if (cycleDay >= 17 && cycleDay <= 28) return 'Luteal';
    return 'Unknown';
  }

  double _calculateAverageCycleLength(List<Map<String, dynamic>> cycles) {
    if (cycles.length < 2) return 28.0;

    final periodStarts = cycles
        .where((cycle) => cycle['value'] == 'Period Start')
        .map((cycle) => DateTime.tryParse(cycle['date']))
        .where((date) => date != null)
        .cast<DateTime>()
        .toList();

    if (periodStarts.length < 2) return 28.0;

    final cycleLengths = <int>[];
    for (int i = 1; i < periodStarts.length; i++) {
      final diff = periodStarts[i].difference(periodStarts[i - 1]).inDays;
      if (diff > 15 && diff < 50) {
        cycleLengths.add(diff);
      }
    }

    return cycleLengths.isEmpty
        ? 28.0
        : cycleLengths.reduce((a, b) => a + b) / cycleLengths.length;
  }

  DateTime? _predictNextPeriod(List<Map<String, dynamic>> cycles) {
    final periodStarts = cycles
        .where((cycle) => cycle['value'] == 'Period Start')
        .map((cycle) => DateTime.tryParse(cycle['date']))
        .where((date) => date != null)
        .cast<DateTime>()
        .toList();

    if (periodStarts.isEmpty) return null;

    periodStarts.sort();
    final lastPeriod = periodStarts.last;
    final averageLength = _calculateAverageCycleLength(cycles);
    return lastPeriod.add(Duration(days: averageLength.round()));
  }

  // BMI Calculator Methods
  void setHeightUnit(String unit) {
    _heightUnit = unit;
    notifyListeners();
  }

  void setWeightUnit(String unit) {
    _weightUnit = unit;
    notifyListeners();
  }

  // The comprehensive calculateBMI method, renamed to be distinct
  // from the public getter and to support all units.
  @override
  Future<double?> calculateBMI() async {
    try {
      double heightInMeters;
      double weightInKg;

      if (_heightUnit == 'Centimeters (cm)') {
        final heightCm = double.tryParse(_heightCmController.text);
        if (heightCm == null || heightCm <= 0) return null;
        heightInMeters = heightCm / 100;
      } else {
        final feet = double.tryParse(_heightFeetController.text) ?? 0;
        final inches = double.tryParse(_heightInchesController.text) ?? 0;
        if (feet <= 0 && inches <= 0) return null;
        heightInMeters = (feet * 0.3048) + (inches * 0.0254);
      }

      final weight = double.tryParse(_weightController.text);
      if (weight == null || weight <= 0) return null;

      if (_weightUnit == 'Pounds (lbs)') {
        weightInKg = weight * 0.453592;
      } else {
        weightInKg = weight;
      }

      final bmi = weightInKg / (heightInMeters * heightInMeters);
      _currentBMI = bmi;

      // Update label and color according to BMI category
      if (bmi < 18.5) {
        bmiStatusLabel = "Underweight";
        bmiStatusColor = Colors.blue;
      } else if (bmi < 25) {
        bmiStatusLabel = "Healthy";
        bmiStatusColor = Colors.green;
      } else if (bmi < 30) {
        bmiStatusLabel = "Overweight";
        bmiStatusColor = Colors.orange;
      } else {
        bmiStatusLabel = "Obese";
        bmiStatusColor = Colors.red;
      }

      await _saveBMIToFirebase(bmi);

      notifyListeners();
      return bmi;
    } catch (e) {
      debugPrint('Error calculating BMI: $e');
      return null;
    }
  }

  Future<void> _saveBMIToFirebase(double bmi) async {
    if (_currentUserId == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(_currentUserId)
          .collection('analytics_data')
          .doc('bmi_data')
          .set({
        'currentBMI': bmi,
        'heightUnit': _heightUnit,
        'weightUnit': _weightUnit,
        'heightCm': _heightCmController.text,
        'heightFeet': _heightFeetController.text,
        'heightInches': _heightInchesController.text,
        'weight': _weightController.text,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error saving BMI to Firebase: $e');
    }
  }

  Future<void> loadBMIData() async {
    if (_currentUserId == null) return;

    try {
      final doc = await _firestore
          .collection('users')
          .doc(_currentUserId)
          .collection('analytics_data')
          .doc('bmi_data')
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        _currentBMI = data['currentBMI']?.toDouble();
        _heightUnit = data['heightUnit'] ?? 'Centimeters (cm)';
        _weightUnit = data['weightUnit'] ?? 'Kilograms (kg)';
        _heightCmController.text = data['heightCm'] ?? '';
        _heightFeetController.text = data['heightFeet'] ?? '';
        _heightInchesController.text = data['heightInches'] ?? '';
        _weightController.text = data['weight'] ?? '';
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading BMI data: $e');
    }
  }

  // *** ADDED THIS HELPER METHOD ***
  String _getMealCategory(DateTime timestamp) {
    final hour = timestamp.hour;
    if (hour >= 5 && hour < 11) {
      // 5:00 AM - 10:59 AM
      return 'meal1';
    } else if (hour >= 11 && hour < 16) {
      // 11:00 AM - 3:59 PM
      return 'meal2';
    } else if (hour >= 16 && hour < 21) {
      // 4:00 PM - 8:59 PM
      return 'meal3';
    } else {
      // 9:00 PM - 4:59 AM
      return 'meal4';
    }
  }

  // *** REPLACE THIS ENTIRE FUNCTION ***
  Future<Map<String, dynamic>> getNutritionData(String timeframe) async {
    if (_currentUserId == null) return {};

    try {
      final startDate = _getTimeframeStartDate(timeframe);
      final nutritionEntries = await _getTrackerEntries('nutrition', startDate);
      print(
          '--- AnalyticsProvider: Processing ${nutritionEntries.length} nutrition entries for getNutritionData.');

      double totalCalories = 0;
      double totalProtein = 0;
      double totalCarbs = 0;
      double totalFat = 0;
      double totalFiber = 0; // Added fiber total

      // MODIFIED: This map will hold daily totals for macros
      final dailyMacroGrams = <String, Map<String, double>>{};

      for (var entry in nutritionEntries) {
        final calories =
            double.tryParse(entry['calories']?.toString() ?? '0') ?? 0.0;
        final protein =
            double.tryParse(entry['protein']?.toString() ?? '0') ?? 0.0;
        final carbs =
            double.tryParse(entry['carbs']?.toString() ?? '0') ?? 0.0;
        final fat = double.tryParse(entry['fat']?.toString() ?? '0') ?? 0.0;
        final fiber =
            double.tryParse(entry['fiber']?.toString() ?? '0') ?? 0.0; // Added fiber

        totalCalories += calories;
        totalProtein += protein;
        totalCarbs += carbs;
        totalFat += fat;
        totalFiber += fiber; // Added fiber

        final timestamp = DateTime.tryParse(entry['timestamp'] ?? '');
        if (timestamp != null) {
          final date = timestamp.toIso8601String().split('T')[0];

          // Initialize the map for the day if it doesn't exist
          dailyMacroGrams.putIfAbsent(
              date,
                  () =>
              {'protein': 0.0, 'carbs': 0.0, 'fat': 0.0, 'fiber': 0.0});

          // Add grams to the correct macro category
          dailyMacroGrams[date]!['protein'] =
              (dailyMacroGrams[date]!['protein'] ?? 0.0) + protein;
          dailyMacroGrams[date]!['carbs'] =
              (dailyMacroGrams[date]!['carbs'] ?? 0.0) + carbs;
          dailyMacroGrams[date]!['fat'] =
              (dailyMacroGrams[date]!['fat'] ?? 0.0) + fat;
          dailyMacroGrams[date]!['fiber'] =
              (dailyMacroGrams[date]!['fiber'] ?? 0.0) + fiber;
        }
      }

      // Calculate average calories based on unique days with entries
      final uniqueDaysWithEntries = dailyMacroGrams.keys.toSet().length;
      final averageCalories = (uniqueDaysWithEntries > 0)
          ? (totalCalories / uniqueDaysWithEntries)
          : 0.0;

      return {
        'totalCalories': totalCalories,
        'dailyAverage': averageCalories, // This is still daily avg CALORIES
        'protein': totalProtein,
        'carbs': totalCarbs,
        'fat': totalFat,
        'fiber': totalFiber,
        'dailyMacroGrams': dailyMacroGrams, // MODIFIED: Pass new map
        'entries': nutritionEntries.length,
      };
    } catch (e) {
      debugPrint('Error getting nutrition data: $e');
      return {};
    }
  }

  Future<Map<String, dynamic>> getEnhancedProgressData(String tracker) async {
    final progressData = _progressData[tracker];
    if (progressData == null) return {};

    try {
      final geminiApiKey = dotenv.env['GEMINI_API_KEY'];
      if (geminiApiKey != null && geminiApiKey.isNotEmpty) {
        final model =
        GenerativeModel(model: 'gemini-pro', apiKey: geminiApiKey);

        final prompt = '''
Analyze this progress data for $tracker and provide insights:

Timeframe: $_selectedTimeframe
This week entries: ${progressData['thisWeek']?.length ?? 0}
Last week entries: ${progressData['lastWeek']?.length ?? 0}
Total entries: ${progressData['total'] ?? 0}
Average value: ${progressData['average']?.toStringAsFixed(1) ?? '0'}

Provide a brief analysis (2-3 sentences) about the progress trends and a practical recommendation.
''';

        final response = await model.generateContent([Content.text(prompt)]);
        final insights = response.text ?? 'No insights available';

        return {
          ...progressData,
          'insights': insights,
          'trend': _calculateTrend(progressData),
        };
      }
    } catch (e) {
      debugPrint('Error generating progress insights: $e');
    }

    return progressData;
  }

  String _calculateTrend(Map<String, dynamic> progressData) {
    final thisWeek = progressData['thisWeekAvg'] ?? 0;
    final lastWeek = progressData['lastWeekAvg'] ?? 0;

    if (thisWeek > lastWeek * 1.1) return 'improving';
    if (thisWeek < lastWeek * 0.9) return 'declining';
    return 'stable';
  }

  // Method to force refresh all data (useful for debugging)
  Future<void> forceRefreshAllData() async {
    _cachedInsights = null;
    _lastInsightsUpdate = null;
    await loadPeriodData(forceRefresh: true);
    if (_selectedTrackers.isNotEmpty) {
      await loadTrackerData();
    }
  }

  void clearAllData() {
    _selectedTrackers.clear();
    _trackerData.clear();
    _periodData.clear();
    _progressData.clear();
    _correlationResults.clear();
    _cachedInsights = null;
    _lastInsightsUpdate = null;
    _selectedPeriodDate = null;
    _selectedSymptoms.clear();
    _isLoggingPeriod = false;
    _isLoadingPeriodData = false;
    notifyListeners();
  }
}

//
// -----------------------------------------------------------------
// ProgressOverviewPage starts here
// -----------------------------------------------------------------
//

class ProgressOverviewPage extends StatefulWidget {
  const ProgressOverviewPage({Key? key}) : super(key: key);

  @override
  State<ProgressOverviewPage> createState() => _ProgressOverviewPageState();
}

class _ProgressOverviewPageState extends State<ProgressOverviewPage> {
  String _selectedNutritionTimeframe = 'This Week';
  Map<String, dynamic> _nutritionData = {};
  bool _isLoadingNutrition = false;
  List<String> selectedTrackers = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadNutritionData();
      context.read<AnalyticsProvider>().loadProgressData();
    });
  }

  Future<void> _loadNutritionData() async {
    setState(() => _isLoadingNutrition = true);
    try {
      final provider = context.read<AnalyticsProvider>();
      final data = await provider.getNutritionData(_selectedNutritionTimeframe);
      if (mounted) {
        setState(() {
          _nutritionData = data ?? {};
          _isLoadingNutrition = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _nutritionData = {};
          _isLoadingNutrition = false;
        });
      }
    }
  }

  BoxDecoration _getCardDecoration(bool isDarkTheme) {
    if (isDarkTheme) {
      return BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color.fromRGBO(40, 50, 49, 0.85),
            const Color.fromARGB(215, 14, 14, 14),
            const Color.fromRGBO(33, 43, 42, 0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: const [0.0, 0.5, 1.0],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.textSecondary(isDarkTheme).withOpacity(0.8),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.textSecondary(isDarkTheme).withOpacity(0.15),
            blurRadius: 12,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
      );
    } else {
      return BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.cardBackground(isDarkTheme).withOpacity(0.95),
            AppColors.cardBackground(isDarkTheme).withOpacity(0.90),
            AppColors.cardBackground(isDarkTheme).withOpacity(0.95),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: const [0.0, 0.5, 1.0],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.textSecondary(isDarkTheme).withOpacity(0.6),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.textSecondary(isDarkTheme).withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AnalyticsProvider>(
      builder: (context, provider, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // SECTION 1: Progress Overview
              _buildSectionHeader(
                  'Progress Overview', isDark, lucide.LucideIcons.trendingUp),
              const SizedBox(height: 12),

              _buildNutritionCard(provider, isDark),
              const SizedBox(height: 16),

              _buildTimeframeSelector(provider, isDark),
              const SizedBox(height: 16),

              if (provider.selectedTrackers.isNotEmpty) ...[
                ...provider.selectedTrackers.map((tracker) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child:
                    _buildTrackerProgressCard(tracker, provider, isDark),
                  );
                }).toList(),
              ],

              const SizedBox(height: 32),

              // SECTION 2: Correlation Insights
              _buildSectionHeader(
                  'Correlation Insights', isDark, lucide.LucideIcons.activity),
              const SizedBox(height: 12),

              _buildTrackerSelectionCard(provider, isDark),
              const SizedBox(height: 16),

              if (selectedTrackers.length >= 2) ...[
                _buildAnalyzeButton(provider, isDark),
                const SizedBox(height: 16),
              ],

              if (provider.isLoadingCorrelations) ...[
                _buildLoadingCard(isDark),
                const SizedBox(height: 16),
              ],

              if (provider.correlationResults.isNotEmpty &&
                  !provider.isLoadingCorrelations) ...[
                _buildCorrelationResults(provider, isDark),
              ],

              if (selectedTrackers.length < 2 &&
                  provider.correlationResults.isEmpty) ...[
                _buildInstructionCard(isDark),
              ],

              const SizedBox(height: 100),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, bool isDark, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          color: const Color(0xFF26A69A),
          size: 24,
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary(isDark),
          ),
        ),
      ],
    );
  }

  Widget _buildNutritionCard(AnalyticsProvider provider, bool isDark) {
    final totalCalories = _nutritionData['totalCalories']?.toDouble() ?? 0;
    final dailyAverage = _nutritionData['dailyAverage']?.toDouble() ?? 0;
    final dailyMacroGrams =
        _nutritionData['dailyMacroGrams'] as Map<String, dynamic>? ??
            <String, dynamic>{};
    final entries = _nutritionData['entries'] ?? 0;

    // --- LOGIC MOVED HERE ---
    // We calculate the max value here so we can pass it to the Y-axis, Grid, and Chart
    final now = DateTime.now();
    final startOfWeek = _selectedNutritionTimeframe == 'This Week'
        ? now.subtract(Duration(days: now.weekday - 1))
        : now.subtract(Duration(days: now.weekday + 6));

    final days = List.generate(7, (index) {
      final date = startOfWeek.add(Duration(days: index));
      return date.toIso8601String().split('T')[0];
    });

    final values = days.map((date) {
      final macroData = dailyMacroGrams[date] as Map<String, dynamic>?;
      if (macroData == null) {
        return {'protein': 0.0, 'carbs': 0.0, 'fat': 0.0, 'fiber': 0.0};
      }
      return {
        'protein': (macroData['protein'] as num?)?.toDouble() ?? 0.0,
        'carbs': (macroData['carbs'] as num?)?.toDouble() ?? 0.0,
        'fat': (macroData['fat'] as num?)?.toDouble() ?? 0.0,
        'fiber': (macroData['fiber'] as num?)?.toDouble() ?? 0.0,
      };
    }).toList();

    final maxValue = values.isEmpty
        ? 1.0
        : values
        .map((dayMacros) =>
    dayMacros['protein']! +
        dayMacros['carbs']! +
        dayMacros['fat']! +
        dayMacros['fiber']!)
        .reduce((a, b) => a > b ? a : b);

    final chartMaxValue = maxValue == 0 ? 50.0 : maxValue * 1.2;
    // --- END OF MOVED LOGIC ---

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _getCardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row (Unchanged)
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.textSecondary(isDark).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  lucide.LucideIcons.utensils,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Nutrition',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary(isDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Timeframe chips (Unchanged)
          Text(
            'Calorie intake for:',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary(isDark),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildTimeFrameChip(
                'This Week',
                _selectedNutritionTimeframe == 'This Week',
                isDark,
                    () {
                  setState(() => _selectedNutritionTimeframe = 'This Week');
                  _loadNutritionData();
                },
              ),
              const SizedBox(width: 8),
              _buildTimeFrameChip(
                'Last Week',
                _selectedNutritionTimeframe == 'Last Week',
                isDark,
                    () {
                  setState(() => _selectedNutritionTimeframe = 'Last Week');
                  _loadNutritionData();
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          _isLoadingNutrition
              ? _buildNutritionLoading(isDark)
              : Column(
            children: [
              // Total Calories and Daily Avg (Unchanged)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          totalCalories.toInt().toString(),
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary(isDark),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Total calories',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary(isDark),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dailyAverage.toInt().toString(),
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary(isDark),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Daily avg.',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary(isDark),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // --- MODIFIED CHART SECTION ---
              SizedBox(
                height: 120, // Height for chart + X-axis labels
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // 1. Y-AXIS
                    _buildYAxis(chartMaxValue, isDark),
                    const SizedBox(width: 8),
                    // 2. CHART (with grid lines behind it)
                    Expanded(
                      child: Stack(
                        children: [
                          // NEW: Grid lines
                          _buildGridLines(chartMaxValue, isDark),

                          // ✅ --- ADDED X AND Y AXIS LINES ---
                          // Y-Axis Line
                          Positioned(
                            left: 0,
                            top: 0,
                            bottom: 24, // Space for X-axis labels
                            child: Container(width: 1, color: Colors.black.withOpacity(0.5)),
                          ),
                          // X-Axis Line
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 24, // Space for X-axis labels
                            child: Container(height: 1, color: Colors.black.withOpacity(0.5)),
                          ),
                          // --- END OF FIX ---

                          // The bars
                          _buildWeeklyChart(
                            days: days,
                            values: values,
                            chartMaxValue: chartMaxValue,
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // --- END OF MODIFIED SECTION ---

              const SizedBox(height: 16),
              _buildLegend(isDark),
              const SizedBox(height: 20),
              if (entries == 0) _buildNoNutritionData(isDark),
            ],
          ),
        ],
      ),
    );
  }

  // --- ADD THIS NEW WIDGET ---
  Widget _buildGridLines(double chartMaxValue, bool isDark) {
    const double chartHeight = 80.0;
    const double bottomPadding = 40.0; // Total space at bottom for labels
    const double barBottom = 24.0; // Actual space for text below bar
    List<Widget> lines = [];

    // --- Horizontal Lines ---
    lines.add(
      Positioned(
        bottom: barBottom, // Align with the bottom of the bar
        left: 0,
        right: 0,
        child: Container(height: 1, color: Colors.grey[300]),
      ),
    );

    double increment = 1000;
    if (chartMaxValue < 100)
      increment = 25;
    else if (chartMaxValue < 500)
      increment = 100;
    else if (chartMaxValue < 2000) increment = 500;

    for (double i = increment; i <= chartMaxValue; i += increment) {
      double bottom = ((i / chartMaxValue) * chartHeight) + barBottom;
      if (bottom > (chartHeight + barBottom)) continue;
      lines.add(
        Positioned(
          bottom: bottom,
          left: 0,
          right: 0,
          child: Container(height: 1, color: Colors.grey[300]),
        ),
      );
    }

    // --- Vertical Lines ---
    lines.add(
      Positioned(
        bottom: barBottom,
        top: 120 -
            (chartHeight + barBottom), // 120 (total) - 80 (bar) - 24 (text)
        left: 0,
        right: 0,
        child: Row(
          children: List.generate(7, (index) {
            return Expanded(
              child: (index == 6)
                  ? const SizedBox() // Don't draw line after last day
                  : Container(
                alignment: Alignment.centerRight,
                child: Container(width: 1, color: Colors.grey[300]),
              ),
            );
          }),
        ),
      ),
    );

    return Stack(children: lines);
  }

  // --- ADD THIS NEW WIDGET ---
  // --- REPLACE THIS WIDGET ---
  Widget _buildYAxis(double chartMaxValue, bool isDark) {
    const double chartHeight = 80.0;
    const double yAxisWidth = 30.0;
    const double bottomPadding = 24.0; // Space for X-axis labels

    List<Widget> labels = [];

    // Add "0" label
    labels.add(
      Positioned(
        bottom: bottomPadding, // Align with the bottom of the bar
        right: 0,
        child: Text(
          '0',
          style: TextStyle(
            fontSize: 12, // <-- FONT SIZE INCREASED
            color: AppColors.textSecondary(isDark),
          ),
        ),
      ),
    );

    double increment = 1000;
    if (chartMaxValue < 100)
      increment = 25;
    else if (chartMaxValue < 500)
      increment = 100;
    else if (chartMaxValue < 2000) increment = 500;

    for (double i = increment; i <= chartMaxValue; i += increment) {
      // Calculate position relative to the bar's height
      double bottom = ((i / chartMaxValue) * chartHeight) + bottomPadding;

      if (bottom > (chartHeight + bottomPadding) ||
          bottom < (bottomPadding + 15)) continue;

      labels.add(
        Positioned(
          bottom: bottom - 6, // Adjust to center the text
          right: 0,
          child: Text(
            '${i.toInt()}',
            style: TextStyle(
              fontSize: 12, // <-- FONT SIZE INCREASED
              color: AppColors.textSecondary(isDark),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: yAxisWidth,
      height: 120, // Must match _buildWeeklyChart height
      child: Stack(
        children: labels,
      ),
    );
  }

  Widget _buildLegend(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLegendItem('Protein', Colors.amber, isDark),
        _buildLegendItem('Carbs', const Color(0xFF28A745), isDark),
        _buildLegendItem('Fat', Colors.blue, isDark),
        _buildLegendItem('Fiber', const Color(0xFFE37F4A), isDark),
      ],
    );
  }

  // *** ADDED ***: Legend item helper
  Widget _buildLegendItem(String label, Color color, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary(isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeFrameChip(
      String label,
      bool isSelected,
      bool isDark,
      VoidCallback onTap,
      ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.textPrimary(isDark)
              : AppColors.cardBackground(isDark),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppColors.textSecondary(isDark).withOpacity(0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color:
            isSelected ? Colors.white : AppColors.textSecondary(isDark),
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildNutritionLoading(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: CircularProgressIndicator(
          color:
          isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
        ),
      ),
    );
  }

  // --- REPLACE THIS WIDGET ---
  Widget _buildWeeklyChart({
    required List<String> days,
    required List<Map<String, double>> values,
    required double chartMaxValue,
    required bool isDark,
  }) {
    return Container(
      height: 120, // Must match _buildYAxis height
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: days.asMap().entries.map((entry) {
          final index = entry.key;
          final dayMacros = values[index];
          // Total value is now total grams
          final totalValue = dayMacros['protein']! +
              dayMacros['carbs']! +
              dayMacros['fat']! +
              dayMacros['fiber']!;

          return Flexible(
            child: _buildDayColumn(
              ['S', 'M', 'T', 'W', 'T', 'F', 'S'][index],
              dayMacros, // Pass the map of macros
              totalValue,
              isDark,
              chartMaxValue,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDayColumn(String day, Map<String, double> dayMacros,
      double totalValue, bool isDark, double chartMaxValue) {
    const double chartHeight = 80.0; // Max height of the bar itself

    // Define macro colors (from your NutritionScannerScreen)
    const proteinColor = Colors.amber;
    const carbsColor = Color(0xFF28A745); // kSuccessColor
    const fatColor = Colors.blue;
    const fiberColor = Color(0xFFE37F4A);

    // Calculate individual heights
    final double proteinHeight = chartMaxValue > 0
        ? (dayMacros['protein']! / chartMaxValue) * chartHeight
        : 0;
    final double carbsHeight = chartMaxValue > 0
        ? (dayMacros['carbs']! / chartMaxValue) * chartHeight
        : 0;
    final double fatHeight = chartMaxValue > 0
        ? (dayMacros['fat']! / chartMaxValue) * chartHeight
        : 0;
    final double fiberHeight = chartMaxValue > 0
        ? (dayMacros['fiber']! / chartMaxValue) * chartHeight
        : 0;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 16,
          height: chartHeight,
          decoration: BoxDecoration(
            color: Colors.transparent, // <-- FIX: Make it transparent
            borderRadius: BorderRadius.circular(4),
          ),
          child: ClipRRect(
            // Clip to maintain border radius
            borderRadius: BorderRadius.circular(4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Stacked from bottom to top
                Container(
                    height: proteinHeight.clamp(0, chartHeight),
                    color: proteinColor),
                Container(
                    height: carbsHeight.clamp(0, chartHeight),
                    color: carbsColor),
                Container(
                    height: fatHeight.clamp(0, chartHeight), color: fatColor),
                Container(
                    height: fiberHeight.clamp(0, chartHeight),
                    color: fiberColor),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          day,
          style: TextStyle(
            fontSize: 10,
            color: AppColors.textSecondary(isDark),
          ),
        ),


      ],
    );
  }

  Widget _buildNoNutritionData(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.textSecondary(isDark).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No nutrition data found.',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary(isDark),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Log your meals to see nutrition insights here.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary(isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeframeSelector(AnalyticsProvider provider, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: _getCardDecoration(isDark),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: provider.selectedTimeframe,
          isExpanded: true,
          icon: Icon(
            lucide.LucideIcons.chevronDown,
            color: isDark
                ? AppColors.darkTextPrimary
                : AppColors.lightTextPrimary,
          ),
          style: TextStyle(
            color: AppColors.textPrimary(isDark),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          dropdownColor: AppColors.cardBackground(isDark),
          items: provider.timeframes.map((String timeframe) {
            return DropdownMenuItem<String>(
              value: timeframe,
              child: Text(
                timeframe,
                style: const TextStyle(
                  fontSize: 12,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            );
          }).toList(),
          onChanged: (String? newValue) {
            if (newValue != null) {
              provider.setSelectedTimeframe(newValue);
            }
          },
        ),
      ),
    );
  }

  Widget _buildTrackerProgressCard(
      String tracker,
      AnalyticsProvider provider,
      bool isDark,
      ) {
    return FutureBuilder<Map<String, dynamic>>(
      future: provider.getEnhancedProgressData(tracker),
      builder: (context, snapshot) {
        final progressData =
            snapshot.data ?? provider.progressData[tracker] ?? {};
        final thisWeekData = progressData['thisWeek'] ?? [];
        final lastWeekData = progressData['lastWeek'] ?? [];
        final average = (progressData['average'] ?? 0.0).toDouble();
        final total = progressData['total'] ?? 0;
        final insights = progressData['insights'] ?? '';
        final trend = progressData['trend'] ?? 'stable';

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: _getCardDecoration(isDark),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.textSecondary(isDark)
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            _getTrackerIcon(tracker),
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            tracker,
                            // ✅ --- RESPONSIVE FIX ---
                            softWrap: true,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary(isDark),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (trend != 'stable') ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.textSecondary(isDark)
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        trend == 'improving' ? '↗ Improving' : '↘ Declining',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: _buildProgressStat(
                      'This Week',
                      thisWeekData.length.toString(),
                      'entries',
                      isDark,
                    ),
                  ),
                  Flexible(
                    child: _buildProgressStat(
                      'Last Week',
                      lastWeekData.length.toString(),
                      'entries',
                      isDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: _buildProgressStat(
                      'Total',
                      total.toString(),
                      'entries',
                      isDark,
                    ),
                  ),
                  Flexible(
                    child: _buildProgressStat(
                      'Average',
                      average.toStringAsFixed(1),
                      _getTrackerUnit(tracker),
                      isDark,
                    ),
                  ),
                ],
              ),
              if (thisWeekData.isNotEmpty || lastWeekData.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildProgressChart(thisWeekData, lastWeekData, isDark),
              ],
              if (insights.isNotEmpty &&
                  snapshot.connectionState == ConnectionState.done) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                    AppColors.textSecondary(isDark).withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.textSecondary(isDark)
                          .withOpacity(0.1),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        lucide.LucideIcons.lightbulb,
                        size: 16,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          insights,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary(isDark),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildProgressStat(
      String label,
      String value,
      String unit,
      bool isDark,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: AppColors.textSecondary(isDark),
          ),
        ),
        const SizedBox(height: 4),
        RichText(
          text: TextSpan(
            text: value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary(isDark),
            ),
            children: [
              TextSpan(
                text: ' $unit',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.normal,
                  color: AppColors.textSecondary(isDark),
                ),
              ),
            ],
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildProgressChart(
      List<dynamic> thisWeekData,
      List<dynamic> lastWeekData,
      bool isDark,
      ) {
    final maxY = [thisWeekData.length, lastWeekData.length, 10]
        .reduce((a, b) => a > b ? a : b)
        .toDouble();

    return Container(
      height: 100,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY,
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            show: true,
            rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  switch (value.toInt()) {
                    case 0:
                      return Text(
                        'Last Week',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary(isDark),
                        ),
                      );
                    case 1:
                      return Text(
                        'This Week',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary(isDark),
                        ),
                      );
                    default:
                      return const Text('');
                  }
                },
              ),
            ),
            leftTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          barGroups: [
            BarChartGroupData(
              x: 0,
              barRods: [
                BarChartRodData(
                  toY: lastWeekData.length.toDouble(),
                  color: AppColors.textSecondary(isDark).withOpacity(0.5),
                  width: 16,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
            BarChartGroupData(
              x: 1,
              barRods: [
                BarChartRodData(
                  toY: thisWeekData.length.toDouble(),
                  color: AppColors.textPrimary(isDark),
                  width: 16,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // CORRELATION SECTION WIDGETS
  Widget _buildTrackerSelectionCard(AnalyticsProvider provider, bool isDark) {
    return Container(
      decoration: _getCardDecoration(isDark),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // ✅ --- RESPONSIVE FIX ---
              Flexible(
                child: Text(
                  'Select Trackers to Compare',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary(isDark),
                  ),
                ),
              ),
              const Spacer(),
              _buildDetailChip(
                '${selectedTrackers.length} selected',
                selectedTrackers.length >= 2
                    ? Icons.check_circle
                    : Icons.warning,
                isDark,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Minimum 2 trackers required for correlation analysis',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary(isDark),
            ),
          ),
          const SizedBox(height: 16),
          ...provider.availableTrackers.map((tracker) {
            final isSelected = selectedTrackers.contains(tracker);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.black.withOpacity(0.1)
                    : AppColors.inputFill(isDark),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? AppColors.black
                      : AppColors.borderColor(isDark),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: CheckboxListTile(
                title: Text(
                  tracker,
                  style: TextStyle(
                    color: AppColors.textPrimary(isDark),
                    fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 14,
                  ),
                ),
                value: isSelected,
                onChanged: (bool? value) {
                  setState(() {
                    if (value == true) {
                      selectedTrackers.add(tracker);
                    } else {
                      selectedTrackers.remove(tracker);
                    }
                  });
                },
                activeColor: AppColors.black,
                checkColor: Colors.white,
                controlAffinity: ListTileControlAffinity.trailing,
                dense: true,
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildDetailChip(String text, IconData icon, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.black.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: isDark
                ? AppColors.darkTextPrimary
                : AppColors.lightTextPrimary,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: isDark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyzeButton(AnalyticsProvider provider, bool isDark) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: provider.isLoadingCorrelations
            ? null
            : () async {
          for (String tracker
          in List.from(provider.selectedTrackers)) {
            provider.toggleTrackerSelection(tracker);
          }
          for (String tracker in selectedTrackers) {
            provider.toggleTrackerSelection(tracker);
          }
          await provider.analyzeCorrelations();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.black,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 3,
          shadowColor: AppColors.black.withOpacity(0.4),
        ),
        child: provider.isLoadingCorrelations
            ? Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor:
                AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            const Text('Analyzing Correlations...',
                style: TextStyle(fontSize: 16)),
          ],
        )
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.analytics,
              size: 20,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            const Text('Analyze Correlations',
                style: TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingCard(bool isDark) {
    return Container(
      decoration: _getCardDecoration(isDark),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.black),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Analyzing Your Data',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary(isDark),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Our AI is discovering patterns and correlations in your tracked data...',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary(isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCorrelationResults(AnalyticsProvider provider, bool isDark) {
    return Container(
      decoration: _getCardDecoration(isDark),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                lucide.LucideIcons.activity,
                color: const Color(0xFF26A69A),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Correlation Analysis Results',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary(isDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Based on your ${provider.selectedTimeframe.toLowerCase()} data',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary(isDark),
            ),
          ),
          const SizedBox(height: 16),
          if (provider.correlationResults.isNotEmpty) ...[
            ...provider.correlationResults.map((correlation) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildCorrelationItem(correlation, isDark),
              );
            }).toList(),
          ] else ...[
            _buildNoCorrelationsFound(isDark),
          ],
        ],
      ),
    );
  }

  Widget _buildCorrelationItem(
      Map<String, dynamic> correlation, bool isDark) {
    final double correlationValue = correlation['correlation'] ?? 0.0;
    final String strength = correlation['strength'] ?? 'Very Weak';
    final String insight =
        correlation['insight'] ?? 'No specific insight available.';
    final int dataPoints = correlation['dataPoints'] ?? 0;

    Color strengthColor;
    IconData strengthIcon;

    switch (strength) {
      case 'Strong':
        strengthColor = AppColors.successColor;
        strengthIcon = Icons.trending_up;
        break;
      case 'Moderate':
        strengthColor = AppColors.warningColor;
        strengthIcon = Icons.trending_flat;
        break;
      case 'Weak':
        strengthColor = AppColors.black;
        strengthIcon = Icons.trending_down;
        break;
      default:
        strengthColor = AppColors.textSecondary(isDark);
        strengthIcon = Icons.remove;
    }

    final bool isPositive = correlationValue > 0;
    final String directionText = isPositive ? 'Positive' : 'Negative';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.black.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border:
        Border.all(color: strengthColor.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ✅ --- RESPONSIVE FIX: Changed Row to Wrap ---
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 8.0, // Adds space if the chip wraps
            children: [
              Text(
                '${correlation['tracker1']} ↔ ${correlation['tracker2']}',
                softWrap: true,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary(isDark),
                ),
              ),
              _buildDetailChip(
                strength,
                strengthIcon,
                isDark,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Correlation: ${correlationValue.toStringAsFixed(3)}',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary(isDark),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 12),
              _buildDetailChip(
                directionText,
                isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                isDark,
              ),
              // ✅ --- RESPONSIVE FIX: Replaced Spacer with Flexible Text ---
              Flexible(
                child: Text(
                  '$dataPoints data points',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary(isDark),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.black.withOpacity(0.1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      lucide.LucideIcons.activity,
                      color: const Color(0xFF26A69A),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        insight,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary(isDark),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (correlation['trend'] != null)
                  Text(
                    'Trend: ${correlation['trend']}',
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: AppColors.textSecondary(isDark),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoCorrelationsFound(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            lucide.LucideIcons.searchX,
            size: 64,
            color: isDark
                ? AppColors.darkTextSecondary.withOpacity(0.5)
                : AppColors.lightTextSecondary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No Significant Correlations Found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary(isDark),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This could mean:\n• Your data points are independent\n• You need more data for meaningful analysis\n• Try selecting different trackers or a longer timeframe',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary(isDark),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionCard(bool isDark) {
    return Container(
      decoration: _getCardDecoration(isDark),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(
            lucide.LucideIcons.info,
            size: 64,
            color: isDark
                ? AppColors.darkTextSecondary.withOpacity(0.5)
                : AppColors.lightTextSecondary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Select at least 2 trackers',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary(isDark),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose multiple trackers above to discover meaningful correlations and patterns in your data.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary(isDark),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getTrackerIcon(String tracker) {
    switch (tracker) {
      case 'Sleep Tracker':
        return lucide.LucideIcons.moon;
      case 'Mood Tracker':
        return lucide.LucideIcons.smile;
      case 'Meditation Tracker':
        return lucide.LucideIcons.zap;
      case 'Expense Tracker':
        return lucide.LucideIcons.dollarSign;
      case 'Savings Tracker':
        return lucide.LucideIcons.piggyBank;
      case 'Alcohol Tracker':
        return lucide.LucideIcons.wine;
      case 'Study Time Tracker':
        return lucide.LucideIcons.bookOpen;
      case 'Mental Well-being Tracker':
        return lucide.LucideIcons.brain;
      case 'Workout Tracker':
        return lucide.LucideIcons.dumbbell;
      case 'Weight Tracker':
        return lucide.LucideIcons.scale;
      case 'Menstrual Cycle':
        return lucide.LucideIcons.calendar;
      default:
        return lucide.LucideIcons.activity;
    }
  }

  String _getTrackerUnit(String tracker) {
    switch (tracker) {
      case 'Sleep Tracker':
        return 'hours';
      case 'Mood Tracker':
        return '/10';
      case 'Weight Tracker':
        return 'kg';
      case 'Study Time Tracker':
        return 'hours';
      case 'Workout Tracker':
        return 'mins';
      default:
        return 'value';
    }
  }
}