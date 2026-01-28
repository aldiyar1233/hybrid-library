import 'package:flutter/material.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Color? backgroundColor;
  final Color? textColor;
  final IconData? icon;
  final double? width;
  final Gradient? gradient;  // Добавлен параметр для градиента

  const CustomButton({
    Key? key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.backgroundColor,
    this.textColor,
    this.icon,
    this.width,
    this.gradient,  // Если указан градиент, backgroundColor игнорируется
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Контент кнопки
    Widget buttonChild = isLoading
        ? const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon),
                const SizedBox(width: 8),
              ],
              Text(text),
            ],
          );

    Widget button;

    // Если есть градиент, используем Container с градиентом
    if (gradient != null) {
      button = Container(
        decoration: BoxDecoration(
          gradient: onPressed != null && !isLoading ? gradient : null,
          color: onPressed == null || isLoading ? Colors.grey[400] : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: textColor ?? Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          child: buttonChild,
        ),
      );
    } else {
      // Обычная кнопка без градиента
      button = ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
        child: buttonChild,
      );
    }

    // Если указана ширина, оборачиваем в SizedBox
    if (width != null) {
      return SizedBox(
        width: width,
        height: 50,
        child: button,
      );
    }

    // Иначе возвращаем кнопку как есть
    return button;
  }
}