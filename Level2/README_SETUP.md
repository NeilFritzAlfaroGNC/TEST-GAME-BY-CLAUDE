# Level 2 · Canteen: Guess the Food

This module is for the existing Food Heroes Godot project. It uses the current Canteen background, the 15 assigned food scenes under `res://scenes/Foods/`, and their original `FoodData` categories. It includes no duplicate food images or database.

## Test in Godot

1. Extract the `Level2` folder beside your project's `project.godot`.
2. Open `res://Level2/scenes/battle_scene_level2_canteen.tscn` and press **F6**.
3. Drag the food from the center card into a GO, GLOW, or GROW basket. A drop outside the baskets does not use a question. An incorrect basket shows the correct category.
4. Select the scene root in the Inspector to change **Food Scenes**, the **Canteen Background**, or the difficulty settings. The active difficulty comes from the project's `ProgressManager` and falls back to Easy.

Foods are shuffled without repeats until the pool is exhausted. Hard reshuffles the pool to reach 20 questions. If a food has more than one supported category in its data, any of those categories is accepted.

| Difficulty | Questions | Correct to pass | Two stars | Three stars | Time |
|---|---:|---:|---:|---:|---:|
| Easy | 10 | 6 | 8 | 9 | 3:00 |
| Normal | 15 | 11 | 13 | 14 | 4:00 |
| Hard | 20 | 16 | 18 | 19 | 5:00 |

The round ends after the last answer or at timeout. The result uses the number answered correctly at that point.

## Activate after testing

1. Enable **Save Progress on Pass** on the Level 2 root if you want to record stars under `canteen_level_2`. It starts off so F6 tests leave your save alone.
2. In `res://scripts/Story Scene/canteen_story_scene.gd`, set `NEXT_SCENE` to `res://Level2/scenes/battle_scene_level2_canteen.tscn`.
3. Keep the original Canteen battle scene and shared food assets in the project.
