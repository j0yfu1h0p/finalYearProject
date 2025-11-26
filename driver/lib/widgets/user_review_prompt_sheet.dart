import 'package:flutter/material.dart';

class UserReviewPromptSheet extends StatefulWidget {
  final String title;
  final String subtitle;
  final String? avatarUrl;
  final Color accentColor;
  final String submitLabel;
  final String skipLabel;
  final Future<void> Function(double rating, String? comment) onSubmit;

  const UserReviewPromptSheet({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onSubmit,
    this.avatarUrl,
    this.accentColor = Colors.black,
    this.submitLabel = 'Submit review',
    this.skipLabel = 'Skip for now',
  });

  @override
  State<UserReviewPromptSheet> createState() => _UserReviewPromptSheetState();
}

class _UserReviewPromptSheetState extends State<UserReviewPromptSheet> {
  int _rating = 0;
  bool _isSubmitting = false;
  String? _error;
  final TextEditingController _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _selectRating(int value) {
    if (_isSubmitting) return;
    setState(() => _rating = value);
  }

  Future<void> _submit() async {
    if (_rating == 0 || _isSubmitting) return;

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    final comment = _commentController.text.trim();

    try {
      await widget.onSubmit(
        _rating.toDouble(),
        comment.isEmpty ? null : comment,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _skip() {
    if (_isSubmitting) return;
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return ConstrainedBox(
                constraints: BoxConstraints(maxHeight: constraints.maxHeight),
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: EdgeInsets.zero,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 48,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey[400],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      CircleAvatar(
                        radius: 34,
                        backgroundColor: widget.accentColor.withOpacity(0.08),
                        backgroundImage:
                            widget.avatarUrl != null &&
                                widget.avatarUrl!.isNotEmpty
                            ? NetworkImage(widget.avatarUrl!)
                            : null,
                        child:
                            widget.avatarUrl == null ||
                                widget.avatarUrl!.isEmpty
                            ? Icon(
                                Icons.person,
                                color: widget.accentColor,
                                size: 36,
                              )
                            : null,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'UberMove',
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.subtitle,
                        style: const TextStyle(color: Colors.black54),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          final starValue = index + 1;
                          return IconButton(
                            onPressed: () => _selectRating(starValue),
                            icon: Icon(
                              _rating >= starValue
                                  ? Icons.star
                                  : Icons.star_border,
                              color: widget.accentColor,
                              size: 34,
                            ),
                          );
                        }),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _rating == 0
                              ? 'Tap a star to rate'
                              : 'You selected $_rating star${_rating == 1 ? '' : 's'}',
                          style: TextStyle(
                            color: _rating == 0
                                ? Colors.black45
                                : widget.accentColor,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _commentController,
                        maxLength: 220,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'Add a note (optional)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 13,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: _skip,
                              child: Text(widget.skipLabel),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _rating == 0 || _isSubmitting
                                  ? null
                                  : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: widget.accentColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                textStyle: const TextStyle(
                                  fontFamily: 'UberMove',
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              child: _isSubmitting
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(widget.submitLabel),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

Future<bool?> showUserReviewPromptSheet({
  required BuildContext context,
  required String title,
  required String subtitle,
  Future<void> Function(double rating, String? comment)? onSubmit,
  String? avatarUrl,
  Color accentColor = Colors.black,
  String submitLabel = 'Submit review',
  String skipLabel = 'Skip for now',
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => UserReviewPromptSheet(
      title: title,
      subtitle: subtitle,
      avatarUrl: avatarUrl,
      accentColor: accentColor,
      submitLabel: submitLabel,
      skipLabel: skipLabel,
      onSubmit: onSubmit ?? (_, __) async {},
    ),
  );
}
