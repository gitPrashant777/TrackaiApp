import 'dart:io';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class Gemini {
  // Use the v1beta endpoint to access JSON mode
  static const String baseUrl =
      "https://generativelanguage.googleapis.com/v1beta/models/";

  final apiKey = dotenv.env['GEMINI_API_KEY'];

  // --- FUNCTION 1 (STEP 1) ---
  // This prompt is now from 'identify-ingredients.ts'
  // It ONLY returns the ingredient list.
  Future<String> describeFoodFromImage(File imageFile) async {
    try {
      final imageBytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(imageBytes);

      // This prompt is a direct translation of 'identify-ingredients.ts'
      final prompt = '''
You are an expert food analyst with exceptional visual acuity, tasked with identifying ingredients for a nutritional analysis app. Accuracy is critical for the user's health tracking.
Your primary task is to identify the dish and every single ingredient in the food image provided and estimate the weight of each ingredient in grams.

First, determine if the image provided is primarily of a food item or meal.

- If it IS a food item/meal:
  - Set 'isFoodItem' to true.
  - If the image contains a recognizable dish (e.g., 'Spaghetti Bolognese', 'Chicken Salad'), provide a concise 'dishName'. Otherwise, leave the 'dishName' field empty.
  - Create a detailed list of all identifiable ingredients in the 'ingredients' array.
  - For each ingredient, provide a 'name' and an estimated 'weightGrams'.
  - Be as granular as possible. For example, for a salad, identify 'Romaine Lettuce', 'Cherry Tomatoes', 'Cucumber slices', 'Grilled Chicken Breast', and 'Caesar Dressing' as separate items with their own weights.
  - **Crucially, infer the presence of common 'hidden' ingredients based on the dish's appearance. This includes cooking oils (e.g., olive oil, butter), seasonings (salt, pepper), and the base components of sauces or dressings.**
  - Do NOT provide a 'nonFoodDescription'.

- If it IS NOT a food item/meal (e.g., a car, a landscape, a person):
  - Set 'isFoodItem' to false.
  - Provide a brief, concise description of what you see in the 'nonFoodDescription' field.
  - Do NOT provide an 'ingredients' array or a 'dishName'.

You MUST respond with ONLY a valid JSON object in this EXACT format:
{
  "isFoodItem": true,
  "dishName": "e.g., Chicken Caesar Salad",
  "ingredients": [
    {"name": "Grilled Chicken Breast", "weightGrams": 150},
    {"name": "Romaine Lettuce", "weightGrams": 100}
  ],
  "nonFoodDescription": null
}

OR

{
  "isFoodItem": false,
  "dishName": null,
  "ingredients": null,
  "nonFoodDescription": "A photo of a car."
}
''';

      return await _callGeminiVision(prompt, base64Image);
    } catch (e) {
      throw Exception('Failed to identify ingredients: $e');
    }
  }


  Future<String> describeFoodFromIngredients(
      List<Map<String, dynamic>> ingredients) async {
    try {

      final ingredientListString = ingredients
          .map((ing) {
        final weight = ing['weightGrams'] ?? ing['weight_g'] ?? 0;
        return "- ${ing['name']}: ${weight}g";
      })
          .join('\n');

      // Also create a clean list for the AI to parse, matching the web schema
      final ingredientsForPrompt = ingredients.map((ing) {
        return {
          "name": ing['name'],
          "weightGrams": ing['weightGrams'] ?? ing['weight_g'] ?? 0
        };
      }).toList();

      final prompt = '''
You are an expert nutritionist using a comprehensive nutritional database. Your task is to calculate the detailed nutritional information for a meal based on a list of ingredients and their weights in grams. Provide the most accurate estimates possible.

Based on the ingredients list provided:
1.  Calculate the total estimated nutritional content. You MUST provide estimates for: calories, total protein, total carbohydrates (including fiber and sugar), total fat (including saturated fat if possible), and sodium (in mg).
2.  Sum the weights of all ingredients to get the total 'estimatedWeightGrams'.
3.  Provide a 'healthScore' from 1 (unhealthy) to 10 (very healthy).
4.  Provide a concise 'healthScoreExplanation' for the score.
5.  For up to 3 of the most significant ingredients, provide a 'detailedAnalysis' of their health benefits (use 'ingredient' and 'analysis' keys).
6.  Structure your output strictly according to the provided schema.

Here is the list of ingredients:
$ingredientListString

You MUST respond with ONLY a valid JSON object in this EXACT format:
{
  "estimatedNutrition": {
    "estimatedWeightGrams": 325,
    "calories": 550,
    "protein": 45,
    "carbohydrates": {
      "total": 30,
      "fiber": 5,
      "sugar": 10
    },
    "fat": {
      "total": 28,
      "saturated": 8
    },
    "sodium": 600,
    "healthScore": 7,
    "healthScoreExplanation": "A high-protein meal, balanced with fats and carbs. The sodium is slightly high from the dressing."
  },
  "detailedAnalysis": [
    {
      "ingredient": "Grilled Chicken Breast",
      "analysis": "Excellent source of lean protein, essential for muscle repair and growth."
    },
    {
      "ingredient": "Romaine Lettuce",
      "analysis": "Provides hydration and vitamins A and K, but is low in calories."
    }
  ]
}
''';

      return await _callGeminiText(prompt);
    } catch (e) {
      throw Exception('Failed to calculate nutrition from ingredients: $e');
    }
  }

  // --- HELPER: Call Vision Model (for Image + Text) ---
  Future<String> _callGeminiVision(String prompt, String base64Image) async {
    final url =
    Uri.parse(baseUrl + "gemini-2.0-flash:generateContent?key=$apiKey");

    final requestBody = {
      'contents': [
        {
          'parts': [
            {'text': prompt},
            {
              'inline_data': {'mime_type': 'image/jpeg', 'data': base64Image},
            },
          ],
        },
      ],
      'generationConfig': {
        'temperature': 0.1, // 0.0 for factual, reproducible results
        'topK': 40,
        'topP': 0.95,
        'maxOutputTokens': 8192,
        'responseMimeType': "application/json", // Force JSON output
      },
      'safetySettings': [
        {
          'category': 'HARM_CATEGORY_HARASSMENT',
          'threshold': 'BLOCK_MEDIUM_AND_ABOVE',
        },
        {
          'category': 'HARM_CATEGORY_HATE_SPEECH',
          'threshold': 'BLOCK_MEDIUM_AND_ABOVE',
        },
        {
          'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
          'threshold': 'BLOCK_MEDIUM_AND_ABOVE',
        },
        {
          'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
          'threshold': 'BLOCK_MEDIUM_AND_ABOVE',
        },
      ],
    };
    return await _executeRequest(url, requestBody);
  }

  // --- HELPER: Call Text Model (for Text-Only) ---
  Future<String> _callGeminiText(String prompt) async {
    final url =
    Uri.parse(baseUrl + "gemini-2.0-flash:generateContent?key=$apiKey");

    final requestBody = {
      'contents': [
        {
          'parts': [
            {'text': prompt}, // Only text
          ],
        },
      ],
      'generationConfig': {
        'temperature': 0.1,
        'topK': 40,
        'topP': 0.95,
        'maxOutputTokens': 8192,
        'responseMimeType': "application/json",
      },
      'safetySettings': [
        {
          'category': 'HARM_CATEGORY_HARASSMENT',
          'threshold': 'BLOCK_MEDIUM_AND_ABOVE',
        },
        {
          'category': 'HARM_CATEGORY_HATE_SPEECH',
          'threshold': 'BLOCK_MEDIUM_AND_ABOVE',
        },
        {
          'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
          'threshold': 'BLOCK_MEDIUM_AND_ABOVE',
        },
        {
          'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
          'threshold': 'BLOCK_MEDIUM_AND_ABOVE',
        },
      ],
    };
    return await _executeRequest(url, requestBody);
  }

  // --- HELPER: Shared Network Request Logic ---
  Future<String> _executeRequest(
      Uri url, Map<String, dynamic> requestBody) async {
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final responseData = json.decode(response.body);

        if (responseData['candidates'] != null &&
            responseData['candidates'].isNotEmpty &&
            responseData['candidates'][0]['content'] != null &&
            responseData['candidates'][0]['content']['parts'] != null &&
            responseData['candidates'][0]['content']['parts'].isNotEmpty) {
          String textResponse =
              responseData['candidates'][0]['content']['parts'][0]['text'] ??
                  '{}';
          return textResponse.trim();
        } else {
          if (responseData['promptFeedback'] != null) {
            final feedback = responseData['promptFeedback'];
            if (feedback['blockReason'] != null) {
              return '{"isFoodItem": false, "nonFoodDescription": "Analysis blocked: ${feedback['blockReason']}"}';
            }
          }
          throw Exception('Invalid response format from Gemini API');
        }
      } else if (response.body.isEmpty) {
        throw Exception(
            'Empty response from Gemini API. Check network and endpoint.');
      } else {
        final errorData =
        response.body.isNotEmpty ? json.decode(response.body) : {};
        final errorMessage = errorData['error']?['message'] ?? 'Unknown error';
        throw Exception('API Error (${response.statusCode}): $errorMessage');
      }
    } catch (e) {
      if (e is http.ClientException) {
        throw Exception('Network error: Please check your internet connection');
      }
      rethrow;
    }
  }

  Future<String> analyzeNutritionLabel(File imageFile) async {
    try {
      final imageBytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(imageBytes);

      final prompt = """
Analyze this nutrition facts label and provide detailed information.
IMPORTANT: You MUST respond with ONLY a valid JSON object, no additional text or markdown formatting.
If it is NOT a valid nutrition label, respond with:
{
  "isValidLabel": false,
  "errorMessage": "No valid nutrition label detected. Please take a clear photo of a nutrition facts label."
}

If it IS a valid nutrition label, respond with this EXACT JSON structure:
{
  "isValidLabel": true,
  "productName": "name of the product",
  "servingSize": "serving size information",
  "servingsPerContainer": "number of servings",
  "calories": 0,
  "quickSummary": "brief nutritional assessment",
  "nutrientBreakdown": {
    "totalFat": {"amount": "0g", "dv": "0% DV", "insight": "Total fat includes all types of fats in the product. It's important for energy and nutrient absorption, but should be consumed in moderation."},
    "saturatedFat": {"amount": "0g", "dv": "0% DV", "insight": "Saturated fat can raise cholesterol levels and should be limited in the diet."},
    "transFat": {"amount": "0g", "dv": "0% DV", "insight": "Trans fat is unhealthy and should be avoided as much as possible."},
    "cholesterol": {"amount": "0mg", "dv": "0% DV", "insight": "Cholesterol is a type of fat found in animal products. High levels in the blood can increase the risk of heart disease."},
    "sodium": {"amount": "0mg", "dv": "0% DV", "insight": "Sodium is a mineral that affects blood pressure. Most people should limit their sodium intake."},
    "totalCarbohydrate": {"amount": "0g", "dv": "0% DV", "insight": "Total carbohydrates are a primary energy source. Complex carbs are better than simple sugars."},
    "dietaryFiber": {"amount": "0g", "dv": "0% DV", "insight": "Dietary fiber aids digestion and can help lower cholesterol. Many people don't get enough."},
    "totalSugars": {"amount": "0g", "dv": "0% DV", "insight": "Excessive sugar intake can lead to weight gain and increased risk of chronic diseases."},
    "addedSugars": {"amount": "0g", "dv": "0% DV", "insight": "Added sugars contribute empty calories and should be consumed sparingly."},
    "protein": {"amount": "0g", "dv": "0% DV", "insight": "Protein is essential for muscle repair and growth, and overall body function."}
  },
  "vitaminsInsight": "Vitamins are a group of organic compounds which are essential for normal growth and nutrition and are required in small quantities in the diet.",
  "vitamins": [
    {"name": "Vitamin A", "amount": "0%", "dv": "0% DV", "insight": "Vitamin A is important for vision, immune function, and cell growth."},
    {"name": "Vitamin C", "amount": "0%", "dv": "0% DV", "insight": "Vitamin C is an antioxidant vital for immune health and skin integrity."}
  ],
  "mineralsInsight": "Minerals are inorganic elements, such as calcium, iron, and zinc, which are essential for the body's functions and are obtained from the diet.",
  "minerals": [
    {"name": "Calcium", "amount": "0%", "dv": "0% DV", "insight": "Calcium is essential for strong bones and teeth, and plays a role in muscle function."},
    {"name": "Iron", "amount": "0%", "dv": "0% DV", "insight": "Iron is vital for red blood cell production and oxygen transport throughout the body."}
  ],
  "ingredientInsights": "analysis of key ingredients and their health implications"
}

You MUST populate all 'amount', 'dv', and 'insight' fields. Provide a concise, helpful insight for each nutrient, a general insight for 'vitaminsInsight', and a general insight for 'mineralsInsight'.
""";

      return await _callGeminiVision(prompt, base64Image);
    } catch (e) {
      throw Exception('Failed to analyze nutrition label: $e');
    }
  }

  // This function is no longer used by NutritionScannerScreen,
  // but we leave it here in case other parts of your app call it.
  Future<String> analyzeNutritionFromImage(File imageFile) async {
    try {
      final imageBytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(imageBytes);

      final prompt = """
Analyze this food image and provide detailed nutrition information.
IMPORTANT: You MUST respond with ONLY a valid JSON object, no additional text or markdown formatting.
Return the information in this EXACT JSON format:
{
  "foodName": "name of the food",
  "healthScore": 8,
  "healthDescription": "detailed health assessment",
  "description": "comprehensive description",
  "nutritionalBreakdown": {
    "calories": 500,
    "protein": 25,
    "carbohydrates": 60,
    "fat": 15,
    "fiber": 8,
    "sugar": 10,
    "sodium": 500
  },
  "ingredients": ["ingredient1", "ingredient2", "ingredient3", "ingredient4", "ingredient5"],
  "origin": "country/region",
  "whoShouldPrefer": [
    {"group": "Athletes", "reason": "provides quick energy"},
    {"group": "Growing children", "reason": "nutrients for development"},
    {"group": "Active individuals", "reason": "sustained energy"},
    {"group": "Health enthusiasts", "reason": "balanced nutrition"}
  ],
  "whoShouldAvoid": [
    {"group": "Diabetics", "reason": "high carbohydrate content"},
    {"group": "Low-sodium diets", "reason": "high sodium levels"},
    {"group": "Weight loss", "reason": "high calorie density"},
    {"group": "Specific allergies", "reason": "contains allergens"}
  ],
  "allergenInfo": "list of allergens or 'No major allergens detected'",
  "quickNote": "interesting fact or health tip"
}
      """;

      return await _callGeminiVision(prompt, base64Image);
    } catch (e) {
      throw Exception('Failed to analyze nutrition: $e');
    }
  }
}