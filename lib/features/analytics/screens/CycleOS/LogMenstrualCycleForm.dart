import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

class LogMenstrualCycleForm extends StatefulWidget {
  const LogMenstrualCycleForm({Key? key}) : super(key: key);

  @override
  State<LogMenstrualCycleForm> createState() => _LogMenstrualCycleFormState();
}

class _LogMenstrualCycleFormState extends State<LogMenstrualCycleForm> {
  DateTime _selectedDate = DateTime.now();
  DateTime _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
  final TextEditingController _cycleLengthController =
  TextEditingController(text: '28');
  final TextEditingController _periodLengthController =
  TextEditingController(text: '5');
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // You could fetch existing data here if you want this form to 'edit'
    // For now, it just sets new data.
  }

  void _onDateSelected(DateTime date) {
    setState(() {
      _selectedDate = date;
    });
  }

  Future<void> _saveEntry() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: Not logged in.')),
      );
      setState(() {
        _isSaving = false;
      });
      return;
    }

    try {
      final int cycleLength = int.parse(_cycleLengthController.text);
      final int periodLength = int.parse(_periodLengthController.text);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('period_settings')
          .doc('config')
          .set({
        'lastPeriodDate': Timestamp.fromDate(_selectedDate),
        'cycleLengthDays': cycleLength,
        'periodLengthDays': periodLength,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cycle data saved!')),
        );
        // Pop with 'true' to signal success to the dashboard
        Navigator.pop(context, true);
      }
    } catch (e) {
      print("Error saving entry: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving data: $e')),
        );
      }
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // --- MODIFICATION: Changed from Padding to Scaffold ---
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Log Menstrual Cycle',style: TextStyle(fontWeight: FontWeight.bold, ),),

        backgroundColor: Colors.white,
        foregroundColor: Colors.black, // For title
        iconTheme: const IconThemeData(color: Colors.black), // For back arrow
        elevation: 1,
      ),
      // Scaffold handles keyboard avoidance by default
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          // Padding is now on the SingleChildScrollView
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              const SizedBox(height: 4),
              const Text(
                'Select the start date of your last period.',
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              _buildMonthSelector(),
              const SizedBox(height: 8),
              _buildCalendarGrid(),
              _buildTextField(
                label: 'Typical Cycle Length (days)*',
                controller: _cycleLengthController,
                hint: 'e.g., 28',
              ),
              const SizedBox(height: 15),
              _buildTextField(
                label: 'Period Length (days)',
                controller: _periodLengthController,
                hint: 'e.g., 5',
                isOptional: true,
              ),
              // Use top padding here instead of the final SizedBox
              Padding(
                padding: const EdgeInsets.only(top: 24, bottom: 40),
                child: Row(
                  children: [
                    // "Save" button
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveEntry,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE91E63),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white),
                          ),
                        )
                            : const Text(
                          'Save Entry',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // "Cancel" button
                    Expanded(
                      child: OutlinedButton(
                        // Just pops the screen
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.grey[400]!),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),

                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text(
                          'Cancel',
                          style:
                          TextStyle(color: Colors.black54, fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMonthSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF5E6F1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Colors.black54),
            onPressed: () {
              setState(() {
                _currentMonth =
                    DateTime(_currentMonth.year, _currentMonth.month - 1);
              });
            },
          ),
          Text(
            DateFormat('MMMM yyyy').format(_currentMonth),
            style: const TextStyle(
              color: Colors.black,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: Colors.black54),
            onPressed: () {
              setState(() {
                _currentMonth =
                    DateTime(_currentMonth.year, _currentMonth.month + 1);
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final daysInMonth =
    DateUtils.getDaysInMonth(_currentMonth.year, _currentMonth.month);
    final firstDayOfMonth =
    DateTime(_currentMonth.year, _currentMonth.month, 1);
    final weekdayOfFirstDay = firstDayOfMonth.weekday % 7;

    final weekdays = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1.5,
      ),
      itemCount: daysInMonth + weekdayOfFirstDay + 7,
      itemBuilder: (context, index) {
        if (index < 7) {
          return Center(
            child: Text(
              weekdays[index],
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        }

        int gridIndex = index - 7;
        if (gridIndex < weekdayOfFirstDay) {
          return Container();
        }

        final day = gridIndex - weekdayOfFirstDay + 1;
        if (day > daysInMonth) {
          return Container();
        }

        final currentDate =
        DateTime(_currentMonth.year, _currentMonth.month, day);
        final isSelected = DateUtils.isSameDay(currentDate, _selectedDate);

        return GestureDetector(
          onTap: () => _onDateSelected(currentDate),
          child: Container(
            alignment: Alignment.center,
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFE91E63) : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$day',
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
    bool isOptional = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.black, fontSize: 14),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          style: const TextStyle(color: Colors.black),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[500]),
            filled: true,
            fillColor: const Color(0xFFF5E6F1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Color(0xFFE91E63)),
            ),
          ),
          validator: (value) {
            if (!isOptional && (value == null || value.isEmpty)) {
              return 'This field is required';
            }
            if (value != null && value.isNotEmpty) {
              final n = int.tryParse(value);
              if (n == null || n <= 0) {
                return 'Please enter a valid number';
              }
            }
            return null;
          },
        ),
      ],
    );
  }
}