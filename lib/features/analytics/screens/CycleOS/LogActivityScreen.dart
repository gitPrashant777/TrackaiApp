import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart'; // Import DateFormat

class LogActivityScreen extends StatefulWidget {
  final DateTime selectedDate;
  final Map<String, dynamic>? existingData;
  final String? docId;

  const LogActivityScreen({
    Key? key,
    required this.selectedDate,
    this.existingData,
    this.docId,
  }) : super(key: key);

  @override
  State<LogActivityScreen> createState() => _LogActivityScreenState();
}

class _LogActivityScreenState extends State<LogActivityScreen> {
  List<String> selectedActivities = [];
  final TextEditingController _exerciseTypeController = TextEditingController(text: 'Yoga'); // Use controller
  final TextEditingController _exerciseDurationController = TextEditingController(text: '45'); // Use controller for duration
  String exerciseIntensity = 'Medium';
  bool protectedSexualActivity = false;
  final TextEditingController _notesController = TextEditingController();

  final List<Map<String, dynamic>> activityTypes = [
    {'name': 'Exercise', 'icon': Icons.directions_run},
    {'name': 'Sexual Activity', 'icon': Icons.favorite_border}, // Changed icon
    {'name': 'Socializing', 'icon': Icons.people_outline}, // Changed icon
    {'name': 'Relaxation', 'icon': Icons.self_improvement}, // New
    {'name': 'Work/Study', 'icon': Icons.work_outline}, // New
    {'name': 'Hobby', 'icon': Icons.palette_outlined}, // New
    // Add more relevant activities
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existingData != null) {
      final data = widget.existingData!;
      selectedActivities = List<String>.from(data['activities'] ?? []);
      _exerciseTypeController.text = data['exerciseType'] ?? 'Yoga';
      _exerciseDurationController.text = (data['exerciseDuration'] as num?)?.toString() ?? '45';
      exerciseIntensity = data['exerciseIntensity'] ?? 'Medium';
      protectedSexualActivity = data['protectedSexualActivity'] ?? false;
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
          widget.existingData == null ? 'LOG ACTIVITIES' : 'EDIT ACTIVITIES',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black, letterSpacing: 0.5,),
        ),
        centerTitle: true,
        actions: [
          // Removed lock icon
        ],
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
            const Text('SELECT ACTIVITIES', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black, letterSpacing: 0.5,),), // Updated title
            const SizedBox(height: 16),
            _buildActivityGrid(),
            const SizedBox(height: 30),

            if (selectedActivities.contains('Exercise')) ...[
              _buildExerciseDetails(),
              const SizedBox(height: 24),
            ],
            if (selectedActivities.contains('Sexual Activity')) ...[
              _buildSexualActivitySection(),
              const SizedBox(height: 24),
            ],
            _buildNotesSection(),
            const SizedBox(height: 40),
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityGrid() {
    // Make grid responsive
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth > 600 ? 4 : 3; // Adjust columns based on width
    final childAspectRatio = screenWidth > 600 ? 1.2 : 1.1;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: activityTypes.length,
      itemBuilder: (context, index) {
        final activity = activityTypes[index];
        final isSelected = selectedActivities.contains(activity['name']);

        return GestureDetector(
          onTap: () {
            setState(() {
              if (isSelected) {
                selectedActivities.remove(activity['name']);
              } else {
                selectedActivities.add(activity['name']);
              }
            });
          },
          child: Container(
            padding: const EdgeInsets.all(12), // Adjust padding
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFFFE4EC) : Colors.white, // Highlight color
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? const Color(0xFFE91E63) : Colors.grey[300]!,
                width: isSelected ? 1.5 : 1,
              ),
              boxShadow: isSelected ? [ BoxShadow( color: Color(0xFFE91E63).withOpacity(0.1), blurRadius: 5, spreadRadius: 1 )] : [BoxShadow( color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2),)], // Subtle shadow
            ),
            child: Column( // Use Column
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  activity['icon'],
                  color: isSelected ? const Color(0xFFE91E63) : Colors.grey[500],
                  size: 26, // Adjust size
                ),
                const SizedBox(height: 8),
                Text(
                  activity['name'],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12, // Adjust size
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? Colors.black87 : Colors.grey[700],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildExerciseDetails() {
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
          const Text('EXERCISE DETAILS', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black, letterSpacing: 0.5,),),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                // Use editable TextField for Type
                child: TextField(
                  controller: _exerciseTypeController,
                  decoration: _inputDecoration('Type (e.g., Yoga, Running)'),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                // Use editable TextField for Duration
                child: TextField(
                  controller: _exerciseDurationController,
                  decoration: _inputDecoration('Duration (min)'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('INTENSITY', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black54, letterSpacing: 0.5,),),
          const SizedBox(height: 12),
          Row( // Use ToggleButtons for a compact intensity selector
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildIntensityChip('Light'),
              _buildIntensityChip('Medium'),
              _buildIntensityChip('Intense'),
            ],
          ),
        ],
      ),
    );
  }

  // Helper for consistent TextField decoration
  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(fontSize: 13, color: Colors.grey[600]),
      filled: true,
      fillColor: const Color(0xFFF5E6F1),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), // Adjust padding
      isDense: true, // Make it more compact
    );
  }


  Widget _buildIntensityChip(String intensity) {
    final isSelected = exerciseIntensity == intensity;
    return Expanded(
      child: Padding( // Add padding around chips
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: GestureDetector(
          onTap: () => setState(() => exerciseIntensity = intensity),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10), // Adjust padding
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFE91E63) : const Color(0xFFF5E6F1).withOpacity(0.7), // Use background with opacity
              borderRadius: BorderRadius.circular(12),
              border: isSelected ? null : Border.all(color: Colors.grey[300]!, width: 1), // Optional border for unselected
            ),
            child: Center(
              child: Text(
                intensity,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : Colors.black54,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSexualActivitySection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), // Reduced padding
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2),),],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('SEXUAL ACTIVITY', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black, letterSpacing: 0.5,),),
          Row(
            children: [
              Text('Protected', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[700],),),
              const SizedBox(width: 8),
              Switch(
                value: protectedSexualActivity,
                onChanged: (value) => setState(() => protectedSexualActivity = value),
                activeColor: const Color(0xFFE91E63),
                inactiveThumbColor: Colors.grey[300],
                inactiveTrackColor: Colors.grey[200],
              ),
            ],
          ),
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
        boxShadow: [ BoxShadow( color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4),),],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('NOTES', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black, letterSpacing: 0.5,),),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController, // Use controller
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Add details about activities, energy levels, etc...', // Updated hint
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
              filled: true,
              fillColor: const Color(0xFFF5E6F1), // Consistent background
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none,),
            ),
            // onChanged: (value) => notes = value, // Not needed
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
        onPressed: _saveActivityLog,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFE91E63),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          elevation: 4,
        ),
        child: const Text('SAVE', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 1,),),
      ),
    );
  }

  // UPDATED Save Logic
  Future<void> _saveActivityLog() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final dateKey = DateFormat('yyyy-MM-dd').format(widget.selectedDate);
    final logRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('activity_logs')
        .doc(dateKey); // Use date as document ID

    // Parse duration safely
    final duration = int.tryParse(_exerciseDurationController.text) ?? 0;

    final logData = {
      'date': Timestamp.fromDate(widget.selectedDate),
      'dateString': dateKey,
      'activities': selectedActivities,
      // Only save exercise details if Exercise was selected
      'exerciseType': selectedActivities.contains('Exercise') ? _exerciseTypeController.text : null,
      'exerciseDuration': selectedActivities.contains('Exercise') ? duration : null,
      'exerciseIntensity': selectedActivities.contains('Exercise') ? exerciseIntensity : null,
      // Only save sexual activity details if selected
      'protectedSexualActivity': selectedActivities.contains('Sexual Activity') ? protectedSexualActivity : null,
      'notes': _notesController.text.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (widget.existingData == null) {
      logData['createdAt'] = FieldValue.serverTimestamp();
    }

    try {
      await logRef.set(logData, SetOptions(merge: true));

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Activity log saved successfully!'),
            backgroundColor: Color(0xFFE91E63),
          ),
        );
      }
    } catch (e) {
      print("Error saving activity log: $e");
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
    _notesController.dispose();
    _exerciseTypeController.dispose();
    _exerciseDurationController.dispose();
    super.dispose();
  }
}