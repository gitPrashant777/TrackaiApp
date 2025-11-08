import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // Import DateFormat

class LogPeriodScreen extends StatefulWidget {
  final DateTime selectedDate;
  final Map<String, dynamic>? existingData; // Optional existing data
  final String? docId; // Optional document ID for updating

  const LogPeriodScreen({
    Key? key,
    required this.selectedDate,
    this.existingData,
    this.docId,
  }) : super(key: key);

  @override
  State<LogPeriodScreen> createState() => _LogPeriodScreenState();
}

class _LogPeriodScreenState extends State<LogPeriodScreen> {
  String selectedFlow = '';
  bool isStartOfPeriod = false;
  bool isEndOfPeriod = false;
  double crampIntensity = 0; // Default to 0 (no pain)

  @override
  void initState() {
    super.initState();
    // Pre-fill data if editing
    if (widget.existingData != null) {
      final data = widget.existingData!;
      selectedFlow = data['flowIntensity'] ?? '';
      isStartOfPeriod = data['isStartOfPeriod'] ?? false;
      isEndOfPeriod = data['isEndOfPeriod'] ?? false;
      // Handle potential double/int from Firestore
      crampIntensity = (data['crampIntensity'] as num?)?.toDouble() ?? 0.0;
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5E6F1),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text( // Dynamic title based on add/edit
          widget.existingData == null ? 'LOG PERIOD' : 'EDIT PERIOD LOG',
          style: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black, letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),

    child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                'Date: ${DateFormat('MMMM d, yyyy').format(widget.selectedDate)}', // Show selected date
                style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 30),
            _buildFlowIntensitySection(),
            const SizedBox(height: 24),

            _buildCrampIntensitySection(),
            const SizedBox(height: 40),
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  // _buildFlowIntensitySection, _buildFlowOption, _buildPeriodToggles,
  // _buildToggleCard remain mostly the same, ensure they use state variables

  Widget _buildFlowIntensitySection() {
    return Container(
      padding: const EdgeInsets.all(24),
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
          const Text(
            'FLOW INTENSITY',
            style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black, letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildFlowOption('Spotting', Icons.water_drop_outlined),
              _buildFlowOption('Light', Icons.water_drop),
              _buildFlowOption('Medium', Icons.opacity), // Changed icon
              _buildFlowOption('Heavy', Icons.waves),    // Changed icon
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFlowOption(String label, IconData icon) {
    final isSelected = selectedFlow == label;
    return GestureDetector(
      onTap: () => setState(() => selectedFlow = label),
      child: Column(
        children: [
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? const Color(0xFFE91E63).withOpacity(0.2) : Colors.grey[100],
              border: Border.all(
                color: isSelected ? const Color(0xFFE91E63) : Colors.grey[300]!,
                width: 2,
              ),
            ),
            child: Icon(
              icon,
              color: isSelected ? const Color(0xFFE91E63) : Colors.grey[400],
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? Colors.black87 : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildToggleCard(String label, bool value, Function(bool) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), // Reduced vertical padding
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [ BoxShadow( color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2),),],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text( label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.black87,),),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFFE91E63),
            inactiveThumbColor: Colors.grey[300],
            inactiveTrackColor: Colors.grey[200],
          ),
        ],
      ),
    );
  }

  Widget _buildCrampIntensitySection() {
    return Container(
      padding: const EdgeInsets.all(20), // Reduced padding
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [ BoxShadow( color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4),),],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('CRAMP INTENSITY', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black, letterSpacing: 0.5,),),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                '${crampIntensity.toInt()}',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFFE91E63),),
              ),
              const SizedBox(width: 12),
              Text( _getCrampLabel(crampIntensity), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.grey[700],),),
            ],
          ),
          const SizedBox(height: 10), // Reduced space
          SliderTheme( // Consistent theme
            data: SliderThemeData(
              activeTrackColor: const Color(0xFFE91E63),
              inactiveTrackColor: const Color(0xFFE91E63).withOpacity(0.2),
              thumbColor: const Color(0xFFE91E63),
              overlayColor: const Color(0xFFE91E63).withOpacity(0.2),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
              trackHeight: 4, // Thinner track
            ),
            child: Slider(
              value: crampIntensity,
              min: 0, // Start from 0 for "No Pain"
              max: 10,
              divisions: 10, // 11 points (0-10)
              onChanged: (value) => setState(() => crampIntensity = value),
            ),
          ),
          // Optional: Labels for min/max
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('0', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                Text('10', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          )
        ],
      ),
    );
  }


  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _savePeriodLog,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFE91E63),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          elevation: 4,
        ),
        child: const Text(
          'SAVE',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 1,),
        ),
      ),
    );
  }

  String _getCrampLabel(double value) {
    if (value == 0) return 'No Pain'; // Handle 0
    if (value <= 3) return 'Mild Pain';
    if (value <= 6) return 'Moderate Pain';
    if (value <= 9) return 'Severe Pain'; // Adjusted range
    return 'Extreme Pain';
  }

  // UPDATED Save Logic
  Future<void> _savePeriodLog() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Use selectedDate passed to the widget
    final dateKey = DateFormat('yyyy-MM-dd').format(widget.selectedDate);
    final logRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('period_logs')
        .doc(dateKey); // Use date as document ID

    final logData = {
      'date': Timestamp.fromDate(widget.selectedDate), // Store exact timestamp too
      'dateString': dateKey, // Store the string for easier querying if needed
      'flowIntensity': selectedFlow,
      'isStartOfPeriod': isStartOfPeriod,
      'isEndOfPeriod': isEndOfPeriod,
      'crampIntensity': crampIntensity,
      'createdAt': FieldValue.serverTimestamp(), // Use server timestamp for creation
      'updatedAt': FieldValue.serverTimestamp(), // Use server timestamp for update
    };

    try {
      // Use set with merge: true to create or update
      await logRef.set(logData, SetOptions(merge: true));

      if (mounted) {
        Navigator.pop(context); // Go back after saving
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Period log saved successfully!'),
            backgroundColor: Color(0xFFE91E63),
          ),
        );
      }
    } catch (e) {
      print("Error saving period log: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving log: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}