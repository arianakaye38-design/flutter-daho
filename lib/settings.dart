import 'package:flutter/material.dart';

final List<String> nationalities = ["Filipino", "American", "Japanese"]..sort();

class UserSettingsScreen extends StatefulWidget {
  const UserSettingsScreen({super.key});

  @override
  State<UserSettingsScreen> createState() => _UserSettingsScreenState();
}

class _UserSettingsScreenState extends State<UserSettingsScreen> {
  String active = 'account';
  Map<String, String> fields = {
    'firstName': '',
    'lastName': '',
    'username': '',
    'gmail': '',
    'age': '',
    'gender': '',
    'nationality': '',
  };

  bool showLogoutModal = false;
  bool showGenderModal = false;
  bool showNationalityModal = false;

  void handleChange(String key, String value) {
    setState(() {
      fields[key] = value;
    });
  }

  void handleLogout() {
    Navigator.of(context).popUntil((route) => route.isFirst);
    Navigator.of(context).pushReplacementNamed('/login');
  }

  void handleBack() {
    Navigator.of(context).pop();
  }

  Widget buildSidebar() {
    const sidebarOptions = [
      {'key': 'account', 'label': 'Account', 'icon': Icons.settings},
      {'key': 'privacy', 'label': 'Privacy', 'icon': Icons.lock_outline},
    ];

    return Container(
      width: 140,
      decoration: BoxDecoration(
        color: const Color(0xFF23272F),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      padding: const EdgeInsets.only(top: 48),
      child: Column(
        children: [
          const SizedBox(height: 60),
          const Icon(Icons.person, size: 72, color: Colors.white),
          const SizedBox(height: 10),
          Text(
            fields['username'] ?? '',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 32),
          ...sidebarOptions.map((opt) {
            final isActive = active == opt['key'];
            return Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: () => setState(() => active = opt['key'] as String),
                child: Container(
                  color: isActive
                      ? Colors.white.withAlpha((0.06 * 255).round())
                      : Colors.transparent,
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 18,
                  ),
                  child: Row(
                    children: [
                      if (isActive)
                        Container(
                          width: 4,
                          height: 32,
                          color: const Color(0xFFE53935),
                          margin: const EdgeInsets.only(right: 8),
                        )
                      else
                        const SizedBox(width: 12),
                      Icon(
                        opt['icon'] as IconData,
                        color: Colors.white,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        opt['label'] as String,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget buildInputField(
    String key,
    String placeholder, {
    bool isNumeric = false,
  }) {
    final controller = TextEditingController(text: fields[key]);
    return TextField(
      controller: controller,
      onChanged: (value) => handleChange(key, value),
      style: const TextStyle(color: Colors.white),
      keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        hintText: placeholder,
        hintStyle: TextStyle(color: Colors.grey[500]),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 12,
          horizontal: 16,
        ),
      ),
    );
  }

  Widget buildDropdown(
    String fieldKey,
    String title,
    List<String> options,
    bool isVisible,
    void Function(bool) setVisible,
  ) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => setVisible(true),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          margin: const EdgeInsets.only(bottom: 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            (fields[fieldKey] ?? '').toString().isNotEmpty
                ? fields[fieldKey]!
                : title,
            style: TextStyle(
              fontSize: 15,
              color: (fields[fieldKey] ?? '').isNotEmpty
                  ? Colors.black
                  : Colors.grey[600],
            ),
          ),
        ),
      ),
    );
  }

  Widget buildModal({
    required bool visible,
    required void Function(bool) onVisibilityChange,
    required String title,
    required List<String> options,
    required void Function(String) onSelected,
  }) {
    if (!visible) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => onVisibilityChange(false),
      child: Container(
        color: Colors.black54,
        alignment: Alignment.center,
        child: Container(
          width: 280,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xFF23272F),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                height: 300,
                child: ListView.builder(
                  itemCount: options.length,
                  itemBuilder: (_, index) {
                    final Object option = options[index];
                    final String item =
                        option as String; // Explicit cast to String
                    return ListTile(
                      title: Text(
                        item,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                        ),
                      ),
                      onTap: () {
                        onSelected(item);
                        onVisibilityChange(false);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildLogoutModal() {
    if (!showLogoutModal) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => setState(() => showLogoutModal = false),
      child: Container(
        color: Colors.black54,
        alignment: Alignment.center,
        child: Container(
          width: 280,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xFF23272F),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Log out account?',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() => showLogoutModal = false);
                        handleLogout();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1976D2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Yes',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => setState(() => showLogoutModal = false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'No',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            buildSidebar(),
            Expanded(
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(36),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Align(
                          alignment: Alignment.topLeft,
                          child: IconButton(
                            icon: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                              size: 28,
                            ),
                            onPressed: handleBack,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Settings',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                buildInputField('firstName', 'First Name'),
                                buildInputField('lastName', 'Last Name'),
                                buildInputField('username', 'Username'),
                                buildInputField('gmail', 'Gmail'),
                                buildInputField('age', 'Age', isNumeric: true),
                                buildDropdown(
                                  'gender',
                                  'Select Gender',
                                  ['Male', 'Female', 'Other'],
                                  showGenderModal,
                                  (v) => setState(() => showGenderModal = v),
                                ),
                                buildDropdown(
                                  'nationality',
                                  'Select Nationality',
                                  nationalities,
                                  showNationalityModal,
                                  (v) =>
                                      setState(() => showNationalityModal = v),
                                ),
                                ElevatedButton(
                                  onPressed: () =>
                                      setState(() => showLogoutModal = true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1976D2),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      'Log Out',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  buildModal(
                    visible: showGenderModal,
                    onVisibilityChange: (v) =>
                        setState(() => showGenderModal = v),
                    title: 'Select Gender',
                    options: ['Male', 'Female', 'Other'],
                    onSelected: (val) => handleChange('gender', val),
                  ),
                  buildModal(
                    visible: showNationalityModal,
                    onVisibilityChange: (v) =>
                        setState(() => showNationalityModal = v),
                    title: 'Select Nationality',
                    options: nationalities,
                    onSelected: (val) => handleChange('nationality', val),
                  ),
                  buildLogoutModal(),
                ],
              ),
            ),
          ],
        ),
      ),
      backgroundColor: const Color(0xFF181C22),
    );
  }
}
