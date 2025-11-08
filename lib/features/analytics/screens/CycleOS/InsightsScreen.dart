// lib/InsightsScreen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'ArticleDetailScreen.dart';
// Make sure this path is correct

// --- 1. UPDATED ARTICLE MODEL ---
class Article {
  final String id;
  final String title;
  final String category;
  final String imageUrl;
  final String content;
  // This is now a map holding all the reviewer's info
  final Map<String, dynamic> reviewer;
  // --- ADDED NEW FIELDS ---
  final String takeaway;
  final List<String> references;
  // ------------------------

  Article({
    required this.id,
    required this.title,
    required this.category,
    required this.imageUrl,
    required this.content,
    required this.reviewer,
    // --- ADDED TO CONSTRUCTOR ---
    required this.takeaway,
    required this.references,
    // ----------------------------
  });

  factory Article.fromDoc(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Article(
      id: doc.id,
      title: data['title'] ?? '',
      category: data['category'] ?? 'General',
      imageUrl: data['imageUrl'] ?? '',
      content: data['content'] ?? '',
      // Read the entire 'reviewer' map
      reviewer: data['reviewer'] as Map<String, dynamic>? ?? {},
      // --- READ NEW FIELDS ---
      takeaway: data['takeaway'] ?? '',
      references: List<String>.from(data['references'] ?? []),
      // -----------------------
    );
  }
}

// ------------------------------

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({Key? key}) : super(key: key);

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5E6F1), // Pinkish theme
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          mainAxisSize: MainAxisSize.min, // Keeps the logo and text together
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/os.jpg', // Your logo path
              width: 28, // Adjust size as needed
              height: 28,
            ),
            const SizedBox(width: 8), // Space between logo and text
            const Text(
              'INSIGHTS',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.black,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        centerTitle: false,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('articles')
            .orderBy('publishedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child:
                CircularProgressIndicator(color: Color(0xFFE91E63)));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No articles published yet.'));
          }

          final articles =
          snapshot.data!.docs.map((doc) => Article.fromDoc(doc)).toList();

          // Group articles by category
          final Map<String, List<Article>> groupedArticles = {};
          for (var article in articles) {
            (groupedArticles[article.category] ??= []).add(article);
          }

          // --- THIS IS THE FIX ---
          // Changed ListView.builder to ListView.separated
          return ListView.separated(
            separatorBuilder: (context, index) => const SizedBox(height: 16), // This now works
            padding: const EdgeInsets.only(bottom: 24),
            // -----------------------
            itemCount: groupedArticles.keys.length,
            itemBuilder: (context, index) {
              String category = groupedArticles.keys.elementAt(index);
              List<Article> categoryArticles = groupedArticles[category]!;
              return _buildCategoryCarousel(category, categoryArticles);
            },
          );
        },
      ),
    );
  }

  Widget _buildCategoryCarousel(String category, List<Article> articles) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 18, 14, 10),
          child: Text(
            category,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ),
        SizedBox(
          height: 220, // This height is good. (140 for image + 80 for text area)
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: articles.length,
            itemBuilder: (context, index) {
              final article = articles[index];
              return _buildArticleCard(article);
            },
          ),
        ),
      ],
    );
  }

  // --- UPDATED WIDGET ---
  Widget _buildArticleCard(Article article) {
    // Get screen width for responsive card
    final screenWidth = MediaQuery.of(context).size.width;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ArticleDetailScreen(article: article),
          ),
        );
      },
      child: Container(
        // Responsive width (approx 2.3 cards will show on a typical screen)
        width: screenWidth * 0.42,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
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
            // Image (Fixed height)
            SizedBox(
              height: 140,
              width: double.infinity,
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                child: article.imageUrl.isNotEmpty
                    ? Image.network(
                  article.imageUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFE91E63),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: const Color(0xFFF5E6F1),
                      child: const Icon(
                        Icons.article,
                        color: Color(0xFFE91E63),
                        size: 40,
                      ),
                    );
                  },
                )
                    : Container( // Placeholder
                  color: const Color(0xFFF5E6F1),
                  child: const Icon(
                    Icons.article,
                    color: Color(0xFFE91E63),
                    size: 40,
                  ),
                ),
              ),
            ),

            // Text Area (Fills the remaining space)
            Expanded( // <-- FIX 1: This prevents the bottom overflow
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  article.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.black,
                    height: 1.3, // <-- FIX 2: Adds nice line spacing
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}