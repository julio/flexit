import '../models/exercise.dart';
import '../models/program.dart';

class Routine {
  final String id;
  final String title;
  final List<ExerciseBlock> blocks;
  final Program? program;
  const Routine({
    required this.id,
    required this.title,
    required this.blocks,
    this.program,
  });

  bool get hasProgram => program != null;
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

/// Hip & Lumbar Reset is a 6-week program. The morning wake-up, decompress,
/// mobilize, and cool-down blocks are constant every week — only Block C
/// (Strengthen) progresses. After week 6 the program enters maintenance and
/// uses the Week 6 strength block indefinitely.
///
/// All exercise IDs are prefixed `hlr-` to keep completion data isolated
/// from Daily 30. Exercises whose dose varies between weeks (e.g. dead bug
/// 3×8 in W1 vs 3×10 in W3) reuse the same ID so per-set completion data
/// carries across weeks.

const _hlrWakeUp = ExerciseBlock(
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
      name: 'Press-Up (McKenzie)',
      duration: '5 reps',
      description:
          'Face-down, hands under shoulders, press the chest up while the hips stay heavy on the floor. Hold each rep only as long as it feels good — no fixed count.',
      cue:
          'Watch where the pain goes. If symptoms move toward the spine (centralize) you can keep going; if they spread down the leg, stop and skip cobra today.',
    ),
  ],
);

const _hlrDecompress = ExerciseBlock(
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
);

const _hlrMobilize = ExerciseBlock(
  id: 'hlr-block2',
  title: 'B. Mobilize',
  duration: '20 min',
  exercises: [
    Exercise(
      id: 'hlr-iliacus-release',
      name: 'Right Anterior Hip Release',
      duration: '5 min',
      description:
          'Lie face-down with a lacrosse ball under the right anterior hip (just inside the bony ASIS, on the iliacus). Breathe; let the tissue soften before any stretching.',
      cue:
          'Tissue quality first, then length. This is what makes the half-kneeling stretch actually work.',
    ),
    Exercise(
      id: 'hlr-hip-flexor-stretch-reach',
      name: 'Half-Kneeling Hip Flexor Stretch with Reach',
      duration: '60 sec each side',
      sets: 2,
      description:
          'Back knee down, front foot forward; squeeze the back glute, then tuck the pelvis under, then reach the same-side arm overhead.',
      cue:
          'Cue order matters: glute squeeze → posterior pelvic tilt → reach. No rib flare on the overhead reach — if your ribs lift, you traded the hip stretch for lumbar extension.',
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
      id: 'hlr-90-90-ir-liftoff',
      name: '90/90 Hip IR Lift-Off',
      duration: '10 reps each side',
      description:
          'In the 90/90 position, lift the back-leg shin a quarter-inch off the floor and hold 5 seconds. Keep the pelvis from rolling.',
      cue:
          'Isolated end-range internal rotation — the right side will be much harder, and that is exactly the point.',
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
      name: 'Prone Press-Up Series',
      duration: '5 reps',
      description:
          'Weeks 1–2: prone press-ups only — hands under shoulders, hips stay heavy, gentle press, return. Watch where symptoms go. Week 3 onward, only if symptoms centralized: progressively build toward straight-arm upward dog over the remaining weeks.',
      cue:
          'Symptom centralization gates the progression. If pain moves toward the spine across reps you can keep going; if it spreads down the leg, stop.',
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
      cue:
          'Hits hip flexor, hamstring, thoracic rotation in one shot. Front-leg depth as tolerated.',
    ),
  ],
);

const _hlrCoolDown = ExerciseBlock(
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
      duration: '2 min',
      description:
          'Lie flat with hands on belly; breathe in 4 seconds, out 6 seconds.',
      cue:
          'Down-regulates the nervous system — the whole program leans on this one for parasympathetic recovery.',
    ),
  ],
);

// ----- Per-week strength blocks (Block C) -----

const _hlrStrengthW1 = ExerciseBlock(
  id: 'hlr-block3-w1',
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
      cue: 'Lower back stays glued to floor. If it lifts, you went too far.',
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
      description: 'Back flat against wall with thighs parallel to floor.',
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
);

const _hlrStrengthW2 = ExerciseBlock(
  id: 'hlr-block3-w2',
  title: 'C. Strengthen',
  duration: '15 min',
  exercises: [
    Exercise(
      id: 'hlr-single-leg-bridge',
      name: 'Single-Leg Glute Bridge',
      duration: '6 reps each side',
      sets: 3,
      description:
          'One foot planted close to the glute, other knee pulled to chest; squeeze, lift.',
      cue:
          'Drive through the planted heel. Hips stay level — no dropping on the up-knee side.',
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
      cue: 'Lower back stays glued to floor.',
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
      id: 'hlr-hip-hinge-bodyweight',
      name: 'Bodyweight Hip Hinge',
      duration: '10 reps',
      sets: 3,
      description:
          'Feet hip-width, hands on the front of the thighs. Push hips straight back, slide the hands down the thighs until you feel hamstring tension, return. No weight — pattern only.',
      cue:
          'Grooves the hinge before you load it. Spine stays long; chest leads, not collapses.',
    ),
    Exercise(
      id: 'hlr-wall-sit',
      name: 'Wall Sit',
      duration: '30 sec',
      sets: 3,
      description: 'Back flat against wall with thighs parallel to floor.',
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
    Exercise(
      id: 'hlr-side-plank-mod',
      name: 'Side Plank (Modified)',
      duration: '20 sec each side',
      sets: 3,
      description:
          'From knees, hips stacked, line from knee to head; lift hips off floor.',
      cue: 'Glute medius does the work. Hips stay stacked.',
    ),
  ],
);

const _hlrStrengthW3 = ExerciseBlock(
  id: 'hlr-block3-w3',
  title: 'C. Strengthen',
  duration: '15 min',
  exercises: [
    Exercise(
      id: 'hlr-single-leg-bridge',
      name: 'Single-Leg Glute Bridge',
      duration: '8 reps each side',
      sets: 3,
      description:
          'Same as glute bridge but one foot only; other knee pulls to chest.',
      cue: 'Drive through the planted heel. Hips stay level.',
    ),
    Exercise(
      id: 'hlr-clams',
      name: 'Side-Lying Clams',
      duration: '15 reps each side',
      sets: 3,
      description:
          'On side with knees bent; keep feet together and open top knee while hips remain stacked.',
      cue: 'No rolling back.',
    ),
    Exercise(
      id: 'hlr-dead-bug',
      name: 'Dead Bug',
      duration: '10 reps each side',
      sets: 3,
      description:
          'On back; extend opposite arm and leg slowly while keeping lower back flat to floor.',
      cue: 'Lower back stays glued to floor.',
    ),
    Exercise(
      id: 'hlr-bird-dog',
      name: 'Bird Dog',
      duration: '10 reps each side',
      sets: 3,
      description:
          'On all fours; extend opposite arm and leg slowly without rotating hips.',
      cue: "Hips don't rotate.",
    ),
    Exercise(
      id: 'hlr-rdl-light',
      name: 'Romanian Deadlift (light KB)',
      duration: '8 reps',
      sets: 3,
      description:
          'Light kettlebell or single dumbbell in front. Hinge at the hip — push hips back, slide the weight down the thighs to mid-shin, return.',
      cue:
          'Hinge, not squat. Spine stays long; bar path tight to the legs.',
    ),
    Exercise(
      id: 'hlr-wall-sit',
      name: 'Wall Sit',
      duration: '40 sec',
      sets: 3,
      description: 'Back flat against wall with thighs parallel to floor.',
      cue: 'Builds quad endurance.',
    ),
    Exercise(
      id: 'hlr-reverse-lunge',
      name: 'Reverse Lunges',
      duration: '8 reps each side',
      sets: 3,
      description:
          'Step back, drop knee to floor lightly, drive up through the front heel.',
      cue: 'Front knee tracks over the foot.',
    ),
    Exercise(
      id: 'hlr-side-plank-mod',
      name: 'Side Plank (Modified)',
      duration: '25 sec each side',
      sets: 3,
      description: 'From knees, hips stacked, line from knee to head.',
      cue: 'Hips stay stacked.',
    ),
  ],
);

const _hlrStrengthW4 = ExerciseBlock(
  id: 'hlr-block3-w4',
  title: 'C. Strengthen',
  duration: '15 min',
  exercises: [
    Exercise(
      id: 'hlr-single-leg-bridge',
      name: 'Single-Leg Glute Bridge',
      duration: '10 reps each side',
      sets: 3,
      description:
          'Same as glute bridge but one foot only; other knee pulls to chest.',
      cue: 'Drive through the planted heel.',
    ),
    Exercise(
      id: 'hlr-clams',
      name: 'Side-Lying Clams',
      duration: '15 reps each side',
      sets: 3,
      description:
          'On side with knees bent; keep feet together and open top knee while hips remain stacked.',
      cue: 'No rolling back.',
    ),
    Exercise(
      id: 'hlr-dead-bug',
      name: 'Dead Bug',
      duration: '10 reps each side',
      sets: 3,
      description:
          'On back; extend opposite arm and leg slowly while keeping lower back flat to floor.',
      cue: 'Lower back stays glued to floor.',
    ),
    Exercise(
      id: 'hlr-bird-dog',
      name: 'Bird Dog',
      duration: '10 reps each side',
      sets: 3,
      description:
          'On all fours; extend opposite arm and leg slowly without rotating hips.',
      cue: "Hips don't rotate.",
    ),
    Exercise(
      id: 'hlr-rdl-light',
      name: 'Romanian Deadlift (light KB)',
      duration: '10 reps',
      sets: 3,
      description:
          'Light kettlebell or single dumbbell in front. Hinge at the hip — push hips back, slide the weight down the thighs to mid-shin, return.',
      cue: 'Hinge, not squat. Spine stays long.',
    ),
    Exercise(
      id: 'hlr-wall-sit',
      name: 'Wall Sit',
      duration: '40 sec',
      sets: 3,
      description: 'Back flat against wall with thighs parallel to floor.',
      cue: 'Builds quad endurance.',
    ),
    Exercise(
      id: 'hlr-reverse-lunge',
      name: 'Reverse Lunges',
      duration: '10 reps each side',
      sets: 3,
      description:
          'Step back, drop knee to floor lightly, drive up through the front heel.',
      cue: 'Front knee tracks over the foot.',
    ),
    Exercise(
      id: 'hlr-side-plank-chair',
      name: 'Side Plank (Chair-Assisted Full)',
      duration: '20 sec each side',
      sets: 3,
      description:
          'Side plank from the feet, but the top foot rests on a chair seat instead of stacking on the bottom foot. Shorter moment arm, full-position alignment.',
      cue:
          'Intermediate step between modified (knees down) and full (feet stacked). Hips stay stacked; line stays straight.',
    ),
    Exercise(
      id: 'hlr-chair-squat-test',
      name: 'Chair Squat Test',
      duration: '8 reps',
      sets: 1,
      description:
          'Stand in front of a knee-height chair. Sit-to-stand for 8 reps. Watch for the lumbar rounding before contact with the chair or knees caving in.',
      cue:
          'This is a gate — if you can do 8 clean reps with a neutral spine, you can introduce the goblet squat in Week 5. If you cannot, stay with this until you can.',
    ),
  ],
);

const _hlrStrengthW5 = ExerciseBlock(
  id: 'hlr-block3-w5',
  title: 'C. Strengthen',
  duration: '15 min',
  exercises: [
    Exercise(
      id: 'hlr-single-leg-bridge',
      name: 'Single-Leg Glute Bridge',
      duration: '10 reps each side',
      sets: 3,
      description:
          'Same as glute bridge but one foot only; other knee pulls to chest.',
      cue: 'Drive through the planted heel.',
    ),
    Exercise(
      id: 'hlr-clams',
      name: 'Side-Lying Clams',
      duration: '15 reps each side',
      sets: 3,
      description:
          'On side with knees bent; keep feet together and open top knee while hips remain stacked.',
      cue: 'No rolling back.',
    ),
    Exercise(
      id: 'hlr-bird-dog',
      name: 'Bird Dog',
      duration: '10 reps each side',
      sets: 3,
      description:
          'On all fours; extend opposite arm and leg slowly without rotating hips.',
      cue: "Hips don't rotate.",
    ),
    Exercise(
      id: 'hlr-goblet-squat',
      name: 'Goblet Squat',
      duration: '8–10 reps',
      sets: 3,
      description:
          'Hold a dumbbell or kettlebell at chest height; squat to a deep, controlled position and stand.',
      cue: 'Chest up, knees track feet, drive through midfoot.',
    ),
    Exercise(
      id: 'hlr-walking-lunge',
      name: 'Walking Lunges',
      duration: '10 reps each side',
      sets: 3,
      description:
          'Step forward into a lunge, drive up off the front heel, and walk into the next step.',
      cue: 'Long step. Stay tall through the torso.',
    ),
    Exercise(
      id: 'hlr-single-leg-deadlift',
      name: 'Single-Leg Deadlift',
      duration: '6 reps each side',
      sets: 3,
      description:
          'Hand on wall for balance; hinge at the hip, back leg extends behind you, return.',
      cue: 'Hinge, do not squat. Spine stays long.',
    ),
    Exercise(
      id: 'hlr-side-plank-full',
      name: 'Side Plank (Full)',
      duration: '30 sec each side',
      sets: 3,
      description: 'From feet, hips lifted, body straight from feet to head.',
      cue: 'Glute medius does the work.',
    ),
  ],
);

const _hlrStrengthW6 = ExerciseBlock(
  id: 'hlr-block3-w6',
  title: 'C. Strengthen',
  duration: '15 min',
  exercises: [
    Exercise(
      id: 'hlr-single-leg-bridge',
      name: 'Single-Leg Glute Bridge',
      duration: '10 reps each side',
      sets: 3,
      description:
          'Same as glute bridge but one foot only; other knee pulls to chest.',
      cue: 'Drive through the planted heel.',
    ),
    Exercise(
      id: 'hlr-clams',
      name: 'Side-Lying Clams',
      duration: '15 reps each side',
      sets: 3,
      description:
          'On side with knees bent; keep feet together and open top knee while hips remain stacked.',
      cue: 'No rolling back.',
    ),
    Exercise(
      id: 'hlr-bird-dog',
      name: 'Bird Dog',
      duration: '10 reps each side',
      sets: 3,
      description:
          'On all fours; extend opposite arm and leg slowly without rotating hips.',
      cue: "Hips don't rotate.",
    ),
    Exercise(
      id: 'hlr-goblet-squat',
      name: 'Goblet Squat',
      duration: '10 reps',
      sets: 3,
      description:
          'Hold a dumbbell or kettlebell at chest height; squat to a deep, controlled position and stand.',
      cue: 'Chest up, knees track feet, drive through midfoot.',
    ),
    Exercise(
      id: 'hlr-walking-lunge',
      name: 'Walking Lunges',
      duration: '10 reps each side',
      sets: 3,
      description:
          'Step forward into a lunge, drive up off the front heel, and walk into the next step.',
      cue: 'Long step. Stay tall through the torso.',
    ),
    Exercise(
      id: 'hlr-single-leg-deadlift',
      name: 'Single-Leg Deadlift',
      duration: '8 reps each side',
      sets: 3,
      description:
          'Hand on wall for balance; hinge at the hip, back leg extends behind you, return.',
      cue: 'Hinge, do not squat. Spine stays long.',
    ),
    Exercise(
      id: 'hlr-side-plank-full',
      name: 'Side Plank (Full)',
      duration: '40–45 sec each side',
      sets: 3,
      description: 'From feet, hips lifted, body straight from feet to head.',
      cue: 'Glute medius does the work.',
    ),
  ],
);

const hipLumbarResetProgram = Program(
  constantBlocks: [_hlrWakeUp, _hlrDecompress, _hlrMobilize, _hlrCoolDown],
  strengthBlockIndex: 3,
  weeks: [
    WeekProgram(
      weekNumber: 1,
      phase: 'Phase 1 · Calm and restore',
      theme: 'Decompress, baseline activation. Nothing aggressive.',
      strengthBlock: _hlrStrengthW1,
      walkingMilesMin: 0.5,
      walkingMilesMax: 0.5,
    ),
    WeekProgram(
      weekNumber: 2,
      phase: 'Phase 1 · Calm and restore',
      theme: 'Add lateral hip stability.',
      strengthBlock: _hlrStrengthW2,
      walkingMilesMin: 0.75,
      walkingMilesMax: 0.75,
    ),
    WeekProgram(
      weekNumber: 3,
      phase: 'Phase 2 · Build capacity',
      theme: 'Load the glutes more, start single-leg work.',
      strengthBlock: _hlrStrengthW3,
      walkingMilesMin: 1,
      walkingMilesMax: 1,
    ),
    WeekProgram(
      weekNumber: 4,
      phase: 'Phase 2 · Build capacity',
      theme: 'Push toward full side plank and longer walks.',
      strengthBlock: _hlrStrengthW4,
      walkingMilesMin: 1.5,
      walkingMilesMax: 2,
    ),
    WeekProgram(
      weekNumber: 5,
      phase: 'Phase 3 · Integrate and load',
      theme: 'Real loading. Compound movements.',
      strengthBlock: _hlrStrengthW5,
      walkingMilesMin: 3,
      walkingMilesMax: 3,
    ),
    WeekProgram(
      weekNumber: 6,
      phase: 'Phase 3 · Integrate and load',
      theme: 'Test the system. Optional return to light jogging.',
      strengthBlock: _hlrStrengthW6,
      walkingMilesMin: 4,
      walkingMilesMax: 5,
    ),
  ],
);

/// Backward-compat accessor: any non-program callers still expect a fixed
/// block list. Returns the Week-1 view (wake-up → decompress → mobilize →
/// strengthen-W1 → cool-down).
final hipLumbarResetBlocks = hipLumbarResetProgram.blocksForWeek(1);

const routines = <Routine>[
  Routine(
    id: hipLumbarResetRoutineId,
    title: 'Hip & Lumbar Reset',
    blocks: [_hlrWakeUp, _hlrDecompress, _hlrMobilize, _hlrStrengthW1, _hlrCoolDown],
    program: hipLumbarResetProgram,
  ),
  Routine(
    id: daily30RoutineId,
    title: 'Daily 30',
    blocks: dailyBlocks,
  ),
];

Routine routineById(String id) =>
    routines.firstWhere((r) => r.id == id, orElse: () => routines.first);
