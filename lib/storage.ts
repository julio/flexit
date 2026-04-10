import AsyncStorage from '@react-native-async-storage/async-storage';

const SESSIONS_KEY = 'flexit_sessions';

export interface Session {
  date: string; // YYYY-MM-DD
  completedAt: string; // ISO timestamp
  type: 'daily' | 'weekend';
}

export async function getSessions(): Promise<Session[]> {
  const raw = await AsyncStorage.getItem(SESSIONS_KEY);
  return raw ? JSON.parse(raw) : [];
}

export async function saveSession(session: Session): Promise<void> {
  const sessions = await getSessions();
  // Replace if same date already exists
  const filtered = sessions.filter((s) => s.date !== session.date);
  filtered.push(session);
  await AsyncStorage.setItem(SESSIONS_KEY, JSON.stringify(filtered));
}

export async function isTodayComplete(): Promise<boolean> {
  const today = formatDate(new Date());
  const sessions = await getSessions();
  return sessions.some((s) => s.date === today);
}

export function formatDate(d: Date): string {
  const year = d.getFullYear();
  const month = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

export function getCurrentStreak(sessions: Session[]): number {
  if (sessions.length === 0) return 0;

  const dateSet = new Set(sessions.map((s) => s.date));
  let streak = 0;
  const today = new Date();

  // Start from today and count backwards
  for (let i = 0; i < 365; i++) {
    const d = new Date(today);
    d.setDate(d.getDate() - i);
    const key = formatDate(d);
    if (dateSet.has(key)) {
      streak++;
    } else if (i === 0) {
      // Today not done yet, still count streak from yesterday
      continue;
    } else {
      break;
    }
  }

  return streak;
}

export function getLongestStreak(sessions: Session[]): number {
  if (sessions.length === 0) return 0;

  const dates = sessions
    .map((s) => s.date)
    .sort()
    .map((d) => new Date(d + 'T00:00:00'));

  let longest = 1;
  let current = 1;

  for (let i = 1; i < dates.length; i++) {
    const diff =
      (dates[i].getTime() - dates[i - 1].getTime()) / (1000 * 60 * 60 * 24);
    if (diff === 1) {
      current++;
      longest = Math.max(longest, current);
    } else if (diff > 1) {
      current = 1;
    }
  }

  return longest;
}
