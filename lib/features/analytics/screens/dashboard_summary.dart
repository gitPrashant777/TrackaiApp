import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:trackai/core/constants/appcolors.dart';
import 'package:trackai/core/themes/theme_provider.dart';
import 'package:trackai/features/analytics/screens/progress_overview.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart' as lucide;
import 'dart:math' as math; // For BMI indicator positioning

class DashboardSummaryPage extends StatefulWidget {
  const DashboardSummaryPage({Key? key}) : super(key: key);

  @override
  State<DashboardSummaryPage> createState() => _DashboardSummaryPageState();
}

class _DashboardSummaryPageState extends State<DashboardSummaryPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // --- NEW STATE FOR RECOMMENDATIONS ---
  String? _recommendation;
  String? _healthyWeightRange;
  // --- END NEW STATE ---

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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
          color: AppColors.primary(isDarkTheme).withOpacity(0.8),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary(isDarkTheme).withOpacity(0.15),
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
          color: AppColors.primary(isDarkTheme).withOpacity(0.6),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary(isDarkTheme).withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
      );
    }
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> options,
    required bool isDarkTheme,
    required Function(String?) onChanged,
    bool isLightForced = false, // --- NEW: To force light theme
  }) {
    final Color primaryText = isLightForced
        ? Colors.black
        : AppColors.textPrimary(isDarkTheme);
    final Color secondaryText = isLightForced
        ? Colors.grey[600]!
        : AppColors.textSecondary(isDarkTheme);
    final Color inputFill = isLightForced
        ? Colors.white
        : AppColors.inputFill(isDarkTheme);
    final Color borderColor = isLightForced
        ? Colors.grey[300]!
        : AppColors.borderColor(isDarkTheme);
    final Color focusedBorderColor = isLightForced ? Colors.black : (isDarkTheme ? Colors.white : Colors.black);
    final Color dropdownBg = isLightForced
        ? Colors.grey[50]!
        : (isDarkTheme ? AppColors.darkCardBackground : Colors.grey[50]!);


    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12, // MODIFIED: Reduced font size
            fontWeight: FontWeight.w500,
            color: primaryText,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          onChanged: onChanged,
          style: TextStyle(
            color: primaryText,
            fontSize: 12, // MODIFIED: Reduced font size
          ),
          dropdownColor: dropdownBg,
          decoration: InputDecoration(
            filled: true,
            fillColor: inputFill,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: borderColor,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: borderColor,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: focusedBorderColor,
                width: 1.5,
              ),
            ),
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 12), // MODIFIED: Reduced padding
          ),
          items: options.map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(
                value,
                style: TextStyle(
                  color: primaryText,
                  fontSize: 12, // MODIFIED: Reduced font size
                ),
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // --- Helper for TextFormFields in light theme ---
  Widget _buildTextFormField({
    required String label,
    required TextEditingController controller,
    required String hintText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12, // MODIFIED: Reduced font size
            fontWeight: FontWeight.w500,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(
              color: Colors.grey[500],
              fontSize: 12, // MODIFIED: Reduced font size
            ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Colors.grey[300]!,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Colors.grey[300]!,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: Colors.black,
                width: 1.5,
              ),
            ),
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 12), // MODIFIED: Reduced padding
          ),
          style: const TextStyle(
            color: Colors.black,
            fontSize: 12, // MODIFIED: Reduced font size
          ),
        ),
      ],
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
            color:
            isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
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

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDark = themeProvider.isDarkMode;

        return Scaffold(
          backgroundColor: AppColors.background(isDark),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: AppColors.cardLinearGradient(isDark),
              ),
            ),
            automaticallyImplyLeading: false,
            toolbarHeight: 0,
          ),
          body: Container(
            decoration: BoxDecoration(
              gradient: AppColors.backgroundLinearGradient(isDark),
            ),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Consumer<AnalyticsProvider>(
                    builder: (context, provider, child) {
                      // ---
                      // --- UPDATED BUILD LOGIC ---
                      // ---
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildConfigureButton(context, provider, isDark),
                          const SizedBox(height: 20),

                          // Tracker Charts (Conditional)
                          if (provider.selectedTrackers.isNotEmpty)
                            _buildCustomDashboardSection(
                                context, provider, isDark)
                          else
                            _buildEmptyState(context, isDark),

                          const SizedBox(height: 24),

                          // Summary (Always Shows)
                          _buildOverallSummaryCard(context, provider, isDark),
                          const SizedBox(height: 24),

                          // BMI Calculator (Always Shows)
                          _buildNewBmiCalculator(context, provider),

                          const SizedBox(height: 100),
                        ],
                      );
                      // ---
                      // --- END UPDATED BUILD LOGIC ---
                      // ---
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildConfigureButton(
      BuildContext context,
      AnalyticsProvider provider,
      bool isDark,
      ) {
    return Container(
      width: double.infinity,
      decoration: _getCardDecoration(isDark),
      child: InkWell(
        onTap: () => _showConfigureDashboard(context, provider, isDark),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                lucide.LucideIcons.slidersHorizontal,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Configure Dashboard',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary(isDark),
                ),
              ),
              const Spacer(),
              Icon(
                Icons.arrow_forward_ios,
                color: AppColors.textSecondary(isDark),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: _getCardDecoration(isDark),
      child: Column(
        children: [
          Icon(
            lucide.LucideIcons.activity,
            color: AppColors.textSecondary(isDark).withOpacity(0.5),
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            'No Trackers Selected',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary(isDark),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Configure your dashboard to see analytics from your selected trackers.',
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

  Widget _buildCustomDashboardSection(
      BuildContext context,
      AnalyticsProvider provider,
      bool isDark,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              lucide.LucideIcons.layoutDashboard,
              color:
              isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Custom Dashboard Trackers',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary(isDark),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                'Displaying charts for your selected trackers (up to 4). Log more data to see trends.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary(isDark),
                ),
              ),
            ),
            if (provider.selectedTrackers.length < 4)
              _buildDetailChip(
                '${4 - provider.selectedTrackers.length} more trackers!',
                Icons.add,
                isDark,
              ),
          ],
        ),
        const SizedBox(height: 16),
        ...provider.selectedTrackers.take(4).map((tracker) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildTrackerChart(
              context,
              tracker,
              provider.trackerData[tracker] ?? [],
              isDark,
            ),
          );
        }).toList(),
      ],
    );
  }
  Widget _buildTrackerChart(
      BuildContext context,
      String trackerName,
      List<Map<String, dynamic>> data,
      bool isDark,
      ) {
    // Safely build FlSpot list and parse timestamps
    final List<FlSpot> spots = [];
    final List<DateTime?> dates = []; // Store corresponding dates

    // --- Sort data by timestamp ascending ---
    // Create a mutable copy to sort
    List<Map<String, dynamic>> sortedData = List.from(data);
    sortedData.sort((a, b) {
      final dateA = DateTime.tryParse(a['timestamp']?.toString() ?? '');
      final dateB = DateTime.tryParse(b['timestamp']?.toString() ?? '');
      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1; // Put nulls last (or first if you prefer)
      if (dateB == null) return -1;
      return dateA.compareTo(dateB); // Sort oldest to newest
    });
    // --- End Sorting ---


    for (int i = 0; i < sortedData.length; i++) {
      final yVal = sortedData[i]['value'];
      final timestampString = sortedData[i]['timestamp']?.toString();
      DateTime? entryDate = DateTime.tryParse(timestampString ?? '');

      if (yVal != null && yVal is num && entryDate != null) {
        // Use index 'i' as the X value for plotting
        spots.add(FlSpot(i.toDouble(), yVal.toDouble()));
        dates.add(entryDate); // Store the date at the same index
      } else {
        // If data is invalid, add a placeholder to keep indices aligned
        spots.add(FlSpot(i.toDouble(), 0)); // Or handle differently
        dates.add(null);
      }
    }


    if (spots.isEmpty) {
      // Keep the empty state message
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: _getCardDecoration(isDark),
        height: 120, // Keep height consistent
        alignment: Alignment.center,
        child: Text('No data logged for $trackerName yet.',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary(isDark)),
          textAlign: TextAlign.center, // Center text
        ),
      );
    }

    // Calculate dynamic Y range (unchanged)
    double minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    double maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    if (minY == maxY) { minY -= 1; maxY += 1; }
    final double yRange = maxY - minY;
    minY = (minY - yRange * 0.1).clamp(0, double.infinity);
    maxY += yRange * 0.1;
    maxY = math.max(maxY, minY + 1); // Ensure maxY is always greater than minY

    final Color lineColor = isDark ? Colors.white : Colors.black; // Line color (unchanged)

    // Determine interval for X-axis labels to avoid clutter
    final double bottomTitleInterval = (spots.length / 5).ceil().toDouble().clamp(1.0, spots.length.toDouble());


    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _getCardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header (unchanged)
          Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: lineColor, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(trackerName, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary(isDark))),
            ],
          ),
          const SizedBox(height: 4),
          Text(_getTrackerUnit(trackerName), style: TextStyle(fontSize: 12, color: AppColors.textSecondary(isDark))),
          const SizedBox(height: 16),

          // Chart
          SizedBox(
            height: 180, // Chart height (unchanged)
            child: LineChart(
              LineChartData(
                minY: minY,
                maxY: maxY,
                gridData: FlGridData( // Grid lines (unchanged)
                  show: true, drawVerticalLine: true,
                  horizontalInterval: (maxY - minY) / 5, // Adjust interval based on range
                  verticalInterval: 1,
                  getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.withOpacity(0.2), strokeWidth: 1),
                  getDrawingVerticalLine: (value) => FlLine(color: Colors.grey.withOpacity(0.2), strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  // Y-Axis Titles (unchanged)
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true, reservedSize: 36,
                      interval: (maxY - minY) / 5, // Match grid interval
                      getTitlesWidget: (value, meta) => Text(
                        value.toStringAsFixed( (maxY - minY) < 5 ? 1 : 0), // Show decimals for small ranges
                        style: TextStyle(fontSize: 10, color: isDark ? Colors.white70 : Colors.black54),
                        textAlign: TextAlign.right, // Align right
                      ),
                    ),
                  ),
                  // --- X-Axis Titles (UPDATED) ---
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24, // Keep reserved space
                      interval: bottomTitleInterval, // Show fewer labels if many points
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        // Check bounds and if the date exists
                        if (index >= 0 && index < dates.length && dates[index] != null) {
                          // Format the date (e.g., "10/30")
                          final String dateText = DateFormat('M/d').format(dates[index]!);
                          return Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              dateText,
                              style: TextStyle(fontSize: 10, color: isDark ? Colors.white70 : Colors.black54),
                            ),
                          );
                        }
                        return const SizedBox.shrink(); // Hide label if index out of bounds or date is null
                      },
                    ),
                  ),
                  // --- END X-Axis Update ---
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), // Hide top
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), // Hide right
                ),
                borderData: FlBorderData( // Border (unchanged)
                  show: true,
                  border: Border.all(color: Colors.grey.withOpacity(0.3), width: 1),
                ),
                lineBarsData: [ // Line data (unchanged)
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: lineColor,
                    barWidth: 2,
                    dotData: FlDotData(show: true), // Show dots on data points
                    belowBarData: BarAreaData(show: true, color: lineColor.withOpacity(0.15)),
                  ),
                ],
                // Optional: Add touch tooltips if desired
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (LineBarSpot touchedSpot) => Colors.blueGrey.withOpacity(0.8), // ✅ Correct type
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final index = spot.spotIndex;
                        final dateStr = (index >= 0 && index < dates.length && dates[index] != null)
                            ? DateFormat('MMM d').format(dates[index]!) // e.g. "Oct 30"
                            : 'Index $index';
                        return LineTooltipItem(
                          '${spot.y.toStringAsFixed(1)} on $dateStr',
                          const TextStyle(color: Colors.white, fontSize: 12),
                        );
                      }).toList();
                    },
                  ),
                ),

              ),
            ),
          ),
        ],
      ),
    );
  }
  String _getTrackerUnit(String trackerName) {
    switch (trackerName) {
      case 'Sleep Tracker':
        return 'Trend over time. Unit: hours';
      case 'Mood Tracker':
        return 'Unit: 1-10 scale';
      case 'Weight Tracker':
        return 'Unit: kg';
      case 'Study Time Tracker':
        return 'Unit: hours';
      case 'Workout Tracker':
        return 'Unit: minutes';
      default:
        return 'Trend over time';
    }
  }

  Widget _buildOverallSummaryCard(
      BuildContext context,
      AnalyticsProvider provider,
      bool isDark,
      ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _getCardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                lucide.LucideIcons.fileText,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Overall Summary',
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
            'Key insights from your tracked activities over the past month.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary(isDark),
            ),
          ),
          const SizedBox(height: 16),
          if (provider.isLoadingSummary)
            Center(
              child: CircularProgressIndicator(
                color: AppColors.black,
                strokeWidth: 3,
              ),
            )
          else if (provider.overallSummary.isNotEmpty)
            _buildSummaryContent(provider.overallSummary, isDark)
          else
            _buildDefaultSummary(isDark),
        ],
      ),
    );
  }

  Widget _buildSummaryContent(String summary, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSummaryInsight(
          'Positive Trend',
          'Your average mood has slightly improved by 5% compared to the previous month. Keep up the great work!',
          isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          isDark,
        ),
        const SizedBox(height: 12),
        _buildSummaryInsight(
          'Area for Focus',
          'Sleep consistency varies, with an average deviation of 1.5 hours from your target. Consider setting a more regular sleep schedule.',
          isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          isDark,
        ),
        const SizedBox(height: 12),
        _buildSummaryInsight(
          'Activity Peak',
          'Your most active days are typically Saturdays, with an average of 45,000 steps.',
          isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          isDark,
        ),
      ],
    );
  }

  Widget _buildDefaultSummary(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSummaryInsight(
          'Getting Started',
          'Start logging data consistently to see personalized insights here.',
          isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          isDark,
        ),
      ],
    );
  }

  Widget _buildSummaryInsight(
      String title,
      String description,
      Color color,
      bool isDark,
      ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 4,
          height: 4,
          margin: const EdgeInsets.only(top: 6),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary(isDark),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---
  // --- START: NEW BMI CALCULATOR WIDGETS ---
  // --- (Replaces old _buildBMICalculator and its helpers)
  // ---

  // ---
  // --- WIDGET UPDATED ---
  // ---
  Widget _buildNewBmiCalculator(BuildContext context, AnalyticsProvider provider) {
    // Force a light theme for this card
    // --- REMOVED: Outer Card and Padding ---
    return Column( // <--- This is now the root widget
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildNewBmiScale(provider),
        const SizedBox(height: 24),
        _buildNewBmiInputForm(context, provider),
        const SizedBox(height: 24),
        if (provider.currentBMI != null) ...[
          _buildNewBmiResult(provider),
          const SizedBox(height: 24),
        ],
        if (_recommendation != null && _healthyWeightRange != null) ...[
          _buildNewBmiRecommendation(provider),
        ],
        const SizedBox(height: 8),
        const Center(
          child: Text(
            "Note: BMI is a general guideline. Consult a healthcare professional.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
      ],
    );
    // --- END REMOVAL ---
  }

  Widget _buildNewBmiScale(AnalyticsProvider provider) {
    const double bmiScaleMin = 15.0;
    const double bmiScaleMax = 40.0;

    double indicatorPosition = 0.0;
    if (provider.currentBMI != null) {
      double range = bmiScaleMax - bmiScaleMin;
      double position = ((provider.currentBMI! - bmiScaleMin) / range);
      indicatorPosition = math.max(0, math.min(1.0, position)); // Clamp 0.0 to 1.0
    }

    return Column(
      children: [
        // 1. Gradient Bar
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              height: 24, // Taller bar
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF007BFF), // Blue
                    Color(0xFF28A745), // Green
                    Color(0xFFFFC107), // Yellow
                    Color(0xFFFD7E14), // Orange
                    Color(0xFFDC3545), // Red
                  ],
                ),
              ),
            ),
            // 2. BMI Indicator
            if (provider.currentBMI != null)
              Positioned(
                left: (MediaQuery.of(context).size.width - 64) * indicatorPosition, // (Full width - padding) * position
                top: -4,
                child: Container(
                  width: 3,
                  height: 32, // Taller
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(2),
                    border: Border.all(color: Colors.white, width: 0.5),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        // 3. Category Labels
        Row( // MODIFIED: Removed 'const' to use the method helper
          children: [
            // These flex values match the React code's flex basis
            Expanded(
              flex: 15, // Underweight
              child: _BmiCategoryLabel(name: "Underweight", range: "< 18.5"),
            ),
            Expanded(
              flex: 15, // Healthy
              child: _BmiCategoryLabel(name: "Healthy", range: "18.5 - 24.9"),
            ),
            Expanded(
              flex: 20, // Overweight
              child: _BmiCategoryLabel(name: "Overweight", range: "25 - 29.9"),
            ),
            Expanded(
              flex: 10, // Obese
              child: _BmiCategoryLabel(name: "Obese", range: "≥ 30"),
            ),
          ],
        )
      ],
    );
  }

  Widget _buildNewBmiInputForm(BuildContext context, AnalyticsProvider provider) {
    return Card(
      color: Colors.grey[100],
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(lucide.LucideIcons.calculator, color: Colors.black, size: 20),
                SizedBox(width: 8),
                Text(
                  "Calculate Your BMI",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12), // MODIFIED: Reduced gap
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- FIX START ---
                Expanded(
                  flex: 3, // Gave more space to the dropdown
                  // --- FIX END ---
                  child: _buildDropdownField(
                    label: 'Height Unit',
                    value: provider.heightUnit,
                    options: ['Centimeters (cm)', 'Feet & Inches (ft/in)'],
                    isDarkTheme: false, // Force light
                    isLightForced: true,
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        provider.setHeightUnit(newValue);
                      }
                    },
                  ),
                ),
                // --- FIX START ---
                const SizedBox(width: 8), // Standardized gap
                Expanded(
                  flex: 2, // Gave less space to the text field
                  // --- FIX END ---
                  child: provider.heightUnit == 'Centimeters (cm)'
                      ? _buildTextFormField(
                    label: "Your Height (cm)",
                    controller: provider.heightCmController,
                    hintText: "E.g., 170",
                  )
                      : Row(
                    children: [
                      Expanded(
                        child: _buildTextFormField(
                          label: "Feet",
                          controller: provider.heightFeetController,
                          hintText: "5",
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildTextFormField(
                          label: "Inches",
                          controller: provider.heightInchesController,
                          hintText: "9",
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12), // MODIFIED: Reduced gap
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- FIX START ---
                Expanded(
                  flex: 3, // Gave more space to the dropdown
                  // --- FIX END ---
                  child: _buildDropdownField(
                    label: 'Weight Unit',
                    value: provider.weightUnit,
                    options: ['Kilograms (kg)', 'Pounds (lbs)'],
                    isDarkTheme: false, // Force light
                    isLightForced: true,
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        provider.setWeightUnit(newValue);
                      }
                    },
                  ),
                ),
                // --- FIX START ---
                const SizedBox(width: 8), // Standardized gap
                Expanded(
                  flex: 2, // Gave less space to the text field
                  // --- FIX END ---
                  child: _buildTextFormField(
                    label: "Your Weight (${provider.weightUnit == 'Kilograms (kg)' ? 'kg' : 'lbs'})",
                    controller: provider.weightController,
                    hintText: provider.weightUnit == 'Kilograms (kg)' ? "E.g., 72" : "E.g., 158",
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16), // MODIFIED: Reduced gap
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.black, // Use app's primary color
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () async {
                  final result = await provider.calculateBMI();
                  if (result != null) {
                    // --- NEW: Calculate recommendation locally ---
                    _generateRecommendation(provider);
                    // --- END NEW ---
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('BMI Calculated: ${result.toStringAsFixed(1)}'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } else {
                    // Clear old results if calc fails
                    setState(() {
                      _recommendation = null;
                      _healthyWeightRange = null;
                    });
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Please enter valid height and weight'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: const Text(
                  'Calculate My BMI',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewBmiResult(AnalyticsProvider provider) {
    final double bmi = provider.currentBMI!;
    final double progress = (bmi - 15) / (40 - 15); // Normalize from 15-40 range
    final Color bmiColor = provider.bmiStatusColor;

    return Column(
      children: [
        // 1. Circular Meter
        SizedBox(
          width: 120,
          height: 120,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CircularProgressIndicator(
                value: 1.0,
                strokeWidth: 10,
                backgroundColor: Colors.grey[200],
                color: Colors.grey[200],
              ),
              CircularProgressIndicator(
                value: progress,
                strokeWidth: 10,
                color: bmiColor,
                strokeCap: StrokeCap.round,
              ),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      bmi.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: bmiColor,
                      ),
                    ),
                    Text(
                      "BMI",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // 2. Text Result
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Your BMI:",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              bmi.toStringAsFixed(1),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: bmiColor,
              ),
            ),
            const SizedBox(width: 8),
            Chip(
              label: Text(
                provider.bmiStatusLabel,
                style: TextStyle(
                  color: bmiColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              backgroundColor: bmiColor.withOpacity(0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: bmiColor.withOpacity(0.2)),
              ),
            )
          ],
        ),
      ],
    );
  }

  Widget _buildNewBmiRecommendation(AnalyticsProvider provider) {
    return Card(
      color: Colors.grey[100],
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(lucide.LucideIcons.trendingUp, color: Colors.black, size: 20),
                SizedBox(width: 8),
                Text(
                  "Recommendation",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Healthy Weight Range:",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  _healthyWeightRange ?? "N/A",
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Text(
              // The user wants this from Gemini, but for now, we use the
              // generated one.
              _recommendation ?? "...",
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper class for the labels under the bar
  Widget _BmiCategoryLabel({required String name, required String range}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
          overflow: TextOverflow.ellipsis, // Added to prevent label overflow
        ),
        Text(
          range,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  // --- NEW: Logic moved from React code into the state ---
  void _generateRecommendation(AnalyticsProvider provider) {
    if (provider.currentBMI == null) return;

    final double bmiVal = provider.currentBMI!;
    final String weightUnit = provider.weightUnit == 'Kilograms (kg)' ? 'kg' : 'lbs';
    final bool isKg = weightUnit == 'kg';

    // 1. Get Height in Meters
    double hCm = 0;
    try {
      if (provider.heightUnit == 'Centimeters (cm)') {
        hCm = double.parse(provider.heightCmController.text);
      } else {
        final double ft = double.parse(provider.heightFeetController.text);
        final double inches = double.parse(provider.heightInchesController.text);
        hCm = (ft * 30.48) + (inches * 2.54);
      }
    } catch (e) {
      return; // Invalid height
    }
    final double heightM = hCm / 100;
    if (heightM <= 0) return;

    // 2. Get Weight in KG
    double wKg = 0;
    try {
      wKg = double.parse(provider.weightController.text);
      if (wKg <= 0) return;
      if (!isKg) {
        wKg = wKg * 0.453592; // Convert lbs to kg
      }
    } catch (e) {
      return; // Invalid weight
    }

    // 3. Calculate Healthy Range
    final double lowerHealthyWeightKg = 18.5 * (heightM * heightM);
    final double upperHealthyWeightKg = 24.9 * (heightM * heightM);

    final String lowerDisplay = isKg
        ? lowerHealthyWeightKg.toStringAsFixed(1)
        : (lowerHealthyWeightKg * 2.20462).toStringAsFixed(1);
    final String upperDisplay = isKg
        ? upperHealthyWeightKg.toStringAsFixed(1)
        : (upperHealthyWeightKg * 2.20462).toStringAsFixed(1);

    final String healthyRange = "$lowerDisplay - $upperDisplay $weightUnit";

    // 4. Generate Recommendation Message
    String recMsg = "";
    if (bmiVal < 18.5) {
      final double weightToGainKg = lowerHealthyWeightKg - wKg;
      final String weightToGainDisplay = isKg
          ? weightToGainKg.toStringAsFixed(1)
          : (weightToGainKg * 2.20462).toStringAsFixed(1);
      recMsg = "Based on your metrics, a weight gain of approximately $weightToGainDisplay $weightUnit is suggested to enter the healthy BMI range.";
    } else if (bmiVal >= 25) {
      final double weightToLoseKg = wKg - upperHealthyWeightKg;
      final String weightToLoseDisplay = isKg
          ? weightToLoseKg.toString()
          : (weightToLoseKg * 2.20462).toStringAsFixed(1);
      recMsg = "Based on your metrics, a weight loss of approximately $weightToLoseDisplay $weightUnit is suggested to enter the healthy BMI range.";
    } else {
      recMsg = "Your BMI is within the healthy range. Focus on maintaining your current lifestyle habits.";
    }

    // 5. Update state
    setState(() {
      _healthyWeightRange = healthyRange;
      _recommendation = recMsg;
    });

    // TODO: Here you would call the Gemini API for a richer recommendation
    // if you want, and then update the state again with that response.
    // For example:
    // _getGeminiRecommendation(bmiVal, hCm, wKg).then((geminiRec) {
    //   if (geminiRec != null) {
    //     setState(() {
    //       _recommendation = geminiRec;
    //     });
    //   }
    // });
  }

  //
  // --- END: NEW BMI CALCULATOR WIDGETS ---
  //

  void _showConfigureDashboard(
      BuildContext context,
      AnalyticsProvider provider,
      bool isDark,
      ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            gradient: AppColors.cardLinearGradient(isDark),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.textSecondary(isDark),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text(
                      'Configure Dashboard',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary(isDark),
                      ),
                    ),
                    const Spacer(),
                    _buildDetailChip(
                      '${provider.selectedTrackers.length} selected',
                      Icons.check_circle,
                      isDark,
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () {
                        if (provider.selectedTrackers.isNotEmpty) {
                          provider.loadTrackerData();
                          provider.generateOverallSummary();
                        }
                        Navigator.pop(context);
                      },
                      child: Text(
                        'Done',
                        style: TextStyle(
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: provider.availableTrackers.length,
                  itemBuilder: (context, index) {
                    final tracker = provider.availableTrackers[index];
                    final isSelected =
                    provider.selectedTrackers.contains(tracker);
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
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                            fontSize: 14,
                          ),
                        ),
                        value: isSelected,
                        onChanged: (bool? value) {
                          provider.toggleTrackerSelection(tracker);
                          setState(() {});
                        },
                        activeColor: AppColors.black,
                        checkColor: Colors.white,
                        controlAffinity: ListTileControlAffinity.trailing,
                        dense: true,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}