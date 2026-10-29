import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

class LockSyncTextField extends StatefulWidget {
  final String label;
  final String placeholder;
  final IconData prefixIcon;
  final TextEditingController controller;
  final bool obscureText;
  final Widget? suffixIcon;
  final TextInputType keyboardType;
  final int? maxLength;
  final ValueChanged<String>? onChanged;
  final TextAlign textAlign;

  const LockSyncTextField({
    super.key,
    required this.label,
    required this.placeholder,
    required this.prefixIcon,
    required this.controller,
    this.obscureText = false,
    this.suffixIcon,
    this.keyboardType = TextInputType.text,
    this.maxLength,
    this.onChanged,
    this.textAlign = TextAlign.start,
  });

  @override
  State<LockSyncTextField> createState() => _LockSyncTextFieldState();
}

class _LockSyncTextFieldState extends State<LockSyncTextField> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChange);
  }

  void _handleFocusChange() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: AppTextStyles.fieldLabel.copyWith(
            color: _isFocused ? AppColors.cyanAccent : AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        AnimatedContainer(
          duration: AppDimensions.animDurationFast,
          height: AppDimensions.inputFieldHeight,
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
            border: Border.all(
              color: _isFocused ? AppColors.cyanAccent : AppColors.borderSubtle,
              width: _isFocused ? 2 : 1.0,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 8.0, right: 8.0),
                child: Icon(
                  widget.prefixIcon,
                  size: 24,
                  color: _isFocused
                      ? AppColors.cyanAccent
                      : AppColors.textMuted,
                ),
              ),
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focusNode,
                  obscureText: widget.obscureText,
                  keyboardType: widget.keyboardType,
                  maxLength: widget.maxLength,
                  onChanged: widget.onChanged,
                  textAlign: widget.textAlign,
                  cursorColor: AppColors.cyanAccent,
                  style: const TextStyle(
                    fontFamily: AppTextStyles.fontMono,
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    counterText: '',
                    hintText: widget.placeholder,
                    hintStyle: const TextStyle(
                      fontFamily: AppTextStyles.fontSans,
                      fontSize: 16,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ),
              if (widget.suffixIcon != null) widget.suffixIcon!,
            ],
          ),
        ),
      ],
    );
  }
}
