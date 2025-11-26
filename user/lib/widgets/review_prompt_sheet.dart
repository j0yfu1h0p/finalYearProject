import 'package:flutter/material.dart';
import '../utils/error_handler.dart';

class ReviewPromptSheet extends StatefulWidget {
  final String title;
  final String subjectName;
  final String? subjectRole;
  final String? subtitle;
  final String? avatarUrl;
  final Color accentColor;
  final Future<void> Function(int rating, String? comment) onSubmit;

  const ReviewPromptSheet({
    super.key,
    required this.title,
    required this.subjectName,
    required this.onSubmit,
    this.subjectRole,
    this.subtitle,
    this.avatarUrl,
    this.accentColor = Colors.green,
  });

  @override
  State<ReviewPromptSheet> createState() => _ReviewPromptSheetState();
}

class _ReviewPromptSheetState extends State<ReviewPromptSheet> {
  int _selectedRating = 0;
  bool _isSubmitting = false;
  String? _errorMessage;
  final TextEditingController _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _handleRatingTap(int value) {
    if (_isSubmitting) return;
    setState(() => _selectedRating = value);
  }

  Future<void> _handleSubmit() async {
    if (_selectedRating == 0 || _isSubmitting) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final comment = _commentController.text.trim();

    try {
      await widget.onSubmit(_selectedRating, comment.isEmpty ? null : comment);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = ErrorHandler.sanitizeErrorMessage(error);
      });
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _handleSkip() {
    if (_isSubmitting) return;
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        decoration: const BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              CircleAvatar(
                radius: 32,
                backgroundColor: widget.accentColor.withOpacity(0.15),
                backgroundImage:
                    widget.avatarUrl != null && widget.avatarUrl!.isNotEmpty
                    ? NetworkImage(widget.avatarUrl!)
                    : null,
                child: widget.avatarUrl == null || widget.avatarUrl!.isEmpty
                    ? Icon(Icons.person, color: widget.accentColor, size: 36)
                    : null,
              ),
              const SizedBox(height: 16),
              Text(
                widget.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'UberMove',
                ),
                textAlign: TextAlign.center,
              ),
              if (widget.subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  widget.subtitle!,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 12),
              Text(
                widget.subjectName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'UberMove',
                ),
              ),
              if (widget.subjectRole != null) ...[
                const SizedBox(height: 4),
                Text(
                  widget.subjectRole!,
                  style: TextStyle(color: Colors.grey[400], fontSize: 13),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final starValue = index + 1;
                  final isSelected = _selectedRating >= starValue;
                  return IconButton(
                    onPressed: () => _handleRatingTap(starValue),
                    icon: Icon(
                      isSelected ? Icons.star : Icons.star_border,
                      color: widget.accentColor,
                      size: 34,
                    ),
                  );
                }),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _selectedRating == 0
                      ? 'Tap a star to rate'
                      : 'You selected $_selectedRating star${_selectedRating == 1 ? '' : 's'}',
                  style: TextStyle(
                    color: _selectedRating == 0
                        ? Colors.grey[500]
                        : widget.accentColor,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _commentController,
                maxLines: 3,
                maxLength: 220,
                cursorColor: widget.accentColor,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Share more details (optional)',
                  labelStyle: TextStyle(color: Colors.grey[500]),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey[800]!),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: widget.accentColor),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  counterStyle: TextStyle(color: Colors.grey[600]),
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _handleSkip,
                      child: const Text(
                        'Skip for now',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _selectedRating == 0 || _isSubmitting
                          ? null
                          : _handleSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.accentColor,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
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
                                color: Colors.black,
                              ),
                            )
                          : const Text('Submit review'),
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
}
