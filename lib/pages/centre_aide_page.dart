import 'package:flutter/material.dart';
import 'package:bladiway/methods/commun_methods.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';

class CentreAidePage extends StatefulWidget {
  const CentreAidePage({super.key});

  @override
  State<CentreAidePage> createState() => _CentreAidePageState();
}

class _CentreAidePageState extends State<CentreAidePage> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  // Les questions et réponses utilisent les clés de traduction
  final List<Map<String, String>> _faqData = [
    {
      'question': 'faq.cancel_trip.question',
      'answer': 'faq.cancel_trip.answer',
      'category': 'trajet',
    },
    {
      'question': 'faq.cancel_reservation.question',
      'answer': 'faq.cancel_reservation.answer',
      'category': 'réservation',
    },
    {
      'question': 'faq.contact_support.question',
      'answer': 'faq.contact_support.answer',
      'category': 'support',
    },
    {
      'question': 'faq.change_language.question',
      'answer': 'faq.change_language.answer',
      'category': 'application',
    },
  ];

  String _searchQuery = '';
  bool _isLoading = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadUserEmail();
  }

  void _loadUserEmail() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email != null) {
      setState(() {
        _emailController.text = user.email!;
      });
    }
  }

  void _scrollToContactForm() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _emailController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredFaqs = _faqData
        .where((faq) => faq['question']!.tr()
        .toLowerCase()
        .contains(_searchQuery.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('help_center.title'.tr()),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.contact_support_rounded),
            tooltip: 'help_center.contact_support'.tr(),
            onPressed: _scrollToContactForm,
          ),
        ],
      ),
      body: ListView(
        controller: _scrollController,
        children: [
          _buildHeader(context),
          _buildSearchBar(context),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              'help_center.faq_title'.tr(),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredFaqs.length,
            itemBuilder: (context, index) {
              final faq = filteredFaqs[index];
              return _buildFaqItem(faq, context);
            },
          ),
          const SizedBox(height: 24),
          _buildContactSupportForm(context),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'help_center.header_title'.tr(),
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'help_center.header_subtitle'.tr(),
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _searchQuery = value),
        decoration: InputDecoration(
          hintText: 'help_center.search_hint'.tr(),
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              _searchController.clear();
              setState(() => _searchQuery = '');
            },
          )
              : null,
        ),
      ),
    );
  }

  Widget _buildFaqItem(Map<String, String> faq, BuildContext context) {
    IconData categoryIcon = Icons.help_outline;
    Color categoryColor = Theme.of(context).colorScheme.primary;

    switch (faq['category']) {
      case 'trajet':
        categoryIcon = Icons.directions_car;
        categoryColor = Colors.blue;
        break;
      case 'réservation':
        categoryIcon = Icons.bookmark_border;
        categoryColor = Colors.orange;
        break;
      case 'support':
        categoryIcon = Icons.support_agent;
        categoryColor = Colors.purple;
        break;
      case 'application':
        categoryIcon = Icons.phone_android;
        categoryColor = Colors.teal;
        break;
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: categoryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(categoryIcon, color: categoryColor),
        ),
        title: Text(
          faq['question']!.tr(),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        childrenPadding: const EdgeInsets.only(bottom: 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
            child: Text(
              faq['answer']!.tr(),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Text(
                  'help_center.feedback_question'.tr(),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.thumb_up_outlined, size: 20),
                  onPressed: () {
                    CommunMethods().displaySnackBar("help_center.feedback_thanks".tr(), context);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.thumb_down_outlined, size: 20),
                  onPressed: () {
                    _scrollToContactForm();
                    CommunMethods().displaySnackBar("help_center.feedback_sorry".tr(), context);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactSupportForm(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.support_agent,
                color: Theme.of(context).colorScheme.primary,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                "help_center.contact_form_title".tr(),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "help_center.contact_form_subtitle".tr(),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'help_center.email_label'.tr(),
              hintText: 'help_center.email_hint'.tr(),
              prefixIcon: const Icon(Icons.email_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'help_center.email_required'.tr();
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _messageController,
            maxLines: 5,
            maxLength: 500,
            decoration: InputDecoration(
              labelText: 'help_center.message_label'.tr(),
              hintText: 'help_center.message_hint'.tr(),
              alignLabelWithHint: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'help_center.message_required'.tr();
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submitSupportRequest,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
                shadowColor: Theme.of(context).colorScheme.primary.withOpacity(0.4),
              ),
              child: _isLoading
                  ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
                  : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.send_rounded, size: 22),
                  const SizedBox(width: 12),
                  Text(
                    "help_center.send_button".tr(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitSupportRequest() async {
    final email = _emailController.text.trim();
    final message = _messageController.text.trim();

    // Validation des champs
    if (email.isEmpty) {
      CommunMethods().displaySnackBar("help_center.error_email_required".tr(), context);
      return;
    }

    if (!RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(email)) {
      CommunMethods().displaySnackBar("help_center.error_email_invalid".tr(), context);
      return;
    }

    if (message.isEmpty) {
      CommunMethods().displaySnackBar("help_center.error_message_required".tr(), context);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Récupérer l'ID de l'utilisateur actuel
      final User? currentUser = FirebaseAuth.instance.currentUser;
      final String userId = currentUser?.uid ?? 'non_connected_user';

      // Ajouter le message dans Firestore
      await FirebaseFirestore.instance.collection('support_messages').add({
        'userId': userId,
        'email': email,
        'message': message,
        'status': 'unprocessed',  // Statut initial du message
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Vibration de confirmation
      HapticFeedback.mediumImpact();

      // Afficher un message de confirmation
      CommunMethods().displaySnackBar("help_center.success_message".tr(), context);

      // Vider le champ message après l'envoi
      _messageController.clear();
    } catch (e) {
      CommunMethods().displaySnackBar("help_center.error_sending".tr(), context);
      print("Erreur d'envoi: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}