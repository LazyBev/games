package combat;

import rl "vendor:raylib";
import "core:fmt";

screenWidth :: 1000;
screenHeight :: 800;

Options :: struct {
    name: cstring,
}

Animation_State :: enum {
    Idle,
    Attack,
    Hurt,
    Death,
}

Animation :: struct {
    texture: rl.Texture2D,
    num_frames: int,
    frame_timer: f32,
    current_frame: int,
    frame_length: f32,
    state: Animation_State,
}

SpriteTextures :: struct {
    idle: rl.Texture2D,
    attack: rl.Texture2D,
    hurt: rl.Texture2D,
    death: rl.Texture2D,
}

SpriteAnimations :: struct {
    idle: Animation,
    attack: Animation,
    hurt: Animation,
    death: Animation,
}

update_animation :: proc(a: ^Animation) {
    using rl;
    a.frame_timer += GetFrameTime();
    if a.frame_timer >= a.frame_length {
        a.frame_timer -= a.frame_length;
        a.current_frame += 1;
        if a.current_frame >= a.num_frames {
            a.current_frame = 0;
        }
    }
}

Enemy :: struct {
    position: rl.Vector2,
    animation: ^Animation,
    health: int,
    max_health: int,
    dead: bool,
}

Player :: struct {
    str: int,
    def: int,
    agi: int,
    dex: int,
    int: int,
}

init_player :: proc(st: int, df: int, ag: int, dx: int, it: int) -> Player {
    return Player{
        str = st,
        def = df,
        agi = ag,
        dex = dx,
        int = it,
    }
}

spawn_enemy :: proc(pos: rl.Vector2, anim: ^Animation) -> Enemy {
    return Enemy{
        position = pos,
        animation = anim,
        health = 100,
        max_health = 100,
        dead = false,
    };
}

draw_animation :: proc(a: Animation, pos: rl.Vector2, flip: bool) {
    using rl;
    width := f32(a.texture.width) / f32(a.num_frames);
    height := f32(a.texture.height);
    source := Rectangle {
        x = f32(a.current_frame) * width,
        y = 0,
        width = flip ? -width : width,
        height = height,
    };
    dest := Rectangle {
        x = pos.x,
        y = pos.y,
        width = width * 4,
        height = height * 4,
    };
    DrawTexturePro(a.texture, source, dest, {dest.width / 2, dest.height / 2}, 0, WHITE);
}

load_animation :: proc(tex: rl.Texture2D, frames: int, frame_time: f32, state: Animation_State) -> Animation {
    if tex.id == 0 {
        fmt.println("ERROR: Texture is not loaded properly!");
    }
    return Animation {
        texture = tex,
        num_frames = frames,
        frame_timer = 0,
        current_frame = 0,
        frame_length = frame_time,
        state = state,
    };
}

update_enemy_animation :: proc(enemy: ^Enemy, anims: ^SpriteAnimations) {
    if enemy.dead {
        return;
    }

    update_animation(enemy.animation);

    // Handle Death Animation Completion
    if enemy.animation.state == .Death {
        if enemy.animation.current_frame == enemy.animation.num_frames - 1 {
            enemy.animation.current_frame = enemy.animation.num_frames - 1; // Hold last frame
            enemy.dead = true;
        }
        return;
    }

    // Handle Hurt Animation Completion
    if enemy.animation.state == .Hurt {
        if enemy.animation.current_frame == enemy.animation.num_frames - 1 {
            enemy.animation = &anims.idle; // Return to idle
            enemy.animation.state = .Idle;
            enemy.animation.current_frame = 0;
            enemy.animation.frame_timer = 0;
        }
    }
}

damage_enemy :: proc(enemy: ^Enemy, amount: int, anims: ^SpriteAnimations) {
    if enemy.dead {
        return; // Don't process damage on a dead enemy
    }

    enemy.health -= amount;
    if enemy.health <= 0 {
        enemy.health = 0;
        enemy.animation = &anims.death; // Switch to death animation
        enemy.animation.state = .Death;
    } else {
        enemy.animation = &anims.hurt; // Switch to hurt animation
        enemy.animation.state = .Hurt;
    }
    enemy.animation.current_frame = 0; // Reset animation
    enemy.animation.frame_timer = 0;
}

main :: proc() {
    using rl;
    InitWindow(screenWidth, screenHeight, "Game");
    SetTargetFPS(60);
    SetExitKey(.Q);

    // Main menu options
    menuOptions: []Options = {
        { name = "Attack"   }, 
        { name = "Defend"   },
        { name = "Stats"    },
        { name = "Items"    },
        { name = "Settings" },
    };

    // Stats menu options
    statsOptions: []Options = {
        { name = "Str" }, 
        { name = "Def" },
        { name = "Agi" },
        { name = "Dex" },
        { name = "Int" },
    };
    mchar := init_player(10, 5, 3, 5, 1);
    player_stats: []int = {mchar.str, mchar.def, mchar.agi, mchar.dex, mchar.int};
    
    // Available items in game
    itemsDict: []Options = {
        { name = "Cloudy Vial" },
        { name = "Vigor Vial"  },
        { name = "Bomb"        },
    };

    // Item menu options
    itemOptions: []Options = {};

    // Settings menu options
    settingsOptions: []Options = {
        { name = "Save" },
        { name = "Quit" },
    };

    Level1 := LoadTexture("assets/Levels/LevelNormal.png");
    defer UnloadTexture(Level1);

    if Level1.width == 0 || Level1.height == 0 {
        fmt.println("ERROR: Failed to load Level1 texture!");
    } else {
        fmt.println("Loaded Level1 texture:", Level1.width, "x", Level1.height);
    }

    // Main menu
    menuSelectedIndex: i32 = 0;
    menuX: i32 = 23;
    menuY: i32 = screenHeight - 238;
    menuWidth: i32 = 175;
    menuHeight: i32 = 35;
    spacing: i32 = 10;
    menuPadding: i32 = 20;
    totalMenuHeight: i32 = (menuHeight + spacing) * i32(len(menuOptions)) - spacing;
    menuBoxHeight: i32 = totalMenuHeight + menuPadding * 2;
    menuBoxWidth: i32 = menuWidth + menuPadding * 2;

    // Stats menu 
    statsSelectedIndex: i32 = 0;
    inStatsMenu: bool = false;
    statsMenuX: i32 = menuX + menuBoxWidth + 6;
    statsMenuY: i32 = menuY;
    statsMenuWidth: i32 = 175;
    statsMenuHeight: i32 = 35;
    statsMenuBoxWidth: i32 = statsMenuWidth + menuPadding * 2;
    statsTotalHeight: i32 = (statsMenuHeight + spacing) * i32(len(statsOptions)) - spacing;
    statsMenuBoxHeight: i32 = statsTotalHeight + menuPadding * 2;

    // Item menu
    itemSelectedIndex: i32 = 0;
    inItemMenu: bool = false;
    itemMenuX: i32 = menuX + menuBoxWidth + 6;
    itemMenuY: i32 = menuY;
    itemMenuWidth: i32 = 175;
    itemMenuHeight: i32 = 35;
    itemMenuBoxWidth: i32 = itemMenuWidth + menuPadding * 2;
    itemTotalHeight: i32 = (itemMenuHeight + spacing) * i32(len(itemOptions)) - spacing;
    itemMenuBoxHeight: i32 = itemTotalHeight + menuPadding * 2;
    
    // Settings menu
    settingsSelectedIndex: i32 = 0;
    inSettingsMenu: bool = false;
    settingsMenuX: i32 = menuX + menuBoxWidth + 6;
    settingsMenuY: i32 = menuY;
    settingsMenuWidth: i32 = 175;
    settingsMenuHeight: i32 = 35;
    settingsMenuBoxWidth: i32 = settingsMenuWidth + menuPadding * 2;
    settingsTotalHeight: i32 = (settingsMenuHeight + spacing) * i32(len(settingsOptions)) - spacing;
    settingsMenuBoxHeight: i32 = settingsTotalHeight + menuPadding * 2;

    // Enemies
    slime_textures := SpriteTextures {
        idle = rl.LoadTexture("assets/Slime_Idle.png"),
        attack = rl.LoadTexture("assets/Slime_Attack.png"),
        hurt = rl.LoadTexture("assets/Slime_Hurt.png"),
        death = rl.LoadTexture("assets/Slime_Death.png"),
    };

    slime_animations := SpriteAnimations {
        idle = load_animation(slime_textures.idle, 6, 0.2, .Idle),
        attack = load_animation(slime_textures.attack, 10, 0.1, .Attack),
        hurt = load_animation(slime_textures.hurt, 5, 0.1, .Hurt),
        death = load_animation(slime_textures.death, 10, 0.15, .Death),
    };
    
    plant_textures := SpriteTextures {
        idle = rl.LoadTexture("assets/Plant_Idle.png"),
        attack = rl.LoadTexture("assets/Plant_Attack.png"),
        hurt = rl.LoadTexture("assets/Plant_Hurt.png"),
        death = rl.LoadTexture("assets/Plant_Death.png"),
    };

    plant_animations := SpriteAnimations {
        idle = load_animation(plant_textures.idle, 6, 0.2, .Idle),
        attack = load_animation(plant_textures.attack, 10, 0.1, .Attack),
        hurt = load_animation(plant_textures.hurt, 5, 0.1, .Hurt),
        death = load_animation(plant_textures.death, 10, 0.15, .Death),
    };

    defer rl.UnloadTexture(slime_textures.idle);
    defer rl.UnloadTexture(slime_textures.attack);
    defer rl.UnloadTexture(slime_textures.hurt);
    defer rl.UnloadTexture(slime_textures.death);
    defer rl.UnloadTexture(plant_textures.idle);
    defer rl.UnloadTexture(plant_textures.attack);
    defer rl.UnloadTexture(plant_textures.hurt);
    defer rl.UnloadTexture(plant_textures.death);

    current_slime_anim: ^Animation = &slime_animations.idle;
    slime_pos := rl.Vector2{ f32(GetScreenWidth()) / 2, f32(GetScreenHeight()) / 2 };
    slime_enemy := spawn_enemy(slime_pos, &slime_animations.idle);
    plant_pos := rl.Vector2{ f32(GetScreenWidth()) / 2, f32(GetScreenHeight()) / 2 };
    plant_enemy := spawn_enemy(plant_pos, &plant_animations.idle);

    controlsVisible := false;
    attackCd := 3;

    // Main game loop
    for !WindowShouldClose() {
        dt := GetFrameTime();
        // Handle input for main menu
        if !inItemMenu && !inSettingsMenu && !inStatsMenu {
            if IsKeyPressed(.W) {
                menuSelectedIndex -= 1;
                if menuSelectedIndex < 0 {
                    menuSelectedIndex = i32(len(menuOptions)) - 1;
                }
            }

            if IsKeyPressed(.S) {
                menuSelectedIndex += 1;
                if menuSelectedIndex >= i32(len(menuOptions)) {
                    menuSelectedIndex = 0;
                }
            }

            if IsKeyPressed(.ENTER) || IsKeyPressed(.SPACE) || IsKeyPressed(.D) {
                if menuSelectedIndex == 1 { // "Defend" selected
                    fmt.println("Selected:", menuOptions[menuSelectedIndex].name);
                } else if menuSelectedIndex == 2 { // "Stats" selected
                    fmt.println("Selected:", menuOptions[menuSelectedIndex].name);
                    inStatsMenu = true;
                } else if menuSelectedIndex == 3 { // "Items" selected
                    fmt.println("Selected:", menuOptions[menuSelectedIndex].name);
                    inItemMenu = true;
                } else if menuSelectedIndex == 4 { // "Settings" selected
                    fmt.println("Selected:", menuOptions[menuSelectedIndex].name);
                    inSettingsMenu = true;
                } else if menuSelectedIndex == 0 && attackCd == 3{
                    fmt.println("Selected:", menuOptions[menuSelectedIndex].name);
                    damage_enemy(&slime_enemy, 10, &slime_animations);
                    attackCd = 0;
                }
                attackCd += 1;
            }
        } else if inStatsMenu {
            // Inside item menu
            if IsKeyPressed(.W) {
                statsSelectedIndex -= 1;
                if statsSelectedIndex < 0 {
                    statsSelectedIndex = i32(len(statsOptions)) - 1;
                }
            }

            if IsKeyPressed(.S) {
                statsSelectedIndex += 1;
                if statsSelectedIndex >= i32(len(statsOptions)) {
                    statsSelectedIndex = 0;
                }
            }

            if IsKeyPressed(.A) || IsKeyPressed(.ESCAPE) {
                inStatsMenu = false; // Exit item menu
            }

            if IsKeyPressed(.ENTER) || IsKeyPressed(.SPACE) || IsKeyPressed(.D) {
            }
        } else if inItemMenu {
            // Inside item menu
            if IsKeyPressed(.W) {
                itemSelectedIndex -= 1;
                if itemSelectedIndex < 0 {
                    itemSelectedIndex = i32(len(itemOptions)) - 1;
                }
            }

            if IsKeyPressed(.S) {
                itemSelectedIndex += 1;
                if itemSelectedIndex >= i32(len(itemOptions)) {
                    itemSelectedIndex = 0;
                }
            }

            if IsKeyPressed(.A) || IsKeyPressed(.ESCAPE) {
                inItemMenu = false; // Exit item menu
            }

            if IsKeyPressed(.ENTER) || IsKeyPressed(.SPACE) || IsKeyPressed(.D) {
                fmt.println("Used item:", itemOptions[itemSelectedIndex].name);
            }
        } else if inSettingsMenu {
            // Inside settings menu
            if IsKeyPressed(.W) {
                settingsSelectedIndex -= 1;
                if settingsSelectedIndex < 0 {
                    settingsSelectedIndex = i32(len(settingsOptions)) - 1;
                }
            }

            if IsKeyPressed(.S) {
                settingsSelectedIndex += 1;
                if settingsSelectedIndex >= i32(len(settingsOptions)) {
                    settingsSelectedIndex = 0;
                }
            }

            if IsKeyPressed(.A) || IsKeyPressed(.ESCAPE) {
                inSettingsMenu = false; // Exit settings menu
            }

            if IsKeyPressed(.ENTER) || IsKeyPressed(.SPACE) || IsKeyPressed(.D) {
                fmt.println("Used setting:", settingsOptions[settingsSelectedIndex].name);
                if settingsOptions[settingsSelectedIndex].name == "Quit" {
                    CloseWindow();
                }
            }
        }

        update_enemy_animation(&slime_enemy, &slime_animations);

        // Draw
        BeginDrawing();
        ClearBackground(RAYWHITE);

        // Draw background texture
        if Level1.width > 0 && Level1.height > 0 {
            DrawTexturePro(
                Level1,
                Rectangle{ 0, 0, f32(Level1.width), f32(Level1.height) }, 
                Rectangle{ 0, 0, f32(screenWidth), f32(screenHeight) },
                Vector2{ 0, 0 },  
                0,                
                WHITE             
            );
        }
        if IsKeyPressed(.H) {
            controlsVisible = !controlsVisible; // Toggle the visibility
        }

        if controlsVisible {
            DrawRectangle(5, 5, 250, 90, ColorAlpha(GRAY, 0.65));
            DrawRectangleLines(5, 5, 250, 90, BLACK);
            DrawText("W/S to navigate", 10, 10, 17, BLACK);
            DrawText("ENTER/SPACE/D to select", 10, 30, 17, BLACK);
            DrawText("A/ESCAPE to deselect", 10, 50, 17, BLACK);
            DrawText("Press Q to quit", 10, 70, 17, BLACK);
        } else {
            DrawText("Press H to show controls", 10, 10, 17, BLACK);
        }

        // Draw main menu
        DrawRectangle(menuX - menuPadding, menuY - menuPadding, menuBoxWidth, menuBoxHeight, ColorAlpha(GRAY, 0.50));
        DrawRectangleLines(menuX - menuPadding, menuY - menuPadding, menuBoxWidth, menuBoxHeight, BLACK);

        // Display main menu options
        i: i32 = 0;
        for option in menuOptions {
            optionY := menuY + (menuHeight + spacing) * i;

            if i == menuSelectedIndex {
                DrawRectangle(menuX - 5, optionY - 3, menuWidth, menuHeight, BLUE);
                DrawRectangleLines(menuX - 5, optionY - 3, menuWidth, menuHeight, BLACK);
                DrawText(option.name, menuX + 5, optionY + 5, 20, RAYWHITE);
            } else {
                DrawText(option.name, menuX + 5, optionY + 5, 20, BLACK);
            }

            i += 1;
        }

        // Draw stats menu
        if inStatsMenu {
            DrawRectangle(statsMenuX - menuPadding, statsMenuY - menuPadding, statsMenuBoxWidth, statsMenuBoxHeight, ColorAlpha(DARKGRAY, 0.50));
            DrawRectangleLines(statsMenuX - menuPadding, statsMenuY - menuPadding, statsMenuBoxWidth, statsMenuBoxHeight, BLACK);

            // Display item menu options
            i = 0;
            for stats in statsOptions {
                statsY := statsMenuY + (statsMenuHeight + spacing) * i;
                statsNum := fmt.ctprintf("%v", player_stats[i]);
                statsWrdNum := fmt.ctprintf("%v : %v", stats.name, statsNum); 
                DrawText(statsWrdNum, statsMenuX + 5, statsY + 5, 20, BLACK);
                i += 1;
            }
        }

        // Draw item menu
        if inItemMenu {
            DrawRectangle(itemMenuX - menuPadding, itemMenuY - menuPadding, itemMenuBoxWidth, itemMenuBoxHeight, ColorAlpha(DARKGRAY, 0.50));
            DrawRectangleLines(itemMenuX - menuPadding, itemMenuY - menuPadding, itemMenuBoxWidth, itemMenuBoxHeight, BLACK);

            // Display item menu options
            i = 0;
            for item in itemOptions {
                itemY := itemMenuY + (itemMenuHeight + spacing) * i;

                if i == itemSelectedIndex {
                    DrawRectangle(itemMenuX - 5, itemY - 3, itemMenuWidth, itemMenuHeight, BLUE);
                    DrawRectangleLines(itemMenuX - 5, itemY - 3, itemMenuWidth, itemMenuHeight, BLACK);
                    DrawText(item.name, itemMenuX + 5, itemY + 5, 20, RAYWHITE);
                } else {
                    DrawText(item.name, itemMenuX + 5, itemY + 5, 20, BLACK);
                }

                i += 1;
            }
        }

        // Draw settings menu
        if inSettingsMenu {
            DrawRectangle(settingsMenuX - menuPadding, settingsMenuY - menuPadding, settingsMenuBoxWidth, settingsMenuBoxHeight, ColorAlpha(DARKGRAY, 0.50));
            DrawRectangleLines(settingsMenuX - menuPadding, settingsMenuY - menuPadding, settingsMenuBoxWidth, settingsMenuBoxHeight, BLACK);

            // Display settings menu options
            i = 0;
            for setting in settingsOptions {
                settingsY := settingsMenuY + (settingsMenuHeight + spacing) * i;

                if i == settingsSelectedIndex {
                    DrawRectangle(settingsMenuX - 5, settingsY - 3, settingsMenuWidth, settingsMenuHeight, BLUE);
                    DrawRectangleLines(settingsMenuX - 5, settingsY - 3, settingsMenuWidth, settingsMenuHeight, BLACK);
                    DrawText(setting.name, settingsMenuX + 5, settingsY + 5, 20, RAYWHITE);
                } else {
                    DrawText(setting.name, settingsMenuX + 5, settingsY + 5, 20, BLACK);
                }

                i += 1;
            }
        }
 
        if !(slime_enemy.dead && slime_enemy.animation.state == .Death && slime_enemy.animation.current_frame == slime_enemy.animation.num_frames - 1) {
            draw_animation(slime_enemy.animation^, slime_enemy.position, false);
        }

        EndDrawing();
    }
}            
