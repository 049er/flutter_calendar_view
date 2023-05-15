// Copyright (c) 2021 Simform Solutions. All rights reserved.
// Use of this source code is governed by a MIT-style license
// that can be found in the LICENSE file.

import 'package:flutter/material.dart';

import 'calendar_event_data.dart';
import 'extensions.dart';
import 'typedefs.dart';

class EventController<T extends Object?> extends ChangeNotifier {
  /// Calendar controller to control all the events related operations like,
  /// adding event, removing event, etc.
  EventController({
    /// This method will provide list of events on particular date.
    ///
    /// This method is use full when you have recurring events.
    /// As of now this library does not support recurring events.
    /// You can implement same behaviour in this function.
    /// This function will overwrite default behaviour of [getEventsOnDay]
    /// function which will be used to display events on given day in
    /// [MonthView], [DayView] and [WeekView].
    ///
    EventFilter<T>? eventFilter,
    this.eventComparison,
  }) : _eventFilter = eventFilter;

  //#region Private Fields
  EventFilter<T>? _eventFilter;

  // Store all calendar event data
  final CalendarData<T> _calendarData = CalendarData();

  // Store selected event.
  CalendarEventData<T>? _selectedEvent;

  //#endregion

  //#region Public Fields

  // TODO: change the type from List<CalendarEventData>
  //  to UnmodifiableListView provided in dart:collection.

  // Note: Do not use this getter inside of EventController class.
  // use _eventList instead.
  /// Returns list of [CalendarEventData<T>] stored in this controller.
  List<CalendarEventData<T>> get events =>
      _calendarData.eventList.toList(growable: false);

  /// This method will provide list of events on particular date.
  ///
  /// This method is use full when you have recurring events.
  /// As of now this library does not support recurring events.
  /// You can implement same behaviour in this function.
  /// This function will overwrite default behaviour of [getEventsOnDay]
  /// function which will be used to display events on given day in
  /// [MonthView], [DayView] and [WeekView].
  ///
  EventFilter<T>? get eventFilter => _eventFilter;

  CalendarEventData<T>? get selectedEvent => _selectedEvent;
  ValueNotifier<CalendarEventData<T>?> selectedEventNotifier =
      ValueNotifier<CalendarEventData<T>?>(null);

  SelectedEventComparison<T>? eventComparison;

  //#endregion

  //#region Public Methods

  /// Selects the given [event].
  void selectEvent(CalendarEventData<T> event) {
    _selectedEvent = event;
    selectedEventNotifier =
        ValueNotifier<CalendarEventData<T>?>(_selectedEvent);
    notifyListeners();
  }

  /// Deselects the selected event.
  void deselectEvent() {
    _selectedEvent = null;
    selectedEventNotifier = ValueNotifier<CalendarEventData<T>?>(null);
    notifyListeners();
  }

  /// Add all the events in the list
  /// If there is an event with same date then
  void addAll(List<CalendarEventData<T>> events) {
    for (final event in events) {
      _addEvent(event);
    }

    notifyListeners();
  }

  /// Adds a single event in [_events]
  void add(CalendarEventData<T> event) {
    _addEvent(event);

    notifyListeners();
  }

  /// Removes [event] from this controller.
  void remove(CalendarEventData<T> event) {
    final date = event.date.withoutTime;

    // Removes the event from single event map.
    if (_calendarData.events[date] != null) {
      if (_calendarData.events[date]!.remove(event)) {
        _calendarData.eventList.remove(event);
        notifyListeners();
        return;
      }
    }

    // Removes the event from ranging or full day event.
    _calendarData.eventList.remove(event);
    _calendarData.rangingEventList.remove(event);
    _calendarData.fullDayEventList.remove(event);
    notifyListeners();
  }

  /// Removes multiple [event] from this controller.
  void removeWhere(bool Function(CalendarEventData<T> element) test) {
    for (final e in _calendarData.events.values) {
      e.removeWhere(test);
    }
    _calendarData.rangingEventList.removeWhere(test);
    _calendarData.eventList.removeWhere(test);
    _calendarData.fullDayEventList.removeWhere(test);
    notifyListeners();
  }

  /// Replaces a single [CalendarEventData] in events
  /// with a new [CalendarEventData].
  void replace({
    required CalendarEventData<T> eventDataToReplace,
    required CalendarEventData<T> newEventData,
  }) {
    late final index;
    if (eventComparison != null) {
      index = events.indexWhere(
        (element) =>
            eventComparison!(
                eventData: element, otherEventData: eventDataToReplace) ==
            true,
      );
    } else {
      /// Find the index of the event to be replaced.
      index = events.indexWhere(
        (element) => element == eventDataToReplace,
      );
    }

    if (index != -1) {
      final event = events[index];
      // Remove the existing event.
      remove(event);

      // Add the updated event.
      add(newEventData);
    }
  }

  /// Returns events on given day.
  ///
  /// To overwrite default behaviour of this function,
  /// provide [_eventFilter] argument in [EventController] constructor.
  List<CalendarEventData<T>> getEventsOnDay(DateTime date) {
    if (_eventFilter != null) return _eventFilter!.call(date, this.events);

    final events = <CalendarEventData<T>>[];

    if (_calendarData.events[date] != null) {
      events.addAll(_calendarData.events[date]!);
    }

    for (final rangingEvent in _calendarData.rangingEventList) {
      if (date == rangingEvent.date ||
          date == rangingEvent.endDate ||
          (date.isBefore(rangingEvent.endDate) &&
              date.isAfter(rangingEvent.date))) {
        events.add(rangingEvent);
      }
    }

    events.addAll(getFullDayEvent(date));

    return events;
  }

  /// Returns full day events on given day.
  List<CalendarEventData<T>> getFullDayEvent(DateTime dateTime) {
    final events = <CalendarEventData<T>>[];
    for (final event in _calendarData.fullDayEventList) {
      if (dateTime.difference(event.date).inDays >= 0 &&
          event.endDate.difference(dateTime).inDays > 0) {
        events.add(event);
      }
    }
    return events;
  }

  void updateFilter({required EventFilter<T> newFilter}) {
    if (newFilter != _eventFilter) {
      _eventFilter = newFilter;
      notifyListeners();
    }
  }

  //#endregion

  //#region Private Methods
  void _addEvent(CalendarEventData<T> event) {
    assert(event.endDate.difference(event.date).inDays >= 0,
        'The end date must be greater or equal to the start date');
    if (_calendarData.eventList.contains(event)) return;
    if (event.endDate.difference(event.date).inDays > 0) {
      if (event.startTime!.isDayStart && event.endTime!.isDayStart) {
        _calendarData.fullDayEventList.add(event);
      } else {
        _calendarData.rangingEventList.add(event);
      }
    } else {
      final date = event.date.withoutTime;

      if (_calendarData.events[date] == null) {
        _calendarData.events.addAll({
          date: [event],
        });
      } else {
        _calendarData.events[date]!.add(event);
      }
    }

    _calendarData.eventList.add(event);

    notifyListeners();
  }

//#endregion
}

class CalendarData<T> {
  // Stores events that occurs only once in a map.
  final events = <DateTime, List<CalendarEventData<T>>>{};

  // Stores all the events in a list.
  final eventList = <CalendarEventData<T>>[];

  // Stores all the ranging events in a list.
  final rangingEventList = <CalendarEventData<T>>[];

  // Stores all full day events
  final fullDayEventList = <CalendarEventData<T>>[];
}
