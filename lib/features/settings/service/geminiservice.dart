import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
// Firestore and Auth imports are necessary for saving the plan
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class GeminiService {
  static final String _apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta';

  // Initialize Firestore and Auth for saving functionality
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // --------------------------------------------------------------------------
  // --- MEAL PLAN FIREBASE LOGIC (UPDATED FOR /gymkitDetails/mealPlan) ---
  // --------------------------------------------------------------------------

  // --- UPDATED METHOD: Get Saved Meal Plan from Firestore (Returns LIST with at most one Map) ---
  // Fetches the single active meal plan stored at the fixed document path.
  static Future<List<Map<String, dynamic>>> getSavedMealPlansList() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      // Fetch the specific 'mealPlan' document at the consistent path
      final docSnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('gymkitDetails') // Consistent Subcollection Name
          .doc('mealPlan') // Consistent Fixed Document ID
          .get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data()!;
        // Convert Firestore Timestamp to DateTime for consistency in the app
        if (data['savedAt'] is Timestamp) {
          data['savedAt'] = (data['savedAt'] as Timestamp).toDate();
        }
        // Return a list containing only this one active plan
        return [data];
      }

      return [];
    } catch (e) {
      print('Error fetching saved meal plan: $e');
      return [];
    }
  }

  // --- UPDATED METHOD: Save Meal Plan to Firestore (Matching the gymkitDetails/workoutPlan structure) ---
  // Saves the plan to the fixed document path, overwriting any previous data.
  static Future<void> saveMealPlan(Map<String, dynamic> planData) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated. Cannot save plan.');
    }

    try {
      // Add necessary metadata
      planData['planType'] = 'meal';
      planData['savedAt'] = Timestamp.now();
      planData['userId'] = user.uid;

      // CRITICAL CHANGE: Use the exact document path and 'mealPlan' ID.
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection(
          'gymkitDetails') // Subcollection Name (same as workoutPlan)
          .doc('mealPlan') // Fixed Document ID
          .set(planData, SetOptions(merge: false)); // Overwrite existing data

      print(
          'Meal plan successfully saved to Firestore at /users/${user
              .uid}/gymkitDetails/mealPlan.');
    } catch (e) {
      print('Firestore failed to save the meal plan: $e');
      throw Exception('Failed to save the meal plan: ${e.toString()}');
    }
  }

  // --------------------------------------------------------------------------
  // --- GEMINI API AND HELPER LOGIC (UNCHANGED) ---
  // --------------------------------------------------------------------------

  static Future<Map<String, dynamic>> generateMealPlan({
    required Map<String, dynamic> userInput,
  }) async {
    if (_apiKey.isEmpty) {
      throw Exception('Gemini API key not found in .env file');
    }

    // --- 1. Pre-process input for the prompt ---
    final int? age = int.tryParse(userInput['age'] ?? '');
    final String? gender = (userInput['gender'] as String?)?.toLowerCase();

    final String? weight = (userInput['weight'] != null &&
        (userInput['weight'] as String).isNotEmpty)
        ? "${userInput['weight']} ${userInput['weightUnit'] ?? 'kg'}"
        : null;

    final String? height = (userInput['height'] != null &&
        (userInput['height'] as String).isNotEmpty)
        ? "${userInput['height']} ${userInput['heightUnit'] ?? 'cm'}"
        : null;

    // Convert "Weight Loss" -> "weight_loss"
    final String? goal =
    (userInput['goal'] as String?)?.toLowerCase().replaceAll(' ', '_');

    final List<String> allergies = [
      ...(userInput['allergies'] as List<String>?) ?? []
    ];
    final String? otherAllergies = userInput['otherAllergies'];
    if (otherAllergies != null && otherAllergies.isNotEmpty) {
      // Add any "other" allergies as a single string
      allergies.add(otherAllergies);
    }

    final String? healthConditions = userInput['healthConditions'];

    final int? calorieGoals = int.tryParse(userInput['calories'] ?? '');
    if (calorieGoals == null) {
      throw Exception("Daily calorie goal is required.");
    }

    String? dietType = userInput['dietType'];
    if (dietType == 'Any / No Specific Diet') {
      dietType = null; // Don't send "Any" to the AI, just omit it
    }

    final int numberOfDays =
        int.tryParse((userInput['days'] as String?)?.split(' ')[0] ?? '7') ?? 7;

    // Combine cuisine and preferences into one string
    final String? cuisine = userInput['cuisine'];
    final String? prefs = userInput['preferences'];
    String? cuisinePreference;
    if ((cuisine?.isNotEmpty ?? false) && (prefs?.isNotEmpty ?? false)) {
      cuisinePreference = "Likes: $cuisine. Other preferences: $prefs";
    } else {
      cuisinePreference = (cuisine?.isNotEmpty ?? false) ? cuisine : prefs;
    }

    // --- 2. Create the prompt ---
    final prompt = _createMealPlanPrompt(
      calorieGoals: calorieGoals,
      numberOfDays: numberOfDays,
      age: age,
      gender: gender,
      weight: weight,
      height: height,
      goal: goal,
      allergies: allergies.isNotEmpty ? allergies : null,
      healthConditions:
      (healthConditions != null && healthConditions.isNotEmpty)
          ? healthConditions
          : null,
      dietType: dietType,
      cuisinePreference: cuisinePreference,
    );

    // --- 3. Make API call ---
    try {
      final response = await http.post(
        Uri.parse(
            '$_baseUrl/models/gemini-2.0-flash:generateContent?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ],
          // UPDATED: Added temperature
          'generationConfig': {
            'temperature': 0.1,
          },
        }),
      );

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final data = jsonDecode(response.body);

        if (data['candidates'] == null &&
            data['promptFeedback']?['blockReason'] != null) {
          throw Exception(
              "Request blocked due to safety settings. Please adjust your inputs (e.g., health conditions).");
        }

        final content =
        data['candidates']?[0]?['content']?['parts']?[0]?['text'];

        if (content != null) {
          final parsed = _parseMealPlanResponse(content);
          if (parsed != null) {
            return parsed; // Success!
          } else {
            throw Exception(
                "Received an unexpected format from the AI. Please try again.");
          }
        } else {
          final finishReason = data['candidates']?[0]?['finishReason'];
          if (finishReason != null && finishReason != 'STOP') {
            throw Exception(
                "AI generation stopped unexpectedly ($finishReason). Please try again.");
          }
          throw Exception(
              "The AI model did not return a valid meal plan. Please try again.");
        }
      } else {
        String errorMessage =
            'Failed to connect to the AI service (Code: ${response
            .statusCode}).';
        try {
          final errorData = jsonDecode(response.body);
          errorMessage = errorData['error']?['message'] ?? errorMessage;
        } catch (_) {
          /* Ignore parsing error */
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      throw Exception(
          "Meal plan generation failed: ${e.toString().replaceFirst(
              "Exception: ", "")}");
    }
  }

  // --- NEW HELPER METHOD ---
  static String _createMealPlanPrompt({
    required int calorieGoals,
    required int numberOfDays,
    int? age,
    String? gender,
    String? weight,
    String? height,
    String? goal,
    List<String>? allergies,
    String? healthConditions,
    String? dietType,
    String? cuisinePreference,
  }) {
    // Build the user info block dynamically
    final userInfo = StringBuffer();
    if (age != null) userInfo.writeln('Age: $age');
    if (gender != null && gender.isNotEmpty)
      userInfo.writeln('Gender: $gender');
    if (weight != null && weight.isNotEmpty)
      userInfo.writeln('Weight: $weight');
    if (height != null && height.isNotEmpty)
      userInfo.writeln('Height: $height');
    if (goal != null && goal.isNotEmpty)
      userInfo.writeln('Fitness Goal: $goal');
    userInfo.writeln('Calorie Goals: $calorieGoals kcal per day.');
    if (healthConditions != null && healthConditions.isNotEmpty) {
      userInfo.writeln(
          'IMPORTANT Health Conditions: $healthConditions. The meal plan MUST be suitable for these conditions.');
    }
    if (allergies != null && allergies.isNotEmpty) {
      userInfo.writeln(
          'IMPORTANT Allergies: ${allergies.join(
              ', ')}. The meal plan MUST NOT contain these allergens.');
    }
    if (dietType != null && dietType.isNotEmpty) {
      userInfo.writeln('Diet Type: $dietType');
    }
    if (cuisinePreference != null && cuisinePreference.isNotEmpty) {
      userInfo.writeln('Preferred Cuisine/Preferences: $cuisinePreference');
    }

    // This is the prompt from your JS file, formatted for Dart.
    return '''
You are a personal nutritionist AI agent and chef, specializing in creating meal plans and corresponding grocery lists.
Generate a meal plan for $numberOfDays days.

You will use the following information to make a meal plan tailored to the user:
${userInfo.toString()}

First, provide a detailed meal plan. Structure it clearly, marking each day and meal type with approximate calories.
For each meal (Breakfast, Lunch, Dinner, and Snacks), you MUST provide a simple recipe or preparation instructions.
For example:
**Day 1**
* Breakfast (approx. 350 calories): Oatmeal with Berries
  - Recipe: Combine 1/2 cup rolled oats with 1 cup water and microwave for 2-3 minutes. Top with 1/2 cup of mixed berries.
* Lunch (approx. 500 calories): Grilled Chicken Salad
  - Recipe: Grill a 4oz chicken breast. Chop and serve over 2 cups of mixed greens with cucumber and tomatoes. Dress with 1 tbsp olive oil and lemon juice.

Ensure the total daily calories are close to the $calorieGoals goal.

Second, after creating the full meal plan, create a consolidated grocery list for all the ingredients required for the entire plan.
The grocery list should be an array of strings.
Crucially, you MUST group the grocery list items by category (e.g., Produce, Proteins, Dairy & Alternatives, Pantry, Spices & Oils, Other).
For each category, add a header string like "**Produce**". Then list the items under it.
**You MUST include quantities for each grocery list item.**
For example, the final 'groceryList' array should look like this: ["**Produce**", "Oats (2 cups)", "Mixed Berries (1 lb)", "**Proteins**", "Chicken Breast (2 lbs)"]

Third, provide a simple cooking guide with some general tips or instructions for preparing some of the meals in the plan.

CRITICAL: You MUST respond with ONLY a valid JSON object with this exact schema:
{
  "mealPlan": "[string]",
  "groceryList": ["[string]"],
  "cookingGuide": "[string]"
}
Do not include markdown backticks (```json) or any text outside the JSON object.
''';
  }

  // --- NEW HELPER METHOD ---
  static Map<String, dynamic>? _parseMealPlanResponse(String content) {
    try {
      String cleanContent = content.trim();
      // In case mimeType fails, still try to clean
      if (cleanContent.startsWith('```json')) {
        cleanContent = cleanContent.substring(7);
      }
      if (cleanContent.endsWith('```')) {
        cleanContent = cleanContent.substring(0, cleanContent.length - 3);
      }

      final decoded = jsonDecode(cleanContent) as Map<String, dynamic>;

      // Validate schema
      if (decoded.containsKey('mealPlan') &&
          decoded['mealPlan'] is String &&
          decoded.containsKey('groceryList') &&
          decoded['groceryList'] is List) {
        // Ensure groceryList is List<String>
        final List<String> groceryList =
        List<String>.from(decoded['groceryList']);

        // Cooking guide is optional, default to empty string if null
        final String cookingGuide = (decoded['cookingGuide'] as String?) ?? '';

        return {
          'mealPlan': decoded['mealPlan'],
          'groceryList': groceryList,
          'cookingGuide': cookingGuide,
        };
      } else {
        print(
            "Parsed JSON missing required 'mealPlan' or 'groceryList' keys.");
        return null; // Invalid structure
      }
    } catch (e) {
      print('Error parsing Gemini meal plan response: $e');
      print('Raw content: $content');
      return null; // JSON parsing failed
    }
  }

  // UPDATED: Removed fallback logic
  static Future<Map<String, dynamic>> calculateNutritionGoals({
    required Map<String, dynamic> onboardingData,
  }) async {
    try {
      if (_apiKey.isEmpty) {
        throw Exception('Gemini API key not found in .env file');
      }

      // Calculate basic metrics
      final age = _calculateAge(onboardingData['dateOfBirth']);
      final bmi = _calculateBMI(onboardingData);

      // Create prompt for Gemini
      final prompt = _createNutritionPrompt(onboardingData, age, bmi);

      // Make API call with correct model name
      final response = await http.post(
        Uri.parse(
            '$_baseUrl/models/gemini-2.0-flash:generateContent?key=$_apiKey'),
        // Using 2.0-flash
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.1, // Already 0.1
            'topP': 0.8,
            'topK': 40,
            'maxOutputTokens': 2048,
            'responseMimeType': 'application/json', // Request JSON output
          },
        }),
      );

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final data = jsonDecode(response.body);
        final content =
        data['candidates']?[0]?['content']?['parts']?[0]?['text'];
        if (content != null) {
          final parsed = _parseGeminiResponse(content);
          if (parsed != null) return parsed;
          // CORRECTED: Throw exception if parsing fails
          throw Exception("Failed to parse AI nutrition response.");
        }
        // CORRECTED: Throw exception if no content
        throw Exception("No content received from AI.");
      } else {
        print('Gemini API Error: ${response.statusCode} - ${response.body}');
        // CORRECTED: Throw exception on API error
        throw Exception(
            'Failed to connect to AI service: ${response.statusCode}');
      }
    } catch (e) {
      print('GeminiService Error: $e');
      // CORRECTED: Re-throw the exception instead of falling back
      throw Exception(
          "Nutrition calculation failed: ${e.toString().replaceFirst(
              "Exception: ", "")}");
    }
  }

  static Future<Map<String, dynamic>> getBodyCompositionAnalysis({
    required int age,
    required String gender, // Should be 'male' or 'female' (lowercase)
    required double weightKg,
    required double heightCm,
    String activityLevel = 'moderate', // Default if not provided
  }) async {
    if (_apiKey.isEmpty) {
      throw Exception('Gemini API key not found in .env file');
    }

    // --- Initialize the Generative Model ---
    final model = GenerativeModel(
      // --- Use gemini-1.5-flash as requested and ensure correct name ---
      model:
      'gemini-2.0-flash', // Use 'gemini-1.5-flash-latest' or specific version
      apiKey: _apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.1, // Low temp for factual calculation
        maxOutputTokens: 8192, // Sufficient for the JSON output
        responseMimeType: 'application/json', // CRITICAL for JSON output
      ),
      // Optional: Add safety settings if needed
      // safetySettings: [
      //   SafetySetting(HarmCategory.harassment, HarmBlockThreshold.mediumAndAbove),
      //   // ... other categories ...
      // ],
    );

    // --- Construct the Prompt ---
    final prompt =
    _createBodyCompositionPrompt(
        age, gender, weightKg, heightCm, activityLevel);

    print('--- Sending Body Comp Prompt to Gemini ---');
    // print(prompt); // Keep for debugging if needed
    print('----------------------------------------');

    try {
      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);

      print('--- Gemini Body Comp Response ---');
      // print('Response Text: ${response.text}'); // Keep for debugging
      print(
          'Finish Reason: ${response.promptFeedback?.blockReason ??
              response.candidates.first
                  .finishReason}'); // Check block/finish reason
      print('-------------------------------');

      // Check for blocked prompt first
      if (response.promptFeedback?.blockReason != null) {
        print(
            'Gemini blocked the prompt: ${response.promptFeedback!
                .blockReason}');
        throw Exception(
            "Request blocked due to safety settings (${response.promptFeedback!
                .blockReason}). Please check inputs.");
      }

      // Check if the response text is valid JSON
      final responseText = response.text;
      if (responseText == null || responseText.isEmpty) {
        // Check finish reason if text is empty
        final finishReason = response.candidates.first.finishReason;
        if (finishReason != null && finishReason != FinishReason.stop) {
          print('Gemini Finish Reason: $finishReason');
          throw Exception(
              "AI generation stopped unexpectedly ($finishReason). Please try again.");
        }
        throw Exception('Empty response received from AI analysis.');
      }

      // Parse the JSON response
      try {
        final Map<String, dynamic> analysis = json.decode(responseText);
        // Basic validation: Check if essential keys exist
        if (analysis.containsKey('healthIndicator') &&
            analysis.containsKey('BMI')) {
          print('Parsed Gemini Body Comp Result: Success');
          return analysis;
        } else {
          print('Parsed Gemini JSON missing expected keys.');
          throw Exception(
              'AI returned data in an unexpected format. Please try again.');
        }
      } catch (e) {
        print('Error parsing Gemini JSON response: $e');
        print('Raw response text: $responseText');
        throw Exception(
            'Failed to understand the AI response format. Please try again.');
      }
    } on FormatException catch (e) {
      print('JSON Format Exception during Body Comp: $e');
      throw Exception(
          'The AI response was not in the expected JSON format. Please try again.');
    } catch (e) {
      print('Error during Gemini API call for Body Comp: $e');
      // Rethrow a user-friendly message or the original exception
      throw Exception(
          'Failed to get AI analysis: ${e.toString().replaceFirst(
              "Exception: ", "")}');
    }
  }

  // Helper to create the specific body composition prompt
  static String _createBodyCompositionPrompt(int age, String gender,
      double weightKg, double heightCm, String activityLevel) {
    // *** THIS IS THE NEW PROMPT YOU PROVIDED ***
    return '''
You are an expert exercise physiologist and nutritionist. Your task is to calculate a comprehensive body composition report based on user-provided data. Use established formulas where possible and provide well-reasoned estimates for metrics that typically require specialized equipment.

User data:
- Age: $age
- Gender: $gender
- Weight: $weightKg kg
- Height: $heightCm cm
- Activity Level: $activityLevel

CRITICAL: You MUST respond with ONLY valid JSON. Do not include markdown or any text outside the JSON object.

First, provide the 'healthIndicator' field as a 3-4 sentence summary. This summary should interpret the key findings, highlight a positive aspect, suggest a specific area for improvement, and mention 1-2 key ideal ranges for context (e.g., "Your BMI is healthy, and your muscle mass is good. The key area for focus is your visceral fat level, which is slightly elevated. Aiming to bring it below 13 would be beneficial. Your body fat percentage is within the healthy range of 18-25% for your demographic.").

Then, provide the following 16 metrics as a flat JSON object with keys in "PascalCase" as shown.

1.  "Body Weight": (Return the user's provided weight: $weightKg)
2.  "BMI": (Calculate as weight (kg) / (height (m))^2. Ideal range is 18.5 - 24.9.)
3.  "Body Fat Percentage": (Use Deurenberg formula: (1.20 * BMI) + (0.23 * Age) - (10.8 * (gender=='male' ? 1 : 0)) - 5.4. Adjust based on activity level. Healthy ranges vary: Men: 10-20% (fit), 20-25% (acceptable). Women: 18-28% (fit), 28-32% (acceptable).)
4.  "Body Fat Mass": (Calculate as Body Weight * (Body Fat Percentage / 100))
5.  "Lean Mass": (Calculate as Body Weight - Body Fat Mass. This is your body weight minus fat.)
6.  "Muscle Mass": (Estimate as a percentage of Lean Mass (e.g., ~75-85%). This is the total weight of all muscle in your body.)
7.  "Skeletal Muscle Mass": (A subset of Muscle Mass. A reasonable estimate is about 70-90% of total muscle mass.)
8.  "Bone Mass": (Estimate based on height and gender. Typically 2.5-5% of body weight.)
9.  "Body Water Percentage": (Typically 55-65% for adult males, 45-55% for adult females. Higher for more muscle mass.)
10. "Water Mass": (Calculate as Body Weight * (Body Water Percentage / 100))
11. "Protein Mass": (Estimate as roughly 20% of Muscle Mass.)
12. "Subcutaneous Fat": (Estimate as a percentage of total Body Fat Mass. Typically 80-90% of total fat.)
13. "Visceral Fat Level": (Provide an index from 1-59. Use BMI and age as primary drivers. A healthy level is typically 1-12. Above 13 is considered high.)
14. "BMR": (Use Mifflin-St Jeor equation: 10 * weight (kg) + 6.25 * height (cm) - 5 * age (years) + (gender=='male' ? 5 : -161). This is the calories your body burns at complete rest.)
15. "Metabolic Age": (Compare the user's BMR to the average BMR for their chronological age group. If their BMR is higher, their metabolic age is lower, and vice-versa.)
16. "Body Composition Score": (Create a score from 1-100. Give high weight to healthy body fat percentage, healthy visceral fat level, and good muscle mass relative to weight.)

Ensure all outputs are numbers (use floating point numbers where appropriate, e.g., for percentages, BMI, mass in kg, BMR) and descriptions/indicators are strings as per the schema. Be precise. Return ONLY the JSON object. Example structure (values are illustrative):
{
  "healthIndicator": "Your BMI is in the healthy range, and your estimated muscle mass appears good for your weight. However, your body fat percentage is slightly elevated, particularly visceral fat. Focusing on consistent exercise and nutrition can help improve these areas. A healthy body fat range for you is X%-Y%, and visceral fat should ideally be below 13.",
  "Body Weight": 75.0,
  "BMI": 22.8,
  "Body Fat Percentage": 26.5,
  "Body Fat Mass": 19.9,
  "Lean Mass": 55.1,
  "Muscle Mass": 44.1,
  "Skeletal Muscle Mass": 35.3,
  "Bone Mass": 2.6,
  "Body Water Percentage": 53.5,
  "Water Mass": 40.1,
  "Protein Mass": 8.8,
  "Subcutaneous Fat": 16.9,
  "Visceral Fat Level": 14.0,
  "BMR": 1650.5,
  "Metabolic Age": 35,
  "Body Composition Score": 78
}
''';
  }

  static String _mapWorkoutFrequencyToActivityLevel(String workoutFrequency) {
    // NOTE: You must adjust these values to match your
    // 'workoutFrequency' options from your onboarding flow.
    switch (workoutFrequency.toLowerCase()) {
      case '0-2 workouts/week': // Example
        return 'light';
      case '3-5 workouts/week': // Example
        return 'moderate';
      case '6+ workouts/week': // Example
        return 'active';
      default:
        return 'light'; // Default fallback
    }
  }

  static String _createNutritionPrompt(Map data, int? age, double? bmi) {
    final String activityLevel = _mapWorkoutFrequencyToActivityLevel(
      data['workoutFrequency'] ?? 'light',
    );

    final double weight = (data['weightKg'] ?? 70).toDouble();
    final double height = (data['heightCm'] ?? 170).toDouble();
    final String gender = data['gender'] ?? 'other';
    final String goal = data['goal'] ?? 'maintenance';

    // --- 2. Target Logic (Matches web logic) ---
    dynamic targetAmount = data['targetAmount']; // This is in KG
    dynamic targetTimeframe = data['targetTimeframe']; // This is in weeks

    // Ensure types are correct, converting from dynamic
    final double? targetWeightChangeKg =
    (targetAmount is num) ? targetAmount.toDouble() : null;
    final int? timeFrameWeeks =
    (targetTimeframe is num) ? targetTimeframe.toInt() : null;

    // It ensures weight loss is negative and gain is positive for the prompt.
    double? finalTargetChangeKg = targetWeightChangeKg;
    if (goal == 'weight_loss' &&
        targetWeightChangeKg != null &&
        targetWeightChangeKg > 0) {
      finalTargetChangeKg = -targetWeightChangeKg;
    } else if (goal == 'weight_gain' &&
        targetWeightChangeKg != null &&
        targetWeightChangeKg < 0) {
      finalTargetChangeKg = -targetWeightChangeKg;
    }

    return '''
You are an expert nutritionist. Calculate the personalized daily macronutrient recommendations based on the following user details.
Use the Mifflin-St Jeor equation for Basal Metabolic Rate (BMR):
BMR (kcal/day) = 10 * weight (kg) + 6.25 * height (cm) - 5 * age (years) + s
where s is +5 for males and -161 for females. For 'other' gender, use an average (e.g., -78).

Then, calculate Total Daily Energy Expenditure (TDEE) by multiplying BMR by an activity factor:
- Light: 1.375
- Moderate: 1.55
- Active: 1.725

Adjust TDEE for the goal:
- Maintenance: TDEE
- Weight Loss or Weight Gain:
  ${(finalTargetChangeKg != null) ? '''
  ${(timeFrameWeeks != null) ? '''
  A target weight change of $finalTargetChangeKg kg over $timeFrameWeeks weeks is specified.
  Calculate the required daily calorie deficit or surplus: ($finalTargetChangeKg * 7700 kcal) / ($timeFrameWeeks * 7 days).
  Adjust TDEE by this daily amount to get the target calories.
  Comment on the safety and feasibility of this rate. A sustainable rate is typically 0.5-1 kg/week for loss, and 0.25-0.5 kg/week for gain. If the calculated rate is too aggressive, advise the user and suggest a more moderate calorie adjustment (e.g., +/- 300-500 kcal from TDEE).
  ''' : '''
  Target weight change is specified but no timeframe. Use a default deficit/surplus of 500 kcal from TDEE. For weight loss, TDEE - 500 kcal. For weight gain, TDEE + 500 kcal.
  '''}
  ''' : '''
  No specific target weight change or timeframe provided for weight loss/gain. Use a default deficit/surplus of 500 kcal from TDEE. For weight loss, TDEE - 500 kcal. For weight gain, TDEE + 500 kcal.
  '''}
  Ensure the calorie target is not excessively low (e.g., below BMR or 1200 kcal for women / 1500 kcal for men).

Calculate macronutrients based on the final target daily calories:
- Protein: 1.8g per kg of body weight. (This is a consistent value within the web's 1.6-2.2g/kg range).
- Fat: 25% of total target calories. (This is a consistent value within the web's 20-35% range).
- Carbohydrates: Remainder of calories.
- Fiber: 14 grams per 1000 calories.
(1g Protein = 4 kcal, 1g Carb = 4 kcal, 1g Fat = 9 kcal)

Provide the calculated calories, protein, carbs, fat, and fiber.
Also, provide a simple, friendly explanation with markdown bolding for titles:

**Your Daily Energy Needs:**
- Explain BMR and state the calculated value.
- Explain TDEE and state the calculated value.

**Your Calorie Goal:**
- State the final target daily calories.
- Explain the deficit or surplus.

**Your Custom Macro Plan:**
- Briefly explain how macros were calculated.

**Goal Feasibility (if applicable):**
${(finalTargetChangeKg != null && timeFrameWeeks != null) ? '''
- Comment on the safety and feasibility of their goal rate.
''' : ''}

AVOID using complex jargon or restating mathematical formulas.

User Details:
- Age: ${age ?? 'Unknown'} years
- Gender: $gender
- Weight: ${weight.toStringAsFixed(1)} kg
- Height: ${height.toStringAsFixed(1)} cm
- Activity Level: $activityLevel
- Goal: $goal
${(finalTargetChangeKg != null)
        ? '- Target Weight Change: $finalTargetChangeKg kg'
        : ''}
${(timeFrameWeeks != null) ? '- Timeframe: $timeFrameWeeks weeks' : ''}

Output the results strictly in the JSON format you were trained on, with these exact fields:
"calories": [integer],
"protein": [integer],
"carbs": [integer],
"fat": [integer],
"fiber": [integer],
"bmr": [integer],
"tdee": [integer],
"explanation": "[string explanation]"
''';
  }

  static Map<String, dynamic>? _parseGeminiResponse(String content) {
    try {
      // The content should be a clean JSON string if responseMimeType works
      String cleanContent = content.trim();

      // Remove potential markdown backticks
      if (cleanContent.startsWith('```json')) {
        cleanContent = cleanContent.substring(7);
      }
      if (cleanContent.endsWith('```')) {
        cleanContent = cleanContent.substring(0, cleanContent.length - 3);
      }

      return jsonDecode(cleanContent) as Map<String, dynamic>;
    } catch (e) {
      print('Error parsing Gemini response: $e');
      print('Raw content: $content');
      return null;
    }
  }

  static int? _calculateAge(dynamic dateOfBirth) {
    if (dateOfBirth == null) return null;
    DateTime birthDate;
    if (dateOfBirth is DateTime) {
      birthDate = dateOfBirth;
    } else if (dateOfBirth is String) {
      birthDate = DateTime.tryParse(dateOfBirth) ?? DateTime.now();
    } else {
      return null;
    }
    final today = DateTime.now();
    int age = today.year - birthDate.year;
    if (today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  static double? _calculateBMI(Map data) {
    try {
      // These values are now reliable kg/cm values
      final double? weightKg = data['weightKg']?.toDouble();
      final double? heightCm = data['heightCm']?.toDouble();

      if (weightKg != null && heightCm != null && heightCm > 0) {
        final heightM = heightCm / 100;
        return weightKg / (heightM * heightM);
      }

      return null;
    } catch (e) {
      print('Error calculating BMI: $e');
      return null;
    }
  }

  // --- REMOVED FALLBACK FUNCTIONS ---
  // _calculateFallbackGoals
  // _calculateBMR
  // _getActivityMultiplier
  // _adjustCaloriesForGoal
  // _calculateMacrosForGoal
  // _getFallbackExplanation
  // --- END OF REMOVED FALLBACK FUNCTIONS ---

  static Future<Map<String, dynamic>?> calculateCaloriesBurned({
    required String activityDescriptionWithDuration, // Combined description
    required double userWeightKg,
  }) async {
    try {
      if (_apiKey.isEmpty) {
        throw Exception('Gemini API key not found in .env file');
      }

      // Create the specific prompt for calorie burn
      final prompt =
      _createCalorieBurnPrompt(activityDescriptionWithDuration, userWeightKg);

      print('--- Sending Prompt to Gemini ---');
      print(prompt);
      print('-------------------------------');

      final response = await http.post(
        Uri.parse(
            '$_baseUrl/models/gemini-2.0-flash:generateContent?key=$_apiKey'),
        // Or your preferred model
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ],
          'generationConfig': {
            // UPDATED: Set temperature to 0.1
            'temperature': 0.1,
            // Lower temp for more deterministic results
            'maxOutputTokens': 1024,
            'responseMimeType': 'application/json',
            // IMPORTANT: Request JSON output
          },
          // Optional safety settings (adjust if needed)
          'safetySettings': [
            {
              'category': 'HARM_CATEGORY_HARASSMENT',
              'threshold': 'BLOCK_MEDIUM_AND_ABOVE'
            },
            {
              'category': 'HARM_CATEGORY_HATE_SPEECH',
              'threshold': 'BLOCK_MEDIUM_AND_ABOVE'
            },
            {
              'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
              'threshold': 'BLOCK_MEDIUM_AND_ABOVE'
            },
            {
              'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
              'threshold': 'BLOCK_MEDIUM_AND_ABOVE'
            },
          ]
        }),
      );

      print('--- Gemini Response ---');
      print('Status Code: ${response.statusCode}');
      print('Body: ${response.body}');
      print('-----------------------');

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final data = jsonDecode(response.body);

        // Check for safety blocks first
        if (data['candidates'] == null &&
            data['promptFeedback']?['blockReason'] != null) {
          print(
              'Gemini blocked the request: ${data['promptFeedback']['blockReason']}');
          throw Exception(
              "Request blocked due to safety settings. Please rephrase your activity.");
        }

        // Extract the text content which should be JSON
        final content =
        data['candidates']?[0]?['content']?['parts']?[0]?['text'];

        if (content != null) {
          final parsed = _parseCalorieBurnResponse(
              content); // Use a dedicated parser
          if (parsed != null) {
            print('Parsed Gemini Result: $parsed');
            return parsed; // Success!
          } else {
            // Parsing failed even though content existed
            print('Failed to parse Gemini JSON response.');
            throw Exception(
                "Received an unexpected format from the AI. Please try again.");
          }
        } else {
          // No content found in the response
          print('No content found in Gemini response candidate.');
          // Check if there was a finishReason other than STOP
          final finishReason = data['candidates']?[0]?['finishReason'];
          if (finishReason != null && finishReason != 'STOP') {
            print('Gemini Finish Reason: $finishReason');
            throw Exception(
                "AI generation stopped unexpectedly ($finishReason). Please try again.");
          }
          throw Exception(
              "The AI model did not return a valid estimation. Please try again or rephrase your activity.");
        }
      } else {
        // Handle HTTP errors
        print('Gemini API HTTP Error: ${response.statusCode}');
        // Try to parse error message if available
        String errorMessage =
            'Failed to connect to the AI service (Code: ${response
            .statusCode}).';
        try {
          final errorData = jsonDecode(response.body);
          errorMessage = errorData['error']?['message'] ?? errorMessage;
        } catch (_) {
          /* Ignore parsing error */
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('GeminiService calculateCaloriesBurned Error: $e');
      // Re-throw the specific error message for better feedback in UI
      throw Exception(
          "Calculation failed: ${e.toString().replaceFirst(
              "Exception: ", "")}");
    }
  }

  // Helper to create the specific prompt
  static String _createCalorieBurnPrompt(String activityDescWithDuration,
      double weightKg) {
    // THIS IS THE EXACT PROMPT FROM YOUR WEB BACKEND CODE
    return '''
You are a fitness and exercise science expert. Your task is to estimate the calories burned for a given activity.
You will be provided with a description of the activity and the user's weight in kilograms.

Use your knowledge of exercise science and MET (Metabolic Equivalent of Task) values to provide an accurate estimation.
A general formula is: Calories Burned per Minute = (MET * 3.5 * user's weight in kg) / 200.
First, determine the MET value for the described activity. If the intensity is mentioned (e.g., light, moderate, vigorous), use it to select a more precise MET value.
Then, extract the duration from the description.
Calculate the total estimated calories burned.

Activity Description: $activityDescWithDuration
User Weight: ${weightKg.toStringAsFixed(1)} kg

Output the estimated calories burned and a brief, friendly explanation of how you arrived at the number. For example, mention the MET value you assumed for the activity.
Ensure the 'estimatedCaloriesBurned' is a number and the 'explanation' is a concise string.

Return ONLY a valid JSON object with the following structure:
{
  "estimatedCaloriesBurned": [number],
  "explanation": "[string]"
}
''';
  }

  // Helper to parse the JSON response for calorie burn
  static Map<String, dynamic>? _parseCalorieBurnResponse(String content) {
    try {
      String cleanContent = content.trim();
      // Remove potential markdown backticks if they still appear despite mimeType request
      if (cleanContent.startsWith('```json')) {
        cleanContent = cleanContent.substring(7);
      }
      if (cleanContent.endsWith('```')) {
        cleanContent = cleanContent.substring(0, cleanContent.length - 3);
      }

      final decoded = jsonDecode(cleanContent) as Map<String, dynamic>;

      // Validate expected fields and types
      if (decoded.containsKey('estimatedCaloriesBurned') &&
          decoded['estimatedCaloriesBurned'] is num &&
          decoded.containsKey('explanation') &&
          decoded['explanation'] is String) {
        // Convert to double explicitly for consistency
        decoded['estimatedCaloriesBurned'] =
            (decoded['estimatedCaloriesBurned'] as num).toDouble();

        return decoded;
      } else {
        print("Parsed JSON missing required fields or has wrong types.");
        return null; // Invalid structure
      }
    } catch (e) {
      print('Error parsing Gemini calorie burn response: $e');
      print('Raw content: $content');
      return null; // JSON parsing failed
    }
  }

  // UPDATED: Removed fallback logic and set temperature to 0.1
  static Future<List<String>> generateExercisePreparationTips({
    required String exerciseName,
    required String context,
  }) async {
    if (_apiKey.isEmpty) {
      throw Exception('Gemini API key not found in .env file');
    }

    final prompt = _createPreparationTipsPrompt(
      exerciseName: exerciseName,
      context: context,
    );

    try {
      final response = await http.post(
        Uri.parse(
            '$_baseUrl/models/gemini-2.0-flash:generateContent?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.1, // UPDATED: Set temperature to 0.1
            'maxOutputTokens': 512,
            'responseMimeType': 'application/json',
          },
        }),
      );

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final data = jsonDecode(response.body);

        if (data['candidates'] == null &&
            data['promptFeedback']?['blockReason'] != null) {
          throw Exception(
              "Request blocked due to safety settings. Please try again.");
        }

        final content =
        data['candidates']?[0]?['content']?['parts']?[0]?['text'];

        if (content != null) {
          final parsed = _parsePreparationTipsResponse(content);
          if (parsed != null) {
            return parsed; // Success: returns List<String>
          } else {
            throw Exception(
                "AI returned tips in an unexpected format. Please try again.");
          }
        }
        // CORRECTED: Throw exception if no content
        throw Exception("No content received from AI.");
      } else {
        String errorMessage =
            'Failed to connect to the AI service (Code: ${response
            .statusCode}).';
        try {
          final errorData = jsonDecode(response.body);
          errorMessage = errorData['error']?['message'] ?? errorMessage;
        } catch (_) {
          /* Ignore parsing error */
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      // CORRECTED: Re-throw exception instead of returning a fallback
      print('Exercise tips generation failed: $e');
      throw Exception(
          "Failed to generate tips: ${e.toString().replaceFirst(
              "Exception: ", "")}");
    }
  }

  /// Helper method to create the preparation tips prompt.
  static String _createPreparationTipsPrompt({
    required String exerciseName,
    required String context,
  }) {
    return '''
You are an expert strength and conditioning coach. Your task is to provide 3-5 concise, specific preparation tips for the given exercise.
Preparation tips should cover setup, equipment checks, and specific pre-movement actions.
Do NOT include general advice like "stay hydrated" or "listen to your body." Focus only on the preparation.

Exercise: "$exerciseName"
Additional Context (Instruction): "$context"

CRITICAL: You MUST respond with ONLY a valid JSON object with this exact schema:
{
  "preparationTips": ["[string]", "[string]", "[string]"]
}
Do not include markdown backticks (```json) or any text outside the JSON object.
''';
  }

  /// Helper method to parse the preparation tips response.
  static List<String>? _parsePreparationTipsResponse(String content) {
    try {
      String cleanContent = content.trim();
      if (cleanContent.startsWith('```json')) {
        cleanContent = cleanContent.substring(7);
      }
      if (cleanContent.endsWith('```')) {
        cleanContent = cleanContent.substring(0, cleanContent.length - 3);
      }

      final decoded = jsonDecode(cleanContent) as Map<String, dynamic>;

      if (decoded.containsKey('preparationTips') &&
          decoded['preparationTips'] is List) {
        // Ensure the list is List<String>
        return List<String>.from(decoded['preparationTips']);
      } else {
        print(
            "Parsed JSON missing required 'preparationTips' key or is not a list.");
        return null;
      }
    } catch (e) {
      print('Error parsing Gemini preparation tips response: $e');
      return null;
    }
  }

  // UPDATED: Set temperature to 0.1
  static Future<Map<String, dynamic>> generateRecipe({
    required Map<String, dynamic> userInput,
  }) async {
    if (_apiKey.isEmpty) {
      throw Exception('Gemini API key not configured');
    }

    try {
      final prompt = _createRecipePrompt(userInput);

      final response = await http.post(
        Uri.parse(
            '$_baseUrl/models/gemini-2.0-flash:generateContent?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.1, // UPDATED: Set temperature to 0.1
            'maxOutputTokens': 2048,
            'responseMimeType': 'application/json', // Request JSON
          },
        }),
      );

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final data = jsonDecode(response.body);

        if (data['candidates'] == null &&
            data['promptFeedback']?['blockReason'] != null) {
          throw Exception("Request blocked due to safety settings.");
        }

        final content =
        data['candidates']?[0]?['content']?['parts']?[0]?['text'];

        if (content != null) {
          // UPDATED: _parseRecipeResponse now throws on failure
          return _parseRecipeResponse(content, userInput);
        } else {
          throw Exception("No content received from AI.");
        }
      } else {
        throw Exception(
            'Failed to connect to AI service: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception(
          'Recipe generation failed: ${e.toString().replaceFirst(
              "Exception: ", "")}');
    }
  }

// --- FIX 1: Clarified the prompt schema ---
  static String _createRecipePrompt(Map<String, dynamic> userInput) {
    final ingredients = userInput['ingredients'];
    final cuisine = userInput['cuisine'];
    final mealType = userInput['mealType'];
    final restrictions = userInput['restrictions'];

    return '''
You are a professional chef and nutritionist. Create a detailed recipe based on the following user preferences:

Available Ingredients: $ingredients
Cuisine Style: $cuisine
Meal Type: $mealType
Dietary Restrictions: ${restrictions.isEmpty ? 'None' : restrictions}

Please provide a complete recipe with:
1. An appealing recipe name
2. Brief description
3. Detailed ingredients list with quantities
4. Step-by-step cooking instructions
5. Estimated cooking time
6. Serving size
7. Difficulty level
8. Nutritional information (calories, protein, carbs, fat per serving)

Format the response as a JSON object with the following structure:
{
  "name": "[string]",
  "description": "[string]",
  "prepTime": "[string]", 
  "cookTime": "[string]", 
  "totalTime": "[string]",
  "servings": "[number]",
  "difficulty": "[string]",
  "cuisine": "[string]",
  "mealType": "[string]",
  "ingredients": ["[string with quantity]", "[string with quantity]"],
  "instructions": ["[step 1]", "[step 2]"],
  "nutritionalInfo": {
    "calories": "[string with units]",
    "protein": "[string with units]",
    "carbs": "[string with units]", 
    "fat": "[string with units]"
  },
  "tips": ["[string tip 1]", "[string tip 2]"]
}

Make the recipe creative, practical, and suitable for the specified cuisine and meal type.
CRITICAL: You MUST respond with ONLY a valid JSON object.
''';
  }
// --- FIX: This function now safely converts lists ---
  static Map<String, dynamic> _parseRecipeResponse(
      String content, Map<String, dynamic> userInput) {
    try {
      String cleanContent = content.trim();

      // Find the first '{' and the last '}' to extract the JSON object
      final int startIndex = cleanContent.indexOf('{');
      final int endIndex = cleanContent.lastIndexOf('}');

      if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
        cleanContent = cleanContent.substring(startIndex, endIndex + 1);
      } else {
        // If no '{' or '}' is found, the content is definitely not JSON
        throw Exception("No valid JSON object found in the AI response.");
      }

      final Map<String, dynamic> recipe = jsonDecode(cleanContent);

      // --- NEW LINES ---
      // Safely convert the dynamic lists to List<String>
      // This prevents the 'List<dynamic>' error in the UI
      if (recipe['ingredients'] is List) {
        recipe['ingredients'] = (recipe['ingredients'] as List)
            .map((item) => item.toString())
            .toList();
      }
      if (recipe['instructions'] is List) {
        recipe['instructions'] = (recipe['instructions'] as List)
            .map((item) => item.toString())
            .toList();
      }
      if (recipe['tips'] is List) {
        recipe['tips'] =
            (recipe['tips'] as List).map((item) => item.toString()).toList();
      }
      // --- END OF NEW LINES ---

      // Add metadata
      recipe['generatedOn'] = DateTime.now().toString().split(' ')[0];
      recipe['userInput'] = userInput;

      return recipe;
    } catch (e) {
      // CORRECTED: Throw exception instead of returning fallback
      print('Error parsing AI recipe: $e');
      print('Raw content: $content');
      throw Exception('Failed to parse AI recipe response. Please try again.');
    }
  }
}