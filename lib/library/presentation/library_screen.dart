import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:trackai/core/constants/appcolors.dart';
import 'package:trackai/core/themes/theme_provider.dart';
import 'package:trackai/features/recipes/presentation/recipe_library_screen.dart';

import '../../features/analytics/screens/CycleOS/period_cycle.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final bool isDarkTheme = themeProvider.isDarkMode;
        final Color backgroundColor = isDarkTheme ? Colors.black : Colors.white;
        final Color primaryTextColor = isDarkTheme ? Colors.white : Colors.black;
        final Color secondaryTextColor = isDarkTheme ? Colors.grey[400]! : Colors.grey[600]!;
        final Color cardBackgroundColor = isDarkTheme ? Colors.grey[900]! : Colors.grey[100]!;
        final Color borderColor = isDarkTheme ? Colors.grey[700]! : Colors.grey[300]!;
        final Color iconContainerColor = isDarkTheme ? Colors.grey[800]! : Colors.grey[200]!;

        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;

        return Scaffold(
          backgroundColor: backgroundColor,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(screenWidth * 0.06), // Responsive padding
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Section
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(screenWidth * 0.03),
                        decoration: BoxDecoration(
                          color: iconContainerColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: borderColor,
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          Icons.library_books,
                          color: primaryTextColor,
                          size: screenWidth * 0.07, // Responsive icon size
                        ),
                      ),
                      SizedBox(width: screenWidth * 0.04),
                      Expanded(
                        child: Text(
                          'Library',
                          style: TextStyle(
                            color: primaryTextColor,
                            fontSize: screenWidth * 0.07, // Responsive font size
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: screenHeight * 0.04),

                  // First Row - Recipe Library & Workouts Library with Equal Heights
                  IntrinsicHeight( // This ensures equal heights
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _buildLibraryCard(
                            context,
                            'Recipe Library',
                            'Browse delicious cooking guides and recipes.',
                            Icons.restaurant_menu_outlined,
                            primaryTextColor,
                            isDarkTheme,
                            cardBackgroundColor,
                            borderColor,
                            primaryTextColor,
                            secondaryTextColor,
                            iconContainerColor,
                            screenWidth,
                            screenHeight,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const RecipeLibraryScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                        SizedBox(width: screenWidth * 0.04),
                        Expanded(
                          child: _buildLibraryCard(
                            context,
                            'Workouts Library',
                            'Access workout guide videos.',
                            Icons.fitness_center_outlined,
                            primaryTextColor,
                            isDarkTheme,
                            cardBackgroundColor,
                            borderColor,
                            primaryTextColor,
                            secondaryTextColor,
                            iconContainerColor,
                            screenWidth,
                            screenHeight,
                            onTap: () => _showComingSoon(context, isDarkTheme),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: screenHeight * 0.02),

                  // Full-width Period Cycle card
                  _buildLibraryCard(
                    context,
                    'CycleOS',
                    'Track your menstrual cycle and health insights.',
                    null, // <-- Icon set to null
                    primaryTextColor,
                    isDarkTheme,
                    cardBackgroundColor,
                    borderColor,
                    primaryTextColor,
                    secondaryTextColor,
                    iconContainerColor,
                    screenWidth,
                    screenHeight,
                    imageAsset: 'assets/images/os.jpg', // <-- Image asset added
                    isNew: true,
                    isFullWidth: true,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MainNavigationScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  Widget _buildLibraryCard(
      BuildContext context,
      String title,
      String description,
      IconData? icon, // <-- Made nullable
      Color iconColor,
      bool isDarkTheme,
      Color cardBackgroundColor,
      Color borderColor,
      Color primaryTextColor,
      Color secondaryTextColor,
      Color iconContainerColor,
      double screenWidth,
      double screenHeight, {
        bool isFullWidth = false,
        bool isBeta = false,
        bool isNew = false,
        String? imageAsset, // <-- Added imageAsset parameter
        required VoidCallback onTap,
      }) {
    // Assertion to ensure one of icon or imageAsset is provided
    assert(icon != null || imageAsset != null, 'Must provide either an icon or an imageAsset');

    final Color badgeBgColor = isDarkTheme ? Colors.white : Colors.black;
    final Color badgeTextColor = isDarkTheme ? Colors.black : Colors.white;
    final Color betaBadgeBgColor = isDarkTheme ? Colors.grey[800]! : Colors.grey[300]!;
    final Color betaBadgeTextColor = isDarkTheme ? Colors.grey[400]! : Colors.grey[700]!;
    final Color newBorderColor = isDarkTheme ? Colors.pinkAccent[100]! : Colors.pinkAccent;

    // Define colors/decorations based on 'isNew'
    final Color finalIconColor;
    final Decoration finalIconContainerDecoration;
    final Decoration finalNewBadgeDecoration;

    if (isNew) {
      finalIconColor = Colors.white; // This will be used for Icon OR Image tint
      finalIconContainerDecoration = BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.pink, Colors.pink.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        // --- MODIFIED: Remove border for imageAsset when isNew ---
        // Only apply border if it's an icon OR if it's not an imageAsset
        border: (imageAsset != null && isNew) ? null : Border.all(
          color: Colors.pink.withOpacity(0.2), // This border will still exist for NEW icons
          width: 1,
        ),
        // --- END MODIFICATION ---
        boxShadow: [
          BoxShadow(
            color: Colors.pink.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      );
      finalNewBadgeDecoration = BoxDecoration(
        gradient: LinearGradient(colors: [Colors.pink, Colors.pink.shade400]),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.pink.withOpacity(0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      );
    } else {
      finalIconColor = iconColor; // This will be used for Icon OR Image tint
      finalIconContainerDecoration = BoxDecoration(
        color: iconContainerColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor,
          width: 1,
        ),
      );
      finalNewBadgeDecoration = BoxDecoration(
        color: badgeBgColor,
        borderRadius: BorderRadius.circular(12),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: isFullWidth ? double.infinity : null,
        padding: EdgeInsets.all(screenWidth * 0.05), // Responsive padding
        decoration: BoxDecoration(
          color: cardBackgroundColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isNew ? newBorderColor : borderColor,
            width: isNew ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDarkTheme ? 0.2 : 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
            if (isNew)
              BoxShadow(
                color: Colors.pink.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, // Important for IntrinsicHeight
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: imageAsset != null ? EdgeInsets.zero : EdgeInsets.all(screenWidth * 0.03),
                  decoration: finalIconContainerDecoration,
                  clipBehavior: imageAsset != null ? Clip.antiAlias : Clip.none,
                  child: imageAsset != null
                      ? Image.asset(
                    imageAsset,
                    width: screenWidth * 0.12,
                    height: screenWidth * 0.12,
                    fit: BoxFit.cover,
                  )
                      : Icon(
                    icon!, // We know from assertion this is safe
                    color: finalIconColor,
                    size: screenWidth * 0.06, // Responsive icon size
                  ),
                ),
                Row(
                  children: [
                    if (isNew)
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: EdgeInsets.symmetric(
                          horizontal: screenWidth * 0.02,
                          vertical: screenHeight * 0.005,
                        ),
                        decoration: finalNewBadgeDecoration,
                        child: Text(
                          'New',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: screenWidth * 0.025,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    if (isBeta)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: screenWidth * 0.02,
                          vertical: screenHeight * 0.005,
                        ),
                        decoration: BoxDecoration(
                          color: betaBadgeBgColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: borderColor,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          'Beta',
                          style: TextStyle(
                            color: betaBadgeTextColor,
                            fontSize: screenWidth * 0.025,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            SizedBox(height: screenHeight * 0.02),
            Text(
              title,
              style: TextStyle(
                color: primaryTextColor,
                fontSize: screenWidth * 0.045, // Responsive font size
                fontWeight: FontWeight.bold,
                letterSpacing: -0.3,
              ),
            ),
            SizedBox(height: screenHeight * 0.01),
            Flexible( // Allows text to wrap and fill available space
              child: Text(
                description,
                style: TextStyle(
                  color: secondaryTextColor,
                  fontSize: screenWidth * 0.035, // Responsive font size
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
  void _showComingSoon(BuildContext context, bool isDarkTheme) {
    final Color snackBarBg = isDarkTheme ? Colors.grey[800]! : Colors.grey[900]!;
    final Color snackBarText = Colors.white;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.info_outline,
              color: snackBarText.withOpacity(0.8),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Coming soon! Stay tuned for updates.',
                style: TextStyle(
                  color: snackBarText,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: snackBarBg,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}