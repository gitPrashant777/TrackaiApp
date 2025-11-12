import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:trackai/features/analytics/screens/CycleOS/hormones_info_screen.dart';

// Import your other screens
import 'FullCalendarScreen.dart';
import 'LogMenstrualCycleForm.dart'; // Make sure this path is correct
import 'analyticsscreen.dart'; // Make sure this path is correct
import 'InsightsScreen.dart'; // Make sure this path is correct

class PeriodDashboard extends StatefulWidget {
  const PeriodDashboard({Key? key}) : super(key: key);

  @override
  State<PeriodDashboard> createState() => _PeriodDashboardState();
}

class _PeriodDashboardState extends State<PeriodDashboard> {
  int cycleDay = 1;
  String predictedPeriod = '---';
  String fertileWindow = '---';
  String currentPhase = 'Loading...';
  bool _isLoadingData = true;
  int _cycleLengthDays = 28;
  int _periodLengthDays = 5;
  DateTime? _lastPeriodDate;

  int _daysToOvulation = 0;
  int _daysToPeriod = 0;
  String _pregnancyChance = '';

  // --- NEW: State for horizontal calendar ---
  DateTime _currentDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadCycleData();
  }

  // --- NEW: Helper for horizontal calendar ---
  List<DateTime> _getWeekDates(DateTime date) {
    // Assuming week starts on Monday (weekday == 1)
    final startOfWeek = date.subtract(Duration(days: date.weekday - 1));
    return List.generate(7, (index) => startOfWeek.add(Duration(days: index)));
  }

  // --- NEW: Navigation for horizontal calendar ---
  void _navigateToWeek(int direction) {
    setState(() {
      _currentDate = _currentDate.add(Duration(days: 7 * direction));
      // You could re-fetch data here if the calendar needed to show logs
    });
  }

  Future<void> _showLogCycleForm() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const LogMenstrualCycleForm(),
      ),
    );
    if (result == true) {
      _loadCycleData();
    }
  }

  Future<void> _loadCycleData() async {
    setState(() {
      _isLoadingData = true;
      predictedPeriod = '---';
      fertileWindow = '---';
      currentPhase = 'Loading...';
      _pregnancyChance = '';
      cycleDay = 1;
      _daysToOvulation = 0;
      _daysToPeriod = 0;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          predictedPeriod = 'Login Required';
          fertileWindow = 'Login Required';
          currentPhase = 'Login Required';
          _isLoadingData = false;
        });
      }
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('period_settings')
          .doc('config')
          .get();

      if (doc.exists && mounted) {
        final data = doc.data()!;
        _lastPeriodDate = (data['lastPeriodDate'] as Timestamp?)?.toDate();
        _cycleLengthDays = (data['cycleLengthDays'] as num?)?.toInt() ?? 28;
        _periodLengthDays = (data['periodLengthDays'] as num?)?.toInt() ?? 5;

        if (_lastPeriodDate != null) {
          final today =
          DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

          // --- ### MODIFIED & FIXED LOGIC START ### ---
          // 1. Calculate the difference in days. Can be negative (if last period is in future)
          final daysDifference = today.difference(_lastPeriodDate!).inDays;

          // 2. Use a true modulo operation to find the cycle day number.
          // This handles both past and future dates correctly.
          // (daysDifference % N + N) % N handles negative numbers, unlike a simple %
          final calculatedCycleDay =
              (daysDifference % _cycleLengthDays + _cycleLengthDays) %
                  _cycleLengthDays +
                  1;

          // 3. Find the start date of the *current* cycle based on today's date and the calculated day.
          final currentCycleStartDate =
          today.subtract(Duration(days: calculatedCycleDay - 1));

          // 4. Calculate all key dates based on the *current* cycle's start
          final currentPeriodEndDate =
          currentCycleStartDate.add(Duration(days: _periodLengthDays - 1));

          final approxOvulationDayInCycle = _cycleLengthDays - 14;
          // Ensure ovulation isn't day 0 or negative if cycle is too short
          final ovulationDayNumber =
          approxOvulationDayInCycle <= 0 ? 1 : approxOvulationDayInCycle;

          final ovulationDate =
          currentCycleStartDate.add(Duration(days: ovulationDayNumber - 1));
          final fertileStartDate = ovulationDate.subtract(const Duration(days: 5));
          final fertileEndDate = ovulationDate.add(const Duration(days: 1));

          // 5. Calculate next period
          final nextPeriodStartDate =
          currentCycleStartDate.add(Duration(days: _cycleLengthDays));
          final nextPeriodEndDate =
          nextPeriodStartDate.add(Duration(days: _periodLengthDays - 1));

          // 6. Calculate "Days To..."
          // If we are in the period, days to next period is 0
          final daysToPeriodFinal = (calculatedCycleDay <= _periodLengthDays)
              ? 0
              : _cycleLengthDays - calculatedCycleDay;

          // Ensure "daysToOvulation" is 0 if ovulation has passed in *this* cycle
          final daysToOvulationFinal = ovulationDate.isBefore(today)
              ? 0
              : ovulationDate.difference(today).inDays;

          // 7. Get the current phase
          final phaseData = _getCurrentPhase(
              today,
              currentCycleStartDate,
              currentPeriodEndDate,
              fertileStartDate,
              fertileEndDate,
              ovulationDate,
              nextPeriodStartDate);
          // --- ### MODIFIED & FIXED LOGIC END ### ---

          setState(() {
            cycleDay = calculatedCycleDay;
            _daysToOvulation = daysToOvulationFinal; // Use the final calculated value
            _daysToPeriod = daysToPeriodFinal; // Use the final calculated value
            predictedPeriod =
            '${DateFormat('MMM d').format(nextPeriodStartDate)} - ${DateFormat('d').format(nextPeriodEndDate)}';
            fertileWindow =
            '${DateFormat('MMM d').format(fertileStartDate)} - ${DateFormat('d').format(fertileEndDate)}';
            currentPhase = phaseData['phase']!;
            _pregnancyChance = phaseData['chance']!;
            _isLoadingData = false;
          });
        } else {
          if (mounted) {
            setState(() {
              predictedPeriod = 'Setup Required';
              fertileWindow = 'Setup Required';
              currentPhase = 'Log your cycle';
              _pregnancyChance = '';
              _isLoadingData = false;
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            predictedPeriod = 'Setup Required';
            fertileWindow = 'Setup Required';
            currentPhase = 'Log your cycle';
            _pregnancyChance = '';
            _isLoadingData = false;
          });
        }
      }
    } catch (e) {
      print("Error loading cycle data: $e");
      if (mounted) {
        setState(() {
          predictedPeriod = 'Error Loading';
          fertileWindow = 'Error Loading';
          currentPhase = 'Error';
          _pregnancyChance = '';
          _isLoadingData = false;
        });
      }
    }
  }

  Map<String, String> _getCurrentPhase(
      DateTime today,
      DateTime currentPeriodStart,
      DateTime currentPeriodEnd,
      DateTime fertileStart,
      DateTime fertileEnd,
      DateTime ovulationDate,
      DateTime nextPeriodStart,
      ) {
    // Check in logical order

    // 1. Are we in the period?
    if ((today.isAfter(currentPeriodStart) ||
        DateUtils.isSameDay(today, currentPeriodStart)) &&
        (today.isBefore(currentPeriodEnd) ||
            DateUtils.isSameDay(today, currentPeriodEnd))) {
      return {
        'phase': 'Menstrual Phase',
        'chance': 'Very Low chance of getting pregnant'
      };
    }

    // 2. Are we in the fertile window?
    if ((today.isAfter(fertileStart) ||
        DateUtils.isSameDay(today, fertileStart)) &&
        (today.isBefore(fertileEnd) ||
            DateUtils.isSameDay(today, fertileEnd))) {
      if (DateUtils.isSameDay(today, ovulationDate)) {
        return {
          'phase': 'Ovulation Day',
          'chance': 'High chance of getting pregnant'
        };
      }
      return {
        'phase': 'Fertile Phase',
        'chance': 'High chance of getting pregnant'
      };
    }

    // 3. If not in period or fertile window, we are either Follicular or Luteal
    // Check if we are *before* the fertile window (Follicular)
    if (today.isBefore(fertileStart)) {
      return {
        'phase': 'Follicular Phase',
        'chance': 'Low chance of getting pregnant'
      };
    }

    // 4. If we are not in any of the above, we must be after the fertile window (Luteal)
    return {
      'phase': 'Luteal Phase',
      'chance': 'Very Low chance of getting pregnant'
    };
  }

  Map<String, Color> _getPregnancyChanceColors() {
    if (_pregnancyChance.contains('High')) {
      return {'background': Color(0xFFE91E63), 'text': Colors.white};
    } else if (_pregnancyChance.contains('Low')) {
      return {'background': Colors.teal.shade400, 'text': Colors.white};
    }
    // Very Low
    return {'background': Colors.grey.shade600, 'text': Colors.white};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5E6F1),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // --- MODIFIED: Added errorBuilder ---
            Image.asset(
              'assets/images/os.jpg',
              width: 28,
              height: 28,
              errorBuilder: (context, error, stackTrace) {
                // Show a fallback icon if the image fails to load
                return const Icon(
                  Icons.spa_outlined, // A fitting fallback
                  color: Color(0xFFE91E63),
                  size: 28,
                );
              },
            ),
            // --- END MODIFICATION ---
            const SizedBox(width: 8),
            const Text(
              'CycleOS',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined,
                color: Color(0xFFE91E63)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const FullCalendarScreen()),
              );
            },
            tooltip: 'View Calendar',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // --- 1. NEWLY ADDED CALENDAR (This is the modified section) ---
            _buildWeekCalendar(),

            // --- 2. "rectangle boz" (Now white) ---
            const SizedBox(height: 10), // Adjusted padding
            _buildPredictionRectangle(),

            // --- 3. "log and hormoes" ---
            _buildButtonRow(),

            // --- 4. "quick" (with updated style) ---
            const SizedBox(height: 10), // Adjusted spacing
            _buildQuickActionScroller(),

            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  // --- WIDGET MODIFIED: Horizontal Week Calendar ---
  // This section contains the changes you requested
  Widget _buildWeekCalendar() {
    final weekDates = _getWeekDates(_currentDate);
    final today = DateTime.now();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x1A000000), // Soft shadow
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [

          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: weekDates.map((date) {
                final dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                final dayLetter = dayLetters[date.weekday - 1];
                final isToday = DateUtils.isSameDay(date, today);

                // --- MODIFICATION START ---
                // We now return a Column directly, and the "shadow" (circular fill)
                // is applied only to the date number.
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 1. Day Letter (Small)
                    Text(
                      dayLetter,
                      style: TextStyle(
                        color: isToday ? Colors.black87 : Colors.black54,
                        fontSize: 12, // <-- SMALLER
                        fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(height: 4), // Space

                    // 2. Day Number (Bigger, with "shadow" circle)
                    Container(
                      // This Container creates the circular shadow
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), // Tuned padding
                      decoration: BoxDecoration(
                        color: isToday
                            ? Colors.grey.shade200
                            : Colors.transparent, // <-- SHADOW
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${date.day}',
                        style: TextStyle(
                          color: Colors.black87, // Always dark
                          fontSize: 18, // <-- BIGGER
                          fontWeight:
                          isToday ? FontWeight.bold : FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                );
                // --- MODIFICATION END ---
              }).toList(),
            ),
          ),

        ],
      ),
    );
  }

  // --- MODIFIED WIDGET: Prediction Box Style ---
  Widget _buildPredictionRectangle() {
    if (currentPhase == 'Log your cycle' && !_isLoadingData) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 15),
        child: Container(
          width: double.infinity,
          height: 180,
          decoration: BoxDecoration(
            // --- MODIFIED: White background ---
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            // --- MODIFIED: Grey shadow ---
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                blurRadius: 10,
                spreadRadius: 1,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  height: 64,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: const Text(
                    'Log Your Cycle',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        // --- MODIFIED: Black text ---
                        color: Colors.black87,
                        height: 1.2),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'to get predictions',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.black.withOpacity(0.6),
                      height: 1.2),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
      child: Container(
        width: double.infinity,
        height: 200,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          // --- MODIFIED: White background ---
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          // --- MODIFIED: Grey shadow ---
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              blurRadius: 10,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: _isLoadingData
              ? const CircularProgressIndicator(
              strokeWidth: 3,
              // --- MODIFIED: Pink progress color ---
              valueColor: AlwaysStoppedAnimation(Color(0xFFE91E63)))
              : _buildPredictionText(),
        ),
      ),
    );
  }

  // --- MODIFIED WIDGET: Prediction Text Style ---
  Widget _buildPredictionText() {
    // Styles for main prediction
    final smallPinkStyle = TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.bold,
      // --- MODIFIED: Black text ---
      color: Colors.black87,
      height: 1.2,
    );
    final bigBlackStyle = TextStyle(
      fontSize: 36,
      fontWeight: FontWeight.bold,
      color: Colors.black,
      height: 1.1,
    );

    // Styles for fertile window
    final fertileBaseStyle = TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        // --- MODIFIED: Darker text ---
        color: Colors.black54);
    final fertileValueStyle =
    // --- MODIFIED: Darker text ---
    const TextStyle(
        fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87);

    // Main prediction widget
    Widget mainPrediction;

    // Logic based on phase (and image flow)
    if (currentPhase == 'Menstrual Phase') {
      mainPrediction = RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: smallPinkStyle,
          children: [
            TextSpan(text: 'Period Day\n'),
            TextSpan(text: '$cycleDay', style: bigBlackStyle),
          ],
        ),
      );
    } else if (currentPhase == 'Follicular Phase') {
      mainPrediction = RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: smallPinkStyle,
          children: [
            TextSpan(text: 'Ovulation in\n'),
            TextSpan(text: '$_daysToOvulation', style: bigBlackStyle),
            TextSpan(text: ' days'),
          ],
        ),
      );
    } else if (currentPhase == 'Ovulation Day') {
      mainPrediction = Text(
        'Prediction: Ovulation Day',
        textAlign: TextAlign.center,
        style: smallPinkStyle.copyWith(fontSize: 24),
      );
    } else if (currentPhase == 'Fertile Phase') {
      // Name change from Ovulation Phase
      mainPrediction = RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: smallPinkStyle,
          children: [
            TextSpan(text: 'Ovulation in\n'),
            TextSpan(text: '$_daysToOvulation', style: bigBlackStyle),
            TextSpan(text: ' days'),
          ],
        ),
      );
    } else if (currentPhase == 'Luteal Phase') {
      mainPrediction = RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: smallPinkStyle,
          children: [
            TextSpan(text: 'Period in\n'),
            TextSpan(text: '$_daysToPeriod', style: bigBlackStyle),
            TextSpan(text: ' days'),
          ],
        ),
      );
    } else {
      mainPrediction = Text(
        currentPhase,
        textAlign: TextAlign.center,
        style: smallPinkStyle,
      );
    }

    // Combine prediction and chance in a Column
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // 1. Main Prediction Text
        Container(
          height: 70,
          alignment: Alignment.center,
          child: mainPrediction,
        ),

        // 2. Pregnancy Chance Tag
        if (_pregnancyChance.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _getPregnancyChanceColors()['background']!,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _pregnancyChance,
              style: TextStyle(
                color: _getPregnancyChanceColors()['text']!,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),

        // 3. Fertile Window Row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // --- MODIFIED: Darker icon ---
            Icon(Icons.favorite_border, size: 16, color: Colors.black54),
            const SizedBox(width: 8),
            Text('Fertile Window: ', style: fertileBaseStyle),
            Text(fertileWindow, style: fertileValueStyle),
          ],
        ),
      ],
    );
  }

  Widget _buildButtonRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
      child: Row(
        children: [
          Expanded(
            child: _buildStyledButton(
              text: 'Log & Edit Cycle',
              onTap: _showLogCycleForm,
              backgroundColor: const Color(0xFFFCE4EC),
              textColor: const Color(0xFFC2185B),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildStyledButton(
              text: 'Horms & Cycle Info',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => HormonesInfoScreen(
                      currentPhase: currentPhase,
                    ),
                  ),
                );
              },
              backgroundColor: const Color(0xFFE8EAF6),
              textColor: const Color(0xFF3F51B5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStyledButton({
    required String text,
    required VoidCallback onTap,
    required Color backgroundColor,
    required Color textColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionScroller() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.0),
          child: Text(
            'Quick Log',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 100, // This height is fine
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                _buildSquareQuickLogButton(
                  label: 'Log Period',
                  icon: Icons.water_drop_outlined,
                  color: const Color(0xFFE57373),
                  onTap: () => Navigator.pushNamed(context, '/log-period')
                      .then((_) => _loadCycleData()),
                ),
                const SizedBox(width: 16),
                _buildSquareQuickLogButton(
                  label: 'Add Symptom',
                  icon: Icons.healing_outlined,
                  color: const Color(0xFF9575CD),
                  onTap: () => Navigator.pushNamed(context, '/log-symptoms')
                      .then((_) => _loadCycleData()),
                ),
                const SizedBox(width: 16),
                _buildSquareQuickLogButton(
                  label: 'Track Mood',
                  icon: Icons.sentiment_satisfied_outlined,
                  color: const Color(0xFFFFD54F),
                  onTap: () => Navigator.pushNamed(context, '/log-mood')
                      .then((_) => _loadCycleData()),
                ),
                const SizedBox(width: 16),
                _buildSquareQuickLogButton(
                  label: 'Log Activity',
                  icon: Icons.directions_run,
                  color: const Color(0xFF4DB6AC),
                  onTap: () => Navigator.pushNamed(context, '/log-activity')
                      .then((_) => _loadCycleData()),
                ),
                const SizedBox(width: 16),
                _buildSquareQuickLogButton(
                  label: 'Add Note',
                  icon: Icons.note_alt_outlined,
                  color: const Color(0xFF64B5F6),
                  onTap: () => Navigator.pushNamed(context, '/log-notes')
                      .then((_) => _loadCycleData()),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- MODIFIED WIDGET: Quick Log Button Style ---
  Widget _buildSquareQuickLogButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        // --- MODIFICATION: Width increased ---
        width: 125, // Was 100
        height: 120,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 28), // Was 30
            const SizedBox(height: 8), // Was 12
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2, // Allow text to wrap
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            )
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------------
// --- MAIN NAVIGATION SCREEN (No changes needed) ---
// -------------------------------------------------------------------
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({Key? key}) : super(key: key);

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  static const List<Widget> _widgetOptions = <Widget>[
    PeriodDashboard(), // Tab 0: Today
    InsightsScreen(), // Tab 1: Insights
    AnalyticsScreen(), // Tab 2: Analytics
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined),
            activeIcon: Icon(Icons.calendar_today),
            label: 'Today',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.lightbulb_outline),
            activeIcon: Icon(Icons.lightbulb),
            label: 'Insights',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics_outlined),
            activeIcon: Icon(Icons.analytics),
            label: 'CycleOS',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: const Color(0xFFE91E63), // Bright pink for selected
        unselectedItemColor: const Color(0xFFFFC1E3), // Light pink for unselected
        backgroundColor: Colors.white,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedFontSize: 12,
        unselectedFontSize: 11,
        onTap: _onItemTapped,
      ),
    );
  }
}