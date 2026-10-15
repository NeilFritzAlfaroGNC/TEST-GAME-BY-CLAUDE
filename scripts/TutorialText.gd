extends RefCounted
class_name TutorialText
## Edit these strings to change the Level 1 tutorial wording later.
## Keep each key in step with its matching tutorial page in Main.gd.

const BELT_TITLE: String = "FOOD BELT & FOOD GROUPS"
const BELT_DESCRIPTION: String = "The moving belt carries food for your Hero. Drag a food from the belt and drop it on the Hero to use it.\n\nGO (yellow) foods give energy. GLOW (green) foods protect your body. GROW (red) foods help your body grow. Choose the group that matches the lesson and monster."
const ENEMY_TITLE: String = "THE HUNGER MONSTER"
const ENEMY_DESCRIPTION: String = "Hunger Monsters move toward your Hero from the left. Feed the Hero a matching food from the belt to defeat the closest monster. A wrong food is returned safely. If a monster reaches the Hero during normal play, you lose a life."
const WRONG_FOOD_TITLE: String = "WRONG FOOD IS SAFE"
const WRONG_FOOD_DESCRIPTION: String = "Try a food from another group. It will return to the belt without costing a life. Then feed the matching GO food to the monster."
const FEED_SUCCESS_TITLE: String = "NICE WORK!"
const FEED_SUCCESS_DESCRIPTION: String = "You used matching food to defeat the monster. Normal Level 1 play will start after this short lesson."
const LIVES_TITLE: String = "LIVES"
const LIVES_DESCRIPTION: String = "In normal gameplay, a monster that reaches the Hero costs one life. Your lesson practice does not remove campaign lives."
const BOSSES_TITLE: String = "BOSS LEVELS"
const BOSSES_DESCRIPTION: String = "Every 5th level is a boss level. Clear its waves, then feed one GO, one GROW, and one GLOW food to build a balanced meal."
const PAUSE_TITLE: String = "PAUSE"
const PAUSE_DESCRIPTION: String = "Press Esc or the Pause button whenever you need a break. Select Finish Tutorial to begin the same Level 1 run."
const COMPLETE_TITLE: String = "TUTORIAL COMPLETE!"
const COMPLETE_DESCRIPTION: String = "You're ready! The tutorial will close and this same Level 1 run will continue. Practice points are not added to your campaign score."