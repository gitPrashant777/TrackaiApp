import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../../library/services/cloudinary_service.dart';
import '../admin_panel_screen.dart';

// Make sure this path is correct

// -------------------------------------------------------------------
// --- 1. REVIEWER SERVICE (Fixed create and delete logic) ---
// -------------------------------------------------------------------
class ReviewerService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'reviewers';

  static Future<String> createReviewer({
    required String name,
    required String title,
    required String location,
    required String linkedInUrl,
    required String quote,
    required List<String> expertise,
    required List<String> education,
    required List<String> awards,
    XFile? imageFile,
    Function(double)? onProgress,
  }) async {
    try {
      if (imageFile == null) {
        throw Exception('Profile image is required.');
      }

      onProgress?.call(0.3); // 30% - Starting upload

      print('Uploading reviewer image...');
      final CloudinaryUploadResult uploadResult =
      await CloudinaryService.uploadImage(
        imageFile: imageFile,
        folder: 'reviewers', // Specify the folder
      );

      // --- IMPORTANT FIX: Get both URL and publicId ---
      final String imageUrl = uploadResult.secureUrl;
      final String publicId = uploadResult.publicId;
      print('Reviewer image uploaded: $imageUrl');
      // -------------------------------------------------

      onProgress?.call(0.7); // 70% - Image uploaded, saving to DB

      final reviewerData = {
        'name': name,
        'title': title,
        'location': location,
        'linkedInUrl': linkedInUrl,
        'quote': quote,
        'expertise': expertise,
        'education': education,
        'awards': awards,
        'imageUrl': imageUrl, // <-- The URL for display
        'publicId': publicId, // <-- The ID for deletion
        'createdAt': FieldValue.serverTimestamp(),
      };

      final docRef = await _firestore.collection(_collection).add(reviewerData);

      onProgress?.call(1.0); // 100% - Done
      return docRef.id;
    } catch (e) {
      // Re-throw the error to be caught by the UI
      rethrow;
    }
  }

  static Stream<List<Reviewer>> getReviewersStream() {
    return _firestore
        .collection(_collection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Reviewer.fromDoc(doc)).toList();
    });
  }

  // --- UPDATED DELETE FUNCTION ---
  static Future<void> deleteReviewer(String id) async {
    try {
      // Get the reviewer doc to find the public_id
      final doc = await _firestore.collection(_collection).doc(id).get();
      if (doc.exists) {
        final publicId = doc.data()?['publicId'] as String?;
        if (publicId != null && publicId.isNotEmpty) {
          // Attempt to delete from Cloudinary first
          print('Deleting image from Cloudinary: $publicId');
          await CloudinaryService.deleteImage(publicId);
        }
      }

      // Delete from Firestore
      await _firestore.collection(_collection).doc(id).delete();
      print('Reviewer deleted from Firestore.');
    } catch (e) {
      print('Error deleting reviewer: $e');
      rethrow;
    }
  }
}

// -------------------------------------------------------------------
// --- 2. REVIEWER MODEL (Updated with publicId) ---
// -------------------------------------------------------------------
class Reviewer {
  final String id;
  final String name;
  final String title;
  final String imageUrl;
  final String publicId; // <-- ADDED
  final String location;
  final String linkedInUrl;
  final String quote;
  final List<String> expertise;
  final List<String> education;
  final List<String> awards;

  Reviewer({
    required this.id,
    required this.name,
    required this.title,
    required this.imageUrl,
    required this.publicId, // <-- ADDED
    required this.location,
    required this.linkedInUrl,
    required this.quote,
    required this.expertise,
    required this.education,
    required this.awards,
  });

  factory Reviewer.fromDoc(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Reviewer(
      id: doc.id,
      name: data['name'] ?? '',
      title: data['title'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      publicId: data['publicId'] ?? '', // <-- ADDED
      location: data['location'] ?? '',
      linkedInUrl: data['linkedInUrl'] ?? '',
      quote: data['quote'] ?? '',
      expertise: List<String>.from(data['expertise'] ?? []),
      education: List<String>.from(data['education'] ?? []),
      awards: List<String>.from(data['awards'] ?? []),
    );
  }
}

// -------------------------------------------------------------------
// --- 3. MANAGE REVIEWERS SCREEN (UI - No changes needed) ---
// -------------------------------------------------------------------
class ManageReviewersScreen extends StatefulWidget {
  const ManageReviewersScreen({Key? key}) : super(key: key);

  @override
  State<ManageReviewersScreen> createState() => _ManageReviewersScreenState();
}

class _ManageReviewersScreenState extends State<ManageReviewersScreen> {
  final _nameController = TextEditingController();
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _linkedInController = TextEditingController();
  final _quoteController = TextEditingController();
  final _expertiseController = TextEditingController();
  final _educationController = TextEditingController();
  final _awardsController = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  XFile? _selectedImage;
  bool _isUploading = false;
  double _uploadProgress = 0.0;

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        imageQuality: 80,
      );
      if (image != null) {
        setState(() {
          _selectedImage = image;
        });
      }
    } catch (e) {
      _showSnackBar('Failed to pick image: $e', isError: true);
    }
  }

  void _clearForm() {
    _nameController.clear();
    _titleController.clear();
    _locationController.clear();
    _linkedInController.clear();
    _quoteController.clear();
    _expertiseController.clear();
    _educationController.clear();
    _awardsController.clear();
    setState(() {
      _selectedImage = null;
    });
  }

  Future<void> _addReviewer() async {
    if (_nameController.text.isEmpty ||
        _titleController.text.isEmpty ||
        _selectedImage == null) {
      _showSnackBar('Please fill in name, title, and select an image.',
          isError: true);
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    try {
      List<String> splitText(String text) {
        return text
            .split('\n')
            .where((s) => s.trim().isNotEmpty)
            .toList();
      }

      await ReviewerService.createReviewer(
        name: _nameController.text,
        title: _titleController.text,
        location: _locationController.text,
        linkedInUrl: _linkedInController.text,
        quote: _quoteController.text,
        expertise: splitText(_expertiseController.text),
        education: splitText(_educationController.text),
        awards: splitText(_awardsController.text),
        imageFile: _selectedImage!,
        onProgress: (progress) {
          setState(() {
            _uploadProgress = progress;
          });
        },
      );

      _clearForm();
      _showSnackBar('Reviewer added successfully!');
    } catch (e) {
      _showSnackBar('Failed to add reviewer: $e', isError: true);
    } finally {
      setState(() {
        _isUploading = false;
        _uploadProgress = 0.0;
      });
    }
  }

  Future<void> _deleteReviewer(String id) async {
    try {
      // Show a confirmation dialog
      final bool? confirm = await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Delete Reviewer?'),
          content: Text('This will also delete their image from the server. This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );

      if (confirm == true) {
        await ReviewerService.deleteReviewer(id);
        _showSnackBar('Reviewer deleted');
      }
    } catch (e) {
      _showSnackBar('Failed to delete reviewer: $e', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: () async {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const AdminPanelScreen()),
          );
          return false;
        },

      child: Scaffold(
      backgroundColor: const Color(0xFFF5E6F1), // Pinkish theme
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: BackButton(
          color: Colors.black, // Match your title style
          onPressed: () {
            // Check if we can go back

            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const AdminPanelScreen()),
            );

            // If no, do nothing (this prevents the app from closing)
          },
        ),
        title: const Text(
          'Manage Reviewers',
          style: TextStyle(color: Colors.black),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAddReviewerCard(),
            const SizedBox(height: 24),
            const Text(
              'Existing Reviewers',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            _buildReviewerList(),
          ],
        ),
      ),
      )
    );
  }

  Widget _buildAddReviewerCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
            'Add New Reviewer',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildImagePicker(),
          const SizedBox(height: 16),
          _buildTextField(
              _nameController, 'Name (e.g., Claudia Pastides, MBBS)'),
          _buildTextField(_titleController, 'Title (e.g., Former Flo director)'),
          _buildTextField(_locationController, 'Location (e.g., Cyprus)'),
          _buildTextField(_linkedInController, 'LinkedIn URL (Optional)'),
          _buildTextField(_quoteController, 'Quote', maxLines: 3),
          _buildTextField(_expertiseController, 'Expertise (one per line)',
              maxLines: 4),
          _buildTextField(_educationController, 'Education (one per line)',
              maxLines: 4),
          _buildTextField(_awardsController, 'Awards (one per line)',
              maxLines: 4),
          const SizedBox(height: 16),
          if (_isUploading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: LinearProgressIndicator(
                value: _uploadProgress,
                color: const Color(0xFFE91E63),
                backgroundColor: const Color(0xFFF5E6F1),
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add Reviewer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE91E63),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isUploading ? null : _addReviewer,
            ),
          ),
        ],
      ),

    );
  }

  Widget _buildImagePicker() {
    return Center(
      child: GestureDetector(
        onTap: _pickImage,
        child: CircleAvatar(
          radius: 50,
          backgroundColor: const Color(0xFFF5E6F1),
          backgroundImage:
          _selectedImage != null ? FileImage(File(_selectedImage!.path)) : null,
          child: _selectedImage == null
              ? const Icon(Icons.camera_alt,
              color: Color(0xFFE91E63), size: 30)
              : Stack(
            alignment: Alignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withOpacity(0.3)),
              ),
              const Icon(Icons.edit, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: _inputDecoration(label),
        style: const TextStyle(color: Colors.black),
      ),
    );
  }

  Widget _buildReviewerList() {
    return StreamBuilder<List<Reviewer>>(
      stream: ReviewerService.getReviewersStream(), // Use the new service
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFFE91E63)));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Text('No reviewers added yet.'),
            ),
          );
        }

        final reviewers = snapshot.data!;

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: reviewers.length,
          itemBuilder: (context, index) {
            final reviewer = reviewers[index];
            return Card(
              color: Colors.white,
              margin: const EdgeInsets.only(top: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
              shadowColor: Colors.black.withOpacity(0.05),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFFF5E6F1),
                  backgroundImage: reviewer.imageUrl.isNotEmpty
                      ? NetworkImage(reviewer.imageUrl)
                      : null,
                  child: reviewer.imageUrl.isEmpty
                      ? const Icon(Icons.person, color: Color(0xFFE91E63))
                      : null,
                ),
                title: Text(reviewer.name,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(reviewer.title,
                    style: const TextStyle(color: Colors.black54)),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _deleteReviewer(reviewer.id),
                ),
              ),
            );
          },
        );
      },
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey[600]),
      filled: true,
      fillColor: const Color(0xFFF5E6F1).withOpacity(0.5),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE91E63)),
      ),
    );
  }
}