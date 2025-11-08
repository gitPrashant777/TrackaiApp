import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // Import DateFormat

class LogSymptomsScreen extends StatefulWidget {
  final DateTime selectedDate;
  final Map<String, dynamic>? existingData;
  final String? docId;

  const LogSymptomsScreen({
    Key? key,
    required this.selectedDate,
    this.existingData,
    this.docId,
  }) : super(key: key);

  @override
  State<LogSymptomsScreen> createState() => _LogSymptomsScreenState();
}

class _LogSymptomsScreenState extends State<LogSymptomsScreen> {
  List<String> selectedPhysicalSymptoms = [];
  List<String> selectedEmotionalSymptoms = [];
  double painIntensity = 0; // Default to 0
  final TextEditingController _notesController = TextEditingController(); // Use controller

  // Hardcoded lists - consider moving to constants or fetching if dynamic
  final List<Map<String, dynamic>> physicalSymptoms = [
    {'name': 'Headache', 'icon': Icons.sentiment_very_dissatisfied}, // More relevant icon?
    {'name': 'Bloating', 'icon': Icons.cloud_outlined}, // Different icon?
    {'name': 'Cramps', 'icon': Icons.healing},
    {'name': 'Fatigue', 'icon': Icons.battery_alert}, // Different icon?
    {'name': 'Nausea', 'icon': Icons.sick_outlined},
    {'name': 'Acne', 'icon': Icons.flare}, // Example new symptom
    // Add more...
  ];

  final List<Map<String, dynamic>> emotionalSymptoms = [
    {'name': 'Mood Swings', 'icon': Icons.swap_horiz}, // Different icon?
    {'name': 'Irritability', 'icon': Icons.sentiment_very_dissatisfied},
    {'name': 'Anxiety', 'icon': Icons.sentiment_neutral}, // Example
    {'name': 'Sadness', 'icon': Icons.sentiment_dissatisfied}, // Example
    // Add more...
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existingData != null) {
      final data = widget.existingData!;
      // Ensure lists are correctly typed from Firestore List<dynamic>
      selectedPhysicalSymptoms = List<String>.from(data['physicalSymptoms'] ?? []);
      selectedEmotionalSymptoms = List<String>.from(data['emotionalSymptoms'] ?? []);
      painIntensity = (data['painIntensity'] as num?)?.toDouble() ?? 0.0;
      _notesController.text = data['notes'] ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5E6F1),
      appBar: AppBar(
        // ... AppBar code ...
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text( // Dynamic title
          widget.existingData == null ? 'LOG SYMPTOMS' : 'EDIT SYMPTOMS',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black, letterSpacing: 0.5,),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                'Date: ${DateFormat('MMMM d, yyyy').format(widget.selectedDate)}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87,),
              ),
            ),
            const SizedBox(height: 30),
            const Text('COMMON SYMPTOMS', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black, letterSpacing: 0.5,),),
            const SizedBox(height: 16),
            const Text('Physical', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87,),),
            const SizedBox(height: 12),
            _buildSymptomGrid(physicalSymptoms, selectedPhysicalSymptoms),
            const SizedBox(height: 24),
            const Text('Emotional', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87,),),
            const SizedBox(height: 12),
            _buildSymptomGrid(emotionalSymptoms, selectedEmotionalSymptoms),
            const SizedBox(height: 30),
            _buildPainIntensitySection(),
            const SizedBox(height: 24),
            _buildNotesSection(),
            const SizedBox(height: 40),
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildSymptomGrid(List<Map<String, dynamic>> symptoms, List<String> selectedList) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, // Adjusted for potentially more items
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.0, // Make them more square
      ),
      itemCount: symptoms.length,
      itemBuilder: (context, index) {
        final symptom = symptoms[index];
        final isSelected = selectedList.contains(symptom['name']);

        return GestureDetector(
          onTap: () {
            setState(() {
              if (isSelected) {
                selectedList.remove(symptom['name']);
              } else {
                selectedList.add(symptom['name']);
              }
            });
          },
          child: Container(
            padding: const EdgeInsets.all(8), // Adjust padding
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFFFE4EC) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? const Color(0xFFE91E63) : Colors.grey[300]!,
                width: isSelected ? 1.5 : 1, // Adjust border width
              ),
              boxShadow: isSelected ? [ BoxShadow( color: Color(0xFFE91E63).withOpacity(0.1), blurRadius: 5, spreadRadius: 1 )] : null,
            ),
            child: Column( // Use Column for better layout
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  symptom['icon'],
                  color: isSelected ? const Color(0xFFE91E63) : Colors.grey[500], // Adjust color
                  size: 28, // Adjust size
                ),
                const SizedBox(height: 8),
                Text(
                  symptom['name'],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12, // Adjust font size
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? Colors.black87 : Colors.grey[700], // Adjust color
                  ),
                  maxLines: 1, // Allow wrapping if needed
                  overflow: TextOverflow.ellipsis,
                ),
                // Remove check icon for cleaner look if desired, border indicates selection
                // if (isSelected) SizedBox(height: 4),
                // if (isSelected) Icon(Icons.check, color: Color(0xFFE91E63), size: 14),
              ],
            ),
          ),
        );
      },
    );
  }


  Widget _buildPainIntensitySection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [ BoxShadow( color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4),),],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('PAIN INTENSITY', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black, letterSpacing: 0.5,),),
          const SizedBox(height: 16),
          Row(
            children: [
              Text( '${painIntensity.toInt()}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFFE91E63),),),
              const SizedBox(width: 12),
              Text(_getPainLabel(painIntensity), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[700],),),
            ],
          ),
          const SizedBox(height: 10),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: const Color(0xFFE91E63),
              inactiveTrackColor: const Color(0xFFE91E63).withOpacity(0.2),
              thumbColor: const Color(0xFFE91E63),
              overlayColor: const Color(0xFFE91E63).withOpacity(0.2),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
              trackHeight: 4,
            ),
            child: Slider(
              value: painIntensity,
              min: 0, // Start from 0
              max: 10,
              divisions: 10, // 11 points (0-10)
              onChanged: (value) => setState(() => painIntensity = value),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('0', style: TextStyle(fontSize: 12, color: Colors.grey[600])), // No Pain
                Text('10', style: TextStyle(fontSize: 12, color: Colors.grey[600])), // Extreme
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildNotesSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4),),],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('NOTES', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black, letterSpacing: 0.5,),),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController, // Use controller
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Add details about your symptoms, triggers, or relief methods...', // Updated hint
              hintStyle: TextStyle(color: Colors.grey[400]),
              filled: true,
              fillColor: const Color(0xFFF5E6F1), // Consistent background
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none,),
            ),
            // onChanged: (value) => notes = value, // No longer needed with controller
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _saveSymptomsLog,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFE91E63),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          elevation: 4,
        ),
        child: const Text('SAVE', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 1,),
        ),
      ),
    );
  }


  String _getPainLabel(double value) {
    if (value == 0) return 'No Pain';
    if (value <= 3) return 'Mild Pain';
    if (value <= 6) return 'Moderate Pain';
    if (value <= 9) return 'Severe Pain';
    return 'Extreme Pain';
  }

  // UPDATED Save Logic
  Future<void> _saveSymptomsLog() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final dateKey = DateFormat('yyyy-MM-dd').format(widget.selectedDate);
    final logRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('symptom_logs')
        .doc(dateKey); // Use date as document ID

    final logData = {
      'date': Timestamp.fromDate(widget.selectedDate),
      'dateString': dateKey,
      'physicalSymptoms': selectedPhysicalSymptoms,
      'emotionalSymptoms': selectedEmotionalSymptoms,
      'painIntensity': painIntensity,
      'notes': _notesController.text.trim(), // Get text from controller
      'updatedAt': FieldValue.serverTimestamp(), // Track updates
    };

    // Add createdAt only if creating a new document
    if (widget.existingData == null) {
      logData['createdAt'] = FieldValue.serverTimestamp();
    }

    try {
      // Use set with merge: true to create or update
      await logRef.set(logData, SetOptions(merge: true));

      if (mounted) {
        Navigator.pop(context); // Go back after saving
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Symptoms log saved successfully!'),
            backgroundColor: Color(0xFFE91E63),
          ),
        );
      }
    } catch (e) {
      print("Error saving symptoms log: $e");
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

  @override
  void dispose() {
    _notesController.dispose(); // Dispose controller
    super.dispose();
  }
}