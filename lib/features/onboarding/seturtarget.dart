import 'package:flutter/material.dart';
import 'package:trackai/core/constants/appcolors.dart';
import 'package:trackai/features/onboarding/service/observices.dart';
import 'dart:math'; // Import for ceiling function

class SetYourTargetPage extends StatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;
  final Function(Map<String, dynamic>) onDataUpdate;
  final bool isMetric;
  final String goal;

  const SetYourTargetPage({
    Key? key,
    required this.onNext,
    required this.onBack,
    required this.onDataUpdate,
    required this.isMetric,
    required this.goal,
  }) : super(key: key);

  @override
  State<SetYourTargetPage> createState() => _SetYourTargetPageState();
}

class _SetYourTargetPageState extends State<SetYourTargetPage> {
  final TextEditingController _amountController = TextEditingController();
  final FocusNode _amountFocusNode = FocusNode();

  String selectedUnit = 'kg';
  bool _isNextEnabled = false;
  bool _isLoading = false;
  bool _isAmountFocused = false;

  // New state variables
  bool _showPaceOptions = false;
  double _enteredAmount = 0.0;
  double? _selectedPaceValue; // e.g., 0.5, 1.0, 1.5
  int? _calculatedTimeframe; // e.g., 50, 25, 17

  @override
  void initState() {
    super.initState();
    selectedUnit = widget.isMetric ? 'kg' : 'lbs';
    _amountController.addListener(_onAmountChanged);
    _amountFocusNode.addListener(() {
      setState(() {
        _isAmountFocused = _amountFocusNode.hasFocus;
      });
    });
  }

  void _onAmountChanged() {
    final amount = double.tryParse(_amountController.text);
    setState(() {
      if (amount != null && amount > 0) {
        _enteredAmount = amount;
        _showPaceOptions = true;
        // If amount changes, reset pace selection
        _selectedPaceValue = null;
        _calculatedTimeframe = null;
      } else {
        _enteredAmount = 0.0;
        _showPaceOptions = false;
        _selectedPaceValue = null;
        _calculatedTimeframe = null;
      }
      // Validate next button
      _isNextEnabled = _showPaceOptions && _selectedPaceValue != null;
    });
  }

  void _handleNext() async {
    if (_isNextEnabled && !_isLoading) {
      setState(() {
        _isLoading = true;
      });

      try {
        double amount = double.parse(_amountController.text);
        double amountKg;
        double amountLbs;

        if (selectedUnit == 'kg') {
          amountKg = amount;
          amountLbs = amount * 2.20462;
        } else {
          amountLbs = amount;
          amountKg = amount / 2.20462;
        }

        // Calculate target pace in KG for backend consistency
        double targetPaceKg;
        if (selectedUnit == 'kg') {
          targetPaceKg = _selectedPaceValue!;
        } else {
          // Convert lbs/week to kg/week
          targetPaceKg = _selectedPaceValue! / 2.20462;
        }

        final targetData = {
          'targetAmountKg': amountKg,
          'targetAmountLbs': amountLbs,
          'targetUnit': selectedUnit,
          'targetTimeframe': _calculatedTimeframe, // Use the calculated value
          'targetPaceKg': targetPaceKg,
        };

        // Save target data to Firebase
        await OnboardingService.updateOnboardingData(targetData);

        // Update parent widget with the data
        widget.onDataUpdate(targetData);

        // Navigate to next page
        widget.onNext();
      } catch (e) {
        print('Error saving target data: $e');
        // Show error message to user
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to save data. Please try again.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _amountController.removeListener(_onAmountChanged);
    _amountController.dispose();
    _amountFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.06,
            vertical: screenHeight * 0.02,
          ),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      const Text(
                        'Set Your Target',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                          letterSpacing: -0.5,
                          height: 1.2,
                        ),
                      ),

                      SizedBox(height: screenHeight * 0.01),

                      // Subtitle
                      Text(
                        'Specifics help us create a precise plan and give you feedback on a healthy rate of change.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w400,
                          height: 1.5,
                        ),
                      ),

                      SizedBox(height: screenHeight * 0.05),

                      // Amount to Gain/Lose
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.goal == 'gain_weight'
                                ? 'Amount to Gain'
                                : 'Amount to Lose',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _isAmountFocused
                                          ? AppColors.primary(false) // <--- FIX: Call the function
                                          : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                  child: TextField(
                                    controller: _amountController,
                                    focusNode: _amountFocusNode,
                                    keyboardType:
                                    TextInputType.numberWithOptions(
                                        decimal: true),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black,
                                    ),
                                    decoration: const InputDecoration(
                                      hintText: 'E.g., 5',
                                      hintStyle: TextStyle(
                                        color: Colors.grey,
                                        fontWeight: FontWeight.w400,
                                      ),
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.symmetric(
                                        vertical: 18,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 1,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.transparent,
                                      width: 1,
                                    ),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: selectedUnit,
                                      isExpanded: true,
                                      icon: Icon(Icons.keyboard_arrow_down,
                                          color: Colors.black),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black,
                                      ),
                                      dropdownColor: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 16),
                                      items:
                                      ['kg', 'lbs'].map((String value) {
                                        return DropdownMenuItem<String>(
                                          value: value,
                                          child: Text(
                                            value,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.black,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (String? newValue) {
                                        if (newValue != null) {
                                          setState(() {
                                            selectedUnit = newValue;
                                            // Trigger re-calculation if amount is already entered
                                            _onAmountChanged();
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Enter a positive number for the amount to ${widget.goal == 'gain_weight' ? 'gain' : 'lose'}.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),

                      // --- NEW: "Choose Your Pace" Section ---
                      if (_showPaceOptions) _buildPaceSelector(),
                    ],
                  ),
                ),
              ),

              // Navigation buttons
              SizedBox(height: screenHeight * 0.02),
              Row(
                children: [
                  GestureDetector(
                    onTap: widget.onBack,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: Colors.grey[300]!, width: 1),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new,
                        color: Colors.black,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        color: (_isNextEnabled && !_isLoading)
                            ? Colors.black
                            : Colors.grey[300],
                      ),
                      child: ElevatedButton(
                        onPressed: (_isNextEnabled && !_isLoading)
                            ? _handleNext
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                        child: _isLoading
                            ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                            : Text(
                          'Next',
                          style: TextStyle(
                            color: (_isNextEnabled && !_isLoading)
                                ? Colors.white
                                : Colors.grey[600],
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

  // --- NEW: Widget Builder for Pace Options ---
  Widget _buildPaceSelector() {
    final bool isKg = selectedUnit == 'kg';
    final String unitLabel = isKg ? 'kg' : 'lbs';
    final String goalLabel = widget.goal == 'gain_weight' ? 'gain' : 'lose';

    // Define paces based on selected unit
    // KG: 0.5 (Recommended), 1.0 (Fast), 1.5 (Ambitious)
    // LBS: 1.0 (Recommended), 2.0 (Fast), 3.0 (Ambitious)
    final double paceValue1 = isKg ? 0.5 : 1.0;
    final double paceValue2 = isKg ? 1.0 : 2.0;
    final double paceValue3 = isKg ? 1.5 : 3.0;

    // Calculate estimated timeframes (and round up)
    final int timePace1 = (_enteredAmount / paceValue1).ceil();
    final int timePace2 = (_enteredAmount / paceValue2).ceil();
    final int timePace3 = (_enteredAmount / paceValue3).ceil();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.04),
        const Text(
          'Choose Your Pace',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 12),
        _buildPaceOptionCard(
          pace: paceValue1,
          unit: unitLabel,
          timeframe: timePace1,
          label: 'Recommended',
          paceValue: paceValue1,
          goalLabel: goalLabel,
        ),
        const SizedBox(height: 12),
        _buildPaceOptionCard(
          pace: paceValue2,
          unit: unitLabel,
          timeframe: timePace2,
          label: 'Fast',
          paceValue: paceValue2,
          goalLabel: goalLabel,
        ),
        const SizedBox(height: 12),
        _buildPaceOptionCard(
          pace: paceValue3,
          unit: unitLabel,
          timeframe: timePace3,
          label: 'Ambitious',
          paceValue: paceValue3,
          goalLabel: goalLabel,
        ),
      ],
    );
  }

  // --- NEW: Helper widget for the pace card ---
  Widget _buildPaceOptionCard({
    required double pace,
    required String unit,
    required int timeframe,
    required String label,
    required double paceValue,
    required String goalLabel,
  }) {
    final bool isSelected = _selectedPaceValue == paceValue;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPaceValue = paceValue;
          _calculatedTimeframe = timeframe;
          _isNextEnabled = true; // Since this can only be tapped if options are shown
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.black : Colors.grey[200]!,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$pace $unit / week',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: isSelected ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
            Text(
              'Est. $timeframe weeks',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}