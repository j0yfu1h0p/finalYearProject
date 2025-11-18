import 'package:flutter/material.dart';
import 'dart:async';

class RefreshButtonWidget extends StatefulWidget {
  final VoidCallback onRefresh;
  final int cooldownSeconds;
  final Color? iconColor;
  final double? iconSize;
  final String? tooltip;

  const RefreshButtonWidget({
    Key? key,
    required this.onRefresh,
    this.cooldownSeconds = 10,
    this.iconColor,
    this.iconSize = 24.0,
    this.tooltip = 'Refresh data',
  }) : super(key: key);

  @override
  State<RefreshButtonWidget> createState() => _RefreshButtonWidgetState();
}

class _RefreshButtonWidgetState extends State<RefreshButtonWidget> {
  bool _isOnCooldown = false;
  int _remainingSeconds = 0;
  Timer? _cooldownTimer;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _handleRefresh() {
    if (_isOnCooldown) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please wait $_remainingSeconds seconds before refreshing again'),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    widget.onRefresh();

    setState(() {
      _isOnCooldown = true;
      _remainingSeconds = widget.cooldownSeconds;
    });

    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _remainingSeconds--;
      });

      if (_remainingSeconds <= 0) {
        timer.cancel();
        setState(() {
          _isOnCooldown = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: Icon(
            Icons.refresh,
            color: _isOnCooldown
              ? (widget.iconColor ?? Colors.white).withOpacity(0.5)
              : (widget.iconColor ?? Colors.white),
            size: widget.iconSize,
          ),
          onPressed: _handleRefresh,
          tooltip: _isOnCooldown
            ? 'Wait $_remainingSeconds seconds'
            : widget.tooltip,
        ),
        if (_isOnCooldown)
          Positioned(
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$_remainingSeconds',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
