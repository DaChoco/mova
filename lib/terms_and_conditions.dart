import 'package:flutter/material.dart';

/// Mock Terms and Conditions screen for Mova.
/// Replace this demonstration content with legally reviewed terms
/// before releasing the application.
class TermsAndConditionsScreen extends StatelessWidget {
  const TermsAndConditionsScreen({super.key});

  static const Color movaGreen = Color(0xFF0F6E56);

  static const List<_TermsSection> sections = [
    _TermsSection(
      title: '1. Introduction',
      body: 'Welcome to Mova, a student carpooling application designed to help users find and coordinate shared rides. By using Mova, you agree to these Terms and Conditions. If you do not agree, please do not use the service.',
    ),
    _TermsSection(
      title: '2. Accounts and eligibility',
      body: 'Users must provide accurate information when creating an account and keep their login credentials secure. You are responsible for activity carried out through your account. Mova may restrict accounts that are misused or provide misleading information.',
    ),
    _TermsSection(
      title: '3. Ride listings and requests',
      body: 'Drivers should provide accurate pickup locations, destinations, departure times and available seats. A ride request is not confirmed until the app indicates that it has been accepted. Users should check the journey details before travelling.',
    ),
    _TermsSection(
      title: '4. User conduct',
      body: 'Users must treat one another respectfully and communicate clearly. Harassment, threats, discrimination, fraudulent ride listings and misuse of another user’s information are prohibited. Users should report suspicious or inappropriate behaviour through the available support channel.',
    ),
    _TermsSection(
      title: '5. Driver and passenger safety',
      body: 'Drivers are responsible for holding the appropriate valid driving licence, complying with road laws and ensuring their vehicles are safe and roadworthy. Passengers must follow reasonable safety instructions and wear seat belts. Do not proceed with a journey you reasonably believe is unsafe.',
    ),
    _TermsSection(
      title: '6. Ride contributions and payments',
      body: 'Any contribution towards a ride should be clearly agreed between the driver and passengers before travelling. Unless explicitly stated in the app, Mova does not guarantee payment processing, reimbursements or the recovery of money owed between users. Fraudulent financial activity is prohibited.',
    ),
    _TermsSection(
      title: '7. Location and personal information',
      body: 'Mova may use your device location, with your permission, to display nearby rides and help calculate routes. You can manage location permissions through your device settings. Users must not misuse, publish or distribute another user’s personal information.',
    ),
    _TermsSection(
      title: '8. Maps and route information',
      body: 'Maps, estimated distances and route suggestions are provided to assist with journey planning. They may be incomplete, inaccurate or out of date and do not guarantee road conditions or arrival times. Drivers remain responsible for choosing a safe and lawful route.',
    ),
    _TermsSection(
      title: '9. Acceptable use and availability',
      body: 'Users must not attempt to access systems without permission, disrupt the service, upload malicious content or interfere with other users. Mova features may occasionally be unavailable, interrupted or changed as the application develops.',
    ),
    _TermsSection(
      title: '10. Responsibility and liability',
      body: 'Mova cannot guarantee that every ride listing, user or journey will be suitable for every person. Users should exercise their own judgement when arranging and taking rides. Nothing in these mock terms excludes a right or liability that cannot lawfully be excluded under applicable law.',
    ),
    _TermsSection(
      title: '11. Changes to these terms',
      body: 'These terms may be updated as Mova develops. Material changes should be communicated to users, and users may be asked to review the updated terms before continuing to use the service.',
    ),
    _TermsSection(
      title: '12. Contact and support',
      body: 'For questions, concerns or reports about a ride, use the official contact or support channel provided by Mova.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Terms & Conditions',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: movaGreen.withValues(alpha: isDark ? 0.18 : 0.08),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: movaGreen.withValues(alpha: 0.22)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: movaGreen.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(
                      Icons.description_outlined,
                      color: movaGreen,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Terms of use',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please read these terms',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      height: 1.5,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: movaGreen,
                        size: 17,
                      ),
                      SizedBox(width: 7),
                      Text(
                        'Mock terms for demonstration',
                        style: TextStyle(
                          color: movaGreen,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Last updated: 18 October 2026',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            ...sections.map((section) => _TermsSectionCard(section: section)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Demo notice: These are sample terms for the Mova interface, not a legally reviewed agreement.',
                      style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TermsSection {
  final String title;
  final String body;

  const _TermsSection({required this.title, required this.body});
}

class _TermsSectionCard extends StatelessWidget {
  const _TermsSectionCard({required this.section});

  final _TermsSection section;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            section.body,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.6,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
