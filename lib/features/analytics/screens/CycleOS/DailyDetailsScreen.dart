import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class DailyDetailsScreen extends StatefulWidget {
  final DateTime selectedDate;

  const DailyDetailsScreen({
    Key? key,
    required this.selectedDate,
  }) : super(key: key);

  @override
  State<DailyDetailsScreen> createState() => _DailyDetailsScreenState();
}

class _DailyDetailsScreenState extends State<DailyDetailsScreen> {
  Map<String, dynamic> dailyData = {};
  Map<String, dynamic>? periodSettings; // To store cycle length etc.
  bool isLoading = true;
  String docIdPeriod = '';
  String docIdSymptoms = '';
  String docIdMood = '';
  String docIdActivity = '';
  String docIdNotes = '';

  @override
  void initState() {
    super.initState();
    _loadAllData(); // Load settings and daily logs
  }

  // Combined loading function
  Future<void> _loadAllData() async {
    setState(() => isLoading = true);
    await _loadPeriodSettings(); // Load settings first
    await _loadDailyData(); // Then load daily logs
    setState(() => isLoading = false);
  }

  // Function to load period settings (needed for cycle day/phase calculation)
  Future<void> _loadPeriodSettings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('period_settings')
          .doc('config')
          .get();
      if (doc.exists && mounted) {
        setState(() {
          periodSettings = doc.data();
        });
      }
    } catch (e) {
      print("Error loading period settings: $e");
      // Handle error appropriately, maybe show a message
    }
  }


  Future<void> _loadDailyData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => isLoading = false); // Stop loading if no user
      return;
    }

    // Don't set isLoading = true here if called after initState via .then()
    // setState(() => isLoading = true);

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(widget.selectedDate);

      // --- Fetch Logs using Date String as ID or Key ---
      // This assumes you save logs with the date string as the document ID
      // OR have a 'dateString' field to query. Using date as ID is simpler.

      // Example using date string as document ID:
      final periodDoc = await FirebaseFirestore.instance
          .collection('users').doc(user.uid).collection('period_logs').doc(dateStr).get();
      final symptomsDoc = await FirebaseFirestore.instance
          .collection('users').doc(user.uid).collection('symptom_logs').doc(dateStr).get();
      final moodDoc = await FirebaseFirestore.instance
          .collection('users').doc(user.uid).collection('mood_logs').doc(dateStr).get();
      final activitiesDoc = await FirebaseFirestore.instance
          .collection('users').doc(user.uid).collection('activity_logs').doc(dateStr).get();
      final notesDoc = await FirebaseFirestore.instance
          .collection('users').doc(user.uid).collection('notes').doc(dateStr).get();

      // Store doc IDs for editing
      docIdPeriod = periodDoc.exists ? periodDoc.id : '';
      docIdSymptoms = symptomsDoc.exists ? symptomsDoc.id : '';
      docIdMood = moodDoc.exists ? moodDoc.id : '';
      docIdActivity = activitiesDoc.exists ? activitiesDoc.id : '';
      docIdNotes = notesDoc.exists ? notesDoc.id : '';


      if (mounted) {
        setState(() {
          dailyData = {
            'period': periodDoc.exists ? periodDoc.data() : null,
            'symptoms': symptomsDoc.exists ? symptomsDoc.data() : null,
            'mood': moodDoc.exists ? moodDoc.data() : null,
            'activities': activitiesDoc.exists ? activitiesDoc.data() : null,
            'notes_log': notesDoc.exists ? notesDoc.data() : null,
          };
          // isLoading = false; // Set loading false only if called from initState
        });
      }
    } catch (e) {
      print("Error loading daily data: $e");
      if (mounted) {
        // Optionally show an error message
        // setState(() => isLoading = false);
      }
    } finally {
      // Ensure loading indicator stops if it was started in initState
      if (isLoading && mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  // --- Helper to calculate Cycle Day and Phase ---
  Map<String, dynamic> _getCycleInfo() {
    if (periodSettings == null || periodSettings!['lastPeriodDate'] == null) {
      return {'cycleDay': 'N/A', 'phase': 'Setup Required'};
    }

    final lastPeriod = (periodSettings!['lastPeriodDate'] as Timestamp).toDate();
    final cycleLength = (periodSettings!['cycleLengthDays'] as num?)?.toInt() ?? 28;
    final periodLength = (periodSettings!['periodLengthDays'] as num?)?.toInt() ?? 5;

    // Calculate difference based on the *selected* date, not today
    final selectedDayOnly = DateTime(widget.selectedDate.year, widget.selectedDate.month, widget.selectedDate.day);
    final daysSinceStart = selectedDayOnly.difference(lastPeriod).inDays;

    if (daysSinceStart < 0) {
      return {'cycleDay': 'N/A', 'phase': 'Before Last Period'};
    }

    final calculatedCycleDay = (daysSinceStart % cycleLength) + 1;
    final currentPhase = _getCurrentPhase(calculatedCycleDay, periodLength, cycleLength);

    return {'cycleDay': calculatedCycleDay.toString(), 'phase': currentPhase};
  }

  // Copied from period_cycle.dart (or move to a shared utility file)
  String _getCurrentPhase(int day, int periodLength, int cycleLength) {
    periodLength = periodLength.clamp(1, cycleLength - 3);
    int approxOvulationDay = cycleLength - 14;
    int follicularEnd = approxOvulationDay - 3;
    int ovulationStart = approxOvulationDay - 2;
    int ovulationEnd = approxOvulationDay + 1;

    if (day <= periodLength) return 'Menstrual Phase';
    if (day <= follicularEnd) return 'Follicular Phase';
    if (day >= ovulationStart && day <= ovulationEnd) return 'Ovulation Phase';
    return 'Luteal Phase';
  }
  // --- End Helper ---

  @override
  Widget build(BuildContext context) {
    // Calculate cycle info here to use in buildDateSection
    final cycleInfo = _getCycleInfo();

    return Scaffold(
      backgroundColor: const Color(0xFFF5E6F1),
      appBar: AppBar(
        // ... AppBar code remains the same ...
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'DAILY DETAILS',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.black,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.black),
            onPressed: () {
              // TODO: Navigate to settings
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Color(0xFFE91E63))))
          : SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // UPDATED: Use dynamic cycle info
            _buildDateSection(cycleInfo['cycleDay'], cycleInfo['phase']),
            const SizedBox(height: 24),

            // Show "Add" button if data is null, otherwise show summary card
            _buildOptionalCard(
              data: dailyData['period'],
              title: 'PERIOD FLOW',
              icon: Icons.water_drop_outlined,
              valueBuilder: (data) => data['flowIntensity']?.toString() ?? 'Not Logged',
              routeName: '/log-period',
              docId: docIdPeriod,
            ),
            _buildOptionalCard(
              data: dailyData['symptoms'],
              title: 'SYMPTOMS',
              icon: Icons.healing_outlined,
              valueBuilder: (data) {
                final physical = (data['physicalSymptoms'] as List?)?.join(', ') ?? '';
                final emotional = (data['emotionalSymptoms'] as List?)?.join(', ') ?? '';
                final all = [physical, emotional].where((s) => s.isNotEmpty).join(' • ');
                return all.isNotEmpty ? all : 'Not Logged';
              },
              routeName: '/log-symptoms',
              docId: docIdSymptoms,
            ),
            _buildOptionalCard(
              data: dailyData['mood'],
              title: 'MOOD',
              icon: Icons.sentiment_satisfied_outlined,
              valueBuilder: (data) {
                // Mood data structure might need adjustment based on how it's saved
                final moods = (data['moods'] as List?)?.map((m) => m.replaceAll(RegExp(r'[0-9]'), '')).toSet().join(', ') ?? ''; // Example: remove index if saved like 'Happy0'
                return moods.isNotEmpty ? moods : 'Not Logged';
              },
              routeName: '/log-mood',
              docId: docIdMood,
            ),
            _buildOptionalCard(
              data: dailyData['activities'],
              title: 'ACTIVITIES',
              icon: Icons.directions_run, // Changed icon
              valueBuilder: (data) {
                final activities = (data['activities'] as List?)?.join(', ') ?? '';
                return activities.isNotEmpty ? activities : 'Not Logged';
              },
              routeName: '/log-activity',
              docId: docIdActivity,
            ),
            _buildOptionalCard(
              data: dailyData['notes_log'],
              title: 'NOTES',
              icon: Icons.note_alt_outlined,
              valueBuilder: (data) => data['notes']?.toString() ?? 'No Notes',
              routeName: '/log-notes',
              isNote: true, // Special handling for notes display
              docId: docIdNotes,
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
      // bottomNavigationBar: _buildBottomNav(), // Kept the bottom nav
    );
  }

  // UPDATED: Dynamic Date Section
  Widget _buildDateSection(String cycleDayStr, String phaseStr) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          DateFormat('EEEE, MMMM d').format(widget.selectedDate), // More detailed date
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Cycle Day $cycleDayStr',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black54,
          ),
        ),
        Text(
          'Phase: $phaseStr',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black54,
          ),
        ),
      ],
    );
  }


  // --- Generic Card Builder ---
  Widget _buildOptionalCard({
    required Map<String, dynamic>? data,
    required String title,
    required IconData icon,
    required String Function(Map<String, dynamic>) valueBuilder,
    required String routeName,
    required String docId, // Pass the document ID
    bool isNote = false, // Flag for notes styling
  }) {
    bool hasData = data != null;
    String displayValue = hasData ? valueBuilder(data) : (isNote ? 'No notes recorded for this day.' : 'Not Logged');

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                      letterSpacing: 0.5,
                    ),
                  ),
                  GestureDetector(
                    // Pass date and potentially existing data/ID to the log screen
                    onTap: () => Navigator.pushNamed(
                        context,
                        routeName,
                        arguments: {
                          'selectedDate': widget.selectedDate,
                          'existingData': data, // Pass existing data
                          'docId': docId, // Pass the doc ID
                        }
                    ).then((_) => _loadDailyData()), // Refresh after returning
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFCE4EC),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        hasData ? 'Edit' : 'Add', // Change button text
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFE91E63),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (isNote) // Special display for notes
                Text(
                  displayValue,
                  style: TextStyle(
                    fontSize: 14,
                    color: hasData ? Colors.grey[700] : Colors.grey[500], // Grey out if no notes
                    fontStyle: hasData ? FontStyle.normal : FontStyle.italic,
                    height: 1.5,
                  ),
                )
              else // Display for other logs
                Row(
                  children: [
                    if (hasData) // Only show icon if data exists
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFCE4EC),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          icon,
                          color: const Color(0xFFE91E63),
                          size: 20,
                        ),
                      ),
                    if (hasData) const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        displayValue,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: hasData ? FontWeight.w600 : FontWeight.normal,
                          color: hasData ? Colors.grey[700] : Colors.grey[500],
                          fontStyle: hasData ? FontStyle.normal : FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 16), // Spacing between cards
      ],
    );
  }


  // --- Bottom Navigation ---
  Widget _buildBottomNav() {
    // ... Bottom Nav code remains the same ...
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: BottomNavigationBar(
        backgroundColor: Colors.transparent, // Make it transparent
        elevation: 0, // Remove elevation
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFFE91E63),
        unselectedItemColor: Colors.grey[400],
        selectedFontSize: 12,
        unselectedFontSize: 12,
        currentIndex: 1, // Highlight Calendar if this is the details view? Or keep 0?
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home), // Add active icon
            label: 'Home', // Changed label
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined),
            activeIcon: Icon(Icons.calendar_today),
            label: 'Calendar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.insert_chart_outlined),
            activeIcon: Icon(Icons.insert_chart),
            label: 'Insights',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
        onTap: (index) {
          // Handle bottom navigation tap
          switch (index) {
            case 0:
            // Navigate to Home (PeriodDashboard) - check if already there?
              if (ModalRoute.of(context)?.settings.name != '/') {
                Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
              }
              break;
            case 1:
            // Already on Calendar/Details related flow, maybe just pop or do nothing?
            // Or open the calendar drawer if on dashboard?
            // Since this is DailyDetails, maybe pop back to dashboard?
            // Navigator.pop(context); // Example: Go back to dashboard/calendar view
              break;
            case 2:
            // Navigate to Insights
              Navigator.pushNamed(context, '/insights'); // Make sure '/insights' route exists
              break;
            case 3:
            // Navigate to Settings
              Navigator.pushNamed(context, '/settings'); // Make sure '/settings' route exists
              break;
          }
        },
      ),
    );
  }
}