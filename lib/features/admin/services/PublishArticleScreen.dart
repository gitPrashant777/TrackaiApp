import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart'; // ✅ For live preview
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

import '../admin_panel_screen.dart';
import 'ManageReviewersScreen.dart' show Reviewer, ReviewerService;
import 'article_service.dart';

class PublishArticleScreen extends StatefulWidget {
  const PublishArticleScreen({Key? key}) : super(key: key);

  @override
  State<PublishArticleScreen> createState() => _PublishArticleScreenState();
}

class _PublishArticleScreenState extends State<PublishArticleScreen> {
  final _titleController = TextEditingController();
  final _markdownController = TextEditingController();
  final _takeawayController = TextEditingController();
  final _referencesController = TextEditingController();
  final _categoryController = TextEditingController(); // --- ADDED ---

  // --- REMOVED ---
  // final List<String> _categories = [ ... ];
  // String? _selectedCategory;
  // --- END REMOVED ---

  List<Reviewer> _reviewers = [];
  Reviewer? _selectedReviewer;

  XFile? _selectedImage;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  final ImagePicker _picker = ImagePicker();

  bool _showPreview = false; // ✅ toggle between editor and preview

  @override
  void initState() {
    super.initState();
    _fetchReviewers();
    // --- REMOVED ---
    // _selectedCategory = _categories.first;
    // --- END REMOVED ---
  }

  @override
  void dispose() {
    _titleController.dispose();
    _markdownController.dispose();
    _takeawayController.dispose();
    _referencesController.dispose();
    _categoryController.dispose(); // --- ADDED ---
    super.dispose();
  }

  Future<void> _fetchReviewers() async {
    try {
      ReviewerService.getReviewersStream().listen((reviewers) {
        if (!mounted) return;
        setState(() {
          _reviewers = reviewers;
          if (_selectedReviewer == null && _reviewers.isNotEmpty) {
            _selectedReviewer = _reviewers.first;
          }
        });
      });
    } catch (e) {
      _showSnackBar('Failed to fetch reviewers: $e', isError: true);
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() => _selectedImage = image);
      }
    } catch (e) {
      _showSnackBar('Failed to pick image: $e', isError: true);
    }
  }

  // --- ADDED: Helper function to format category ---
  String _formatCategory(String input) {
    if (input.isEmpty) return '';
    // Trims whitespace, converts to lowercase, then capitalizes first letter
    String trimmed = input.trim().toLowerCase();
    return '${trimmed[0].toUpperCase()}${trimmed.substring(1)}';
  }
  // --- END ADDED ---

  void _clearForm() {
    _titleController.clear();
    _markdownController.clear();
    _takeawayController.clear();
    _referencesController.clear();
    _categoryController.clear(); // --- ADDED ---
    setState(() {
      _selectedImage = null;
      // --- REMOVED ---
      // _selectedCategory = _categories.first;
      // --- END REMOVED ---
      _selectedReviewer = _reviewers.isNotEmpty ? _reviewers.first : null;
    });
  }

  Future<void> _publishArticle() async {
    // --- MODIFIED: Updated validation check ---
    if (_titleController.text.isEmpty ||
        _markdownController.text.isEmpty ||
        _selectedReviewer == null ||
        _selectedImage == null ||
        _categoryController.text.isEmpty || // <-- Changed
        _takeawayController.text.isEmpty ||
        _referencesController.text.isEmpty) {
      _showSnackBar('Please fill all fields properly.', isError: true);
      return;
    }
    // --- END MODIFIED ---

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    try {
      final List<String> referencesList = _referencesController.text
          .split('\n')
          .where((s) => s.trim().isNotEmpty)
          .toList();

      // --- MODIFIED: Format the category string before sending ---
      final String formattedCategory = _formatCategory(_categoryController.text);
      // --- END MODIFIED ---

      await ArticleService.createArticle(
        title: _titleController.text,
        category: formattedCategory, // <-- Changed
        content: _markdownController.text,
        reviewer: _selectedReviewer!,
        imageFile: _selectedImage!,
        takeaway: _takeawayController.text,
        references: referencesList,
        onProgress: (progress) {
          setState(() {
            _uploadProgress = progress;
          });
        },
      );

      _clearForm();
      _showSnackBar('Article published successfully!');
    } catch (e) {
      _showSnackBar('Failed to publish: $e', isError: true);
    } finally {
      setState(() {
        _isUploading = false;
        _uploadProgress = 0.0;
      });
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return; // --- ADDED: Safety check
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  void _wrapSelection(String prefix, String suffix) {
    final value = _markdownController.value;
    final sel = value.selection;
    final selected = value.text.substring(sel.start, sel.end);
    final newText =
    value.text.replaceRange(sel.start, sel.end, '$prefix$selected$suffix');
    _markdownController.value = value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(
        offset: sel.start + prefix.length + selected.length + suffix.length,
      ),
    );
  }

  void _insertLineStart(String text) {
    final value = _markdownController.value;
    final sel = value.selection;
    final int lineStart = value.text.lastIndexOf('\n', sel.start - 1) + 1;
    final newText = value.text.replaceRange(lineStart, lineStart, text);
    _markdownController.value = value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: sel.start + text.length),
    );
  }

  Future<bool> _onWillPop() async {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const AdminPanelScreen()),
    );
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5E6F1),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: _onWillPop,
          ),
          title: const Text('Publish New Article',
              style: TextStyle(color: Colors.black)),
          iconTheme: const IconThemeData(color: Colors.black),
          actions: [
            IconButton(
              icon: Icon(
                _showPreview ? Icons.edit_note : Icons.remove_red_eye,
                color: Colors.pink,
              ),
              onPressed: () {
                setState(() => _showPreview = !_showPreview);
              },
              tooltip: _showPreview ? 'Edit Mode' : 'Preview Mode',
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildTextField(_titleController, 'Title'),
              // --- MODIFIED: Replaced dropdown with text field ---
              _buildTextField(_categoryController, 'Category'),
              // --- END MODIFIED ---
              _buildImagePicker(),
              const SizedBox(height: 16),
              _buildReviewerDropdown(),

              // Toolbar
              if (!_showPreview)
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Wrap(
                    spacing: 6,
                    children: [
                      _toolButton('H1', () => _insertLineStart('# ')),
                      _toolButton('H2', () => _insertLineStart('## ')),
                      _toolButton('B', () => _wrapSelection('**', '**')),
                      _toolButton('I', () => _wrapSelection('_', '_')),
                      _toolButton('•', () => _insertLineStart('- ')),
                      _toolButton('1.', () => _insertLineStart('1. ')),
                      _toolButton('❝', () => _insertLineStart('> ')),
                      _toolButton('</>', () => _wrapSelection('`', '`')),
                    ],
                  ),
                ),

              // Editor or Preview
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _showPreview
                    ? MarkdownBody(
                  data: _markdownController.text.isEmpty
                      ? 'Start writing to see preview here...'
                      : _markdownController.text,
                  styleSheet: MarkdownStyleSheet(
                    h1: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold),
                    h2: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                    p: const TextStyle(fontSize: 16),
                  ),
                )
                    : ConstrainedBox(
                  constraints: const BoxConstraints(
                      minHeight: 200, maxHeight: 600),
                  child: TextField(
                    controller: _markdownController,
                    keyboardType: TextInputType.multiline,
                    maxLines: null,
                    style: const TextStyle(color: Colors.black),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText:
                      'Write your article here using Markdown syntax...',
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),
              _buildTextField(_takeawayController, 'The takeaway', maxLines: 5),
              _buildTextField(
                  _referencesController, 'References (one per line)',
                  maxLines: 5),

              if (_isUploading)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: LinearProgressIndicator(
                    value: _uploadProgress,
                    color: const Color(0xFFE91E63),
                    backgroundColor: const Color(0xFFF5E6F1),
                  ),
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE91E63),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isUploading ? null : _publishArticle,
                  child: _isUploading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Publish Article'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toolButton(String label, VoidCallback onPressed) => ElevatedButton(
    onPressed: onPressed,
    style: ElevatedButton.styleFrom(
      elevation: 0,
      backgroundColor: Colors.white,
      side: const BorderSide(color: Color(0xFFE0E0E0)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      minimumSize: const Size(40, 36),
    ),
    child: Text(label, style: const TextStyle(color: Colors.black)),
  );

  Widget _buildTextField(TextEditingController controller, String label,
      {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.black),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey[700]),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE91E63)),
          ),
        ),
      ),
    );
  }

  // --- REMOVED ---
  // Widget _buildCategoryDropdown() { ... }
  // --- END REMOVED ---

  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        width: double.infinity,
        height: 180,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _selectedImage == null
                ? Colors.grey[400]!
                : const Color(0xFFE91E63),
          ),
        ),
        child: _selectedImage != null
            ? ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(File(_selectedImage!.path),
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover),
        )
            : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_photo_alternate_outlined,
                size: 40, color: Colors.grey),
            const SizedBox(height: 8),
            Text('Tap to add cover image',
                style: TextStyle(color: Colors.grey[700], fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewerDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      margin: const EdgeInsets.only(bottom: 16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Reviewer>(
          isExpanded: true,
          value: _selectedReviewer,
          hint: const Text('Select a Reviewer'),
          style: const TextStyle(color: Colors.black, fontSize: 16),
          onChanged: (Reviewer? newValue) {
            setState(() => _selectedReviewer = newValue);
          },
          items: _reviewers
              .map((Reviewer r) =>
              DropdownMenuItem(value: r, child: Text(r.name)))
              .toList(),
        ),
      ),
    );
  }
}