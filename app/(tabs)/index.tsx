import React, { useCallback, useState } from 'react';
import {
  ScrollView,
  StyleSheet,
  Text,
  View,
  Pressable,
  Linking,
  Alert,
} from 'react-native';
import { useFocusEffect } from '@react-navigation/native';
import { Colors } from '@/constants/Colors';
import {
  getTodayBlocks,
  isWeekendDay,
  ExerciseBlock,
  Exercise,
} from '@/lib/exercises';
import {
  isTodayComplete,
  saveSession,
  formatDate,
  getSessions,
  getCurrentStreak,
} from '@/lib/storage';

export default function TodayScreen() {
  const [done, setDone] = useState(false);
  const [streak, setStreak] = useState(0);
  const blocks = getTodayBlocks();
  const isWeekend = isWeekendDay();

  useFocusEffect(
    useCallback(() => {
      let active = true;
      (async () => {
        const complete = await isTodayComplete();
        const sessions = await getSessions();
        if (active) {
          setDone(complete);
          setStreak(getCurrentStreak(sessions));
        }
      })();
      return () => {
        active = false;
      };
    }, [])
  );

  const handleCheckOut = async () => {
    const today = formatDate(new Date());
    await saveSession({
      date: today,
      completedAt: new Date().toISOString(),
      type: isWeekend ? 'weekend' : 'daily',
    });
    setDone(true);
    const sessions = await getSessions();
    setStreak(getCurrentStreak(sessions));
  };

  const confirmCheckOut = () => {
    Alert.alert('Check Out', "Mark today's session as complete?", [
      { text: 'Cancel', style: 'cancel' },
      { text: 'Done!', onPress: handleCheckOut },
    ]);
  };

  const totalExercises = blocks.reduce(
    (sum, b) => sum + b.exercises.length,
    0
  );

  return (
    <View style={styles.container}>
      <ScrollView
        style={styles.scroll}
        contentContainerStyle={styles.scrollContent}
        showsVerticalScrollIndicator={false}>
        {/* Header */}
        <View style={styles.header}>
          <Text style={styles.greeting}>
            {isWeekend ? 'Weekend Deep Session' : 'Daily 15'}
          </Text>
          <Text style={styles.subtitle}>
            {totalExercises} exercises
            {isWeekend ? ' \u00b7 ~25 min' : ' \u00b7 ~15 min'}
          </Text>
          {streak > 0 && (
            <View style={styles.streakBadge}>
              <Text style={styles.streakText}>{streak} day streak</Text>
            </View>
          )}
        </View>

        {done && (
          <View style={styles.doneBanner}>
            <Text style={styles.doneBannerText}>
              Today's session complete
            </Text>
          </View>
        )}

        {/* Blocks */}
        {blocks.map((block) => (
          <BlockCard key={block.id} block={block} />
        ))}

        <View style={{ height: 120 }} />
      </ScrollView>

      {/* Check Out Button */}
      {!done && (
        <View style={styles.checkOutContainer}>
          <Pressable
            style={({ pressed }) => [
              styles.checkOutButton,
              pressed && styles.checkOutPressed,
            ]}
            onPress={confirmCheckOut}>
            <Text style={styles.checkOutText}>Check Out</Text>
          </Pressable>
        </View>
      )}
    </View>
  );
}

function BlockCard({ block }: { block: ExerciseBlock }) {
  return (
    <View style={styles.block}>
      <View style={styles.blockHeader}>
        <Text style={styles.blockTitle}>{block.title}</Text>
        <Text style={styles.blockDuration}>{block.duration}</Text>
      </View>
      {block.exercises.map((exercise) => (
        <ExerciseCard key={exercise.id} exercise={exercise} />
      ))}
    </View>
  );
}

function ExerciseCard({ exercise }: { exercise: Exercise }) {
  return (
    <View style={styles.exerciseCard}>
      <Text style={styles.exerciseName}>{exercise.name}</Text>
      <Text style={styles.exerciseDuration}>{exercise.duration}</Text>
      <Text style={styles.exerciseDescription}>{exercise.description}</Text>
      <Text style={styles.exerciseCue}>{exercise.cue}</Text>
      {exercise.videoUrl && (
        <Pressable
          style={styles.videoLink}
          onPress={() => Linking.openURL(exercise.videoUrl!)}>
          <Text style={styles.videoLinkText}>Watch video</Text>
        </Pressable>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: Colors.bg,
  },
  scroll: {
    flex: 1,
  },
  scrollContent: {
    padding: 20,
    paddingTop: 8,
  },
  header: {
    marginBottom: 20,
  },
  greeting: {
    fontSize: 28,
    fontWeight: '800',
    color: Colors.text,
    marginBottom: 4,
  },
  subtitle: {
    fontSize: 15,
    color: Colors.textSecondary,
  },
  streakBadge: {
    marginTop: 10,
    backgroundColor: Colors.accentDim,
    alignSelf: 'flex-start',
    paddingHorizontal: 12,
    paddingVertical: 5,
    borderRadius: 12,
  },
  streakText: {
    color: Colors.accent,
    fontSize: 13,
    fontWeight: '700',
  },
  doneBanner: {
    backgroundColor: Colors.successDim,
    borderRadius: 12,
    padding: 14,
    marginBottom: 16,
    borderWidth: 1,
    borderColor: Colors.success + '40',
  },
  doneBannerText: {
    color: Colors.success,
    fontWeight: '700',
    fontSize: 15,
    textAlign: 'center',
  },
  block: {
    marginBottom: 20,
  },
  blockHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 10,
    paddingHorizontal: 4,
  },
  blockTitle: {
    fontSize: 16,
    fontWeight: '700',
    color: Colors.accent,
    textTransform: 'uppercase',
    letterSpacing: 0.5,
  },
  blockDuration: {
    fontSize: 13,
    color: Colors.textSecondary,
  },
  exerciseCard: {
    backgroundColor: Colors.card,
    borderRadius: 14,
    padding: 16,
    marginBottom: 8,
    borderWidth: 1,
    borderColor: Colors.cardBorder,
  },
  exerciseName: {
    fontSize: 17,
    fontWeight: '600',
    color: Colors.text,
  },
  exerciseDuration: {
    fontSize: 13,
    color: Colors.textSecondary,
    marginTop: 2,
  },
  exerciseDescription: {
    fontSize: 14,
    color: Colors.textSecondary,
    lineHeight: 21,
    marginTop: 10,
  },
  exerciseCue: {
    fontSize: 13,
    color: Colors.accent,
    marginTop: 8,
    fontStyle: 'italic',
  },
  videoLink: {
    marginTop: 10,
    backgroundColor: Colors.accentDim,
    alignSelf: 'flex-start',
    paddingHorizontal: 14,
    paddingVertical: 7,
    borderRadius: 8,
  },
  videoLinkText: {
    color: Colors.accent,
    fontSize: 13,
    fontWeight: '600',
  },
  checkOutContainer: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    padding: 20,
    paddingBottom: 36,
    backgroundColor: Colors.bg + 'F0',
  },
  checkOutButton: {
    backgroundColor: Colors.accent,
    borderRadius: 16,
    paddingVertical: 18,
    alignItems: 'center',
  },
  checkOutPressed: {
    opacity: 0.85,
    transform: [{ scale: 0.98 }],
  },
  checkOutText: {
    color: '#fff',
    fontSize: 18,
    fontWeight: '800',
  },
});
