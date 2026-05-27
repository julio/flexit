import '../models/exercise.dart';

class Routine {
  final String id;
  final String title;
  final List<ExerciseBlock> blocks;
  const Routine({required this.id, required this.title, required this.blocks});
}

const daily30RoutineId = 'daily30';
const hipLumbarResetRoutineId = 'hipLumbarReset';

/// Hip & Lumbar Reset is the new default — it's what Julio is currently
/// working through. Daily 30 stays available as an alternate.
const defaultRoutineId = hipLumbarResetRoutineId;

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
        sets: 2,
        timer: TimerSpec(settingKey: 'pigeon', defaultSeconds: 90),
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

/// 6-Week Hip & Lumbar Reset — ~50 min total: morning wake-up, decompress,
/// mobilize, strengthen, cool down. All exercise IDs are prefixed `hlr-` to
/// keep completion data isolated from Daily 30.
const hipLumbarResetBlocks = <ExerciseBlock>[
  ExerciseBlock(
    id: 'hlr-block0',
    title: 'Morning Wake-Up',
    duration: '5 min',
    exercises: [
      Exercise(
        id: 'hlr-cat-cow',
        name: 'Cat-Cow',
        duration: '10 reps',
        description:
            'Move spine vertebra by vertebra in alternating flexion and extension.',
        cue: 'Exhale into the cat (round), inhale into the cow (arch).',
      ),
      Exercise(
        id: 'hlr-single-knee-chest',
        name: 'Single Knee to Chest',
        duration: '30 sec each side',
        description:
            'Lying on back, pull one knee gently toward chest while opposite leg stays extended.',
        cue: 'Pull one knee gently to chest, other leg stays straight.',
      ),
      Exercise(
        id: 'hlr-pelvic-tilts',
        name: 'Pelvic Tilts',
        duration: '20 reps',
        description:
            'Lying on back with knees bent, flatten lower back by tucking pelvis, then release.',
        cue: 'Small movement, just the pelvis.',
      ),
      Exercise(
        id: 'hlr-gentle-cobra',
        name: 'Gentle Cobra',
        duration: '5 reps × 5 sec hold',
        description:
            'Face-down position, push up on forearms or hands to comfortable range.',
        cue: 'Only as far as comfortable.',
      ),
    ],
  ),
  ExerciseBlock(
    id: 'hlr-block1',
    title: 'A. Decompress',
    duration: '10 min',
    exercises: [
      Exercise(
        id: 'hlr-supine-90-90',
        name: 'Supine 90/90',
        duration: '5 min',
        description:
            'Lie on back with calves on chair/couch; hips and knees at 90 degrees.',
        cue:
            'Long slow belly breathing. This is the single most important position.',
      ),
      Exercise(
        id: 'hlr-constructive-rest',
        name: 'Constructive Rest',
        duration: '5 min',
        description:
            'Lie on back with knees bent, feet flat about hip-width apart.',
        cue:
            'Let the floor hold you. Breathe. Psoas releases passively here.',
      ),
    ],
  ),
  ExerciseBlock(
    id: 'hlr-block2',
    title: 'B. Mobilize',
    duration: '15 min',
    exercises: [
      Exercise(
        id: 'hlr-hip-flexor-stretch-reach',
        name: 'Half-Kneeling Hip Flexor Stretch with Reach',
        duration: '60 sec each side',
        sets: 2,
        description:
            'Back knee down, front foot forward; squeeze back glute and tuck pelvis, then reach same-side arm overhead.',
        cue: 'Squeeze the back glute hard, then tuck the pelvis under.',
      ),
      Exercise(
        id: 'hlr-90-90-switches',
        name: '90/90 Hip Switches',
        duration: '10 switches',
        description:
            'Sit with one leg bent in front at 90°, other bent behind at 90°; switch sides by rotating both legs together.',
        cue: 'Directly works the limited hip rotation you have.',
      ),
      Exercise(
        id: 'hlr-figure-4',
        name: 'Supine Figure 4 Stretch',
        duration: '60 sec each side',
        description:
            'Lie on back; place right ankle on left knee, pull left thigh toward chest.',
        cue: 'Feel in the right glute.',
      ),
      Exercise(
        id: 'hlr-cobra-upward-dog',
        name: 'Cobra to Upward Dog Progression',
        duration: '5 reps',
        description:
            'Press up from floor progressively toward straight arms.',
        cue: 'Do not force, but visit your end range daily.',
      ),
      Exercise(
        id: 'hlr-adductor-rocks',
        name: 'Adductor Rocks',
        duration: '10 reps each side',
        description:
            'On all fours; extend one leg out to side with foot flat; rock hips back.',
        cue: 'Feel inner thigh stretch.',
      ),
      Exercise(
        id: 'hlr-worlds-greatest',
        name: "World's Greatest Stretch",
        duration: '3 reps each side',
        description:
            'Low lunge, opposite hand on floor, twist toward front leg while reaching other arm to ceiling.',
        cue: 'Hits hip flexor, hamstring, thoracic rotation in one shot.',
      ),
    ],
  ),
  ExerciseBlock(
    id: 'hlr-block3',
    title: 'C. Strengthen',
    duration: '15 min',
    exercises: [
      Exercise(
        id: 'hlr-glute-bridge',
        name: 'Glute Bridge',
        duration: '15 reps',
        sets: 3,
        description:
            'Feet close to glutes; squeeze glutes then lift hips without arching lower back.',
        cue: 'Squeeze glutes first, then lift hips. No back arch.',
      ),
      Exercise(
        id: 'hlr-clams',
        name: 'Side-Lying Clams',
        duration: '15 reps each side',
        sets: 3,
        description:
            'On side with knees bent; keep feet together and open top knee while hips remain stacked.',
        cue: 'No rolling back. Wakes up the glute medius.',
      ),
      Exercise(
        id: 'hlr-dead-bug',
        name: 'Dead Bug',
        duration: '8 reps each side',
        sets: 3,
        description:
            'On back; extend opposite arm and leg slowly while keeping lower back flat to floor.',
        cue:
            'Lower back stays glued to floor. If it lifts, you went too far.',
      ),
      Exercise(
        id: 'hlr-bird-dog',
        name: 'Bird Dog',
        duration: '8 reps each side',
        sets: 3,
        description:
            'On all fours; extend opposite arm and leg slowly without rotating hips.',
        cue: "Hips don't rotate.",
      ),
      Exercise(
        id: 'hlr-wall-sit',
        name: 'Wall Sit',
        duration: '30 sec',
        sets: 3,
        description:
            'Back flat against wall with thighs parallel to floor.',
        cue: 'Builds quad endurance.',
      ),
      Exercise(
        id: 'hlr-standing-hip-extension',
        name: 'Standing Hip Extension',
        duration: '12 reps each leg',
        sets: 3,
        description:
            'Standing with hand on wall for balance; kick one leg straight back and squeeze glute.',
        cue: 'Pelvis stays level, no back arching.',
      ),
    ],
  ),
  ExerciseBlock(
    id: 'hlr-block4',
    title: 'D. Cool Down',
    duration: '5 min',
    exercises: [
      Exercise(
        id: 'hlr-childs-pose',
        name: "Child's Pose",
        duration: '60 sec',
        description:
            'Sit hips back to heels with arms extended forward, forehead down.',
        cue: 'Decompresses the spine.',
      ),
      Exercise(
        id: 'hlr-knees-chest-both',
        name: 'Knees to Chest (Both)',
        duration: '60 sec',
        description: 'Lie on back and hug both knees toward chest.',
        cue: 'Breathe.',
      ),
      Exercise(
        id: 'hlr-supine-twist',
        name: 'Supine Spinal Twist',
        duration: '60 sec each side',
        description:
            'On back with knees bent; drop both knees to one side and look opposite direction.',
        cue: 'Gentle.',
      ),
      Exercise(
        id: 'hlr-final-breathing',
        name: 'Final Breathing',
        duration: '60 sec',
        description:
            'Lie flat with hands on belly; breathe in 4 seconds, out 6 seconds.',
        cue: 'Down-regulates the nervous system.',
      ),
    ],
  ),
];

const routines = <Routine>[
  Routine(
    id: hipLumbarResetRoutineId,
    title: 'Hip & Lumbar Reset',
    blocks: hipLumbarResetBlocks,
  ),
  Routine(
    id: daily30RoutineId,
    title: 'Daily 30',
    blocks: dailyBlocks,
  ),
];

Routine routineById(String id) =>
    routines.firstWhere((r) => r.id == id, orElse: () => routines.first);
