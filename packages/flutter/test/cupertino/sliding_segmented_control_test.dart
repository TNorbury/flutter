// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:collection';

import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widgets/semantics_tester.dart';

dynamic getRenderSegmentedControl(WidgetTester tester) {
  return tester.allRenderObjects.firstWhere(
    (RenderObject currentObject) {
      return currentObject.toStringShort().contains('_RenderSegmentedControl');
    },
  );
}

Rect currentUnscaledThumbRect(WidgetTester tester, { bool useGlobalCoordinate = false }) {
  final dynamic renderSegmentedControl = getRenderSegmentedControl(tester);
  final Rect local = renderSegmentedControl.currentThumbRect as Rect;
  if (!useGlobalCoordinate)
    return local;

  final RenderBox segmentedControl = renderSegmentedControl as RenderBox;
  return local.shift(segmentedControl.localToGlobal(Offset.zero));
}

double currentThumbScale(WidgetTester tester) => getRenderSegmentedControl(tester).thumbScale as double;

Widget setupSimpleSegmentedControl() {
  const Map<int, Widget> children = <int, Widget>{
    0: Text('Child 1'),
    1: Text('Child 2'),
  };

  return boilerplate(
    builder: (BuildContext context) {
      return CupertinoSlidingSegmentedControl<int>(
        children: children,
        groupValue: groupValue,
        onValueChanged: defaultCallback,
      );
    },
  );
}

StateSetter? setState;
int? groupValue = 0;
void defaultCallback(int? newValue) {
  setState!(() { groupValue = newValue; });
}

Widget boilerplate({ required WidgetBuilder builder }) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Center(
      child: StatefulBuilder(builder: (BuildContext context, StateSetter setter) {
        setState = setter;
        return builder(context);
      }),
    ),
  );
}

void main() {

  setUp(() {
    setState = null;
    groupValue = 0;
  });

  testWidgets('Need at least 2 children', (WidgetTester tester) async {
    final Map<int, Widget> children = <int, Widget>{};
    groupValue = null;
    try {
      await tester.pumpWidget(
        CupertinoSlidingSegmentedControl<int>(
          children: children,
          groupValue: groupValue,
          onValueChanged: defaultCallback,
        ),
      );
      fail('Should not be possible to create a segmented control with no children');
    } on AssertionError catch (e) {
      expect(e.toString(), contains('children.length'));
    }
    try {
      children[0] = const Text('Child 1');

      await tester.pumpWidget(
        CupertinoSlidingSegmentedControl<int>(
          children: children,
          groupValue: groupValue,
          onValueChanged: defaultCallback,
        ),
      );
      fail('Should not be possible to create a segmented control with just one child');
    } on AssertionError catch (e) {
      expect(e.toString(), contains('children.length'));
    }

    groupValue = -1;
    try {
      children[1] = const Text('Child 2');
      children[2] = const Text('Child 3');
      await tester.pumpWidget(
        CupertinoSlidingSegmentedControl<int>(
          children: children,
          groupValue: groupValue,
          onValueChanged: defaultCallback,
        ),
      );
      fail('Should not be possible to create a segmented control with a groupValue pointing to a non-existent child');
    } on AssertionError catch (e) {
      expect(e.toString(), contains('groupValue must be either null or one of the keys in the children map'));
    }
  });

  testWidgets('Padding works', (WidgetTester tester) async {
    const Key key = Key('Container');

    const Map<int, Widget> children = <int, Widget>{
      0: Text('Child 1'),
      1: Text('Child 2'),
    };

    Future<void> verifyPadding({ EdgeInsets? padding }) async {
      final EdgeInsets effectivePadding = padding ?? const EdgeInsets.symmetric(vertical: 2, horizontal: 3);
      final Rect segmentedControlRect = tester.getRect(find.byKey(key));

      expect(
        tester.getTopLeft(find.ancestor(of: find.byWidget(children[0]!), matching: find.byType(MetaData))),
        segmentedControlRect.topLeft + effectivePadding.topLeft,
      );
      expect(
        tester.getBottomLeft(find.ancestor(of: find.byWidget(children[0]!), matching: find.byType(MetaData))),
        segmentedControlRect.bottomLeft + effectivePadding.bottomLeft,
      );

      expect(
        tester.getTopRight(find.ancestor(of: find.byWidget(children[1]!), matching: find.byType(MetaData))),
        segmentedControlRect.topRight + effectivePadding.topRight,
      );
      expect(
        tester.getBottomRight(find.ancestor(of: find.byWidget(children[1]!), matching: find.byType(MetaData))),
        segmentedControlRect.bottomRight + effectivePadding.bottomRight,
      );
    }

    await tester.pumpWidget(
      boilerplate(
        builder: (BuildContext context) {
          return CupertinoSlidingSegmentedControl<int>(
            key: key,
            children: children,
            groupValue: groupValue,
            onValueChanged: defaultCallback,
          );
        },
      ),
    );

    // Default padding works.
    await verifyPadding();

    // Switch to Child 2 padding should remain the same.
    await tester.tap(find.text('Child 2'));
    await tester.pumpAndSettle();

    await verifyPadding();

    await tester.pumpWidget(
      boilerplate(
        builder: (BuildContext context) {
          return CupertinoSlidingSegmentedControl<int>(
            key: key,
            padding: const EdgeInsets.fromLTRB(1, 3, 5, 7),
            children: children,
            groupValue: groupValue,
            onValueChanged: defaultCallback,
          );
        },
      ),
    );

    // Custom padding works.
    await verifyPadding(padding: const EdgeInsets.fromLTRB(1, 3, 5, 7));

    // Switch back to Child 1 padding should remain the same.
    await tester.tap(find.text('Child 1'));
    await tester.pumpAndSettle();

    await verifyPadding(padding: const EdgeInsets.fromLTRB(1, 3, 5, 7));
  });

  testWidgets('Tap changes toggle state', (WidgetTester tester) async {
    const Map<int, Widget> children = <int, Widget>{
      0: Text('Child 1'),
      1: Text('Child 2'),
      2: Text('Child 3'),
    };

    await tester.pumpWidget(
      boilerplate(
        builder: (BuildContext context) {
          return CupertinoSlidingSegmentedControl<int>(
            key: const ValueKey<String>('Segmented Control'),
            children: children,
            groupValue: groupValue,
            onValueChanged: defaultCallback,
          );
        },
      ),
    );

    expect(groupValue, 0);

    await tester.tap(find.text('Child 2'));

    expect(groupValue, 1);

    // Tapping the currently selected item should not change groupValue.
    await tester.tap(find.text('Child 2'));

    expect(groupValue, 1);
  });

  testWidgets(
    'Segmented controls respect theme',
    (WidgetTester tester) async {
      const Map<int, Widget> children = <int, Widget>{
        0: Text('Child 1'),
        1: Icon(IconData(1)),
      };

      await tester.pumpWidget(
        CupertinoApp(
          theme: const CupertinoThemeData(brightness: Brightness.dark),
          home: boilerplate(
            builder: (BuildContext context) {
              return CupertinoSlidingSegmentedControl<int>(
                children: children,
                groupValue: groupValue,
                onValueChanged: defaultCallback,
              );
            },
          ),
        ),
      );

      DefaultTextStyle textStyle = tester.widget(find.widgetWithText(DefaultTextStyle, 'Child 1').first);

      expect(textStyle.style.fontWeight, FontWeight.w500);

      await tester.tap(find.byIcon(const IconData(1)));
      await tester.pump();
      await tester.pumpAndSettle();

      textStyle = tester.widget(find.widgetWithText(DefaultTextStyle, 'Child 1').first);

      expect(groupValue, 1);
      expect(textStyle.style.fontWeight, FontWeight.normal);
    },
  );

  testWidgets('SegmentedControl dark mode', (WidgetTester tester) async {
    const Map<int, Widget> children = <int, Widget>{
      0: Text('Child 1'),
      1: Icon(IconData(1)),
    };

    Brightness brightness = Brightness.light;
    late StateSetter setState;

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (BuildContext context, StateSetter setter) {
          setState = setter;
          return MediaQuery(
            data: MediaQueryData(platformBrightness: brightness),
            child: boilerplate(
              builder: (BuildContext context) {
                return CupertinoSlidingSegmentedControl<int>(
                  children: children,
                  groupValue: groupValue,
                  onValueChanged: defaultCallback,
                  thumbColor: CupertinoColors.systemGreen,
                  backgroundColor: CupertinoColors.systemRed,
                );
              },
            ),
          );
        },
      ),
    );

    final BoxDecoration decoration = tester.widget<Container>(find.descendant(
      of: find.byType(UnconstrainedBox),
      matching: find.byType(Container),
    )).decoration! as BoxDecoration;

    expect(getRenderSegmentedControl(tester).thumbColor.value, CupertinoColors.systemGreen.color.value);
    expect(decoration.color!.value, CupertinoColors.systemRed.color.value);

    setState(() { brightness = Brightness.dark; });
    await tester.pump();

    final BoxDecoration decorationDark = tester.widget<Container>(find.descendant(
      of: find.byType(UnconstrainedBox),
      matching: find.byType(Container),
    )).decoration! as BoxDecoration;


    expect(getRenderSegmentedControl(tester).thumbColor.value, CupertinoColors.systemGreen.darkColor.value);
    expect(decorationDark.color!.value, CupertinoColors.systemRed.darkColor.value);
  });

  testWidgets(
    'Children can be non-Text or Icon widgets (in this case, '
        'a Container or Placeholder widget)',
    (WidgetTester tester) async {
      const Map<int, Widget> children = <int, Widget>{
        0: Text('Child 1'),
        1: SizedBox(width: 50, height: 50),
        2: Placeholder(),
      };

      await tester.pumpWidget(
        boilerplate(
          builder: (BuildContext context) {
            return CupertinoSlidingSegmentedControl<int>(
              children: children,
              groupValue: groupValue,
              onValueChanged: defaultCallback,
            );
          },
        ),
      );
    },
  );

  testWidgets('Passed in value is child initially selected', (WidgetTester tester) async {
    await tester.pumpWidget(setupSimpleSegmentedControl());

    expect(getRenderSegmentedControl(tester).highlightedIndex, 0);
  });

  testWidgets('Null input for value results in no child initially selected', (WidgetTester tester) async {
    const Map<int, Widget> children = <int, Widget>{
      0: Text('Child 1'),
      1: Text('Child 2'),
    };

    groupValue = null;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return boilerplate(
            builder: (BuildContext context) {
              return CupertinoSlidingSegmentedControl<int>(
                children: children,
                groupValue: groupValue,
                onValueChanged: defaultCallback,
              );
            },
          );
        },
      ),
    );

    expect(getRenderSegmentedControl(tester).highlightedIndex, null);
  });

  testWidgets('Long press not-selected child interactions', (WidgetTester tester) async {
    const Map<int, Widget> children = <int, Widget>{
      0: Text('Child 1'),
      1: Text('Child 2'),
      2: Text('Child 3'),
      3: Text('Child 4'),
      4: Text('Child 5'),
    };

    // Child 3 is initially selected.
    groupValue = 2;

    await tester.pumpWidget(
      boilerplate(
        builder: (BuildContext context) {
          return CupertinoSlidingSegmentedControl<int>(
            children: children,
            groupValue: groupValue,
            onValueChanged: defaultCallback,
          );
        },
      ),
    );

    double getChildOpacityByName(String childName) {
      return tester.renderObject<RenderAnimatedOpacity>(
        find.ancestor(matching: find.byType(AnimatedOpacity), of: find.text(childName)),
      ).opacity.value;
    }

    // Opacity 1 with no interaction.
    expect(getChildOpacityByName('Child 1'), 1);

    final Offset center = tester.getCenter(find.text('Child 1'));
    final TestGesture gesture = await tester.startGesture(center);
    await tester.pumpAndSettle();

    // Opacity drops to 0.2.
    expect(getChildOpacityByName('Child 1'), 0.2);

    // Move down slightly, slightly outside of the segmented control.
    await gesture.moveBy(const Offset(0, 50));
    await tester.pumpAndSettle();
    expect(getChildOpacityByName('Child 1'), 0.2);

    // Move further down and far away from the segmented control.
    await gesture.moveBy(const Offset(0, 200));
    await tester.pumpAndSettle();
    expect(getChildOpacityByName('Child 1'), 1);

    // Move to child 5.
    await gesture.moveTo(tester.getCenter(find.text('Child 5')));
    await tester.pumpAndSettle();
    expect(getChildOpacityByName('Child 1'), 1);
    expect(getChildOpacityByName('Child 5'), 0.2);

    // Move to child 2.
    await gesture.moveTo(tester.getCenter(find.text('Child 2')));
    await tester.pumpAndSettle();
    expect(getChildOpacityByName('Child 1'), 1);
    expect(getChildOpacityByName('Child 5'), 1);
    expect(getChildOpacityByName('Child 2'), 0.2);
  });

  testWidgets('Long press does not change the opacity of currently-selected child', (WidgetTester tester) async {
    double getChildOpacityByName(String childName) {
      return tester.renderObject<RenderAnimatedOpacity>(
        find.ancestor(matching: find.byType(AnimatedOpacity), of: find.text(childName)),
      ).opacity.value;
    }

    await tester.pumpWidget(setupSimpleSegmentedControl());

    final Offset center = tester.getCenter(find.text('Child 1'));
    await tester.startGesture(center);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(getChildOpacityByName('Child 1'), 1);
  });

  testWidgets('Height of segmented control is determined by tallest widget', (WidgetTester tester) async {
    final Map<int, Widget> children = <int, Widget>{
      0: Container(constraints: const BoxConstraints.tightFor(height: 100.0)),
      1: Container(constraints: const BoxConstraints.tightFor(height: 400.0)),
      2: Container(constraints: const BoxConstraints.tightFor(height: 200.0)),
    };

    await tester.pumpWidget(
      boilerplate(
        builder: (BuildContext context) {
          return CupertinoSlidingSegmentedControl<int>(
            key: const ValueKey<String>('Segmented Control'),
            children: children,
            groupValue: groupValue,
            onValueChanged: defaultCallback,
          );
        },
      ),
    );

    final RenderBox buttonBox = tester.renderObject(
      find.byKey(const ValueKey<String>('Segmented Control')),
    );

    expect(
      buttonBox.size.height,
      400.0 + 2 * 2, // 2 px padding on both sides.
    );
  });

  testWidgets('Width of each segmented control segment is determined by widest widget', (WidgetTester tester) async {
    final Map<int, Widget> children = <int, Widget>{
      0: Container(constraints: const BoxConstraints.tightFor(width: 50.0)),
      1: Container(constraints: const BoxConstraints.tightFor(width: 100.0)),
      2: Container(constraints: const BoxConstraints.tightFor(width: 200.0)),
    };

    await tester.pumpWidget(
      boilerplate(
        builder: (BuildContext context) {
          return CupertinoSlidingSegmentedControl<int>(
            key: const ValueKey<String>('Segmented Control'),
            children: children,
            groupValue: groupValue,
            onValueChanged: defaultCallback,
          );
        },
      ),
    );

    final RenderBox segmentedControl = tester.renderObject(
      find.byKey(const ValueKey<String>('Segmented Control')),
    );

    // Subtract the 8.0px for horizontal padding separator. Remaining width should be allocated
    // to each child equally.
    final double childWidth = (segmentedControl.size.width - 8) / 3;

    expect(childWidth, 200.0 + 9.25 * 2);
  });

  testWidgets('Width is finite in unbounded space', (WidgetTester tester) async {
    const Map<int, Widget> children = <int, Widget>{
      0: SizedBox(width: 50),
      1: SizedBox(width: 70),
    };

    await tester.pumpWidget(
      boilerplate(
        builder: (BuildContext context) {
          return Row(
            children: <Widget>[
              CupertinoSlidingSegmentedControl<int>(
                key: const ValueKey<String>('Segmented Control'),
                children: children,
                groupValue: groupValue,
                onValueChanged: defaultCallback,
              ),
            ],
          );
        },
      ),
    );

    final RenderBox segmentedControl = tester.renderObject(
      find.byKey(const ValueKey<String>('Segmented Control')),
    );

    expect(
      segmentedControl.size.width,
      70 * 2 + 9.25 * 4 + 3 * 2 + 1, // 2 children + 4 child padding + 2 outer padding + 1 separator
    );
  });

  testWidgets('Directionality test - RTL should reverse order of widgets', (WidgetTester tester) async {
    const Map<int, Widget> children = <int, Widget>{
      0: Text('Child 1'),
      1: Text('Child 2'),
    };

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.rtl,
        child: Center(
          child: StatefulBuilder(
            builder: (BuildContext context, StateSetter setter) {
              setState = setter;
              return CupertinoSlidingSegmentedControl<int>(
                children: children,
                groupValue: groupValue,
                onValueChanged: defaultCallback,
              );
            },
          ),
        ),
      ),
    );

    expect(tester.getTopRight(find.text('Child 1')).dx > tester.getTopRight(find.text('Child 2')).dx, isTrue);
  });

  testWidgets('Correct initial selection and toggling behavior - RTL', (WidgetTester tester) async {
    const Map<int, Widget> children = <int, Widget>{
      0: Text('Child 1'),
      1: Text('Child 2'),
    };
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.rtl,
        child: Center(
          child: StatefulBuilder(
            builder: (BuildContext context, StateSetter setter) {
              setState = setter;
              return CupertinoSlidingSegmentedControl<int>(
                children: children,
                groupValue: groupValue,
                onValueChanged: defaultCallback,
              );
            },
          ),
        ),
      ),
    );

    // highlightedIndex is 1 instead of 0 because of RTL.
    expect(getRenderSegmentedControl(tester).highlightedIndex, 1);

    await tester.tap(find.text('Child 2'));
    await tester.pump();

    expect(getRenderSegmentedControl(tester).highlightedIndex, 0);

    await tester.tap(find.text('Child 2'));
    await tester.pump();

    expect(getRenderSegmentedControl(tester).highlightedIndex, 0);
  });

  testWidgets('Segmented control semantics', (WidgetTester tester) async {
    final SemanticsTester semantics = SemanticsTester(tester);
    const Map<int, Widget> children = <int, Widget>{
      0: Text('Child 1'),
      1: Text('Child 2'),
    };

    await tester.pumpWidget(
      boilerplate(
        builder: (BuildContext context) {
          return CupertinoSlidingSegmentedControl<int>(
            children: children,
            groupValue: groupValue,
            onValueChanged: defaultCallback,
          );
        },
      ),
    );

    expect(
      semantics,
      hasSemantics(
        TestSemantics.root(
          children: <TestSemantics>[
            TestSemantics.rootChild(
              label: 'Child 1',
              flags: <SemanticsFlag>[
                SemanticsFlag.isButton,
                SemanticsFlag.isInMutuallyExclusiveGroup,
                SemanticsFlag.isSelected,
              ],
              actions: <SemanticsAction>[
                SemanticsAction.tap,
              ],
            ),
            TestSemantics.rootChild(
              label: 'Child 2',
              flags: <SemanticsFlag>[
                SemanticsFlag.isButton,
                SemanticsFlag.isInMutuallyExclusiveGroup,
              ],
              actions: <SemanticsAction>[
                SemanticsAction.tap,
              ],
            ),
          ],
        ),
        ignoreId: true,
        ignoreRect: true,
        ignoreTransform: true,
      ),
    );

    await tester.tap(find.text('Child 2'));
    await tester.pump();

    expect(
      semantics,
      hasSemantics(
        TestSemantics.root(
          children: <TestSemantics>[
            TestSemantics.rootChild(
              label: 'Child 1',
              flags: <SemanticsFlag>[
                SemanticsFlag.isButton,
                SemanticsFlag.isInMutuallyExclusiveGroup,
              ],
              actions: <SemanticsAction>[
                SemanticsAction.tap,
              ],
            ),
            TestSemantics.rootChild(
              label: 'Child 2',
              flags: <SemanticsFlag>[
                SemanticsFlag.isButton,
                SemanticsFlag.isInMutuallyExclusiveGroup,
                SemanticsFlag.isSelected,
              ],
              actions: <SemanticsAction>[
                SemanticsAction.tap,
              ],
            ),
          ],
        ),
        ignoreId: true,
        ignoreRect: true,
        ignoreTransform: true,
      ),
    );

    semantics.dispose();
  });

  testWidgets('Non-centered taps work on smaller widgets', (WidgetTester tester) async {
    final Map<int, Widget> children = <int, Widget>{};
    children[0] = const Text('Child 1');
    children[1] = const SizedBox();

    await tester.pumpWidget(
      boilerplate(
        builder: (BuildContext context) {
          return CupertinoSlidingSegmentedControl<int>(
            key: const ValueKey<String>('Segmented Control'),
            children: children,
            groupValue: groupValue,
            onValueChanged: defaultCallback,
          );
        },
      ),
    );

    expect(groupValue, 0);

    final Offset centerOfTwo = tester.getCenter(find.byWidget(children[1]!));
    // Tap within the bounds of children[1], but not at the center.
    // children[1] is a SizedBox thus not hittable by itself.
    await tester.tapAt(centerOfTwo + const Offset(10, 0));

    expect(groupValue, 1);
  });

  testWidgets('Hit-tests report accurate local position in segments', (WidgetTester tester) async {
    final Map<int, Widget> children = <int, Widget>{};
    late TapDownDetails tapDownDetails;
    children[0] = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (TapDownDetails details) { tapDownDetails = details; },
      child: const SizedBox(width: 200, height: 200),
    );
    children[1] = const Text('Child 2');

    await tester.pumpWidget(
      boilerplate(
        builder: (BuildContext context) {
          return CupertinoSlidingSegmentedControl<int>(
            key: const ValueKey<String>('Segmented Control'),
            children: children,
            groupValue: groupValue,
            onValueChanged: defaultCallback,
          );
        },
      ),
    );

    expect(groupValue, 0);

    final Offset segment0GlobalOffset = tester.getTopLeft(find.byWidget(children[0]!));
    await tester.tapAt(segment0GlobalOffset + const Offset(7, 11));

    expect(tapDownDetails.localPosition, const Offset(7, 11));
    expect(tapDownDetails.globalPosition, segment0GlobalOffset + const Offset(7, 11));
  });

  testWidgets('Thumb animation is correct when the selected segment changes', (WidgetTester tester) async {
    await tester.pumpWidget(setupSimpleSegmentedControl());

    final Rect initialRect = currentUnscaledThumbRect(tester, useGlobalCoordinate: true);
    expect(currentThumbScale(tester), 1);
    final TestGesture gesture = await tester.startGesture(tester.getCenter(find.text('Child 2')));
    await tester.pump();

    // Does not move until tapUp.
    expect(currentThumbScale(tester), 1);
    expect(currentUnscaledThumbRect(tester, useGlobalCoordinate: true), initialRect);

    // Tap up and the sliding animation should play.
    await gesture.up();
    await tester.pump();
    // 10 ms isn't long enough for this gesture to be recognized as a longpress.
    await tester.pump(const Duration(milliseconds: 10));

    expect(currentThumbScale(tester), 1);
    expect(
      currentUnscaledThumbRect(tester, useGlobalCoordinate: true).center.dx,
      greaterThan(initialRect.center.dx),
    );

    await tester.pumpAndSettle();

    expect(currentThumbScale(tester), 1);
    expect(
      currentUnscaledThumbRect(tester, useGlobalCoordinate: true).center,
      // We're using a critically damped spring so expect the value of the
      // animation controller to not be 1.
      offsetMoreOrLessEquals(tester.getCenter(find.text('Child 2')), epsilon: 0.01),
    );

    // Press the currently selected widget.
    await gesture.down(tester.getCenter(find.text('Child 2')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));

    // The thumb shrinks but does not moves towards left.
    expect(currentThumbScale(tester), lessThan(1));
    expect(
      currentUnscaledThumbRect(tester, useGlobalCoordinate: true).center,
      offsetMoreOrLessEquals(tester.getCenter(find.text('Child 2')), epsilon: 0.01),
    );

    await tester.pumpAndSettle();
    expect(currentThumbScale(tester), moreOrLessEquals(0.95, epsilon: 0.01));
    expect(
      currentUnscaledThumbRect(tester, useGlobalCoordinate: true).center,
      offsetMoreOrLessEquals(tester.getCenter(find.text('Child 2')), epsilon: 0.01),
    );

    // Drag to Child 1.
    await gesture.moveTo(tester.getCenter(find.text('Child 1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));

    // Moved slightly to the left
    expect(currentThumbScale(tester), moreOrLessEquals(0.95, epsilon: 0.01));
    expect(
      currentUnscaledThumbRect(tester, useGlobalCoordinate: true).center.dx,
      lessThan(tester.getCenter(find.text('Child 2')).dx),
    );

    await tester.pumpAndSettle();
    expect(currentThumbScale(tester), moreOrLessEquals(0.95, epsilon: 0.01));
    expect(
      currentUnscaledThumbRect(tester, useGlobalCoordinate: true).center,
      offsetMoreOrLessEquals(tester.getCenter(find.text('Child 1')), epsilon: 0.01),
    );

    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
    expect(currentThumbScale(tester), greaterThan(0.95));

    await tester.pumpAndSettle();
    expect(currentThumbScale(tester), moreOrLessEquals(1, epsilon: 0.01));
  });

  testWidgets(
    'Thumb does not go out of bounds in animation',
    (WidgetTester tester) async {
      const Map<int, Widget> children = <int, Widget>{
        0: Text('Child 1', maxLines: 1),
        1: Text('wiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiide Child 2', maxLines: 1),
        2: SizedBox(height: 400),
      };

      await tester.pumpWidget(boilerplate(
        builder: (BuildContext context) {
          return CupertinoSlidingSegmentedControl<int>(
            children: children,
            groupValue: groupValue,
            onValueChanged: defaultCallback,
          );
        },
      ));

      final Rect initialThumbRect = currentUnscaledThumbRect(tester, useGlobalCoordinate: true);

      // Starts animating towards 1.
      setState!(() { groupValue = 1; });
      await tester.pump(const Duration(milliseconds: 10));

      const Map<int, Widget> newChildren = <int, Widget>{
        0: Text('C1', maxLines: 1),
        1: Text('C2', maxLines: 1),
      };

      // Now let the segments shrink.
      await tester.pumpWidget(boilerplate(
        builder: (BuildContext context) {
          return CupertinoSlidingSegmentedControl<int>(
            children: newChildren,
            groupValue: 1,
            onValueChanged: defaultCallback,
          );
        },
      ));

      final RenderBox renderSegmentedControl = getRenderSegmentedControl(tester) as RenderBox;
      final Offset segmentedControlOrigin = renderSegmentedControl.localToGlobal(Offset.zero);

      // Expect the segmented control to be much narrower.
      expect(segmentedControlOrigin.dx, greaterThan(initialThumbRect.left));

      final Rect thumbRect = currentUnscaledThumbRect(tester, useGlobalCoordinate: true);
      expect(initialThumbRect.size.height, 400);
      expect(thumbRect.size.height, lessThan(100));
      // The new thumbRect should fit in the segmentedControl. The -1 and the +1
      // are to account for the thumb's vertical EdgeInsets.
      expect(segmentedControlOrigin.dx - 1, lessThanOrEqualTo(thumbRect.left));
      expect(segmentedControlOrigin.dx + renderSegmentedControl.size.width + 1, greaterThanOrEqualTo(thumbRect.right));
    },
  );

  testWidgets('Transition is triggered while a transition is already occurring', (WidgetTester tester) async {
    const Map<int, Widget> children = <int, Widget>{
      0: Text('A'),
      1: Text('B'),
      2: Text('C'),
    };

    await tester.pumpWidget(
      boilerplate(
        builder: (BuildContext context) {
          return CupertinoSlidingSegmentedControl<int>(
            key: const ValueKey<String>('Segmented Control'),
            children: children,
            groupValue: groupValue,
            onValueChanged: defaultCallback,
          );
        },
      ),
    );

    await tester.tap(find.text('B'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));

    // Between A and B.
    final Rect initialThumbRect = currentUnscaledThumbRect(tester, useGlobalCoordinate: true);
    expect(initialThumbRect.center.dx, greaterThan(tester.getCenter(find.text('A')).dx));
    expect(initialThumbRect.center.dx, lessThan(tester.getCenter(find.text('B')).dx));

    // While A to B transition is occurring, press on C.
    await tester.tap(find.text('C'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));

    final Rect secondThumbRect = currentUnscaledThumbRect(tester, useGlobalCoordinate: true);

    // Between the initial Rect and B.
    expect(secondThumbRect.center.dx, greaterThan(initialThumbRect.center.dx));
    expect(secondThumbRect.center.dx, lessThan(tester.getCenter(find.text('B')).dx));

    await tester.pump(const Duration(milliseconds: 500));

    // Eventually moves to C.
    expect(
      currentUnscaledThumbRect(tester, useGlobalCoordinate: true).center,
      offsetMoreOrLessEquals(tester.getCenter(find.text('C')), epsilon: 0.01),
    );
  });

  testWidgets('Insert segment while animation is running', (WidgetTester tester) async {
    final Map<int, Widget> children = SplayTreeMap<int, Widget>((int a, int b) => a - b);

    children[0] = const Text('A');
    children[2] = const Text('C');
    children[3] = const Text('D');

    await tester.pumpWidget(
      boilerplate(
        builder: (BuildContext context) {
          return CupertinoSlidingSegmentedControl<int>(
            key: const ValueKey<String>('Segmented Control'),
            children: children,
            groupValue: groupValue,
            onValueChanged: defaultCallback,
          );
        },
      ),
    );

    await tester.tap(find.text('D'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));

    children[1] = const Text('B');
    await tester.pumpWidget(
      boilerplate(
        builder: (BuildContext context) {
          return CupertinoSlidingSegmentedControl<int>(
            key: const ValueKey<String>('Segmented Control'),
            children: children,
            groupValue: groupValue,
            onValueChanged: defaultCallback,
          );
        },
      ),
    );

    await tester.pumpAndSettle();
    // Eventually moves to D.
    expect(
      currentUnscaledThumbRect(tester, useGlobalCoordinate: true).center,
      offsetMoreOrLessEquals(tester.getCenter(find.text('D')), epsilon: 0.01),
    );
  });

  testWidgets('change selection programmatically when dragging', (WidgetTester tester) async {
    const Map<int, Widget> children = <int, Widget>{
      0: Text('A'),
      1: Text('B'),
      2: Text('C'),
    };

    bool callbackCalled = false;

    void onValueChanged(int? newValue) {
      callbackCalled = true;
    }

    await tester.pumpWidget(
      boilerplate(
        builder: (BuildContext context) {
          return CupertinoSlidingSegmentedControl<int>(
            key: const ValueKey<String>('Segmented Control'),
            children: children,
            groupValue: groupValue,
            onValueChanged: onValueChanged,
          );
        },
      ),
    );

    // Start dragging.
    final TestGesture gesture = await tester.startGesture(tester.getCenter(find.text('A')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Change selection programmatically.
    setState!(() { groupValue = 1; });
    await tester.pump();
    await tester.pumpAndSettle();

    // The ongoing drag gesture should veto the programmatic change.
    expect(
      currentUnscaledThumbRect(tester, useGlobalCoordinate: true).center,
      offsetMoreOrLessEquals(tester.getCenter(find.text('A')), epsilon: 0.01),
    );

    // Move the pointer to 'B'. The onValueChanged callback will be called but
    // since the parent widget thinks we're already at 'B', it will not trigger
    // a rebuild for us.
    await gesture.moveTo(tester.getCenter(find.text('B')));
    await gesture.up();

    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      currentUnscaledThumbRect(tester, useGlobalCoordinate: true).center,
      offsetMoreOrLessEquals(tester.getCenter(find.text('B')), epsilon: 0.01),
    );

    expect(callbackCalled, isFalse);
  });

  testWidgets('Disallow new gesture when dragging', (WidgetTester tester) async {
    const Map<int, Widget> children = <int, Widget>{
      0: Text('A'),
      1: Text('B'),
      2: Text('C'),
    };

    bool callbackCalled = false;

    void onValueChanged(int? newValue) {
      callbackCalled = true;
    }

    await tester.pumpWidget(
      boilerplate(
        builder: (BuildContext context) {
          return CupertinoSlidingSegmentedControl<int>(
            key: const ValueKey<String>('Segmented Control'),
            children: children,
            groupValue: groupValue,
            onValueChanged: onValueChanged,
          );
        },
      ),
    );

    // Start dragging.
    final TestGesture gesture = await tester.startGesture(tester.getCenter(find.text('A')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Tap a different segment.
    await tester.tap(find.text('C'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      currentUnscaledThumbRect(tester, useGlobalCoordinate: true).center,
      offsetMoreOrLessEquals(tester.getCenter(find.text('A')), epsilon: 0.01),
    );

    // A different drag.
    await tester.drag(find.text('A'), const Offset(300, 0));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      currentUnscaledThumbRect(tester, useGlobalCoordinate: true).center,
      offsetMoreOrLessEquals(tester.getCenter(find.text('A')), epsilon: 0.01),
    );

    await gesture.up();
    expect(callbackCalled, isFalse);
  });

  testWidgets('gesture outlives the widget', (WidgetTester tester) async {
    // Regression test for https://github.com/flutter/flutter/issues/63338.
    const Map<int, Widget> children = <int, Widget>{
      0: Text('A'),
      1: Text('B'),
      2: Text('C'),
    };

    await tester.pumpWidget(
      boilerplate(
        builder: (BuildContext context) {
          return CupertinoSlidingSegmentedControl<int>(
            key: const ValueKey<String>('Segmented Control'),
            children: children,
            groupValue: groupValue,
            onValueChanged: defaultCallback,
          );
        },
      ),
    );

    // Start dragging.
    final TestGesture gesture = await tester.startGesture(tester.getCenter(find.text('A')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await tester.pumpWidget(const Placeholder());

    await gesture.moveBy(const Offset(200, 0));
    await tester.pump();
    await tester.pump();

    await gesture.up();
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('computeDryLayout is pure', (WidgetTester tester) async {
    // Regression test for https://github.com/flutter/flutter/issues/73362.
    const Map<int, Widget> children = <int, Widget>{
      0: Text('A'),
      1: Text('B'),
      2: Text('C'),
    };

    const Key key = ValueKey<int>(1);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 10,
            child: CupertinoSlidingSegmentedControl<int>(
              key: key,
              children: children,
              groupValue: groupValue,
              onValueChanged: defaultCallback,
            ),
          ),
        ),
      ),
    );

    final RenderBox renderBox = getRenderSegmentedControl(tester) as RenderBox;

    final Size size = renderBox.getDryLayout(const BoxConstraints());
    expect(size.width, greaterThan(10));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Has consistent size, independent of groupValue', (WidgetTester tester) async {
    // Regression test for https://github.com/flutter/flutter/issues/62063.
    const Map<int, Widget> children = <int, Widget>{
      0: Text('A'),
      1: Text('BB'),
      2: Text('CCCC'),
    };

    groupValue = null;
    await tester.pumpWidget(
      boilerplate(
        builder: (BuildContext context) {
          return CupertinoSlidingSegmentedControl<int>(
            key: const ValueKey<String>('Segmented Control'),
            children: children,
            groupValue: groupValue,
            onValueChanged: defaultCallback,
          );
        },
      ),
    );

    final RenderBox renderBox = getRenderSegmentedControl(tester) as RenderBox;
    final Size size = renderBox.size;

    for (final int value in children.keys) {
      setState!(() { groupValue = value; });
      await tester.pump();
      await tester.pumpAndSettle();

      expect(renderBox.size, size);
    }
  });


  testWidgets('ScrollView + SlidingSegmentedControl interaction', (WidgetTester tester) async {
    const Map<int, Widget> children = <int, Widget>{
      0: Text('Child 1'),
      1: Text('Child 2'),
    };
    final ScrollController scrollController = ScrollController();

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ListView(
          controller: scrollController,
          children: <Widget>[
            const SizedBox(height: 100),
            boilerplate(
              builder: (BuildContext context) {
                return CupertinoSlidingSegmentedControl<int>(
                  children: children,
                  groupValue: groupValue,
                  onValueChanged: defaultCallback,
                );
              },
            ),
            const SizedBox(height: 1000),
          ],
        ),
      ),
    );

    // Tapping still works.
    await tester.tap(find.text('Child 2'));
    await tester.pump();

    expect(groupValue, 1);

    // Vertical drag works for the scroll view.
    final TestGesture gesture = await tester.startGesture(tester.getCenter(find.text('Child 1')));
    // The first moveBy doesn't actually move the scrollable. It's there to make
    // sure VerticalDragGestureRecognizer wins the arena. This is due to
    // startBehavior being set to DragStartBehavior.start.
    await gesture.moveBy(const Offset(0, -100));
    await gesture.moveBy(const Offset(0, -100));
    await tester.pump();

    expect(scrollController.offset, 100);

    // Does not affect the segmented control.
    expect(groupValue, 1);

    await gesture.moveBy(const Offset(0, 100));
    await gesture.up();
    await tester.pump();

    expect(scrollController.offset, 0);
    expect(groupValue, 1);

    // Long press vertical drag is recognized by the segmented control.
    await gesture.down(tester.getCenter(find.text('Child 1')));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveBy(const Offset(0, -100));
    await gesture.moveBy(const Offset(0, -100));
    await tester.pump();

    // Should not scroll.
    expect(scrollController.offset, 0);
    expect(groupValue, 1);

    await gesture.moveBy(const Offset(0, 100));
    await gesture.moveBy(const Offset(0, 100));
    await gesture.up();
    await tester.pump();

    expect(scrollController.offset, 0);
    expect(groupValue, 0);

    // Horizontal drag is recognized by the segmentedControl.
    await gesture.down(tester.getCenter(find.text('Child 1')));
    await gesture.moveBy(const Offset(50, 0));
    await gesture.moveTo(tester.getCenter(find.text('Child 2')));
    await gesture.up();
    await tester.pump();

    expect(scrollController.offset, 0);
    expect(groupValue, 1);
  });
}
