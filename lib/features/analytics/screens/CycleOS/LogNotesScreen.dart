import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // Import DateFormat

class LogNotesScreen extends StatefulWidget {
  final DateTime selectedDate;
  final Map<String, dynamic>? existingData;
  final String? docId;

  const LogNotesScreen({
    Key? key,
    required this.selectedDate,
    this.existingData,
    this.docId,
  }) : super(key: key);

  @override
  State<LogNotesScreen> createState() => _LogNotesScreenState();
}

class _LogNotesScreenState extends State<LogNotesScreen> {
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Pre-fill notes if editing
    if (widget.existingData != null) {
      _notesController.text = widget.existingData!['notes'] ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        // ... AppBar code ...
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text( // Dynamic Title
          widget.existingData == null ? 'LOG NOTES' : 'EDIT NOTES',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black, letterSpacing: 0.5,),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Date: ${DateFormat('MMMM d, yyyy').format(widget.selectedDate)}', // Show selected date
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87,),
            ),
            const SizedBox(height: 20), // Reduced space

            // Notes Input
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16), // Adjust padding
                decoration: BoxDecoration(
                  color: const Color(0xFFF5E6F1), // Consistent light background
                  borderRadius: BorderRadius.circular(16), // Slightly less rounded
                  border: Border.all( color: Colors.grey[300]!, width: 1,), // Subtle border
                ),
                child: TextField(
                  controller: _notesController,
                  maxLines: null, // Allow infinite lines
                  expands: true,
                  keyboardType: TextInputType.multiline, // Explicitly set keyboard type
                  textAlignVertical: TextAlignVertical.top,
                  decoration: InputDecoration( // Use InputDecoration for consistency
                    hintText: 'Add any notes, thoughts, or observations for the day...', // More general hint
                    hintStyle: TextStyle(color: Colors.grey[500], fontSize: 15,), // Adjusted hint style
                    border: InputBorder.none, // Remove default border
                    contentPadding: EdgeInsets.zero, // Remove extra padding inside TextField
                  ),
                  style: const TextStyle(fontSize: 15, color: Colors.black87, height: 1.5,), // Adjusted text style
                ),
              ),
            ),

            const SizedBox(height: 30),

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _saveNotes,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE91E63),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  elevation: 4,
                ),
                child: const Text('SAVE', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 1,),),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // UPDATED Save Logic
  Future<void> _saveNotes() async {
    final notesText = _notesController.text.trim();
    // Allow saving empty notes to clear existing ones if needed
    // if (notesText.isEmpty) {
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     const SnackBar(content: Text('Please enter some notes'), backgroundColor: Colors.red,),
    //   );
    //   return;
    // }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final dateKey = DateFormat('yyyy-MM-dd').format(widget.selectedDate);
    final logRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('notes') // Changed collection name to 'notes'
        .doc(dateKey); // Use date as document ID

    final logData = {
      'date': Timestamp.fromDate(widget.selectedDate),
      'dateString': dateKey,
      'notes': notesText,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (widget.existingData == null) {
      logData['createdAt'] = FieldValue.serverTimestamp();
    }


    try {
      // Use set with merge: true to create or update
      await logRef.set(logData, SetOptions(merge: true));

      if (mounted) {
        Navigator.pop(context); // Go back
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(notesText.isEmpty ? 'Notes cleared successfully!' : 'Notes saved successfully!'), // Dynamic message
            backgroundColor: const Color(0xFFE91E63),
          ),
        );
      }
    } catch (e) {
      print("Error saving notes: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving notes: ${e.toString()}'),
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