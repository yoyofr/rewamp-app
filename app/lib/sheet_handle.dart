import 'package:flutter/material.dart';

/// [showModalBottomSheet] with a handle that also CLOSES on a tap. Material's
/// own (`showDragHandle`) only drags: a tap on it did nothing, and a sheet
/// tall enough to fill the window could then not be closed without picking
/// an entry. Every sheet with a handle goes through here.
Future<T?> showHandleSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool useRootNavigator = false,
  Color? backgroundColor,
  ShapeBorder? shape,
  BoxConstraints? constraints,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useRootNavigator: useRootNavigator,
    backgroundColor: backgroundColor,
    shape: shape,
    constraints: constraints,
    builder: (ctx) => SheetWithHandle(child: builder(ctx)),
  );
}

/// A sheet's handle, ABOVE its content: tapping it closes the sheet, a drag
/// still goes to the sheet, which follows the finger.
class SheetWithHandle extends StatelessWidget {
  final Widget child;
  const SheetWithHandle({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final color =
        Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          label: MaterialLocalizations.of(context).closeButtonTooltip,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).maybePop(),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: SizedBox(
                width: double.infinity,
                height: 28,
                child: Center(
                  child: Container(
                    width: 32,
                    height: 4,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Flexible(child: child),
      ],
    );
  }
}
