import React, { useCallback, useState } from 'react';
import { ScrollView, StyleSheet, Text, View } from 'react-native';
import { useFocusEffect } from '@react-navigation/native';
import { Calendar, DateData } from 'react-native-calendars';
import { Colors } from '@/constants/Colors';
import {
  getSessions,
  getCurrentStreak,
  getLongestStreak,
  formatDate,
  Session,
} from '@/lib/storage';

export default function CalendarScreen() {
  const [sessions, setSessions] = useState<Session[]>([]);
  const [selectedDate, setSelectedDate] = useState<string | null>(null);

  useFocusEffect(
    useCallback(() => {
      let active = true;
      (async () => {
        const s = await getSessions();
        if (active) setSessions(s);
      })();
      return () => {
        active = false;
      };
    }, [])
  );

  const currentStreak = getCurrentStreak(sessions);
  const longestStreak = getLongestStreak(sessions);
  const totalSessions = sessions.length;

  // Build marked dates for calendar
  const today = formatDate(new Date());
  const sessionDates = new Set(sessions.map((s) => s.date));

  // Build a range of dates to check for "broken chain"
  const markedDates: Record<string, any> = {};

  // Mark all session dates as green
  sessions.forEach((s) => {
    markedDates[s.date] = {
      customStyles: {
        container: {
          backgroundColor: Colors.success,
          borderRadius: 8,
        },
        text: {
          color: '#fff',
          fontWeight: '700',
        },
      },
    };
  });

  // Mark missed dates (gaps in the chain) as red dots, only between first session and today
  if (sessions.length > 0) {
    const sortedDates = sessions.map((s) => s.date).sort();
    const firstDate = new Date(sortedDates[0] + 'T00:00:00');
    const todayDate = new Date(today + 'T00:00:00');

    for (
      let d = new Date(firstDate);
      d <= todayDate;
      d.setDate(d.getDate() + 1)
    ) {
      const key = formatDate(d);
      if (!sessionDates.has(key) && key !== today) {
        markedDates[key] = {
          customStyles: {
            container: {
              backgroundColor: 'transparent',
              borderWidth: 1,
              borderColor: Colors.missed + '60',
              borderRadius: 8,
            },
            text: {
              color: Colors.missed,
            },
          },
        };
      }
    }
  }

  // Highlight today
  if (markedDates[today]) {
    markedDates[today].customStyles.container = {
      ...markedDates[today].customStyles.container,
      borderWidth: 2,
      borderColor: Colors.accent,
    };
  } else {
    markedDates[today] = {
      customStyles: {
        container: {
          backgroundColor: 'transparent',
          borderWidth: 2,
          borderColor: Colors.accent,
          borderRadius: 8,
        },
        text: {
          color: Colors.text,
          fontWeight: '700',
        },
      },
    };
  }

  // Selected date highlight
  if (selectedDate && markedDates[selectedDate]) {
    markedDates[selectedDate].customStyles.container = {
      ...markedDates[selectedDate].customStyles.container,
      borderWidth: 2,
      borderColor: Colors.accent,
    };
  }

  const selectedSession = selectedDate
    ? sessions.find((s) => s.date === selectedDate)
    : null;

  // Recent sessions (last 10)
  const recentSessions = [...sessions]
    .sort((a, b) => b.date.localeCompare(a.date))
    .slice(0, 10);

  return (
    <ScrollView
      style={styles.container}
      contentContainerStyle={styles.content}
      showsVerticalScrollIndicator={false}>
      {/* Stats */}
      <View style={styles.statsRow}>
        <StatBox label="Current Streak" value={`${currentStreak}`} accent />
        <StatBox label="Longest Streak" value={`${longestStreak}`} />
        <StatBox label="Total Sessions" value={`${totalSessions}`} />
      </View>

      {/* Calendar */}
      <View style={styles.calendarContainer}>
        <Calendar
          markingType="custom"
          markedDates={markedDates}
          onDayPress={(day: DateData) => setSelectedDate(day.dateString)}
          theme={{
            backgroundColor: Colors.card,
            calendarBackground: Colors.card,
            dayTextColor: Colors.text,
            textDisabledColor: Colors.textMuted,
            monthTextColor: Colors.text,
            textMonthFontWeight: '700',
            textMonthFontSize: 17,
            arrowColor: Colors.accent,
            todayTextColor: Colors.accent,
            textDayHeaderFontSize: 12,
            textDayHeaderFontWeight: '600',
            textSectionTitleColor: Colors.textSecondary,
          }}
        />
      </View>

      {/* Selected date detail */}
      {selectedDate && (
        <View style={styles.selectedDetail}>
          <Text style={styles.selectedDateText}>
            {new Date(selectedDate + 'T12:00:00').toLocaleDateString('en-US', {
              weekday: 'long',
              month: 'long',
              day: 'numeric',
            })}
          </Text>
          {selectedSession ? (
            <Text style={styles.selectedStatus}>
              Completed at{' '}
              {new Date(selectedSession.completedAt).toLocaleTimeString(
                'en-US',
                { hour: 'numeric', minute: '2-digit' }
              )}
              {' \u00b7 '}
              {selectedSession.type === 'weekend'
                ? 'Weekend deep session'
                : 'Daily 15'}
            </Text>
          ) : (
            <Text style={[styles.selectedStatus, { color: Colors.textMuted }]}>
              {selectedDate === today ? 'Not yet completed' : 'Missed'}
            </Text>
          )}
        </View>
      )}

      {/* Recent History */}
      <Text style={styles.sectionTitle}>Recent Sessions</Text>
      {recentSessions.length === 0 ? (
        <Text style={styles.emptyText}>
          No sessions yet. Complete your first workout!
        </Text>
      ) : (
        recentSessions.map((s) => (
          <View key={s.date} style={styles.historyRow}>
            <View>
              <Text style={styles.historyDate}>
                {new Date(s.date + 'T12:00:00').toLocaleDateString('en-US', {
                  weekday: 'short',
                  month: 'short',
                  day: 'numeric',
                })}
              </Text>
              <Text style={styles.historyType}>
                {s.type === 'weekend' ? 'Weekend deep session' : 'Daily 15'}
              </Text>
            </View>
            <Text style={styles.historyTime}>
              {new Date(s.completedAt).toLocaleTimeString('en-US', {
                hour: 'numeric',
                minute: '2-digit',
              })}
            </Text>
          </View>
        ))
      )}

      <View style={{ height: 40 }} />
    </ScrollView>
  );
}

function StatBox({
  label,
  value,
  accent,
}: {
  label: string;
  value: string;
  accent?: boolean;
}) {
  return (
    <View style={[styles.statBox, accent && styles.statBoxAccent]}>
      <Text style={[styles.statValue, accent && styles.statValueAccent]}>
        {value}
      </Text>
      <Text style={styles.statLabel}>{label}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: Colors.bg,
  },
  content: {
    padding: 20,
    paddingTop: 8,
  },
  statsRow: {
    flexDirection: 'row',
    gap: 10,
    marginBottom: 20,
  },
  statBox: {
    flex: 1,
    backgroundColor: Colors.card,
    borderRadius: 14,
    padding: 14,
    alignItems: 'center',
    borderWidth: 1,
    borderColor: Colors.cardBorder,
  },
  statBoxAccent: {
    borderColor: Colors.accent + '50',
    backgroundColor: Colors.accentDim,
  },
  statValue: {
    fontSize: 28,
    fontWeight: '800',
    color: Colors.text,
  },
  statValueAccent: {
    color: Colors.accent,
  },
  statLabel: {
    fontSize: 11,
    color: Colors.textSecondary,
    marginTop: 4,
    textTransform: 'uppercase',
    letterSpacing: 0.3,
  },
  calendarContainer: {
    backgroundColor: Colors.card,
    borderRadius: 14,
    overflow: 'hidden',
    borderWidth: 1,
    borderColor: Colors.cardBorder,
    marginBottom: 16,
  },
  selectedDetail: {
    backgroundColor: Colors.card,
    borderRadius: 12,
    padding: 14,
    marginBottom: 20,
    borderWidth: 1,
    borderColor: Colors.cardBorder,
  },
  selectedDateText: {
    color: Colors.text,
    fontSize: 15,
    fontWeight: '600',
  },
  selectedStatus: {
    color: Colors.success,
    fontSize: 13,
    marginTop: 4,
  },
  sectionTitle: {
    fontSize: 16,
    fontWeight: '700',
    color: Colors.text,
    marginBottom: 12,
    textTransform: 'uppercase',
    letterSpacing: 0.5,
  },
  emptyText: {
    color: Colors.textMuted,
    fontSize: 14,
    textAlign: 'center',
    paddingVertical: 20,
  },
  historyRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    backgroundColor: Colors.card,
    borderRadius: 12,
    padding: 14,
    marginBottom: 8,
    borderWidth: 1,
    borderColor: Colors.cardBorder,
  },
  historyDate: {
    color: Colors.text,
    fontSize: 15,
    fontWeight: '600',
  },
  historyType: {
    color: Colors.textSecondary,
    fontSize: 12,
    marginTop: 2,
  },
  historyTime: {
    color: Colors.textSecondary,
    fontSize: 13,
  },
});
