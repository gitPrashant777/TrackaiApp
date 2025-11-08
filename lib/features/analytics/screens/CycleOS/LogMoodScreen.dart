import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // Import DateFormat

class LogMoodScreen extends StatefulWidget {
  final DateTime selectedDate;
  final Map<String, dynamic>? existingData;
  final String? docId;

  const LogMoodScreen({
    Key? key,
    required this.selectedDate,
    this.existingData,
    this.docId,
  }) : super(key: key);

  @override
  State<LogMoodScreen> createState() => _LogMoodScreenState();
}

class _LogMoodScreenState extends State<LogMoodScreen> {
  // Use unique keys for selected moods if needed, or just names if duplicates allowed
  List<String> selectedMoods = []; // Store just the names for simplicity now
  double moodIntensity = 5; // Default to neutral
  final TextEditingController _notesController = TextEditingController();

  // Consider making this list more diverse and unique
  final List<Map<String, dynamic>> moodOptions = [
    {'name': 'Happy', 'emoji': '😊'},
    {'name': 'Calm', 'emoji': '😌'},
    {'name': 'Energetic', 'emoji': '⚡'}, // Different emoji
    {'name': 'Sad', 'emoji': '😢'},
    {'name': 'Stressed', 'emoji': '😫'}, // New mood
    {'name': 'Irritable', 'emoji': '😠'},
    {'name': 'Content', 'emoji': '🙂'}, // New mood
    {'name': 'Anxious', 'emoji': '😰'},
    {'name': 'Tired', 'emoji': '😴'}, // New mood
  ];


  @override
  void initState() {
    super.initState();
    if (widget.existingData != null) {
      final data = widget.existingData!;
      // Assuming 'moods' is stored as a List<String> of names
      selectedMoods = List<String>.from(data['moods'] ?? []);
      moodIntensity = (data['moodIntensity'] as num?)?.toDouble() ?? 5.0;
      _notesController.text = data['notes'] ?? '';
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCE4EC), // Light pink background
      appBar: AppBar(
        // ... AppBar code ...
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton( // Changed icon
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text( // Dynamic title
          widget.existingData == null ? 'LOG MOOD' : 'EDIT MOOD',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black, letterSpacing: 0.5,),
        ),
        centerTitle: true,
        actions: [
          // Removed lock icon, add if needed
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center( // Center the date
              child: Text(
                'Date: ${DateFormat('MMMM d, yyyy').format(widget.selectedDate)}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87,),
              ),
            ),
            const SizedBox(height: 20), // Reduced space
            const Center(
              child: Text( 'HOW ARE YOU FEELING?', style: TextStyle( fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black, letterSpacing: 0.5,),), // Adjusted size
            ),
            const SizedBox(height: 24), // Reduced space
            _buildMoodGrid(),
            const SizedBox(height: 24),
            _buildMoodIntensitySection(),
            const SizedBox(height: 24),
            _buildNotesSection(),
            const SizedBox(height: 40),
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildMoodGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 1, // Keep square
      ),
      itemCount: moodOptions.length, // Use actual length
      itemBuilder: (context, index) {
        final mood = moodOptions[index];
        final isSelected = selectedMoods.contains(mood['name']); // Select by name

        return GestureDetector(
          onTap: () {
            setState(() {
              final name = mood['name'];
              if (isSelected) {
                selectedMoods.remove(name);
              } else {
                selectedMoods.add(name); // Add only the name
              }
            });
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? const Color(0xFFE91E63) : Colors.transparent,
                width: 2, // Slightly thinner border
              ),
              boxShadow: [
                BoxShadow( color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 3), ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text( mood['emoji'], style: const TextStyle(fontSize: 40), ), // Slightly smaller emoji
                const SizedBox(height: 8),
                Text(
                  mood['name'],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12, // Smaller text
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500, // Adjusted weight
                    color: isSelected ? Colors.black87 : Colors.black54,
                  ),
                ),
                // Consider removing check for cleaner look, border shows selection
                // if (isSelected) Padding( padding: EdgeInsets.only(top: 4), child: Icon( Icons.check_circle, color: Color(0xFFE91E63), size: 16,), ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMoodIntensitySection() {
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
          const Text('MOOD INTENSITY', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black, letterSpacing: 0.5,),),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: const Color(0xFFE91E63),
                    inactiveTrackColor: const Color(0xFFE91E63).withOpacity(0.2),
                    thumbColor: const Color(0xFFE91E63),
                    overlayColor: const Color(0xFFE91E63).withOpacity(0.2),
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12), // Smaller thumb
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 24), // Smaller overlay
                    trackHeight: 4, // Thinner track
                  ),
                  child: Slider(
                    value: moodIntensity,
                    min: 0, // Start from 0
                    max: 10,
                    divisions: 10,
                    onChanged: (value) => setState(() => moodIntensity = value),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFCE4EC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${moodIntensity.toInt()} - ${_getMoodIntensityLabel(moodIntensity)}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFFE91E63),),
                ),
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
              hintText: 'Add details about your mood, potential triggers, or context...', // Updated hint
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13,),
              filled: true,
              fillColor: const Color(0xFFFCE4EC), // Match background
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
        onPressed: _saveMoodLog,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFE91E63),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          elevation: 4,
        ),
        child: const Text('SAVE', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 1,),),
      ),
    );
  }

  String _getMoodIntensityLabel(double value) {
    if (value == 0) return 'None';
    if (value <= 3) return 'Low';
    if (value <= 6) return 'Moderate';
    if (value <= 9) return 'High';
    return 'Very High'; // Adjusted label
  }

  // UPDATED Save Logic
  Future<void> _saveMoodLog() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final dateKey = DateFormat('yyyy-MM-dd').format(widget.selectedDate);
    final logRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('mood_logs')
        .doc(dateKey); // Use date as document ID

    final logData = {
      'date': Timestamp.fromDate(widget.selectedDate),
      'dateString': dateKey,
      'moods': selectedMoods, // Save the list of names
      'moodIntensity': moodIntensity,
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
            content: Text('Mood log saved successfully!'),
            backgroundColor: Color(0xFFE91E63),
          ),
        );
      }
    } catch (e) {
      print("Error saving mood log: $e");
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
    super.dispose();
  }
}