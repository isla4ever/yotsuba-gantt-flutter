import 'package:flutter/material.dart';

/// Visual tokens for [YotsubaGantt].
@immutable
class YgGanttThemeData {
  /// Creates a theme.
  const YgGanttThemeData({
    required this.backgroundColor,
    required this.sidebarColor,
    required this.headerColor,
    required this.gridColor,
    required this.primaryColor,
    required this.todayColor,
    required this.textColor,
    required this.mutedTextColor,
    required this.dependencyColor,
    required this.taskTextStyle,
    required this.headerTextStyle,
    required this.rowHeight,
    required this.taskHeight,
    required this.taskRadius,
  });

  /// Balanced light theme matching the Vue package.
  factory YgGanttThemeData.light({Color seed = const Color(0xff218c61)}) {
    return YgGanttThemeData(
      backgroundColor: const Color(0xffffffff),
      sidebarColor: const Color(0xfffbfcfb),
      headerColor: const Color(0xfff6f8f7),
      gridColor: const Color(0xffe4e9e6),
      primaryColor: seed,
      todayColor: const Color(0xffe86f51),
      textColor: const Color(0xff17221d),
      mutedTextColor: const Color(0xff6b7771),
      dependencyColor: const Color(0xff7d8c85),
      taskTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        height: 1.1,
      ),
      headerTextStyle: const TextStyle(
        color: Color(0xff4e5d56),
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
      rowHeight: 46,
      taskHeight: 26,
      taskRadius: 5,
    );
  }

  /// Main canvas color.
  final Color backgroundColor;

  /// Fixed task-list color.
  final Color sidebarColor;

  /// Timeline header color.
  final Color headerColor;

  /// Grid line color.
  final Color gridColor;

  /// Default task color.
  final Color primaryColor;

  /// Today marker color.
  final Color todayColor;

  /// Primary text color.
  final Color textColor;

  /// Secondary text color.
  final Color mutedTextColor;

  /// Default dependency line color.
  final Color dependencyColor;

  /// Task bar text style.
  final TextStyle taskTextStyle;

  /// Header scale text style.
  final TextStyle headerTextStyle;

  /// Default row height.
  final double rowHeight;

  /// Default task bar height.
  final double taskHeight;

  /// Default task bar radius.
  final double taskRadius;

  /// Returns a changed theme.
  YgGanttThemeData copyWith({
    Color? backgroundColor,
    Color? sidebarColor,
    Color? headerColor,
    Color? gridColor,
    Color? primaryColor,
    Color? todayColor,
    Color? textColor,
    Color? mutedTextColor,
    Color? dependencyColor,
    TextStyle? taskTextStyle,
    TextStyle? headerTextStyle,
    double? rowHeight,
    double? taskHeight,
    double? taskRadius,
  }) {
    return YgGanttThemeData(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      sidebarColor: sidebarColor ?? this.sidebarColor,
      headerColor: headerColor ?? this.headerColor,
      gridColor: gridColor ?? this.gridColor,
      primaryColor: primaryColor ?? this.primaryColor,
      todayColor: todayColor ?? this.todayColor,
      textColor: textColor ?? this.textColor,
      mutedTextColor: mutedTextColor ?? this.mutedTextColor,
      dependencyColor: dependencyColor ?? this.dependencyColor,
      taskTextStyle: taskTextStyle ?? this.taskTextStyle,
      headerTextStyle: headerTextStyle ?? this.headerTextStyle,
      rowHeight: rowHeight ?? this.rowHeight,
      taskHeight: taskHeight ?? this.taskHeight,
      taskRadius: taskRadius ?? this.taskRadius,
    );
  }
}
