// lib/screens/terms_conditions_screen.dart
import 'package:flutter/material.dart';

class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms and Conditions',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
        backgroundColor: const Color.fromARGB(233, 214, 251, 250),
        centerTitle: true,
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Welcome to AUTOFIX!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueGrey),
            ),
            SizedBox(height: 10),
            Text(
              'Welcome to AUTOFIX! These Terms and Conditions ("Terms") govern your access to and use of the AUTOFIX mobile application (the "App"), provided by AUTOFIX. By downloading, installing, accessing, or using the App, you agree to be bound by these Terms. If you do not agree with any part of these Terms, you must not use the App.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.justify,
            ),
            SizedBox(height: 20),
            Text(
              '1. Overview of AUTOFIX',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
            ),
            SizedBox(height: 5),
            Text(
              'AUTOFIX is a mobile application designed to connect vehicle owners ("Drivers") with certified mechanics and service providers ("Mechanics") for on-demand roadside assistance and vehicle services. The App facilitates service requests, real-time tracking, secure payments, and provides intelligent diagnostics, operating in both online and offline modes.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.justify,
            ),
            SizedBox(height: 15),
            Text(
              '2. Eligibility and Account Registration',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
            ),
            SizedBox(height: 5),
            Text(
              'Eligibility: To use AUTOFIX, you must be at least 18 years old and capable of forming a binding contract.\n'
              '\n'
              'Account Types: The App offers two primary account types:\n'
              'Driver Account: For vehicle owners seeking roadside assistance.\n'
              'Mechanic Account: For certified mechanics providing services.\n'
              'Registration: Users must register for an account by providing accurate information, including name, contact details, and vehicle information. Users are responsible for maintaining the confidentiality of their account credentials.\n'
              'Account Security: You are responsible for safeguarding your password and any activities or actions under your account. You agree to notify AUTOFIX immediately of any unauthorized use of your account. AUTOFIX cannot and will not be liable for any loss or damage arising from your failure to comply with these security obligations.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.justify,
            ),
            SizedBox(height: 15),
            Text(
              '3. Use of the App:\n'
              '3.1. For Drivers',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
            ),
            SizedBox(height: 5),
            Text(
              'Service Requests: You can request roadside assistance by detailing your location and the issue. You agree to provide accurate information to facilitate efficient service.\n'
              'Mechanic Selection: You can view nearby Mechanics, their availability, profiles, ratings, and specialties to select a suitable service provider.\n'
              'Communication: The App provides live chat and image sharing features to communicate with Mechanics. You agree to use these features responsibly and respectfully.\n'
              'Service Types: You can select between "On-site service" (requiring a down payment) and "Shop visit" (no down payment).\n'
              'Payments: You agree to make payments for services through the App\'s secure payment gateway. A down payment may be required for on-site services, with the full payment due upon service completion.\n'
              'Reporting and Ratings: You can report service issues and rate Mechanics based on their service quality.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.justify,
            ),
            SizedBox(height: 15),
            Text(
              '3.2. For Mechanics',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
            ),
            SizedBox(height: 5),
            Text(
              'Profile Management: You agree to maintain an accurate and up-to-date profile including personal/shop information, certifications, specialties, experience, pricing, and operating hours. You may be required to upload shop/tools documentation for verification.\n'
              'Job Management: You will receive real-time service requests and can accept or decline them based on your availability and capabilities.\n'
              'Location Management: You agree to enable real-time location tracking while on duty and manage your availability status and service radius within the App.\n'
              'Communication: You agree to use the in-app communication features professionally to communicate with Drivers, provide ETA updates, and document repairs.\n'
              'Payment Processing: You acknowledge and agree to the App\'s payment processing system, including down payment verification and triggering full payment upon job completion.\n'
              'Reputation Management: You understand that your ratings and reviews from Drivers will impact your reputation on the platform.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.justify,
            ),
            SizedBox(height: 15),
            Text(
              '3.3. Offline Module',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
            ),
            SizedBox(height: 5),
            Text(
              'The Offline Module provides diagnostic guides, common breakdown solutions, vehicle-specific troubleshooting, and symptom-based search without an internet connection. This module is for informational purposes only and should not replace professional mechanical advice.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.justify,
            ),
            SizedBox(height: 15),
            Text(
              '4. Payments and Fees',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
            ),
            SizedBox(height: 5),
            Text(
              'All payments for services rendered through AUTOFIX are processed securely via the App\'s integrated payment gateway.\n'
              'Pricing: Mechanic pricing for services will be displayed within the App. By requesting a service, you agree to the stated price.\n'
              'Down Payments: For "On-site services," a down payment may be required upfront. This down payment is non-refundable if you cancel the service after a Mechanic has been dispatched, unless otherwise specified by the Mechanic or these Terms.\n'
              'Full Payment: The remaining balance for services is due upon completion of the service and must be paid through the App.\n'
              'Payment Disputes: Any payment disputes should be reported to AUTOFIX support immediately.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.justify,
            ),
            SizedBox(height: 15),
            Text(
              '5. Cancellations and Refunds',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
            ),
            SizedBox(height: 5),
            Text(
              'Driver Cancellations: If you cancel a service request after a Mechanic has accepted it and is en route, you may be subject to a cancellation fee or forfeiture of your down payment, depending on the Mechanic\'s policy and the timing of the cancellation.\n'
              'Mechanic Cancellations: If a Mechanic cancels an accepted request, AUTOFIX will assist the Driver in finding an alternative Mechanic, and any down payment made will be refunded.\n'
              'Service Issues: If you are dissatisfied with a service, you must report it through the App\'s service reporting system within a reasonable timeframe. AUTOFIX will review such reports on a case-by-case basis and may facilitate resolutions between Drivers and Mechanics.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.justify,
            ),
            SizedBox(height: 15),
            Text(
              '6. User Conduct and Responsibilities',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
            ),
            SizedBox(height: 5),
            Text(
              'You agree to use AUTOFIX only for lawful purposes and in a manner that does not infringe the rights of, or restrict or inhibit the use and enjoyment of the App by, any third party.\n'
              '\n'
              'Prohibited Conduct: You agree not to:\n'
              '* Use the App for any fraudulent or unlawful activity.\n'
              '* Impersonate any person or entity.\n'
              '* Harass, abuse, or harm another person or group.\n'
              '* Interfere with or disrupt the operation of the App or the servers or networks connected to the App.\n'
              '* Attempt to gain unauthorized access to any portion or feature of the App.\n'
              '* Upload or transmit any harmful code, viruses, or other malicious software.\n'
              '* Collect or store personal data about other users without their consent.\n'
              'Accuracy of Information: You are solely responsible for the accuracy of information provided in your profile and service requests/offers.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.justify,
            ),
            SizedBox(height: 15),
            Text(
              '7. Disclaimer of Warranties',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
            ),
            SizedBox(height: 5),
            Text(
              'AUTOFIX is provided "as is" and "as available," without any warranties of any kind, either express or implied. AUTOFIX does not guarantee that:\n'
              '\n'
              '* The App will be available at all times or be uninterrupted, secure, or error-free.\n'
              '* The information provided through the App (including diagnostic guides in the Offline Module) is accurate, complete, or reliable.\n'
              '* Mechanics will meet your specific needs or expectations.\n'
              '* Services performed by Mechanics will be free from defects or errors.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.justify,
            ),
            SizedBox(height: 15),
            Text(
              '8. Limitation of Liability',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
            ),
            SizedBox(height: 5),
            Text(
              'To the fullest extent permitted by applicable law, AUTOFIX shall not be liable for any indirect, incidental, special, consequential, or punitive damages, or any loss of profits or revenues, whether incurred directly or indirectly, or any loss of data, use, goodwill, or other intangible losses, resulting from (a) your access to or use of or inability to access or use the App; (b) any conduct or content of any third party on the App, including without limitation, any defamatory, offensive, or illegal conduct of other users or third parties; or (c) unauthorized access, use, or alteration of your transmissions or content.\n'
              'AUTOFIX acts as a platform connecting Drivers and Mechanics. AUTOFIX is not responsible for the quality or suitability of services provided by Mechanics. Any dispute regarding services must be resolved directly between the Driver and the Mechanic, though AUTOFIX may, at its discretion, assist in mediating such disputes.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.justify,
            ),
            SizedBox(height: 15),
            Text(
              '9. Indemnification',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
            ),
            SizedBox(height: 5),
            Text(
              'You agree to indemnify, defend, and hold harmless AUTOFIX, its affiliates, officers, directors, employees, and agents from and against any and all claims, liabilities, damages, losses, costs, expenses, or fees (including reasonable attorneys\' fees) that such parties may incur as a result of or arising from your (or anyone using your account\'s) violation of these Terms or your use of the App.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.justify,
            ),
            SizedBox(height: 15),
            Text(
              '10. Privacy',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
            ),
            SizedBox(height: 5),
            Text(
              'Your privacy is important to us. Our Privacy Policy, available within the App and on our website, explains how we collect, use, and disclose information about you. By using AUTOFIX, you consent to our collection, use, and disclosure of your information as described in the Privacy Policy. We comply with GDPR regulations regarding data protection.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.justify,
            ),
            SizedBox(height: 15),
            Text(
              '11. Security and Compliance',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
            ),
            SizedBox(height: 5),
            Text(
              'AUTOFIX employs various security measures, including end-to-end encrypted communications and role-based access control, to protect your data. We strive to comply with relevant data protection laws and regulations, including GDPR. However, no security system is impenetrable, and we cannot guarantee the absolute security of your information.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.justify,
            ),
            SizedBox(height: 15),
            Text(
              '12. Modifications to Terms',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
            ),
            SizedBox(height: 5),
            Text(
              'AUTOFIX reserves the right to modify these Terms at any time. If we make changes, we will notify you by revising the "Last Updated" date at the top of these Terms and, in some cases, we may provide you with additional notice (such as adding a statement to our homepage or sending you a notification). Your continued use of the App after any changes signifies your acceptance of the revised Terms.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.justify,
            ),
            SizedBox(height: 15),
            Text(
              '13. Governing Law and Dispute Resolution',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
            ),
            SizedBox(height: 5),
            Text(
              'These Terms shall be governed by and construed in accordance with the laws of the Republic of the Philippines, without regard to its conflict of law principles.'
              '\n'
              'Any dispute, controversy, or claim arising out of or relating to these Terms or the breach, termination, or invalidity thereof shall be settled by amicable negotiation. If a resolution cannot be reached through negotiation, the dispute shall be submitted to the competent courts located in Metro Manila, Philippines.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.justify,
            ),
            SizedBox(height: 15),
            Text(
              '14. Severability',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
            ),
            SizedBox(height: 5),
            Text(
              'If any provision of these Terms is found to be unenforceable or invalid, that provision will be limited or eliminated to the minimum extent necessary so that these Terms will otherwise remain in full force and effect and enforceable.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.justify,
            ),
            SizedBox(height: 15),
            Text(
              '15. Contact Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
            ),
            SizedBox(height: 5),
            Text(
              'If you have any questions about these Terms, please contact us at:\n'
              'autofixviii@gmail.com',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.justify,
            ),
            SizedBox(height: 5),
            Text(
              'Last updated: May 30, 2025',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
