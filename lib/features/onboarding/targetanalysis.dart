import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:trackai/core/constants/appcolors.dart';

class TargetAnalysisPage extends StatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;
  final double targetAmount;
  final String targetUnit;
  final int targetTimeframe;
  final String goal;

  const TargetAnalysisPage({
    Key? key,
    required this.onNext,
    required this.onBack,
    required this.targetAmount,
    required this.targetUnit,
    required this.targetTimeframe,
    required this.goal,
  }) : super(key: key);

  @override
  State<TargetAnalysisPage> createState() => _TargetAnalysisPageState();
}

class _TargetAnalysisPageState extends State<TargetAnalysisPage> {
  String _headlineText = "";
  String _recommendationText = "";
  bool _isLoading = true;
  bool _errorOccurred = false;

  @override
  void initState() {
    super.initState();
    _generateAnalysis();
  }

  Future<void> _generateAnalysis() async {
    setState(() {
      _isLoading = true;
      _errorOccurred = false;
    });

    try {
      final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
      if (apiKey.isEmpty) {
        throw Exception('API key not found in .env file');
      }

      // --- FIXED MODEL NAME ---
      final model = GenerativeModel(model: 'gemini-2.0-flash', apiKey: apiKey); // Using 1.5-flash
      String goalType = widget.goal == 'gain_weight' ? 'gain' : 'lose';

      // Format to 0 decimal places for a clean prompt
      String amount = widget.targetAmount.toStringAsFixed(0);
      String timeframeText = widget.targetTimeframe > 1 ? 'weeks' : 'week';

      // --- UPDATED PROMPT ---
      String prompt = '''
      Analyze this fitness goal:
      Goal: $goalType $amount ${widget.targetUnit} in ${widget.targetTimeframe} $timeframeText.
      
      Respond in two parts, separated by '||':
      1.  **Headline:** A short, encouraging headline that includes the goal and a brief analysis. 
          Example: Losing 45 kg in 30 weeks is an ambitious goal.
      2.  **Recommendation:** A one or two-sentence recommendation for the user.
          Example: This is a fast pace. While achievable, ensure you're feeling energetic and healthy. A pace of 0.5-0.8 kg per week is often recommended for sustainable loss.
      ''';
      // --- END UPDATED PROMPT ---

      final content = [Content.text(prompt)];
      final response = await model.generateContent(content).timeout(
        Duration(seconds: 30),
        onTimeout: () => throw Exception('API request timed out'),
      );

      final text = response.text ?? '';

      // --- UPDATED SPLIT LOGIC ---
      final parts = text.contains('||') ? text.split('||') : [text, 'Consult a professional for advice.'];

      setState(() {
        // Remove any markdown like '*' from the response
        _headlineText = parts.isNotEmpty ? parts[0].trim().replaceAll('*', '') : 'No analysis provided';
        _recommendationText = parts.length > 1 ? parts[1].trim().replaceAll('*', '') : 'Consult a professional for advice.';
        _isLoading = false;
      });
    } catch (e) {
      print('Detailed Error: $e'); // Log detailed error
      setState(() {
        _errorOccurred = true;
        _isLoading = false;
        _headlineText = 'Error Generating Analysis';
        _recommendationText = 'Please check your API key, network connection, or try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // --- REVERTED THEME ---
      backgroundColor: Colors.white, // Back to light background
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 60), // Pushes content down

                      _isLoading
                          ? _buildLoadingState() // Loading Widget
                          : _errorOccurred
                          ? _buildErrorState() // Error Widget
                          : _buildSuccessState(), // Success Widget
                    ],
                  ),
                ),
              ),

              // --- UPDATED NAVIGATION BUTTONS for Light Theme ---
              Row(
                children: [
                  GestureDetector(
                    onTap: widget.onBack,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.grey[100], // Light grey
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: Colors.grey[300]!, width: 1),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new,
                        color: Colors.black, // Black icon
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      height: 64,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(32),
                        color: Colors.black, // Black button
                      ),
                      child: ElevatedButton(
                        onPressed: widget.onNext,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(32),
                          ),
                        ),
                        child: const Text(
                          'Next',
                          style: TextStyle(
                            color: Colors.white, // White text
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- NEW: Helper widget for loading state (Light Theme) ---
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              Colors.black, // --- FIXED COLOR ---
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Analyzing your goal...',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w400,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // --- UPDATED Helper widget for success state (Light Theme) ---
  Widget _buildSuccessState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Static Title
        const Text(
          'Your Target Analysis',
          style: TextStyle(
            fontSize: 30, // Large text
            fontWeight: FontWeight.bold,
            color: Colors.black, // Black text
            height: 1.3,
          ),
          textAlign: TextAlign.start,
        ),
        const SizedBox(height: 24),

        // 2. AI Headline
        Text(
          _headlineText,
          style: const TextStyle(
            fontSize: 22, // Slightly smaller
            fontWeight: FontWeight.w600, // Bold but not as bold as title
            color: Colors.black87, // Slightly less prominent
            height: 1.3,
          ),
          textAlign: TextAlign.start,
        ),
        const SizedBox(height: 16),

        // 3. AI Recommendation
        Text(
          _recommendationText,
          style: TextStyle(
            fontSize: 16, // Smaller
            color: Colors.grey[600], // Dimmer text
            height: 1.5,
            fontWeight: FontWeight.w400,
          ),
          textAlign: TextAlign.start,
        ),
      ],
    );
  }

  // --- NEW: Helper widget for error state (Light Theme) ---
  Widget _buildErrorState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Headline
        Text(
          _headlineText,
          style: const TextStyle(
            fontSize: 24, // Smaller for error
            fontWeight: FontWeight.bold,
            color: Colors.red, // Error color
            height: 1.3,
          ),
          textAlign: TextAlign.start,
        ),
        const SizedBox(height: 24),
        // Recommendation
        Text(
          _recommendationText,
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
            height: 1.5,
            fontWeight: FontWeight.w400,
          ),
          textAlign: TextAlign.start,
        ),
        const SizedBox(height: 32),
        Center(
          child: ElevatedButton(
            onPressed: _generateAnalysis,
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black, // Black button
                foregroundColor: Colors.white, // White text
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)
            ),
            child: const Text(
              'Try Again',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}