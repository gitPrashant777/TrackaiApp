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
  // DateTime _currentDate = DateTime.now(); // No longer needed for week calendar

  // --- NEW STATE VARIABLES ---
  int _daysToOvulation = 0;
  String _pregnancyChance = ''; // Will store "High", "Low", etc.
  // -------------------------

  @override
  void initState() {
    super.initState();
    _loadCycleData();
  }

  // --- ADDED FUNCTION TO PUSH FULL SCREEN ---
  Future<void> _showLogCycleForm() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const LogMenstrualCycleForm(),
      ),
    );

    // This logic stays the same.
    // If the form was saved, 'result' will be true
    if (result == true) {
      _loadCycleData();
    }
  }
  // --- END OF ADDED FUNCTION ---


  // --- MODIFIED FUNCTION ---
  Future<void> _loadCycleData() async {
    setState(() {
      _isLoadingData = true;
      predictedPeriod = '---';
      fertileWindow = '---';
      currentPhase = 'Loading...';
      _pregnancyChance = ''; // Reset
      cycleDay = 1;
      _daysToOvulation = 0; // Reset countdown
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
          final daysSinceStart = today.difference(_lastPeriodDate!).inDays;

          final calculatedCycleDay = (daysSinceStart % _cycleLengthDays) + 1;

          final nextPeriod =
          _lastPeriodDate!.add(Duration(days: _cycleLengthDays));
          final periodEndDate =
          nextPeriod.add(Duration(days: _periodLengthDays - 1));

          final ovulationDay = nextPeriod.subtract(const Duration(days: 14));
          final fertileStart = ovulationDay.subtract(const Duration(days: 5));
          final fertileEnd = ovulationDay.add(const Duration(days: 1));

          int approxOvulationDayNum = _cycleLengthDays - 14;
          DateTime currentCycleOvulationDate =
          _lastPeriodDate!.add(Duration(days: approxOvulationDayNum));

          int daysToOvulation;
          if (today.isAfter(currentCycleOvulationDate)) {
            DateTime nextCycleOvulationDate =
            currentCycleOvulationDate.add(Duration(days: _cycleLengthDays));
            daysToOvulation = nextCycleOvulationDate.difference(today).inDays;
          } else {
            daysToOvulation = currentCycleOvulationDate.difference(today).inDays;
          }

          // --- MODIFIED: Get phase and chance from map ---
          final phaseData = _getCurrentPhase(
              calculatedCycleDay, _periodLengthDays, _cycleLengthDays, ovulationDay, fertileStart, fertileEnd);

          setState(() {
            cycleDay = calculatedCycleDay;
            _daysToOvulation = daysToOvulation; // <-- Save to state
            predictedPeriod =
            '${DateFormat('MMM d').format(nextPeriod)} - ${DateFormat('d').format(periodEndDate)}';
            fertileWindow =
            '${DateFormat('MMM d').format(fertileStart)} - ${DateFormat('d').format(fertileEnd)}';

            // --- MODIFIED: Set new state variables ---
            currentPhase = phaseData['phase']!;
            _pregnancyChance = phaseData['chance']!;
            // -----------------------------------------

            _isLoadingData = false;
          });
        } else {
          if (mounted) {
            setState(() {
              predictedPeriod = 'Setup Required';
              fertileWindow = 'Setup Required';
              // --- THIS IS THE KEY for the "Log your cycle" text ---
              currentPhase = 'Log your cycle';
              _pregnancyChance = ''; // <-- Reset
              _isLoadingData = false;
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            predictedPeriod = 'Setup Required';
            fertileWindow = 'Setup Required';
            // --- THIS IS THE KEY for the "Log your cycle" text ---
            currentPhase = 'Log your cycle';
            _pregnancyChance = ''; // <-- Reset
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
          _pregnancyChance = ''; // <-- Reset
          _isLoadingData = false;
        });
      }
    }
  }
  // -------------------------

  // --- MODIFIED: Function now returns a Map ---
  Map<String, String> _getCurrentPhase(int day, int periodLength, int cycleLength, DateTime ovulationDay, DateTime fertileStart, DateTime fertileEnd) {
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

    // 1. Menstrual Phase
    if (day <= periodLength) {
      return {'phase': 'Menstrual Phase', 'chance': 'Very Low chance of getting pregnant'};
    }

    // 2. Ovulation Phase (Fertile Window)
    if (DateUtils.isSameDay(today, ovulationDay)) {
      return {'phase': 'Ovulation Day', 'chance': 'High chance of getting pregnant'};
    }
    if ((today.isAfter(fertileStart) || DateUtils.isSameDay(today, fertileStart)) &&
        (today.isBefore(fertileEnd) || DateUtils.isSameDay(today, fertileEnd))) {
      return {'phase': 'Ovulation Phase', 'chance': 'High chance of getting pregnant'};
    }

    // 3. Follicular Phase (after period, before fertile window)
    int approxOvulationDay = cycleLength - 14;
    // Assuming fertile window starts 5 days before ovulation, so "low" is before that.
    int follicularEnd = approxOvulationDay - 6;

    if (day <= follicularEnd) {
      return {'phase': 'Follicular Phase', 'chance': 'Low chance of getting pregnant'};
    }

    // 4. Luteal Phase (after fertile window)
    // Anything after fertile window and before next period
    return {'phase': 'Luteal Phase', 'chance': 'Very Low chance of getting pregnant'};
  }
  // ----------------------------------------------

  // --- NEW HELPER FUNCTION FOR COLOR ---
  Color _getPregnancyChanceColor() {
    if (_pregnancyChance.contains('High')) {
      return Color(0xFFE91E63); // Pink
    } else if (_pregnancyChance.contains('Low')) {
      return Colors.teal; // Green/Teal
    }
    return Colors.black.withOpacity(0.7); // Grey for "Very Low"
  }
  // -------------------------------------


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5E6F1),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        // --- MODIFIED: Title and alignment ---
        title: Row(
          mainAxisSize: MainAxisSize.min, // Keep content tight
          children: [
            // Add your image here
            Image.asset(
              'assets/images/os.jpg',
              width: 28, // Adjust size as needed
              height: 28,
            ),
            const SizedBox(width: 8), // Spacing
            const Text(
              'Cycle OS',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        centerTitle: false,// Aligns to the left
        // ------------------------------------
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined, color: Color(0xFFE91E63)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const FullCalendarScreen()),
              );
            },
            tooltip: 'View Calendar',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // --- REMOVED: Week Calendar Container ---

            // --- ADDED: Top padding to replace the calendar space ---
            const SizedBox(height: 30),

            // --- ADDED NEW BUTTON ---
            _buildHormonesButton(),
            const SizedBox(height: 25), // Space between button and circle
            // ------------------------

            _buildCycleDayCircle(), // This widget is modified
            const SizedBox(height: 20),

            // --- NEW: Pregnancy chance text moved here ---
            if (!_isLoadingData && _pregnancyChance.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 10.0),
                child: Text(
                  _pregnancyChance,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _getPregnancyChanceColor(), // Dynamic color
                      height: 1.2
                  ),
                ),
              ),
            // -------------------------------------------

            _buildLogCycleWidget(),
            const SizedBox(height: 20),
            _buildPredictions(), // This widget is modified
            const SizedBox(height: 30),
            _buildQuickLogSection(),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // --- REMOVED: _getWeekDates function ---

  // --- REMOVED: _buildWeekCalendar function ---

  // --- MODIFIED WIDGET ---
  Widget _buildCycleDayCircle() {
    // --- NEW: Check for "Log your cycle" state ---
    if (currentPhase == 'Log your cycle' && !_isLoadingData) {
      return Container(
        width: 200,
        height: 200,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [
              const Color(0xFFE91E63).withOpacity(0.3),
              const Color(0xFFE91E63).withOpacity(0.15),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE91E63).withOpacity(0.1),
              blurRadius: 15,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                height: 64, // Give it space
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 10), // Prevent overflow
                child: const Text(
                  'Log Your Cycle',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold, // Make it bold
                      color: Color(0xFFE91E63),
                      height: 1.2
                  ),
                ),
              ),
              const SizedBox(height: 8), // Increased spacing
              Text(
                'to get predictions',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black.withOpacity(0.6),
                    height: 1.2
                ),
              ),
            ],
          ),
        ),
      );
    }
    // --- END "Log your cycle" state ---

    // --- REMOVED ovulationText variable and logic ---

    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            const Color(0xFFE91E63).withOpacity(0.3),
            const Color(0xFFE91E63).withOpacity(0.15),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE91E63).withOpacity(0.1),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _isLoadingData
                ? SizedBox(
                height: 64, // Keep space for loader
                child: Center(
                    child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation(Colors.black54))))
                : Container(
              height: 64, // Give it space
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 10), // Prevent overflow
              // --- MODIFIED: Call new helper function ---
              child: _buildOvulationTextWidget(),
            ),
            // --- REMOVED old Text widget and commented-out phase text ---
          ],
        ),
      ),
    );
  }
  // -------------------------

  // --- NEW HELPER WIDGET FOR RICHTEXT ---
  Widget _buildOvulationTextWidget() {
    // Define styles
    final smallPinkStyle = TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.bold,
      color: Color(0xFFE91E63),
      height: 1.2,
    );
    final bigBlackStyle = TextStyle(
      fontSize: 36, // "big"
      fontWeight: FontWeight.bold,
      color: Colors.black, // "color black"
      height: 1.1,
    );

    if (_daysToOvulation == 0) {
      // Case 1: Ovulation (Predicted)
      return Text(
        'Ovulation (Predicted)',
        textAlign: TextAlign.center,
        style: smallPinkStyle.copyWith(fontSize: 24),
      );
    } else if (_daysToOvulation == 1) {
      // Case 2: Ovulation in 1 day (NO newline)
      return RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: smallPinkStyle,
          children: [
            TextSpan(text: 'Ovulation in '),
            TextSpan(text: '1', style: bigBlackStyle),
            TextSpan(text: ' day'),
          ],
        ),
      );
    } else if (_daysToOvulation > 1) {
      // Case 3: Ovulation in \n X days (WITH newline)
      return RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: smallPinkStyle,
          children: [
            TextSpan(text: 'Ovulation in\n'), // Keep the newline
            TextSpan(text: '$_daysToOvulation', style: bigBlackStyle),
            TextSpan(text: ' days'),
          ],
        ),
      );
    } else {
      // Fallback (e.g., if days are negative, though logic should prevent this)
      return Text(
        currentPhase, // Show the phase as a fallback
        textAlign: TextAlign.center,
        style: smallPinkStyle,
      );
    }
  }
  // --- END OF NEW HELPER WIDGET ---

  Widget _buildLogCycleWidget() {
    // ... (This function is correct, no changes needed) ...
    return GestureDetector(
      onTap: _showLogCycleForm, // This now calls the correct function
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.edit_outlined, color: Color(0xFFE91E63), size: 18),
            SizedBox(width: 8),
            Text(
              'Log or edit your cycle',
              style: TextStyle(
                color: Color(0xFFE91E63),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- MODIFIED WIDGET ---
  Widget _buildPredictions() {
    final baseStyle = TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Colors.black.withOpacity(0.7));
    final valueStyle =
    const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87);
    final loadingStyle = TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        fontStyle: FontStyle.italic,
        color: Colors.black.withOpacity(0.5));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // --- REMOVED: Next Period Row ---

          // --- MODIFIED: "Fertile Days" to "Fertile Window" ---
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.favorite_border, size: 16, color: Color(0xFFE91E63)),
              const SizedBox(width: 8),
              Text('Fertile Window: ', style: baseStyle), // <-- Text changed
              _isLoadingData
                  ? Text('Calculating...', style: loadingStyle)
                  : Text(fertileWindow, style: valueStyle),
            ],
          ),
          const SizedBox(height: 15),

          // --- REMOVED: Pregnancy chance text (moved above log button) ---
        ],
      ),
    );
  }
  // -------------------------

  // --- MODIFIED WIDGET: For the "Hormones & Cycle Info" button ---
  Widget _buildHormonesButton() {
    return Padding(
      // --- MODIFIED: Reduced padding to make it wider ---
      padding: const EdgeInsets.symmetric(horizontal: 30.0),
      child: GestureDetector(
        onTap: () {
          // MODIFIED: Use the showModalBottomSheet from the previous step
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) {
              return HormonesInfoScreen();
            },
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14), // Button height
          decoration: BoxDecoration(
            color: const Color(0xFFE91E63), // Main pink color
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE91E63).withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center, // Center the content
            children: [
              Icon(Icons.bubble_chart_outlined, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text(
                'Hormones & Cycle Info',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  // -----------------------------------------------------------------

  Widget _buildQuickLogSection() {
    // ... (This function is correct, no changes needed) ...
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.0),
            child: Text(
              'Quick Log',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(height: 20),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildQuickLogButton(
                  icon: Icons.water_drop_outlined,
                  label: 'Period',
                  color: const Color(0xFFE91E63),
                  onTap: () => Navigator.pushNamed(context, '/log-period')
                      .then((_) => _loadCycleData()),
                ),
                const SizedBox(width: 20),
                _buildQuickLogButton(
                  icon: Icons.healing_outlined,
                  label: 'Symptoms',
                  color: const Color(0xFFE91E63),
                  onTap: () => Navigator.pushNamed(context, '/log-symptoms')
                      .then((_) => _loadCycleData()),
                ),
                const SizedBox(width: 20),
                _buildQuickLogButton(
                  icon: Icons.sentiment_satisfied_outlined,
                  label: 'Mood',
                  color: const Color(0xFFE91E63),
                  onTap: () => Navigator.pushNamed(context, '/log-mood')
                      .then((_) => _loadCycleData()),
                ),
                const SizedBox(width: 20),
                _buildQuickLogButton(
                  icon: Icons.favorite_outline,
                  label: 'Activity',
                  color: const Color(0xFFE91E63),
                  onTap: () => Navigator.pushNamed(context, '/log-activity')
                      .then((_) => _loadCycleData()),
                ),
                const SizedBox(width: 20),
                _buildQuickLogButton(
                  icon: Icons.note_alt_outlined,
                  label: 'Notes',
                  color: const Color(0xFFE91E63),
                  onTap: () => Navigator.pushNamed(context, '/log-notes')
                      .then((_) => _loadCycleData()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickLogButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    // ... (This function is correct, no changes needed) ...
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.1),
              border: Border.all(
                color: color.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              color: color,
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
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
    InsightsScreen(),  // Tab 1: Insights
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
            label: 'Analytics',
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