// lib/features/home/presentation/meal_detail_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:trackai/features/home/homepage/log/food_log_entry.dart'; // Adjust import path if needed
import 'package:lucide_icons_flutter/lucide_icons.dart' as lucide; // Adjust import path if needed

// --- Copy Color Constants (or import from a shared file) ---
const Color kCardColorDarker = Color(0xFFE9ECEF);
const Color kTextColor = Color(0xFF212529);
const Color kTextSecondaryColor = Color(0xFF6C757D);
const Color kSuccessColor = Color(0xFF28A745);
const Color kWarningColor = Color(0xFFFFC107);
const Color kDangerColor = Color(0xFFDC3545);
// -----------------------------------------------------------

class MealDetailScreen extends StatelessWidget {
  final FoodLogEntry entry;

  const MealDetailScreen({Key? key, required this.entry}) : super(key: key);

  // --- Helper: Get Health Score Color ---
  Color _getHealthScoreColor(int score) {
    if (score >= 8) return kSuccessColor;
    if (score >= 5) return kWarningColor;
    return kDangerColor;
  }

  // --- Helper: Build Nutrient Card ---
  Widget _buildNutrientCard(
      BuildContext context, // Added context
      String title,
      String value,
      String unit,
      IconData icon,
      Color iconColor,
      ) {
    final sw = MediaQuery.of(context).size.width; // Get screen width from context

    return Container(
      padding: EdgeInsets.symmetric(horizontal: sw * 0.02, vertical: sw * 0.03),
      decoration: BoxDecoration(
        color: kCardColorDarker, // Use light theme inner card color
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: iconColor, size: sw * 0.06),
          SizedBox(height: sw * 0.015),
          Text(
            title,
            style: TextStyle(
              fontSize: sw * 0.03,
              fontWeight: FontWeight.w600,
              color: kTextColor, // Dark text
            ),
            textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: sw * 0.01),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: TextStyle(fontSize: sw * 0.05, fontWeight: FontWeight.bold, color: kTextColor), // Dark text
                ),
                SizedBox(width: sw * 0.005),
                Text(
                  unit,
                  style: TextStyle(fontSize: sw * 0.025, color: kTextSecondaryColor), // Secondary text
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.grey[100], // Background for the whole screen
      appBar: AppBar(
        backgroundColor: Colors.white, // White AppBar
        elevation: 1,
        shadowColor: Colors.black.withOpacity(0.1),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Meal Details',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(sw * 0.05), // Padding around the content
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Food Name
            Text(
              entry.name,
              style: TextStyle(
                fontSize: sw * 0.055, // Larger title
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: sh * 0.02),

            // Image Display
            if (entry.imagePath != null) ...[
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12.0),
                  child: Image.file(
                    File(entry.imagePath!),
                    height: sh * 0.25, // Slightly larger image
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: sh * 0.25,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        child: const Center(child: Icon(Icons.error_outline, color: Colors.grey)),
                      );
                    },
                  ),
                ),
              ),
              SizedBox(height: sh * 0.03),
            ],

            // Calories Display
            Center(
              child: Column(
                children: [
                  Icon(lucide.LucideIcons.flame, color: Colors.black, size: sw * 0.07),
                  SizedBox(height: sh * 0.01),

                  // --- MODIFIED WIDGET ---
                  Container(
                    // Added padding and rounded corners for a cleaner look
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey[300], // Background color as requested
                      borderRadius: BorderRadius.circular(12), // Rounded corners
                    ),
                    child: Text(
                      '${entry.calories}',
                      style: TextStyle(fontSize: sw * 0.12, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                  ),
                  // --- END MODIFICATION ---

                  SizedBox(height: sh * 0.005), // Added a small space

                  Text(
                    'kcal',
                    style: TextStyle(fontSize: sw * 0.04, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            SizedBox(height: sh * 0.03),

            // Macro Grid
            Row(
              children: [
                Expanded(child: _buildNutrientCard(context, 'Protein', '${entry.protein}', 'g', lucide.LucideIcons.zap, Colors.amber)),
                SizedBox(width: sw * 0.03),
                Expanded(child: _buildNutrientCard(context, 'Carbs', '${entry.carbs}', 'g', lucide.LucideIcons.wheat, Colors.green)),
              ],
            ),
            SizedBox(height: sh * 0.02),
            Row(
              children: [
                Expanded(child: _buildNutrientCard(context, 'Fat', '${entry.fat}', 'g', lucide.LucideIcons.droplet, Colors.blue)),
                SizedBox(width: sw * 0.03),
                Expanded(child: _buildNutrientCard(context, 'Fiber', '${entry.fiber}', 'g', lucide.LucideIcons.leaf, Colors.orange)),
              ],
            ),
            SizedBox(height: sh * 0.03),

            // Conditional Health Score Card
            if (entry.healthScore != null) ...[
              Container(
                padding: EdgeInsets.all(sw * 0.04),
                decoration: BoxDecoration(
                  color: kCardColorDarker, // Inner card background
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(children: [
                          Icon(Icons.favorite, color: Colors.red[400], size: sw * 0.05),
                          SizedBox(width: sw * 0.02),
                          Text('Health Score', style: TextStyle(fontSize: sw * 0.045, fontWeight: FontWeight.bold, color: Colors.black87)),
                        ]),
                        Text('${entry.healthScore}/10', style: TextStyle(fontSize: sw * 0.04, fontWeight: FontWeight.bold, color: Colors.black87)),
                      ],
                    ),
                    SizedBox(height: sh * 0.015),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: (entry.healthScore ?? 0) / 10.0,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(_getHealthScoreColor(entry.healthScore ?? 0)),
                        minHeight: 10,
                      ),
                    ),
                    if (entry.healthDescription != null && entry.healthDescription!.isNotEmpty) ...[
                      SizedBox(height: sh * 0.015),
                      Text(
                        entry.healthDescription!,
                        style: TextStyle(fontSize: sw * 0.035, color: Colors.black54, height: 1.4),
                      ),
                    ]
                  ],
                ),
              ),
              SizedBox(height: sh * 0.04),
            ],

            // Add more details here if needed (e.g., timestamp)

            SizedBox(height: sh * 0.02), // Bottom padding before potential future elements
          ],
        ),
      ),
    );
  }
}