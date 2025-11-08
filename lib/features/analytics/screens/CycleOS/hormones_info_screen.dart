import 'package:flutter/material.dart';
class HormonesInfoScreen extends StatelessWidget {
  // --- NEW: Added currentPhase ---
  final String currentPhase;

  const HormonesInfoScreen({
    Key? key,
    required this.currentPhase, // Make it required
  }) : super(key: key);
  // ------------------------------

  // --- Define colors and styles ---
  static const Color _greenColor = Color(0xFF63C68B);
  static const Color _blueColor = Color(0xFF67A5E1);
  static const Color _yellowColor = Color(0xFFE5B942);
  static const Color _redColor = Color(0xFFE86C6B);
  static const Color _orangeColor = Color(0xFFFFA726);
  static const Color _pinkColor = Color(0xFFEC407A);

  static const TextStyle _defaultStyle = TextStyle(
    fontSize: 15,
    height: 1.5,
    color: Colors.black87,
  );
  static const TextStyle _boldStyle = TextStyle(
    fontSize: 15,
    height: 1.5,
    color: Colors.black87,
    fontWeight: FontWeight.w600,
  );
  // --------------------------------

  // --- NEW: Helper to get color from phase name ---
  Color _getPhaseColor(String phase) {
    if (phase.contains('Period') || phase.contains('Menstrual')) return _redColor;
    if (phase.contains('Follicular')) return _blueColor;
    if (phase.contains('Ovulation') || phase.contains('Fertile')) return _greenColor; // Ovulation is green in this file
    if (phase.contains('Luteal')) return _orangeColor;
    if (phase.contains('PMS')) return _pinkColor;
    return Colors.black87; // Default
  }

  // --- NEW: Helper to get the short phase description ---
  String _getPhaseDescription(String phase) {
    if (phase.contains('Period') || phase.contains('Menstrual')) {
      return "The start of your cycle, characterized by menstrual bleeding. Hormone levels are low. You might feel tired or have low energy.";
    }
    if (phase.contains('Follicular')) {
      return "After your period, estrogen starts to rise, boosting energy and mood. Your body prepares for ovulation.";
    }
    // This will catch "Ovulation Day", "Ovulation Phase", and "Fertile Phase"
    if (phase.contains('Ovulation') || phase.contains('Fertile')) {
      return "This is your fertile window. Estrogen and LH peak, leading to high energy and your highest fertility.";
    }
    if (phase.contains('Luteal')) {
      return "After ovulation, progesterone rises. You might experience PMS symptoms as your body prepares for the next period.";
    }
    if (phase.contains('PMS')) {
      return "Progesterone and estrogen fall, which can trigger PMS symptoms like mood swings, bloating, and fatigue before your period starts.";
    }
    return "Tracking your cycle helps us learn its unique rhythm."; // Default
  }
  // ---------------------------------------------

  // Main build method
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: const Text(
          'Hormones & Cycle Info',
          style: TextStyle(
              color: Colors.black, fontSize: 18, fontWeight: FontWeight.w700),
        ),
        // --- MODIFIED: Changed close icon to a back arrow ---
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFE91E63)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        // --------------------------------------------------
      ),
      // --- MODIFIED: ListView order changed ---
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // *** NEW: Added the label you requested ***
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              'This is the current phase:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          // *****************************************
          _buildCurrentPhaseDisplay(), // MOVED TO TOP
          const SizedBox(height: 24),
          _buildHormonesSection(),
          const SizedBox(height: 24),
          _buildPhasesSection(context), // This is now modified
        ],
      ),
    );
  }

  // --- NEW WIDGET: The dark display box ---
  Widget _buildCurrentPhaseDisplay() {
    return Container(
      // No margin, padding is handled by the ListView
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        // --- MODIFIED: Color changed to grey[100] ---
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            currentPhase,
            style: TextStyle(
              color: _getPhaseColor(currentPhase), // Use the dynamic color
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _getPhaseDescription(currentPhase), // Get the dynamic description
            style: TextStyle(
              // --- MODIFIED: Text color changed to be readable ---
              color: Colors.grey[800],
              fontSize: 15,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
  // ------------------------------------------

  Widget _buildHormonesSection() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- REMOVED: "Your current phase is..." RichText was here ---

          // --- MODIFIED: Image is now the first item in this card ---
          Image.asset(
            'assets/images/gp.jpg',
            width: double.infinity,
            // height: 180, // Removed fixed height
            fit: BoxFit.fitWidth, // Changed from cover to fitWidth
            semanticLabel: 'Graph of hormone cycles',
          ),
          // -------------------------------------

          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Understanding Your Hormones',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          ExpansionTile(
            leading:
            const CircleAvatar(backgroundColor: _yellowColor, radius: 10),
            title: const Text('FSH (Follicle-Stimulating Hormone)'),
            children: [
              _buildExpansionContent(
                  'FSH kicks off the menstrual cycle. It stimulates the ovaries to prepare an egg for release. Levels are highest in the first half of the cycle, peaking just before ovulation.')
            ],
          ),
          ExpansionTile(
            leading: const CircleAvatar(backgroundColor: _redColor, radius: 10),
            title: const Text('LH (Luteinizing Hormone)'),
            children: [
              _buildExpansionContent(
                  'LH is the trigger for ovulation. A sharp surge in LH causes the dominant follicle to rupture and release an egg. This surge is what ovulation predictor kits detect.')
            ],
          ),
          ExpansionTile(
            leading:
            const CircleAvatar(backgroundColor: _greenColor, radius: 10),
            title: const Text('PG (Progesterone)'),
            children: [
              _buildExpansionContent(
                  'Progesterone dominates the second half of the cycle (luteal phase). Its main job is to maintain the uterine lining, making it hospitable for a potential pregnancy. If no pregnancy occurs, levels drop, triggering menstruation.')
            ],
          ),
          ExpansionTile(
            leading: const CircleAvatar(backgroundColor: _blueColor, radius: 10),
            title: const Text('E2 (Estrogen/Estradiol)'),
            children: [
              _buildExpansionContent(
                  'The star of the follicular phase, Estrogen rebuilds the uterine lining. It also boosts mood and energy. It peaks right before ovulation and has a smaller rise in the luteal phase.')
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPhasesSection(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Phases of Your Cycle',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87),
            ),
          ),
          // --- MOVED: Current phase was removed from here ---

          // --- MODIFIED: Added initiallyExpanded ---
          ExpansionTile(
            initiallyExpanded: currentPhase.contains('Period') || currentPhase.contains('Menstrual'), // Auto-expands
            leading: const Icon(Icons.water_drop_outlined, color: _redColor),
            title: const Text(
              'Period',
              style: TextStyle(fontWeight: FontWeight.w600, color: _redColor),
            ),
            iconColor: _redColor,
            collapsedIconColor: _redColor,
            children: [
              _buildPhaseContent([
                _buildSectionTitle('Learn about your period'),
                _buildRichText([
                  const TextSpan(
                      text:
                      'The period is the first phase of your menstrual cycle (1). ',
                      style: _defaultStyle),
                  TextSpan(
                      text: 'Estrogen',
                      style: _defaultStyle.copyWith(color: _blueColor)),
                  const TextSpan(text: ' and ', style: _defaultStyle),
                  TextSpan(
                      text: 'progesterone',
                      style: _defaultStyle.copyWith(color: _greenColor)),
                  const TextSpan(
                      text:
                      ' levels drop by the end of each menstrual cycle if pregnancy doesn\'t occur. This hormonal change is causing the tissue in the uterus to shrink (1), which is the beginning of your next cycle. During your period, your uterus sheds this lining, called the ',
                      style: _defaultStyle),
                  TextSpan(
                      text: 'endometrium',
                      style: _defaultStyle.copyWith(color: _greenColor)),
                  const TextSpan(
                      text:
                      ' (1). Old blood and tissue from inside the uterus leave your body through the vagina (1).',
                      style: _defaultStyle),
                ]),
                _buildParagraph(
                    'Menstrual periods have historically been taboo (2). Unfortunately, it continues to be uncomfortable for women and people with cycles to talk about menstruating in some cultures (2) even though menstruation is a regular part of life (2) and millions of people menstruate each day (1).'),
                _buildParagraph(
                    'There\'s no real "normal" when it comes to periods. Periods vary a lot. The average number of bleeding days for most adults is 4.5 to 8 days (1). Total blood loss during the whole period can vary from 5 ml to 80 ml (3). If you\'re concerned about how much blood you\'re losing, try using a menstrual cup so you can measure your blood loss more easily.'),
                _buildParagraph(
                    'Tracking your period can help you identify patterns in the symptoms you experience. It will also help Clue predict your next estimated period start-date.'),
                _buildReferences([
                  '1. King TL, Brucker MC, Osborne K, Jevitt C, editors. Varney\'s midwifery. Sixth edition. Burlington, MA: Jones & Bartlett Learning; 2019. 1380 p. 592, 594, 606.',
                  '2. The Lancet Child & Adolescent Health. Normalising menstruation, empowering girls. The Lancet Child & Adolescent Health. 2018 Jun;2(6):379.',
                ]),
              ])
            ],
          ),
          // --- MODIFIED: Added initiallyExpanded ---
          ExpansionTile(
            initiallyExpanded: currentPhase.contains('Follicular'), // Auto-expands
            leading: const Icon(Icons.star_border, color: _blueColor),
            title: const Text(
              'Follicular Phase',
              style: TextStyle(fontWeight: FontWeight.w600, color: _blueColor),
            ),
            iconColor: _blueColor,
            collapsedIconColor: _blueColor,
            children: [
              _buildPhaseContent([
                _buildSectionTitle("It's your early follicular phase"),
                _buildParagraph(
                    'During your period and the days that follow, estrogen (E2) and progesterone (PG) are at their lowest. Follicle stimulating hormone (FSH) rises to recruit follicles, which contain immature eggs. As one follicle becomes dominant, estrogen levels start to increase, while FSH begins to decline.'),
                const SizedBox(height: 16),
                _buildRichText([
                  TextSpan(
                      text: 'E2:',
                      style: _boldStyle.copyWith(color: _blueColor)),
                  const TextSpan(text: ' Low', style: _defaultStyle),
                ]),
                _buildRichText([
                  TextSpan(
                      text: 'PG:',
                      style: _boldStyle.copyWith(color: _greenColor)),
                  const TextSpan(text: ' Rising', style: _defaultStyle),
                ]),
                _buildRichText([
                  TextSpan(
                      text: 'FSH:',
                      style: _boldStyle.copyWith(color: _yellowColor)),
                  const TextSpan(text: ' Elevated', style: _defaultStyle),
                ]),
                const SizedBox(height: 16),
                _buildSectionTitle('Common Experiences'),
                _buildBulletPoint('You might feel low on energy'),
                _buildBulletPoint(
                    'But as estrogen starts to rise, your mood and focus may gradually improve'),
                _buildBulletPoint(
                    'Some people experience period cramps due to prostaglandins triggering uterine contractions'),
              ])
            ],
          ),
          // --- MODIFIED: Added initiallyExpanded ---
          ExpansionTile(
            initiallyExpanded: currentPhase.contains('Ovulation') || currentPhase.contains('Fertile'), // Auto-expands
            leading: const Icon(Icons.star_outline_rounded, color: _greenColor),
            title: const Text(
              'Ovulation',
              style: TextStyle(fontWeight: FontWeight.w600, color: _greenColor),
            ),
            iconColor: _greenColor,
            collapsedIconColor: _greenColor,
            children: [
              _buildPhaseContent([
                _buildSectionTitle('Potential Fertile Day'),
                _buildRichText([
                  const TextSpan(
                      text: 'Because the exact timing of ', style: _defaultStyle),
                  TextSpan(
                      text: 'ovulation',
                      style: _defaultStyle.copyWith(color: _greenColor)),
                  const TextSpan(
                      text:
                      ' is difficult to predict, you could potentially be fertile during any phase of your cycle. There\'s always a chance you could become pregnant any time you have penis-in-vagina sex.',
                      style: _defaultStyle),
                ]),
                _buildSectionTitle('The fertile window'),
                _buildRichText([
                  const TextSpan(
                      text:
                      'The fertile window displayed in the Clue app is only an estimate. This estimation is not effective in preventing pregnancy. Using it as ',
                      style: _defaultStyle),
                  TextSpan(
                      text: 'birth control',
                      style: _defaultStyle.copyWith(color: _greenColor)),
                  const TextSpan(
                      text:
                      ' puts you at a higher risk of unintended pregnancy. It hasn\'t been tested in a clinical study and does not take cycle variability into account, so it can\'t be used as a ',
                      style: _defaultStyle),
                  TextSpan(
                      text: 'contraceptive',
                      style: _defaultStyle.copyWith(color: _greenColor)),
                  const TextSpan(
                      text:
                      '. Speak to your healthcare provider or visit your local Planned Parenthood or family planning clinic to discuss your different birth control options. If you\'re planning to become pregnant, use ',
                      style: _defaultStyle),
                  TextSpan(
                      text: 'Clue Conceive',
                      style: _defaultStyle.copyWith(color: _greenColor)),
                  const TextSpan(
                      text:
                      ' to track your period and get clinically-tested predictions for the best days to time sex or home insemination... [content truncated]',
                      style: _defaultStyle),
                ]),
                _buildSectionTitle('Why fertile days vary'),
                _buildRichText([
                  const TextSpan(
                      text:
                      'Sperm has to fertilize an egg to start a pregnancy, but there\'s a lot more to understanding how fertility works. Most months, one of your ovaries releases a mature egg in a process called ',
                      style: _defaultStyle),
                  TextSpan(
                      text: 'ovulation',
                      style: _defaultStyle.copyWith(color: _greenColor)),
                  const TextSpan(
                      text:
                      ' (1). The egg survives for approximately 12 to 24 hours, and pregnancy only occurs if sperm is present (1). Sperm survives in the body for up to 5 days (2). These days leading up to ovulation plus the day of ovulation is known as the ',
                      style: _defaultStyle),
                  TextSpan(
                      text: '"fertile window"',
                      style: _defaultStyle.copyWith(color: _greenColor)),
                  const TextSpan(
                      text:
                      ' (2). The fertile window is the days of your cycle when pregnancy is most likely... [content truncated] ...such as ',
                      style: _defaultStyle),
                  TextSpan(
                      text: 'cervical mucus',
                      style: _defaultStyle.copyWith(color: _greenColor)),
                  const TextSpan(text: ', ', style: _defaultStyle),
                  TextSpan(
                      text: 'ovulation tests',
                      style: _defaultStyle.copyWith(color: _greenColor)),
                  const TextSpan(text: ', and ', style: _defaultStyle),
                  TextSpan(
                      text: 'basal body temperature (BBT)',
                      style: _defaultStyle.copyWith(color: _greenColor)),
                  const TextSpan(
                      text:
                      ', to learn more about your body and its changes throughout the cycle... [content truncated]',
                      style: _defaultStyle),
                ]),
                _buildReferences([
                  '1. Jones RE, Lopez KH. Human Reproductive Biology. 3rd ed. Elsevier Science: 2006.',
                  '2. Wilcox AJ, Weinberg CR, Baird DD. Timing of Sexual Intercourse in Relation to Ovulation... N Engl J Med. 1995 Dec 7:333(23):1517-21.',
                  '3. Wilcox AJ, Dunson D, Baird DD. The timing of the "fertile window"... BMJ. 2000 Nov 18:321(7271):1259-62.',
                  '4. Campbell LR, Scalise AL, DiBenedictis BT, Mahalingaiah S. Menstrual cycle length and modern living...',
                  '5. American Society for Reproductive Medicine (ASRM). Fertility evaluation of infertile women...',
                  '6. Hatcher RA, Nelson AL, Trussell J, et al. Contraceptive Technology (21st edition)...',
                  '7. The American College of obstetricians and Gynecologists. FAQ: Fertility Awareness-Based Methods...',
                ]),
              ])
            ],
          ),
          // --- MODIFIED: Added initiallyExpanded ---
          ExpansionTile(
            initiallyExpanded: currentPhase.contains('Luteal'), // Auto-expands
            leading: const Icon(Icons.nightlight_round, color: _orangeColor),
            title: const Text(
              'Luteal Phase',
              style: TextStyle(fontWeight: FontWeight.w600, color: _orangeColor),
            ),
            iconColor: _orangeColor,
            collapsedIconColor: _orangeColor,
            children: [
              _buildPhaseContent([
                _buildSectionTitle('Your Luteal Phase'),
                _buildParagraph(
                    'During the luteal phase, which follows ovulation, the corpus luteum (the remnant of the dominant follicle) produces high levels of progesterone and some estrogen. These hormones prepare the uterine lining for a potential pregnancy. If pregnancy does not occur, the corpus luteum degenerates, causing a sharp drop in progesterone and estrogen, which triggers menstruation. Luteinizing Hormone (LH), which peaked just before ovulation, drops significantly during this phase.'),
                const SizedBox(height: 16),
                _buildSectionTitle('Hormone Levels'),
                _buildRichText([
                  TextSpan(
                      text: 'E2 (Estrogen):',
                      style: _boldStyle.copyWith(color: _blueColor)),
                  const TextSpan(
                      text: ' Rises initially, then drops sharply.',
                      style: _defaultStyle),
                ]),
                _buildRichText([
                  TextSpan(
                      text: 'PG (Progesterone):',
                      style: _boldStyle.copyWith(color: _greenColor)),
                  const TextSpan(
                      text: ' Dominant and elevated, then drops sharply.',
                      style: _defaultStyle),
                ]),
                _buildRichText([
                  TextSpan(
                      text: 'FSH (Follicle-Stimulating Hormone):',
                      style: _boldStyle.copyWith(color: _yellowColor)),
                  const TextSpan(text: ' Low.', style: _defaultStyle),
                ]),
                _buildRichText([
                  TextSpan(
                      text: 'LH (Luteinizing Hormone):',
                      style: _boldStyle.copyWith(color: _redColor)),
                  const TextSpan(
                      text: ' Drops significantly after the pre-ovulation surge.',
                      style: _defaultStyle),
                ]),
                const SizedBox(height: 16),
                _buildSectionTitle('Common Experiences'),
                _buildBulletPoint(
                    'You might experience premenstrual syndrome (PMS) symptoms such as bloating, breast tenderness, mood swings, and fatigue.'),
                _buildBulletPoint(
                    'Progesterone\'s calming effect might make you feel more introverted or less energetic.'),
                _buildBulletPoint(
                    'Some people experience food cravings, particularly for carbohydrates.'),
              ])
            ],
          ),
          // --- MODIFIED: Added initiallyExpanded ---
          ExpansionTile(
            initiallyExpanded: currentPhase.contains('PMS'), // Auto-expands
            leading:
            const Icon(Icons.self_improvement_outlined, color: _pinkColor),
            title: const Text(
              'PMS (Late Luteal Phase)',
              style: TextStyle(fontWeight: FontWeight.w600, color: _pinkColor),
            ),
            iconColor: _pinkColor,
            collapsedIconColor: _pinkColor,
            children: [
              _buildPhaseContent([
                _buildSectionTitle('Learn about PMS'),
                _buildRichText([
                  TextSpan(
                      text: 'Premenstrual syndrome (PMS)',
                      style: _defaultStyle.copyWith(color: _greenColor)),
                  const TextSpan(
                      text:
                      ' is a recurring pattern of emotional, physical, and behavioral changes in the days before your period (1). Most people experience some PMS symptoms, although every person\'s experience is unique (2).',
                      style: _defaultStyle),
                ]),
                _buildSectionTitle('Some common PMS symptoms include (1):'),
                _buildBulletPoint('Headaches'),
                _buildBulletPoint('Breast tenderness'),
                _buildBulletPoint('Bloating and water retention'),
                _buildBulletPoint('Gastrointestinal symptoms'),
                _buildBulletPoint('Anxiety, tearfulness, irritability'),
                _buildBulletPoint('Fatigue'),
                _buildBulletPoint('Acne'),
                _buildBulletPoint('Food cravings'),
                const SizedBox(height: 16),
                _buildRichText([
                  const TextSpan(
                      text: 'Many people also experience ',
                      style: _defaultStyle),
                  TextSpan(
                      text: 'positive premenstrual symptoms',
                      style: _defaultStyle.copyWith(color: _greenColor)),
                  const TextSpan(
                      text:
                      ' such as increased creativity, increased libido and higher confidence, but it\'s not as common to hear about them because people are more likely to track negative PMS symptoms (3,4). Using Clue to track your premenstrual symptoms can help you define what PMS looks like for you. Tracking can also help you recognize the factors that may amplify or alleviate PMS, like sleep pattern or sugar intake.',
                      style: _defaultStyle),
                ]),
                _buildReferences([
                  '1. American College of Obstetricians and Gynecologists. Premenstrual Syndrome (PMS) Internet...',
                  '2. Romans S, Clarkson R, Einstein G, Petrovic M, Stewart D. Mood and the menstrual cycle...',
                  '3. King M, Ussher J. It\'s not all bad: Women\'s construction and lived experience of positive premenstrual change...',
                  '4. Cosgrove L, Riddle B. Constructions of Femininity and Experiences of Menstrual Distress...',
                ]),
              ])
            ],
          ),
        ],
      ),
    );
  }

  // --- Helper Widgets for Content ---

  Widget _buildExpansionContent(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Text(
        text,
        style: TextStyle(fontSize: 15, color: Colors.grey[700], height: 1.4),
      ),
    );
  }

  Widget _buildPhaseContent(List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildParagraph(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        text,
        style: _defaultStyle,
      ),
    );
  }

  Widget _buildRichText(List<TextSpan> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: RichText(
        text: TextSpan(
          style: _defaultStyle,
          children: children,
        ),
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, bottom: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ',
              style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: Colors.black87,
                  fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 15, height: 1.5, color: Colors.black87)),
          ),
        ],
      ),
    );
  }

  Widget _buildReferences(List<String> refs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text(
          'References',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        ...refs.map((ref) => Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Text(
            ref,
            style: TextStyle(
                fontSize: 12, color: Colors.grey[700], height: 1.4),
          ),
        )),
      ],
    );
  }
}