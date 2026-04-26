import 'package:flutter/material.dart';

class TextFieldInput extends StatelessWidget {
  final TextEditingController textEditingController;
  final bool isPass;
  final String hintText;
  final TextInputType textInputType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;

  const TextFieldInput({
    Key? key,
    required this.textEditingController,
    this.isPass = false,
    required this.hintText,
    required this.textInputType,
    this.textInputAction,
    this.onSubmitted,
    this.focusNode,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? Colors.grey[700]! : Colors.grey[400]!;
    final focusedColor = isDark ? Colors.white : Colors.black;

    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: BorderSide(color: borderColor, width: 1),
    );
    final focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: BorderSide(color: focusedColor, width: 1.5),
    );

    return TextField(
      controller: textEditingController,
      keyboardType: textInputType,
      obscureText: isPass,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      focusNode: focusNode,
      style: TextStyle(color: isDark ? Colors.white : Colors.black),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle:
            TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[500]),
        border: inputBorder,
        focusedBorder: focusedBorder,
        enabledBorder: inputBorder,
        filled: true,
        fillColor: isDark ? Colors.grey[900] : Colors.grey[100],
        contentPadding: const EdgeInsets.all(12),
      ),
    );
  }
}
