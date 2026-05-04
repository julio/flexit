import '../models/exercise.dart';

const dailyBlocks = <ExerciseBlock>[
  ExerciseBlock(
    id: 'block0',
    title: 'Activate',
    duration: '1 min',
    exercises: [
      Exercise(
        id: 'jumps',
        name: '100 Jumps in Place',
        duration: '100 reps',
        description:
            'Stand tall, feet hip-width. Jump straight up off both feet — small, light hops. No rope, just bouncing in place. Land soft on the balls of your feet.',
        cue: 'Quick and springy. Raises heart rate and warms the calves before mobility work.',
      ),
    ],
  ),
  ExerciseBlock(
    id: 'block1',
    title: 'Wake Up the Spine + Hips',
    duration: '2 min',
    exercises: [
      Exercise(
        id: 'cat-cow',
        name: 'Cat-Cow',
        duration: '10 reps',
        description:
            'Hands and knees, wrists under shoulders, knees under hips. Inhale: drop belly, lift chest, look up. Exhale: round spine, tuck chin, push floor away.',
        cue: 'Move slowly — 3 seconds each direction.',
        videoUrl: 'https://www.youtube.com/watch?v=LIVJZZyZ2qM',
      ),
      Exercise(
        id: 'hip-cars',
        name: 'Hip CARs',
        duration: '5 per direction, each side',
        description:
            'Standing, hold a wall for balance. Lift knee to hip height, rotate out to the side, sweep leg back behind you, return.',
        cue: 'Keep pelvis completely still — movement only in the hip socket.',
        videoUrl: 'https://www.youtube.com/watch?v=hRMrq6G81p8',
      ),
    ],
  ),
  ExerciseBlock(
    id: 'block2',
    title: 'Mobilize',
    duration: '4 min',
    exercises: [
      Exercise(
        id: '90-90',
        name: '90/90 Hip Switches',
        duration: '10 total (5 per side)',
        description:
            'Sit on floor, both knees at 90°. Lift knees, keep heels pivoted, rotate to opposite side.',
        cue: 'Phase 1: hands behind. Phase 2: tall spine. Phase 3: no-hands hinge.',
        videoUrl: 'https://www.youtube.com/watch?v=m51AZSXMvEA',
      ),
      Exercise(
        id: 'worlds-greatest',
        name: "World's Greatest Stretch",
        duration: '5 per side',
        description:
            'Deep lunge, place hand inside front foot, rotate opposite arm to ceiling. Hold 2s. Drive hips back to straighten front leg.',
        cue: 'Opens hip flexors, adductors, hamstrings, and thoracic spine all at once.',
        videoUrl: 'https://www.youtube.com/watch?v=-CiWQ2IvY34',
      ),
    ],
  ),
  ExerciseBlock(
    id: 'block3',
    title: 'Lengthen',
    duration: '6 min',
    exercises: [
      Exercise(
        id: 'couch-stretch',
        name: 'Couch Stretch',
        duration: '90 sec per side',
        sets: 2,
        timer: TimerSpec(settingKey: 'couch-stretch', defaultSeconds: 90),
        description:
            'Kneel facing away from couch. Back foot on seat. Step front foot forward. Squeeze glute, drive hips forward.',
        cue: "Stay tall — don't lean forward. Squeeze the glute on the back leg.",
        videoUrl: 'https://www.youtube.com/shorts/TIJu5aWPke0',
      ),
      Exercise(
        id: 'pigeon',
        name: 'Pigeon Pose',
        duration: '90 sec per side',
        description:
            'From all fours, slide knee forward toward wrist. Extend back leg straight behind. Walk hands forward and lower torso.',
        cue: 'Breathe and relax into it. Opens deep external hip rotators.',
        videoUrl: 'https://www.youtube.com/shorts/AI5A1PRYX7E',
      ),
    ],
  ),
  ExerciseBlock(
    id: 'block4',
    title: 'Strength',
    duration: '12 min',
    exercises: [
      Exercise(
        id: 'glute-bridge',
        name: 'Glute Bridge',
        duration: '15 reps, slow',
        description:
            'Lie on back, feet flat, knees bent. Drive through heels, squeeze glutes at top for 2s, lower slowly (3s down).',
        cue: 'When glutes are weak, your lower back compensates. Fix that here.',
        videoUrl: 'https://www.youtube.com/shorts/LORVjN2bg5o',
      ),
      Exercise(
        id: 'push-ups',
        name: 'Push-Ups',
        duration: '3 × 20 reps',
        sets: 3,
        reps: RepSpec(settingKey: 'push-ups', defaultReps: 20),
        description:
            'Hands shoulder-width, body in a straight line from head to heels. Lower chest to just above the floor, push back up. Rest 60–90 sec between sets.',
        cue: 'Brace the core and squeeze glutes — no sagging hips, no piked butt.',
      ),
      Exercise(
        id: 'plank',
        name: 'Plank',
        duration: '3 × 1 min',
        sets: 3,
        timer: TimerSpec(settingKey: 'plank', defaultSeconds: 60),
        description:
            'Forearms on the floor, elbows under shoulders, body in a straight line from head to heels. Hold 1 min. Rest 30–45 sec between sets.',
        cue: 'Squeeze glutes and pull belly button toward spine — straight line, no sagging.',
      ),
      Exercise(
        id: 'pull-ups',
        name: 'Pull-Ups',
        duration: '3 × 5 reps',
        sets: 3,
        reps: RepSpec(
            settingKey: 'pull-ups',
            defaultReps: 5,
            minReps: 1,
            maxReps: 15),
        description:
            'Overhand grip, shoulder-width. Pull until chin clears the bar, lower with control to a full hang. Rest 90–120 sec between sets.',
        cue: 'Lead with the elbows pulling down. Full hang at the bottom for the lat stretch.',
      ),
    ],
  ),
];
