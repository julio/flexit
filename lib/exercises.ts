export interface Exercise {
  id: string;
  name: string;
  duration: string;
  description: string;
  cue: string;
  videoUrl?: string;
}

export interface ExerciseBlock {
  id: string;
  title: string;
  duration: string;
  exercises: Exercise[];
}

export const dailyBlocks: ExerciseBlock[] = [
  {
    id: 'block1',
    title: 'Wake Up the Spine + Hips',
    duration: '2 min',
    exercises: [
      {
        id: 'cat-cow',
        name: 'Cat-Cow',
        duration: '10 reps',
        description:
          'Hands and knees, wrists under shoulders, knees under hips. Inhale: drop belly, lift chest, look up. Exhale: round spine, tuck chin, push floor away.',
        cue: 'Move slowly — 3 seconds each direction.',
        videoUrl: 'https://www.youtube.com/watch?v=LIVJZZyZ2qM',
      },
      {
        id: 'hip-cars',
        name: 'Hip CARs',
        duration: '5 per direction, each side',
        description:
          'Standing, hold a wall for balance. Lift knee to hip height, rotate out to the side, sweep leg back behind you, return.',
        cue: 'Keep pelvis completely still — movement only in the hip socket.',
        videoUrl: 'https://www.youtube.com/watch?v=hRMrq6G81p8',
      },
    ],
  },
  {
    id: 'block2',
    title: 'Mobilize',
    duration: '4 min',
    exercises: [
      {
        id: '90-90',
        name: '90/90 Hip Switches',
        duration: '10 total (5 per side)',
        description:
          'Sit on floor, both knees at 90°. Lift knees, keep heels pivoted, rotate to opposite side.',
        cue: 'Phase 1: hands behind. Phase 2: tall spine. Phase 3: no-hands hinge.',
        videoUrl: 'https://www.youtube.com/watch?v=m51AZSXMvEA',
      },
      {
        id: 'worlds-greatest',
        name: "World's Greatest Stretch",
        duration: '5 per side',
        description:
          'Deep lunge, place hand inside front foot, rotate opposite arm to ceiling. Hold 2s. Drive hips back to straighten front leg.',
        cue: 'Opens hip flexors, adductors, hamstrings, and thoracic spine all at once.',
        videoUrl: 'https://www.youtube.com/watch?v=-CiWQ2IvY34',
      },
    ],
  },
  {
    id: 'block3',
    title: 'Lengthen',
    duration: '6 min',
    exercises: [
      {
        id: 'couch-stretch',
        name: 'Couch Stretch',
        duration: '90 sec per side',
        description:
          'Kneel facing away from couch. Back foot on seat. Step front foot forward. Squeeze glute, drive hips forward.',
        cue: 'Stay tall — don\'t lean forward. Squeeze the glute on the back leg.',
        videoUrl: 'https://www.youtube.com/shorts/TIJu5aWPke0',
      },
      {
        id: 'pigeon',
        name: 'Pigeon Pose',
        duration: '90 sec per side',
        description:
          'From all fours, slide knee forward toward wrist. Extend back leg straight behind. Walk hands forward and lower torso.',
        cue: 'Breathe and relax into it. Opens deep external hip rotators.',
        videoUrl: 'https://www.youtube.com/shorts/AI5A1PRYX7E',
      },
    ],
  },
  {
    id: 'block4',
    title: 'Strengthen + Decompress',
    duration: '3 min',
    exercises: [
      {
        id: 'glute-bridge',
        name: 'Glute Bridge',
        duration: '15 reps, slow',
        description:
          'Lie on back, feet flat, knees bent. Drive through heels, squeeze glutes at top for 2s, lower slowly (3s down).',
        cue: 'When glutes are weak, your lower back compensates. Fix that here.',
        videoUrl: 'https://www.youtube.com/shorts/LORVjN2bg5o',
      },
      {
        id: 'dead-hang',
        name: 'Dead Hang',
        duration: '45-60 sec total',
        description:
          'Overhand grip, shoulder-width. Hang completely. Relax shoulders and lower back.',
        cue: 'Let gravity decompress your spine. 2x30s if needed.',
        videoUrl: 'https://www.youtube.com/shorts/9eY15prKcUY',
      },
    ],
  },
];

export const weekendExtras: ExerciseBlock = {
  id: 'weekend',
  title: 'Weekend Deep Session',
  duration: '10 min extra',
  exercises: [
    {
      id: 'frog-stretch',
      name: 'Frog Stretch',
      duration: '2 min',
      description:
        'On all fours, spread knees wide, feet turned out, inner ankles flat. Rock hips back and forward.',
      cue: 'Opens adductors and inner hip.',
      videoUrl: 'https://www.youtube.com/watch?v=7d-4CkcXWVU',
    },
    {
      id: 'knee-crossover',
      name: 'Knee-to-Chest Cross-Over',
      duration: '30 sec per side, 2 rounds',
      description:
        'Lie on back, pull one knee to chest, then across body toward opposite shoulder. Keep both shoulders on floor.',
      cue: 'Rotational stretch for outer hip and IT band.',
      videoUrl: 'https://www.youtube.com/shorts/iAaLLSALFMg',
    },
    {
      id: 'iso-mid-split',
      name: 'Isometric Mid-Split Hold',
      duration: '3 x 30 sec',
      description:
        'Wide stance, toes out. Hold wide position. Press feet into floor as if squeezing together.',
      cue: 'Builds strength at end range — makes flexibility gains permanent.',
      videoUrl: 'https://www.youtube.com/watch?v=7LTLpbKP2cc',
    },
    {
      id: 'sl-rdl',
      name: 'Single-Leg Romanian Deadlift',
      duration: '8 per side',
      description:
        'Stand on one leg, hinge forward at hips with flat back. Touch floor, drive back up by squeezing glute.',
      cue: 'Builds posterior chain that protects your lower back.',
      videoUrl: 'https://www.youtube.com/shorts/s32cCgmRV3I',
    },
    {
      id: 'floor-to-stand',
      name: 'Floor-to-Standing Drill',
      duration: '10 reps',
      description:
        'Sit on floor, stand up. Progress: one hand, one finger, no hands.',
      cue: 'Functional test integrating hip mobility, strength, and balance.',
      videoUrl: 'https://www.youtube.com/shorts/ghuq5AMt7vc',
    },
  ],
};

export function getTodayBlocks(): ExerciseBlock[] {
  const day = new Date().getDay();
  const isWeekend = day === 0 || day === 6;
  if (isWeekend) {
    return [...dailyBlocks, weekendExtras];
  }
  return dailyBlocks;
}

export function isWeekendDay(date?: Date): boolean {
  const d = date ?? new Date();
  return d.getDay() === 0 || d.getDay() === 6;
}
