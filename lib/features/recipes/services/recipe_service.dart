import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../../../library/services/cloudinary_service.dart';

class RecipeService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static const String _collection = 'recipes';

  /// Create recipe
  // *** MODIFIED ***: Added calories parameter
  static Future<String> createRecipe({
    required String title,
    required String description,
    required List<String> ingredients,
    required List<String> instructions,
    required String difficulty,
    required int prepTime,
    required int cookTime,
    required int servings,
    required String category,
    required int calories, // *** NEW ***
    XFile? imageFile,
    Map<String, String>? nutrition,
    List<String>? tags,
  }) async {
    try {
      print('👨‍🍳 Creating recipe: $title');
      String? imageUrl;
      String? imagePublicId;

      if (imageFile != null) {
        try {
          print('📤 Uploading to Cloudinary...');

          final cloudinaryTags = {
            'type': 'recipe',
            'difficulty': difficulty.toLowerCase(),
            'category': category.toLowerCase(),
          };

          if (tags != null && tags.isNotEmpty) {
            cloudinaryTags['recipe_tags'] = tags.join(',');
          }

          final uploadResult = await CloudinaryService.uploadImage(
            imageFile: imageFile,
            folder: 'recipes',
            tags: cloudinaryTags,
          );
          imageUrl = uploadResult.secureUrl;
          imagePublicId = uploadResult.publicId;
          print('✅ Image uploaded: $imageUrl');
        } catch (e) {
          print('❌ Cloudinary upload error: $e');
        }
      }

      if (title.trim().isEmpty) {
        throw RecipeException('Recipe title is required.');
      }
      if (ingredients.isEmpty) {
        throw RecipeException('At least one ingredient is required.');
      }
      if (instructions.isEmpty) {
        throw RecipeException('Cooking instructions are required.');
      }

      // *** MODIFIED ***: Add calories to the Firestore document
      final recipeData = {
        'title': title.trim(),
        'description': description.trim(),
        'ingredients': ingredients.map((e) => e.trim()).toList(),
        'instructions': instructions.map((e) => e.trim()).toList(),
        'difficulty': difficulty,
        'prepTime': prepTime,
        'cookTime': cookTime,
        'servings': servings,
        'category': category,
        'calories': calories, // *** NEW ***
        'imageUrl': imageUrl,
        'imagePublicId': imagePublicId,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': _auth.currentUser?.uid ?? 'anonymous',
        'createdByEmail': _auth.currentUser?.email ?? 'anonymous',
        'isActive': true,
        'views': 0,
        'likes': 0,
        'rating': 0.0,
        'nutrition': nutrition ?? {},
        'tags': tags ?? [],
      };

      final docRef = await _firestore.collection(_collection).add(recipeData);
      print('✅ Recipe saved: ${docRef.id}');
      return docRef.id;
    } on RecipeException {
      rethrow;
    } catch (e) {
      print('❌ Recipe creation error: $e');
      throw RecipeException('Failed to create recipe: ${e.toString()}');
    }
  }

  /// Get recipes stream - OPTIMIZED & WORKS WITH EXISTING DATA
  static Stream<List<Map<String, dynamic>>> getRecipesStream() {
    print('🔍 Starting recipes stream...');

    return _firestore
        .collection(_collection)
        .where('isActive', isEqualTo: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      print('📊 Loaded ${snapshot.docs.length} recipes');

      final recipes = snapshot.docs.map((doc) {
        try {
          final data = doc.data();
          data['id'] = doc.id;

          // Generate optimized URLs if imagePublicId exists
          if (data['imagePublicId'] != null && data['imagePublicId'].toString().isNotEmpty) {
            final publicId = data['imagePublicId'] as String;

            data['cardImageUrl'] = CloudinaryService.getOptimizedUrl(
              publicId,
              width: 400,
              height: 300,
              quality: 'auto:low',
            );

            data['thumbnailUrl'] = CloudinaryService.getOptimizedUrl(
              publicId,
              width: 200,
              height: 150,
              quality: '60',
            );
          } else if (data['imageUrl'] != null) {
            // Fallback to original URL if no publicId
            data['cardImageUrl'] = data['imageUrl'];
            data['thumbnailUrl'] = data['imageUrl'];
          }

          return data;
        } catch (e) {
          print('❌ Error processing recipe ${doc.id}: $e');
          return {
            'id': doc.id,
            'title': 'Error loading recipe',
            'description': 'Unable to load recipe data',
            'error': true,
          };
        }
      }).toList();

      // Sort by createdAt in memory (descending - newest first)
      recipes.sort((a, b) {
        try {
          final aTime = a['createdAt'];
          final bTime = b['createdAt'];

          if (aTime == null) return 1;
          if (bTime == null) return -1;

          final aDate = aTime is Timestamp ? aTime.toDate() : DateTime.now();
          final bDate = bTime is Timestamp ? bTime.toDate() : DateTime.now();

          return bDate.compareTo(aDate);
        } catch (e) {
          return 0;
        }
      });

      return recipes;
    })
        .handleError((error) {
      print('❌ Stream error: $error');
      return <Map<String, dynamic>>[];
    });
  }

  /// Get single recipe by ID
  static Future<Map<String, dynamic>?> getRecipeById(String id) async {
    try {
      print('🔍 Fetching recipe: $id');
      if (id.trim().isEmpty) {
        throw RecipeException('Invalid recipe ID.');
      }

      final doc = await _firestore.collection(_collection).doc(id).get();

      if (!doc.exists) {
        throw RecipeException('Recipe not found.');
      }

      final data = doc.data()!;
      data['id'] = doc.id;

      // Generate high-res URL if imagePublicId exists
      if (data['imagePublicId'] != null && data['imagePublicId'].toString().isNotEmpty) {
        data['highResImageUrl'] = CloudinaryService.getOptimizedUrl(
          data['imagePublicId'],
          width: 800,
          height: 600,
          quality: 'auto',
        );
      } else if (data['imageUrl'] != null) {
        data['highResImageUrl'] = data['imageUrl'];
      }

      return data;
    } catch (e) {
      print('❌ Error fetching recipe: $e');
      if (e is RecipeException) rethrow;
      throw RecipeException('Failed to load recipe: ${e.toString()}');
    }
  }

  /// Increment recipe views
  static Future<void> incrementViews(String id) async {
    try {
      if (id.trim().isEmpty) return;
      await _firestore.collection(_collection).doc(id).update({
        'views': FieldValue.increment(1),
        'lastViewed': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('❌ Failed to increment views: $e');
    }
  }

  /// Get recipes count
  static Future<int> getRecipesCount() async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('isActive', isEqualTo: true)
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      print('❌ Error getting recipe count: $e');
      return 0;
    }
  }

  /// Delete recipe
  static Future<void> deleteRecipe(String id) async {
    try {
      if (id.trim().isEmpty) {
        throw RecipeException('Invalid recipe ID');
      }

      // Get recipe to check imagePublicId
      final doc = await _firestore.collection(_collection).doc(id).get();
      if (doc.exists) {
        final data = doc.data();

        // Delete image from Cloudinary if exists
        if (data?['imagePublicId'] != null) {
          try {
            await CloudinaryService.deleteImage(data!['imagePublicId']);
            print('✅ Cloudinary image deleted');
          } catch (e) {
            print('⚠️ Failed to delete Cloudinary image: $e');
          }
        }
      }

      // Delete Firestore document
      await _firestore.collection(_collection).doc(id).delete();
      print('✅ Recipe deleted: $id');
    } catch (e) {
      print('❌ Error deleting recipe: $e');
      throw RecipeException('Failed to delete recipe: ${e.toString()}');
    }
  }
}

class RecipeException implements Exception {
  final String message;
  RecipeException(this.message);

  @override
  String toString() => message;
}