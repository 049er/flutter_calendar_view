// Copyright (c) 2021 Simform Solutions. All rights reserved.
// Use of this source code is governed by a MIT-style license
// that can be found in the LICENSE file.

part of 'event_arrangers.dart';

class SideEventArranger<T extends Object?> extends EventArranger<T> {
  /// This class will provide method that will arrange
  /// all the events side by side.
  const SideEventArranger({
    required this.minimumDuration,
  });

  final Duration minimumDuration;

  @override
  List<OrganizedCalendarEventData<T>> arrange({
    required List<CalendarEventData<T>> events,
    required double height,
    required double width,
    required double heightPerMinute,
  }) {
    final mergedEvents = MergeEventArranger<T>(minimumDuration: minimumDuration).arrange(
      events: events,
      height: height,
      width: width,
      heightPerMinute: heightPerMinute,
    );

    final arrangedEvents = <OrganizedCalendarEventData<T>>[];

    for (final event in mergedEvents) {
      // If there is only one event in list that means, there
      // is no simultaneous events.
      if (event.events.length == 1) {
        arrangedEvents.add(event);
        continue;
      }

      final concurrentEvents = event.events;

      if (concurrentEvents.isEmpty) continue;

      var column = 1;
      final sideEventData = <_SideEventData<T>>[];
      var currentEventIndex = 0;

      while (concurrentEvents.isNotEmpty) {
        final event = concurrentEvents[currentEventIndex];
        final end = event.endTime!.getTotalMinutes == 0 ? Constants.minutesADay : event.endTime!.getTotalMinutes;
        sideEventData.add(_SideEventData(column: column, event: event));
        concurrentEvents.removeAt(currentEventIndex);

        while (currentEventIndex < concurrentEvents.length) {
          if (end < concurrentEvents[currentEventIndex].startTime!.getTotalMinutes) {
            break;
          }

          currentEventIndex++;
        }

        if (concurrentEvents.isNotEmpty && currentEventIndex >= concurrentEvents.length) {
          column++;
          currentEventIndex = 0;
        }
      }

      final slotWidth = width / column;

      for (final sideEvent in sideEventData) {
        if (sideEvent.event.startTime == null || sideEvent.event.endTime == null) {
          assert(() {
            try {
              debugPrint("Start time or end time of an event can not be null. "
                  "This ${sideEvent.event} will be ignored.");
            } catch (e) {} // Suppress exceptions.

            return true;
          }(), "Can not add event in the list.");

          continue;
        }

        var startTime = sideEvent.event.startTime!;
        var endTime = sideEvent.event.endTime!;
        final duration = endTime.difference(startTime);
        if (duration < minimumDuration) {
          startTime = sideEvent.event.startTime!.subtract(Duration(minutes: (minimumDuration.inMinutes / 2).toInt()));
          endTime = sideEvent.event.endTime!.add(Duration(minutes: (minimumDuration.inMinutes / 2).toInt()));
        }

        final bottom =
            height - (endTime.getTotalMinutes == 0 ? Constants.minutesADay : endTime.getTotalMinutes) * heightPerMinute;
        arrangedEvents.add(OrganizedCalendarEventData<T>(
          left: slotWidth * (sideEvent.column - 1),
          right: slotWidth * (column - sideEvent.column),
          top: startTime.getTotalMinutes * heightPerMinute,
          bottom: bottom,
          startDuration: startTime,
          endDuration: endTime,
          events: [sideEvent.event],
        ));
      }
    }

    return arrangedEvents;
  }
}

class _SideEventData<T> {
  final int column;
  final CalendarEventData<T> event;

  const _SideEventData({
    required this.column,
    required this.event,
  });
}
