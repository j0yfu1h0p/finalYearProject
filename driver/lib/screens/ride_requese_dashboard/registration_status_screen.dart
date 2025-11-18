import 'package:flutter/material.dart';

class RegistrationStatusScreen extends StatelessWidget {
  final String driverStatus;
  final String mechanicStatus;
  final Future<void> Function()? onCheckStatus;
  final VoidCallback onGoToServices;

  const RegistrationStatusScreen({
    super.key,
    required this.driverStatus,
    required this.mechanicStatus,
    required this.onCheckStatus,
    required this.onGoToServices,
  });

  Future<void> _handleRefresh() async {
    if (onCheckStatus != null) {
      await onCheckStatus!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final statuses = {'driver': driverStatus, 'mechanic': mechanicStatus};

    final statusEntries = statuses.entries
        .where((entry) => entry.value != 'not_registered')
        .toList();

    final bool anyApproved = statusEntries.any(
      (entry) => entry.value == 'approved',
    );

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        body: RefreshIndicator(
          onRefresh: _handleRefresh,
          color: Colors.green,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.yellow[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'If your requested role/status is not showing here, please log out and log in again to refresh your account.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                            fontFamily: "UberMove",
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const Text(
                        'Your registration status',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.black54,
                          fontFamily: "UberMove",
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList.separated(
                  itemBuilder: (context, index) {
                    final entry = statusEntries[index];
                    final display = _getStatusDisplay(entry.value);
                    if (display == null) return const SizedBox.shrink();

                    final role = entry.key;
                    final status = entry.value;

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              role.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black54,
                                fontFamily: "UberMove",
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: display['color'].withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    display['icon'],
                                    size: 28,
                                    color: display['color'],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        display['title'],
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          color: display['color'],
                                          fontFamily: "UberMove",
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        display['message'],
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.black87,
                                          fontFamily: "UberMove",
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              display['details'],
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black54,
                                fontFamily: "UberMove",
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (status == 'rejected') ...[
                              const Divider(height: 1),
                              const SizedBox(height: 16),
                              const Text(
                                'Need help? Contact our support team:',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  fontFamily: "UberMove",
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Icon(
                                    Icons.phone,
                                    color: Colors.green[700],
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '+92-316-9977808',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.green[700],
                                      fontFamily: "UberMove",
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.email,
                                    color: Colors.green[700],
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'support@myautobridge.com',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.green[700],
                                      fontFamily: "UberMove",
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                  separatorBuilder: (context, _) => const SizedBox(height: 16),
                  itemCount: statusEntries.length,
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
                sliver: SliverToBoxAdapter(
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: anyApproved
                          ? onGoToServices
                          : () async {
                              await _handleRefresh();
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: anyApproved
                            ? Colors.green
                            : Colors.white,
                        foregroundColor: anyApproved
                            ? Colors.white
                            : Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: anyApproved
                              ? BorderSide.none
                              : const BorderSide(color: Colors.green),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        anyApproved ? 'Go to Services' : 'Check Status Again',
                        style: const TextStyle(
                          fontSize: 16,
                          fontFamily: "UberMove",
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Map<String, dynamic>? _getStatusDisplay(String status) {
    switch (status) {
      case 'pending':
        return {
          'icon': Icons.hourglass_top_rounded,
          'color': Colors.orange,
          'title': 'Pending Review',
          'message': 'Your registration is under review',
          'details':
              'We will notify you once approved. This process typically takes 24-48 hours.',
        };
      case 'approved':
        return {
          'icon': Icons.check_circle_rounded,
          'color': Colors.green,
          'title': 'Approved',
          'message': 'Your registration was approved',
          'details': 'You can now start accepting requests.',
        };
      case 'rejected':
        return {
          'icon': Icons.error_outline_rounded,
          'color': Colors.red,
          'title': 'Registration Rejected',
          'message': 'Your registration was not approved',
          'details': 'Please contact support for more information.',
        };
      default:
        return null;
    }
  }
}
