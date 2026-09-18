// -----------------------------------------------------------------------------
// Dungeon of the Phoenix - by Syn9
// Refactored for C3 0.8.6
// -----------------------------------------------------------------------------

module game;

import std, libc;
import raylib6::rl;

// -----------------------------------------------------------------------------
// Constants
// -----------------------------------------------------------------------------

const String VERSION = "v1.0.0";
const int SCALE      = 3;
const int XRES       = 600;
const int XRES_HALF  = XRES / 2;
const int YRES       = 320;
const int YRES_HALF  = YRES / 2;
const int SCALE_8    = SCALE * 8;
const int MAP_WIDTH  = 75;
const int MAP_HEIGHT = 36;
const int MAP_SZ     = 3000;

const RLColor SHARKGRAY    = { 34, 32, 39, 255 };
const RLColor DARKDARKGRAY = { 20, 20, 20, 255 };
const RLColor DARKRED      = { 128, 20, 25, 255 };
const RLColor BITTERSWEET  = { 254, 111, 94, 255 };
const RLColor CYAN         = { 0, 224, 224, 255 };

const RLColor[6] FLAME_COLORS = { rl::YELLOW, rl::ORANGE, rl::WHITE, rl::RED, rl::ORANGE, rl::WHITE };
const RLColor[5] MAGIC_COLORS = { rl::GREEN, rl::DARKGREEN, rl::YELLOW, rl::GREEN, rl::DARKGREEN };

const String PROMPT_START = $feat(EMSCRIPTEN) ? "Click to start." : "Press <SPACE> to start.";
const String PROMPT_END   = $feat(EMSCRIPTEN) ? "Click to end." : "Press <SPACE> to end.";

// -----------------------------------------------------------------------------
// Embedded Asset Data
// -----------------------------------------------------------------------------

const char[*] EMBED_ICONS      = $embed("../assets/icons.png");
const char[*] EMBED_REVEAL     = $embed("../assets/reveal.png");
const char[*] EMBED_GRADIENT   = $embed("../assets/gradient.png");
const char[*] EMBED_FONT_SM    = $embed("../assets/font.png");

const char[*] EMBED_SND_BLIP      = $embed("../assets/sounds/blip.ogg");
const char[*] EMBED_SND_HURT      = $embed("../assets/sounds/hurt.ogg");
const char[*] EMBED_SND_ATTACK    = $embed("../assets/sounds/attack.ogg");
const char[*] EMBED_SND_PICKUP    = $embed("../assets/sounds/pickup.ogg");
const char[*] EMBED_SND_POTION    = $embed("../assets/sounds/potion.ogg");
const char[*] EMBED_SND_AMBIENT_1 = $embed("../assets/sounds/ambient-1.ogg");
const char[*] EMBED_SND_AMBIENT_2 = $embed("../assets/sounds/ambient-2.ogg");
const char[*] EMBED_SND_AMBIENT_3 = $embed("../assets/sounds/ambient-3.ogg");
const char[*] EMBED_SND_CAST      = $embed("../assets/sounds/cast.ogg");
const char[*] EMBED_SND_DEAD      = $embed("../assets/sounds/dead.ogg");
const char[*] EMBED_SND_DOOR      = $embed("../assets/sounds/door.ogg");
const char[*] EMBED_SND_LEVELUP   = $embed("../assets/sounds/levelup.ogg");
const char[*] EMBED_SND_SHAKE     = $embed("../assets/sounds/shake.ogg");
const char[*] EMBED_SND_MELODY    = $embed("../assets/sounds/melody.ogg");

// -----------------------------------------------------------------------------
// Enums
// -----------------------------------------------------------------------------

enum MenuState
{
	INTRO,
	CONTROLS,
	GAME,
	WIN,
}

enum AiState
{
	WANDER,
	CHASE,
}

enum Direction : (Vec2 v)
{
	UP    { { 0, -1 } },
	DOWN  { { 0, 1 } },
	LEFT  { { -1, 0 } },
	RIGHT { { 1, 0 } },
	NONE  { { 0, 0 } },
}

enum ItemKind : (int sprite, RLColor color, String name)
{
	HELMET        { 5 * 8 + 1, rl::VIOLET, "Helmet" },
	MAIL          { 5 * 8 + 2, rl::VIOLET, "Mail" },
	SHIELD        { 5 * 8 + 0, rl::VIOLET, "Shield" },
	FOOD          { 5 * 8 + 3, rl::BROWN,  "Food" },
	HEART         { 6 * 8 + 1, rl::RED,    "Heart Container" },
	KEY           { 6 * 8 + 7, rl::GOLD,   "Key" },
	POTION_HEALTH { 6 * 8 + 3, rl::RED,    "Health Potion" },
	POTION_MANA   { 6 * 8 + 4, rl::GREEN,  "Mana Potion" },
	ROD           { 6 * 8 + 2, rl::GREEN,  "Rod" },
}

// -----------------------------------------------------------------------------
// Structures
// -----------------------------------------------------------------------------

struct Notification
{
	char[64] buf;
	sz len;
	RLColor color;
	float timer;
}

struct Entity
{
	float px;
	float py;
	int ix;
	int iy;
	int kx;
	int ky;
	int sprite;
	int health;
	int max_health;
	int mana;
	int max_mana;
	int defense;
	int power;
	int level;
	int skip_update;
	float cooldown;
	AiState state;
	bool enemy;
	bool block_movement;
}

struct Projectile
{
	Vec2 p;
	Vec2 v;
	bool active;
}

struct Room
{
	int x;
	int y;
	int w;
	int h;
	int cx;
	int cy;
}

struct Item
{
	int ix;
	int iy;
	ItemKind kind;
	bool found;
}

struct PipStyle
{
	int sprite_empty;
	int sprite_half;
	int sprite_full;
	RLColor col_empty;
	RLColor col_half;
	RLColor col_full;
	RLColor col_text;
	String label;
}

const PipStyle HP_STYLE = {
	.sprite_empty = 0,
	.sprite_half  = 0,
	.sprite_full  = 1,
	.col_empty    = rl::DARKGRAY,
	.col_half     = DARKRED,
	.col_full     = rl::RED,
	.col_text     = DARKRED,
	.label        = "HP",
};

const PipStyle MP_STYLE = {
	.sprite_empty = 6,
	.sprite_half  = 6,
	.sprite_full  = 6,
	.col_empty    = rl::DARKGREEN,
	.col_half     = rl::DARKGREEN,
	.col_full     = rl::GREEN,
	.col_text     = rl::DARKGREEN,
	.label        = "MP",
};

// -----------------------------------------------------------------------------
// Grouped State Structures
// -----------------------------------------------------------------------------

struct GameState
{
	MenuState menu;
	bool intro_hold;
	bool game_win;
	bool quit_game;
	double t_clock;
	double t_game;
	double t_win;
	int key_delay;
	int amort;
	Direction last_move;
	float blip_timer;
	float ambient_timer;
	float death_timer;
}

struct ShakeState
{
	bool active;
	bool sound_played;
	double timer;
	double move_timer;
	float x;
	float y;
}

struct Inventory
{
	int[2] potions;
	bool helmet;
	bool mail;
	bool shield;
	bool key;
	bool rod;
	bool tears;
}

struct Dungeon
{
	int[MAP_SZ] board;
	int[MAP_SZ] board3;
	int[MAP_SZ] dist;
	int[MAP_SZ] dist2;
	bool[MAP_SZ] seen;
	bool[MAP_SZ] known;
	Room[100] rooms;
	int num_rooms;
	IntVec2[25] torches;
	int num_torches;
	double t_flames;
	bool keep_going;
	int start_idx;
	int win_idx;
	int phoenix_loc;
	double phoenix_frame;
}

struct Assets
{
	RLTexture icons;
	RLTexture reveal;
	RLTexture gradient;
	RLFont fnt;
	RLFont fnt_sm;

	RLRenderTexture2D ceiling_tex;
	RLRenderTexture2D ground_tex;
	RLRenderTexture2D pre_game_tex;

	RLSound snd_blip;
	RLSound snd_hurt;
	RLSound snd_attack;
	RLSound snd_pickup;
	RLSound snd_potion;
	RLSound snd_ambient_1;
	RLSound snd_ambient_2;
	RLSound snd_ambient_3;
	RLSound snd_cast;
	RLSound snd_dead;
	RLSound snd_door;
	RLSound snd_levelup;
	RLSound snd_shake;
	RLSound snd_melody;
}

// -----------------------------------------------------------------------------
// Globals
// -----------------------------------------------------------------------------

GameState game = { .menu = INTRO, .intro_hold = true, .last_move = UP };
ShakeState shake = { .timer = 5.0 };
Inventory inv = { .potions = { 1, 1 } };
Dungeon dungeon;
Assets assets;

Notification note;
Projectile magic_ball;
Entity[100] entities;
int num_entities;
Item[100] loot;
int num_loot;

// -----------------------------------------------------------------------------
// Asset Loading Helpers
// -----------------------------------------------------------------------------

fn RLTexture load_embedded_texture(char[] data, ZString ext)
{
	RLImage img = rl::load_image_from_memory(ext, data.ptr, (int)data.len);
	defer rl::unload_image(img);
	return rl::load_texture_from_image(img);
}

fn RLSound load_embedded_sound(char[] data, ZString ext)
{
	RLWave wave = rl::load_wave_from_memory(ext, data.ptr, (int)data.len);
	defer rl::unload_wave(wave);
	return rl::load_sound_from_wave(wave);
}

fn void load_all_assets()
{
	assets.fnt = rl::load_font("assets/alagard.fnt");
	RLImage img_sm = rl::load_image_from_memory(".png", (char*)&EMBED_FONT_SM, (int)EMBED_FONT_SM.len);
	defer rl::unload_image(img_sm);
	assets.fnt_sm = rl::load_font_from_image(img_sm, rl::MAGENTA, 32);

	$foreach $m : Assets::members:
		$switch $m.type:
			$case RLTexture:
				assets.$m = load_embedded_texture(&$eval("EMBED_" +++ @str_upper($m.name)), ".png");
			$case RLSound:
				assets.$m = load_embedded_sound(&$eval("EMBED_" +++ @str_upper($m.name)), ".ogg");
			$case RLRenderTexture2D:
				assets.$m = rl::load_render_texture(MAP_WIDTH * 8, MAP_HEIGHT * 8);
		$endswitch
	$endforeach
}

fn void unload_all_assets()
{
	$foreach $m : Assets::members:
		$switch $m.type:
			$case RLSound:
				rl::unload_sound(assets.$m);
			$case RLTexture:
				rl::unload_texture(assets.$m);
			$case RLFont:
				rl::unload_font(assets.$m);
			$case RLRenderTexture2D:
				rl::unload_render_texture(assets.$m);
		$endswitch
	$endforeach
}

// -----------------------------------------------------------------------------
// Utility and Drawing Helpers
// -----------------------------------------------------------------------------

fn int util_rand_range(int lhs, int rhs) => lhs + rand(rhs - lhs);

fn void draw_texture(
	RLTexture texture,
	float tx, float ty, float tw, float th,
	float dx, float dy, float dw, float dh,
	RLColor color = rl::WHITE
)
{
	rl::draw_texture_pro(
		texture,
		{ tx, ty, tw, th },
		{ dx, dy, dw, dh },
		{ 0, 0 },
		0,
		color
	);
}

fn void draw_icon(
	int tx, int ty,
	float dx, float dy,
	float dw = SCALE_8, float dh = SCALE_8,
	RLColor color = rl::WHITE
)
{
	draw_texture(assets.icons, tx * 8.0f, ty * 8.0f, 8, 8, dx, dy, dw, dh, color);
}

fn void add_note(String text, RLColor color, float cooldown)
{
	sz copy_len = math::min(text.len, (sz)64);
	note.buf[:copy_len] = text[:copy_len][..];
	note.len = copy_len;
	note.color = color;
	note.timer = cooldown;
}

fn void draw_text(int x, int y, String txt, RLColor color) => @pool()
{
	rl::draw_text_ex(assets.fnt, txt.zstr_tcopy(), { x, y }, 15 * SCALE, 1, color);
}

fn void draw_text_sm(int x, int y, String txt, RLColor color) => @pool()
{
	rl::draw_text_ex(assets.fnt_sm, txt.zstr_tcopy(), { x, y }, SCALE_8, 0, color);
}

fn void draw_text_sm_center(int x, int y, String txt, RLColor color) => @pool()
{
	int m = (int)rl::measure_text_ex(assets.fnt_sm, txt.zstr_tcopy(), SCALE_8, 0).x;
	draw_text_sm(x - m / 2, y, txt, color);
}

// -----------------------------------------------------------------------------
// UI Rendering
// -----------------------------------------------------------------------------

fn void draw_house()
{
	float x = (XRES_HALF - 110) * (float)SCALE;
	float y = YRES_HALF * (float)SCALE;
	float s = (float)SCALE;

	draw_texture(assets.gradient, 0, 0, 110, 26, x, y - 52 * s, 220 * s, 52 * s);
	draw_texture(assets.icons, 40, 0, 8, 8, x, y, 220 * s, 46 * s, SHARKGRAY);

	// Corners
	draw_texture(assets.icons, 0, 80, 8, 8, x - 8 * s, y - 60 * s, SCALE_8, SCALE_8, rl::GOLD);
	draw_texture(assets.icons, 40, 80, 8, 8, x + 220 * s, y - 60 * s, SCALE_8, SCALE_8, rl::GOLD);
	draw_texture(assets.icons, 48, 80, 8, 8, x - 8 * s, y + 46 * s, SCALE_8, SCALE_8, rl::GOLD);
	draw_texture(assets.icons, 56, 80, 8, 8, x + 220 * s, y + 46 * s, SCALE_8, SCALE_8, rl::GOLD);

	// Borders
	draw_texture(assets.icons, 8, 80, 8, 8, x, y - 60 * s, 220 * s, SCALE_8, rl::GOLD);
	draw_texture(assets.icons, 32, 80, 8, 8, x, y + 46 * s, 220 * s, SCALE_8, rl::GOLD);
	draw_texture(assets.icons, 24, 80, 8, 8, x - 8 * s, y - 52 * s, SCALE_8, 98 * s, rl::GOLD);
	draw_texture(assets.icons, 16, 80, 8, 8, x + 220 * s, y - 52 * s, SCALE_8, 98 * s, rl::GOLD);
}

fn void draw_modal_frame(String prompt)
{
	draw_house();
	int y = YRES_HALF;
	draw_icon(0, 0, (XRES_HALF - 40) * (float)SCALE, (float)(y - 30) * SCALE, SCALE_8 * 2.0f, SCALE_8 * 2.0f, { 0, 128, 255, 255 });
	draw_icon(0, 1, (XRES_HALF - 8) * (float)SCALE, (float)(y - 30) * SCALE, SCALE_8 * 2.0f, SCALE_8 * 2.0f, BITTERSWEET);
	draw_text_sm_center(XRES_HALF * SCALE, (y + 37) * SCALE, prompt, rl::GRAY);
}

fn void draw_intro()
{
	draw_modal_frame(PROMPT_START);
	int x = XRES_HALF - 110;
	int y = YRES_HALF;

	draw_text_sm((x + 7) * SCALE, (y + 4) * SCALE, "Dear", rl::WHITE);
	draw_text_sm((x + 30) * SCALE, (y + 4) * SCALE, "Adventurer", rl::BLUE);
	draw_text_sm((x + 81) * SCALE, (y + 4) * SCALE, ", your mother is gravely ill.", rl::WHITE);
	draw_text_sm((x + 7) * SCALE, (y + 14) * SCALE, "You must find the", rl::LIGHTGRAY);
	draw_text_sm((x + 87) * SCALE, (y + 14) * SCALE, "Tears of the Phoenix", CYAN);
	draw_text_sm((x + 186) * SCALE, (y + 14) * SCALE, "in the", rl::LIGHTGRAY);
	draw_text_sm((x + 7) * SCALE, (y + 24) * SCALE, "forbidden ruins to save her. Please hurry...", rl::GRAY);
}

fn void draw_controls()
{
	draw_modal_frame(PROMPT_START);
	int x = XRES_HALF - 110;
	int y = YRES_HALF;

	draw_text_sm((x + 7) * SCALE, (y + 4) * SCALE, "Controls:", rl::WHITE);
	draw_text_sm((x + 19) * SCALE, (y + 14) * SCALE, "Move: Arrow Keys", rl::WHITE);
	draw_text_sm((x + 14) * SCALE, (y + 24) * SCALE, "Attack: Bump", rl::WHITE);
	draw_text_sm((x + 121) * SCALE, (y + 4) * SCALE, "H: Heal Potion", rl::RED);
	draw_text_sm((x + 120) * SCALE, (y + 14) * SCALE, "M: Mana Potion", rl::GREEN);
	draw_text_sm((x + 121) * SCALE, (y + 24) * SCALE, "C: Cast Magic", rl::GREEN);
}

fn void draw_win()
{
	int y = YRES_HALF;
	game.t_win += 1.0 / 60.0;
	if (game.t_win < 0.50) return;

	draw_house();
	float t = (float)game.t_win;
	float xx = t * 10.0f;
	float alpha = math::max(0.0f, 255.0f * (1.0f - t / 10.0f));

	draw_icon(0, 0, (XRES_HALF - 40 + xx) * (float)SCALE, (float)(y - 30) * SCALE, SCALE_8 * 2.0f, SCALE_8 * 2.0f, { 0, 128, 255, (char)alpha });
	draw_text_sm_center(XRES_HALF * SCALE, (y + 10) * SCALE, "I'm almost there, please hold on...", CYAN);
	draw_text_sm_center(XRES_HALF * SCALE, (y + 37) * SCALE, PROMPT_END, rl::GRAY);
}

fn void draw_stat_bar(PipStyle style, int current, int max_val, int lvl, float x, float y)
{
	float ratio = (float)current / max_val;
	float inc = 1.0f / (lvl * 6.0f);
	float tot = 0;
	const float ICON_LG = SCALE_8 * 2.0f;

	for (int i = 0; i < lvl * 2; i++)
	{
		float px = x + i * ICON_LG;
		draw_icon(style.sprite_empty, 6, px, y, ICON_LG, ICON_LG, style.col_empty);
		tot += inc;
		if (ratio > tot) draw_icon(style.sprite_half, 6, px, y, ICON_LG, ICON_LG, style.col_half);
		tot += inc;
		if (ratio > tot) draw_icon(style.sprite_full, 6, px, y, ICON_LG, ICON_LG, style.col_full);
		tot += inc;
	}
	draw_text(
		(int)x,
		(int)(y - 14.0f * (float)SCALE),
		string::tformat("%s: %d/%d", style.label, current, max_val),
		style.col_text
	);
}

fn void ui_draw()
{
	const float ICON_LG = SCALE_8 * 2.0f;

	if (shake.active)
	{
		double dt = 1.0 / 60.0;
		dungeon.phoenix_frame += (dungeon.phoenix_frame > 1.0) ? dt * 1.50 : dt;
		if (dungeon.phoenix_frame > 8.0) dungeon.phoenix_frame = 8.0;

		shake.timer -= dt;
		if (shake.timer < 4.50 && !shake.sound_played)
		{
			rl::play_sound(assets.snd_shake);
			shake.sound_played = true;
			inv.tears = true;
			rl::play_sound(assets.snd_levelup);
			add_note("Found Phoenix Tears!", CYAN, 999.0f);
		}
		if (shake.sound_played)
		{
			shake.move_timer -= dt;
			if (shake.move_timer < 0)
			{
				shake.move_timer = 0.05;
				float an = (float)(rnd() * math::TAU);
				shake.x = math::cos(an) * 4.0f;
				shake.y = math::sin(an) * 4.0f;
			}
			if (shake.timer < 0)
			{
				shake.active = false;
				shake.x = 0;
				shake.y = 0;
				game.menu = WIN;
				rl::play_sound(assets.snd_melody);
				game.game_win = true;
				for (int eidx = 1; eidx < num_entities; eidx++)
				{
					entities[eidx].health = 0;
					entities[eidx].sprite = 39;
					entities[eidx].block_movement = false;
				}
			}
		}
	}

	float t_delta = 1.0f / 60.0f;
	int lvl = entities[0].level;
	draw_text(0, (YRES - 30) * SCALE, string::tformat("Level: %d", lvl), rl::DARKGRAY);
	draw_text(76 * SCALE, (YRES - 30) * SCALE, string::tformat("Pwr: %d", entities[0].power), rl::DARKGRAY);
	draw_text(144 * SCALE, (YRES - 30) * SCALE, string::tformat("Def: %d", entities[0].defense), rl::DARKGRAY);

	// Status icons
	if (inv.shield) draw_icon(0, 5, 208 * (float)SCALE, (YRES - 32) * (float)SCALE, ICON_LG, ICON_LG, { 128, 0, 255, 255 });
	if (inv.helmet) draw_icon(1, 5, 224 * (float)SCALE, (YRES - 32) * (float)SCALE, ICON_LG, ICON_LG, { 128, 0, 255, 255 });
	if (inv.mail)   draw_icon(2, 5, 240 * (float)SCALE, (YRES - 32) * (float)SCALE, ICON_LG, ICON_LG, { 128, 0, 255, 255 });
	if (inv.key)    draw_icon(7, 6, 256 * (float)SCALE, (YRES - 32) * (float)SCALE, ICON_LG, ICON_LG, { 255, 255, 0, 255 });
	if (inv.tears)  draw_icon(7, 7, 256 * (float)SCALE, (YRES - 32) * (float)SCALE, ICON_LG, ICON_LG, { 32, 192, 255, 255 });

	if (!game.game_win && !shake.active)
	{
		game.t_game = rl::get_time() - game.t_clock;
	}

	int m = (int)(game.t_game / 60.0);
	int s = (int)(game.t_game - m * 60.0);
	draw_text_sm(208 * SCALE, (YRES - 10) * SCALE, string::tformat("GameTime: %d:%02d", m, s), rl::GRAY);

	// Notifications
	if (note.timer > 0.0f)
	{
		note.timer -= t_delta;
		RLColor color = note.color;
		if (note.timer < 1.0f)
		{
			color = DARKDARKGRAY;
		}
		else if (note.timer < 2.0f)
		{
			color = rl::DARKGRAY;
		}
		draw_text(0, (YRES - 16) * SCALE, string::tformat("> %s", (String)note.buf[:note.len]), color);
	}
	else
	{
		draw_text(0, (YRES - 16) * SCALE, ">", DARKDARKGRAY);
	}

	// Health pips
	draw_stat_bar(HP_STYLE, entities[0].health, entities[0].max_health, lvl, (XRES_HALF - 16) * (float)SCALE, (YRES - 16) * (float)SCALE);
	draw_icon(3, 6, (XRES_HALF + 84) * (float)SCALE, (YRES - 32) * (float)SCALE, ICON_LG, ICON_LG, rl::RED);
	draw_text((XRES_HALF + 100) * SCALE, (YRES - 30) * SCALE, string::tformat("x%d", inv.potions[0]), rl::RED);
	draw_text((XRES_HALF + 68) * SCALE, (YRES - 30) * SCALE, "H:", rl::RED);

	// Mana pips
	if (inv.rod)
	{
		draw_stat_bar(MP_STYLE, entities[0].mana, entities[0].max_mana, lvl, (XRES_HALF + 150) * (float)SCALE, (YRES - 16) * (float)SCALE);
		draw_icon(2, 6, (XRES_HALF + 150 - 18) * (float)SCALE, (YRES - 32) * (float)SCALE, ICON_LG, ICON_LG, { 128, 255, 128, 255 });
		draw_icon(3, 6, (XRES_HALF + 252) * (float)SCALE, (YRES - 32) * (float)SCALE, ICON_LG, ICON_LG, rl::GREEN);
		draw_text((XRES_HALF + 268) * SCALE, (YRES - 30) * SCALE, string::tformat("x%d", inv.potions[1]), rl::GREEN);
		draw_text((XRES_HALF + 234) * SCALE, (YRES - 30) * SCALE, "M:", rl::GREEN);
		draw_text((XRES_HALF + 134) * SCALE, (YRES - 15) * SCALE, "C:", rl::GREEN);
	}

	switch (game.menu)
	{
		case INTRO:    draw_intro();
		case CONTROLS: draw_controls();
		case WIN:      draw_win();
		default:       break;
	}
}

// -----------------------------------------------------------------------------
// Entity Management and Combat
// -----------------------------------------------------------------------------

fn void entity_new(int x, int y, int sprite, int health, int level, int power, int defense, bool enemy)
{
	entities[num_entities++] = {
		.px = x,
		.py = y,
		.ix = x,
		.iy = y,
		.sprite = sprite,
		.block_movement = true,
		.health = health,
		.max_health = health,
		.defense = defense,
		.power = power,
		.level = level,
		.enemy = enemy,
		.state = WANDER,
		.skip_update = -1,
	};
}

fn void entity_draw_player()
{
	float x = entities[0].px;
	float y = entities[0].py;
	RLColor col = (entities[0].health > 0) ? { 0, 128, 255, 255 } : { 64, 64, 64, 255 };
	draw_icon(0, 0, x * SCALE_8, y * SCALE_8, color: col);
}

fn void step_to_zero(int* v)
{
	if (*v < 0)
	{
		(*v)++;
	}
	else if (*v > 0)
	{
		(*v)--;
	}
}

fn void entity_draw_all()
{
	float px = entities[0].px;
	float py = entities[0].py;
	if (entities[0].health == 0) entity_draw_player();

	for (int i = 1; i < num_entities; i++)
	{
		if (entities[i].skip_update < 0)
		{
			if (!dungeon.seen[entities[i].iy * MAP_WIDTH + entities[i].ix]) continue;

			float x = entities[i].px;
			float y = entities[i].py;
			if (entities[i].health > 0)
			{
				float dist = math::hypot(px - x, py - y);
				if (dist < 7.0f)
				{
					int sprite = entities[i].sprite;
					int tx = sprite % 8;
					int ty = sprite / 8;
					float ratio = math::min(1.0f, (float)entities[0].level / (entities[i].level + 2.0f) * 0.75f);
					RLColor col = { 48, 48, 48, 255 };
					if (dist < 5.0f)
					{
						col = { (char)(255.0f * (1.0f - ratio)), (char)(255.0f * ratio), 0, 255 };
					}
					draw_icon(tx, ty, x * SCALE_8 + shake.x, y * SCALE_8 + shake.y, color: col);
				}
				else
				{
					entities[i].skip_update = util_rand_range(5, 10);
				}
			}
			else
			{
				draw_icon(7, 4, x * SCALE_8 + shake.x, y * SCALE_8 + shake.y, color: DARKRED);
			}
		}
		else
		{
			entities[i].skip_update--;
		}

		step_to_zero(&entities[i].kx);
		step_to_zero(&entities[i].ky);
	}

	dungeon.t_flames += 1.0 / 60.0;
	for (int i = 0; i < dungeon.num_torches; i++)
	{
		int ix = dungeon.torches[i].x;
		int iy = dungeon.torches[i].y;
		if (ix == entities[0].ix && iy == entities[0].iy && entities[0].health > 0)
		{
			entities[0].health = 0;
			rl::play_sound(assets.snd_dead);
		}
		if (dungeon.seen[iy * MAP_WIDTH + ix])
		{
			int ofs = (int)(dungeon.t_flames * 12.0 + i) % 6;
			int tx  = (int)(dungeon.t_flames * 12.0 + i) % 7;
			draw_icon(tx, 7, ix * (float)SCALE_8 + shake.x, iy * (float)SCALE_8 + shake.y, color: FLAME_COLORS[ofs]);
		}
	}

	if (magic_ball.active)
	{
		draw_icon(6, 6, magic_ball.p.x * SCALE_8 + shake.x, magic_ball.p.y * SCALE_8 + shake.y, color: MAGIC_COLORS[util_rand_range(0, 5)]);
	}

	if (entities[0].health > 0) entity_draw_player();
}

fn void damage_monster(int target_idx, int dmg)
{
	entities[target_idx].health = math::max(0, entities[target_idx].health - dmg);
	add_note(string::tformat("Hit Beast for %d dmg!", dmg), rl::GRAY, 5.0f);
	entities[0].cooldown = 0.30f;
	rl::play_sound(assets.snd_attack);
	if (entities[target_idx].health == 0)
	{
		entities[target_idx].sprite = 39;
		entities[target_idx].block_movement = false;
		add_note("Beast fell!", rl::LIGHTGRAY, 5.0f);
	}
}

fn void entity_move(int eidx, Direction move_dir)
{
	int ix  = entities[eidx].ix;
	int iy  = entities[eidx].iy;
	int idx = iy * MAP_WIDTH + ix;

	switch (move_dir)
	{
		case UP:    if (iy > 0 && dungeon.board[idx - MAP_WIDTH] < 3) iy--;
		case DOWN:  if (iy < MAP_HEIGHT - 1 && dungeon.board[idx + MAP_WIDTH] < 3) iy++;
		case LEFT:  if (ix > 0 && dungeon.board[idx - 1] < 3) ix--;
		case RIGHT: if (ix < MAP_WIDTH - 1 && dungeon.board[idx + 1] < 3) ix++;
		default:    break;
	}

	int new_idx = iy * MAP_WIDTH + ix;
	if (eidx == 0 && idx != new_idx && dungeon.board[new_idx] == 1)
	{
		if (inv.key)
		{
			inv.key = false;
			add_note("Unlocked!", rl::YELLOW, 5.0f);
			dungeon.board[new_idx] = 2;
			rl::play_sound(assets.snd_door);
		}
		else
		{
			add_note("Locked!", rl::ORANGE, 5.0f);
			new_idx = idx;
		}
	}

	if (idx != new_idx)
	{
		for (int i = 1; i < num_entities; i++)
		{
			if (entities[i].skip_update < 0 && entities[i].block_movement
				&& new_idx == entities[i].iy * MAP_WIDTH + entities[i].ix)
			{
				if (eidx == 0 && entities[eidx].cooldown < 0)
				{
					entities[0].kx = (ix - entities[eidx].ix) * 8;
					entities[0].ky = (iy - entities[eidx].iy) * 8;
					damage_monster(i, 1);
				}
				ix = entities[eidx].ix;
				iy = entities[eidx].iy;
				break;
			}
		}

		entities[eidx].ix = ix;
		entities[eidx].iy = iy;

		if (eidx == 0 && iy * MAP_WIDTH + ix == dungeon.win_idx)
		{
			shake.active = true;
			rl::play_sound(assets.snd_cast);
		}
	}
	else if (eidx == 0 && note.timer < 0.10f)
	{
		add_note("Blocked!", rl::BROWN, 3.0f);
	}
}

fn void entity_spawn_monster(int x, int y, int lvl)
{
	int mx = math::clamp(lvl * 23 / 5, 4, 23);
	int sprite = 16 + util_rand_range(0, mx);
	entity_new(
		x,
		y,
		sprite,
		(int)(1.0 + (1.0 + rnd()) * lvl),
		lvl,
		(int)math::ceil((0.20 + rnd() * 0.50) * lvl),
		(int)math::ceil((0.20 + rnd() * 0.50) * lvl),
		true
	);
}

fn void entity_update(int eidx, float t_delta)
{
	float fps = 1.0f / t_delta;
	if (fps < 10.0f)
	{
		entities[eidx].px = entities[eidx].ix;
		entities[eidx].py = entities[eidx].iy;
		game.key_delay = 0;
	}

	float dx = entities[eidx].ix - entities[eidx].px;
	entities[eidx].px = (math::abs(dx) > 0.10f) ? entities[eidx].px + dx * 0.50f : entities[eidx].ix;

	float dy = entities[eidx].iy - entities[eidx].py;
	entities[eidx].py = (math::abs(dy) > 0.10f) ? entities[eidx].py + dy * 0.50f : entities[eidx].iy;

	entities[eidx].cooldown -= t_delta;
}

fn void restart_game()
{
	game = {
		.menu = GAME,
		.intro_hold = false,
		.last_move = UP,
		.t_clock = rl::get_time(),
	};
	shake = { .timer = 5.0 };
	inv = { .potions = { 1, 1 } };
	dungeon.phoenix_frame = 0;
	note = {};
	magic_ball = {};
	while (!gen_rooms()) {}
	map_update_visibility();
	rl::play_sound(assets.snd_melody);
}

fn void entity_update_all()
{
	if (game.intro_hold) return;

	float t_delta = 1.0f / 60.0f;
	entity_update(0, t_delta);

	if (entities[0].health <= 0)
	{
		if (game.death_timer == 0.0f)
		{
			add_note("YOU DIED!", rl::RED, 3.0f);
		}
		game.death_timer += t_delta;
		if (game.death_timer >= 3.0f)
		{
			restart_game();
			return;
		}
	}

	if (shake.active) return;

	if (entities[0].health > 0 && entities[0].health < (int)(entities[0].max_health * 0.31f) && !shake.active && !game.game_win)
	{
		game.blip_timer -= t_delta;
		if (game.blip_timer < 0)
		{
			game.blip_timer = 1.00f;
			rl::play_sound(assets.snd_blip);
		}
	}

	if (magic_ball.active)
	{
		magic_ball.p += magic_ball.v * t_delta;
		int[<2>] p = (int[<2>])(magic_ball.p + 0.5f);
		int idx = p.y * MAP_WIDTH + p.x;
		if (dungeon.board[idx] != -1)
		{
			magic_ball.active = false;
		}
	}

	if (!game.game_win && !shake.active)
	{
		game.ambient_timer -= t_delta;
		if (game.ambient_timer < 0)
		{
			game.ambient_timer = 4.0f + 4.0f * (float)rnd();
			switch (util_rand_range(0, 3))
			{
				case 0: rl::play_sound(assets.snd_ambient_1);
				case 1: rl::play_sound(assets.snd_ambient_2);
				case 2: rl::play_sound(assets.snd_ambient_3);
			}
		}
	}

	for (int i = 1; i < num_entities; i++)
	{
		if (entities[i].health > 0 && magic_ball.active)
		{
			if (math::hypot(entities[i].px - magic_ball.p.x, entities[i].py - magic_ball.p.y) < 0.50f)
			{
				damage_monster(i, 2 * entities[0].level);
			}
		}

		if (entities[i].health > 0 && entities[i].skip_update < 0 && entities[i].cooldown < 0)
		{
			if (game.amort == i % 4)
			{
				float dx   = entities[0].px - entities[i].px;
				float dy   = entities[0].py - entities[i].py;
				float dist = math::hypot(dx, dy);

				if (entities[i].state == WANDER && dist < 5.00f)
				{
					entities[i].state = CHASE;
				}
				else if (entities[i].state == CHASE && dist > 7.0f)
				{
					entities[i].state = WANDER;
				}

				if (dist < 1.20f && rnd() < 0.50 && entities[0].health > 0)
				{
					add_note("Beast hit for 1 dmg!", rl::RED, 5.0f);
					entities[i].cooldown = 0.70f;
					entities[i].ix = (int)entities[i].px;
					entities[i].iy = (int)entities[i].py;
					entities[i].kx = (int)dx * 8;
					entities[i].ky = (int)dy * 8;
					entities[0].health = math::max(0, entities[0].health - 1);
					rl::play_sound(assets.snd_hurt);
					if (entities[0].health == 0)
					{
						rl::play_sound(assets.snd_dead);
					}
				}

				if (entities[i].state == WANDER && rnd() < 0.10)
				{
					switch (util_rand_range(0, 4))
					{
						case 0: entity_move(i, UP);
						case 1: entity_move(i, DOWN);
						case 2: entity_move(i, LEFT);
						case 3: entity_move(i, RIGHT);
					}
				}
				else if (entities[i].state == CHASE && rnd() < 0.10)
				{
					if (math::abs(dx) > math::abs(dy))
					{
						entity_move(i, (entities[i].px < entities[0].px) ? RIGHT : LEFT);
					}
					else
					{
						entity_move(i, (entities[i].py < entities[0].py) ? DOWN : UP);
					}
				}
			}
		}
		entity_update(i, t_delta);
	}
}

// -----------------------------------------------------------------------------
// Dungeon Generation
// -----------------------------------------------------------------------------

fn bool check_room_plot(int x, int y, int w, int h)
{
	if (x < 0 || y < 0 || x + w > MAP_WIDTH - 1 || y + h > MAP_HEIGHT - 1) return false;
	for (int yy = 0; yy < h; yy++)
	{
		for (int xx = 0; xx < w; xx++)
		{
			if (dungeon.board[(yy + y) * MAP_WIDTH + xx + x] != -1) return false;
		}
	}
	return true;
}

fn void gen_room_plot(int x, int y, int w, int h)
{
	for (int yy = 0; yy < h; yy++)
	{
		for (int xx = 0; xx < w; xx++)
		{
			dungeon.board[(yy + y) * MAP_WIDTH + xx + x] = (yy == 0 || xx == 0) ? 6 : 4;
		}
	}
	dungeon.rooms[dungeon.num_rooms++] = {
		.x = x,
		.y = y,
		.w = w,
		.h = h,
		.cx = x + w / 2,
		.cy = y + h / 2,
	};
}

fn void gen_hallway(int r0_in, int r1_in)
{
	int r0 = r0_in;
	int r1 = r1_in;
	if (dungeon.rooms[r1].cy < dungeon.rooms[r0].cy)
	{
		r0 = r1_in;
		r1 = r0_in;
	}
	int y0 = dungeon.rooms[r0].cy;
	int y1 = dungeon.rooms[r1].cy;

	if (dungeon.rooms[r0].cx < dungeon.rooms[r1].x)
	{
		int x0 = dungeon.rooms[r0].cx;
		int x1 = dungeon.rooms[r1].cx;
		if (rnd() < 0.50)
		{
			for (int x = x0; x <= x1; x++) dungeon.board[y0 * MAP_WIDTH + x] = 4;
			for (int y = y0; y <= y1; y++) dungeon.board[y * MAP_WIDTH + x1] = 4;
		}
		else
		{
			for (int y = y0; y <= y1; y++) dungeon.board[y * MAP_WIDTH + x0] = 4;
			for (int x = x0; x <= x1; x++) dungeon.board[y1 * MAP_WIDTH + x] = 4;
		}
	}
	else
	{
		int x0 = dungeon.rooms[r1].cx;
		int x1 = dungeon.rooms[r0].cx;
		if (rnd() < 0.50)
		{
			for (int x = x0; x <= x1; x++) dungeon.board[y0 * MAP_WIDTH + x] = 4;
			for (int y = y0; y <= y1; y++) dungeon.board[y * MAP_WIDTH + x0] = 4;
		}
		else
		{
			for (int y = y0; y <= y1; y++) dungeon.board[y * MAP_WIDTH + x1] = 4;
			for (int x = x0; x <= x1; x++) dungeon.board[y1 * MAP_WIDTH + x] = 4;
		}
	}
}

fn void update_dist(int idx)
{
	if (dungeon.dist[idx] != -1) return;
	int x = idx % MAP_WIDTH;
	int y = idx / MAP_WIDTH;
	if (x < 1 || y < 1 || x > MAP_WIDTH - 2 || y > MAP_HEIGHT - 2) return;

	int d = math::max(
		dungeon.dist[idx - MAP_WIDTH],
		dungeon.dist[idx + MAP_WIDTH],
		dungeon.dist[idx - 1],
		dungeon.dist[idx + 1]
	);
	if (d > -1)
	{
		dungeon.dist2[idx] = d + 1;
	}
	dungeon.keep_going = true;
}

fn int place_key_in_region(int min_x, int max_x, int min_y, int max_y, bool[MAP_SZ]* taken)
{
	int key_idx = 0;
	int max_d = -1;
	for (int y = min_y; y < max_y; y++)
	{
		for (int x = min_x; x < max_x; x++)
		{
			int idx = y * MAP_WIDTH + x;
			int d = dungeon.dist[idx];
			if (d > max_d)
			{
				max_d = d;
				key_idx = idx;
				(*taken)[idx] = true;
			}
		}
	}
	item_new(key_idx % MAP_WIDTH, key_idx / MAP_WIDTH, KEY);
	return key_idx;
}

fn void render_map_textures()
{
	rl::@texture_mode(assets.ground_tex)
	{
		rl::clear_background(rl::BLACK);
		for (int yi = 0; yi < MAP_HEIGHT; yi++)
		{
			for (int xi = 0; xi < MAP_WIDTH; xi++)
			{
				int idx = yi * MAP_WIDTH + xi;
				int t = dungeon.board[idx];
				if (t < 0) continue;

				int r = 96;
				int g = 96;
				int b = 96;
				if (t == 3)
				{
					r = 64; g = 48; b = 32;
				}
				else if (t == 1)
				{
					r = 192; g = 127; b = 32;
				}
				if (xi < 26 && yi < 19) r = 0;
				if (xi > 49)
				{
					r = (int)(r * 1.20f);
					g = (int)(g * 1.20f);
					b = (int)(b * 1.20f);
					if (yi > 18) { r = 230; g = 230; b = 230; }
				}
				draw_icon(t % 8, t / 8, xi * 8.0f, yi * 8.0f, 8, 8, { (char)(r / 3), (char)(g / 3), (char)(b / 3), 255 });
			}
		}
	};

	rl::@texture_mode(assets.ceiling_tex)
	{
		rl::clear_background(rl::BLANK);
		for (int yi = 0; yi < MAP_HEIGHT; yi++)
		{
			for (int xi = 0; xi < MAP_WIDTH; xi++)
			{
				int idx = yi * MAP_WIDTH + xi;
				int t = dungeon.board3[idx];
				if (t < 0) continue;

				int tx = t % 8;
				int ty = t / 8;
				int r = 32; int g = 21; int b = 42;
				if (xi < 26 && yi < 19)
				{
					g = 42; b = 32; r = 21;
					tx = 6 + (xi + yi) % 2;
					ty = (xi + yi) % 2;
				}
				if (xi > 49) r = (int)(r * 0.30f);
				draw_icon(tx, ty, xi * 8.0f + 4.0f, yi * 8.0f + 2.0f, 8, 8, { (char)r, (char)g, (char)b, 255 });
			}
		}
	};

	rl::@texture_mode(assets.pre_game_tex)
	{
		rl::clear_background(rl::BLANK);
		for (int yi = 0; yi < MAP_HEIGHT; yi++)
		{
			for (int xi = 0; xi < MAP_WIDTH; xi++)
			{
				int r = (int)(255.0f * ((float)yi / MAP_HEIGHT) * 0.10f);
				int b = (int)(255.0f * (1.0f - (float)yi / MAP_HEIGHT) * 0.30f);
				int g = (int)(b * 0.70f);
				draw_icon(5, 1, xi * 8.0f, yi * 8.0f, 8, 8, { (char)r, (char)g, (char)b, 255 });
			}
		}
	};
}

struct ItemSpawn
{
	int bx;
	int by;
	int count;
	ItemKind kind;
}

fn bool gen_rooms()
{
	io::printn("Generating Rooms");

	dungeon.board[..]  = -1;
	dungeon.board3[..] = -1;
	dungeon.dist[..]   = -1;
	dungeon.dist2[..]  = -1;
	dungeon.seen[..]   = false;
	dungeon.known[..]  = false;

	dungeon.num_rooms   = 0;
	dungeon.num_torches = 0;
	num_loot            = 0;
	num_entities        = 0;

	int w3 = MAP_WIDTH / 3;
	int h2 = MAP_HEIGHT / 2;

	int[<2>][6] regions = { { 0, 0 }, { 0, 1 }, { 1, 1 }, { 1, 0 }, { 2, 0 }, { 2, 1 } };
	foreach (reg : regions)
	{
		int xx = reg.x;
		int yy = reg.y;
		for (int k = 0; k < 200; k++)
		{
			int w = util_rand_range(4, 8);
			int h = util_rand_range(4, 6);
			int x = util_rand_range(xx * w3, (xx + 1) * w3 - w + 1);
			int y = util_rand_range(yy * h2, (yy + 1) * h2 - h + 1);
			if (check_room_plot(x, y, w, h))
			{
				gen_room_plot(x, y, w, h);
			}
		}
	}

	bool[MAP_SZ] taken;

	int pw = 6;
	int ph = 6;
	int py = MAP_HEIGHT - 7;
	int px = 54 + util_rand_range(0, 15);
	dungeon.phoenix_loc = (py + 2) * MAP_WIDTH + px + 2;
	gen_room_plot(px, py, pw, ph);
	for (int yy = 0; yy < ph; yy++)
	{
		for (int xx = 0; xx < pw; xx++)
		{
			taken[(py + yy) * MAP_WIDTH + px + xx] = true;
		}
	}

	for (int i = 0; i < MAP_SZ; i++)
	{
		if (dungeon.board[i] == -1) dungeon.board[i] = 6;
	}

	for (int i = 0; i < dungeon.num_rooms - 1; i++)
	{
		gen_hallway(i, i + 1);
	}

	int[MAP_SZ] board_pass;
	for (int i = 0; i < MAP_SZ; i++)
	{
		int val = dungeon.board[i];
		if (val == 4)
		{
			val = -1;
		}
		else if (val == -1)
		{
			val = 3;
		}
		dungeon.board[i] = val;
		board_pass[i] = val;
	}

	for (int xi = 0; xi < MAP_WIDTH; xi++)
	{
		int idx = 18 * MAP_WIDTH + xi;
		if (dungeon.board[idx] == -1)
		{
			board_pass[idx] = 1;
		}
	}

	for (int yi = 0; yi < MAP_HEIGHT - 1; yi++)
	{
		for (int xi = 0; xi < MAP_WIDTH - 1; xi++)
		{
			int idx = yi * MAP_WIDTH + xi;
			if (dungeon.board[idx] == 6 && dungeon.board[idx + 1] == 6 && dungeon.board[idx + MAP_WIDTH] == 6 && dungeon.board[idx + MAP_WIDTH + 1] == 6)
			{
				dungeon.board3[idx] = 13;
			}
		}
	}

	for (int yi = 0; yi < MAP_HEIGHT; yi++)
	{
		for (int xi = 0; xi < MAP_WIDTH; xi++)
		{
			int idx = yi * MAP_WIDTH + xi;
			if (dungeon.board[idx] != 6) continue;

			bool left  = xi > 0 && dungeon.board[idx - 1] == 6;
			bool up    = yi > 0 && dungeon.board[idx - MAP_WIDTH] == 6;
			bool right = xi < MAP_WIDTH - 1 && dungeon.board[idx + 1] == 6;
			bool down  = yi < MAP_HEIGHT - 1 && dungeon.board[idx + MAP_WIDTH] == 6;

			int xx = (up ? 1 : 0) | (down ? 2 : 0) | (left ? 4 : 0);
			int yy = 8 + (right ? 1 : 0);
			board_pass[idx] = yy * 8 + xx;
		}
	}

	dungeon.board = board_pass;

	for (int yi = 0; yi < MAP_HEIGHT; yi++)
	{
		for (int xi = 0; xi < MAP_WIDTH; xi++)
		{
			int idx = yi * MAP_WIDTH + xi;
			if (xi > 0 && xi < MAP_WIDTH - 1)
			{
				if (((dungeon.board[idx - 1] == 77 && dungeon.board[idx] == 77 && dungeon.board[idx + 1] == 77) ||
					 (dungeon.board[idx - 1] == 78 && dungeon.board[idx] == 78 && dungeon.board[idx + 1] == 78)) && rnd() < 0.80)
				{
					dungeon.board[idx] = 76;
				}
			}
			if (yi > 0 && yi < MAP_HEIGHT - 1)
			{
				if (((dungeon.board[idx - MAP_WIDTH] == 71 && dungeon.board[idx] == 71 && dungeon.board[idx + MAP_WIDTH] == 71) ||
					 (dungeon.board[idx - MAP_WIDTH] == 75 && dungeon.board[idx] == 75 && dungeon.board[idx + MAP_WIDTH] == 75)) && rnd() < 0.80)
				{
					dungeon.board[idx] = 67;
				}
			}
		}
	}

	for (int i = 0; i < MAP_SZ; i++)
	{
		if (dungeon.board[i] == 1)
		{
			dungeon.dist[i] = 0;
		}
		else if (dungeon.board[i] != -1)
		{
			dungeon.dist[i] = -2;
		}
	}

	int min_dist_sq = int::max;
	for (int yi = 0; yi < 13; yi++)
	{
		for (int xi = 0; xi < 13; xi++)
		{
			int idx = yi * MAP_WIDTH + xi;
			if (dungeon.board[idx] != -1) continue;
			int d_sq = xi * xi + yi * yi;
			if (d_sq < min_dist_sq)
			{
				min_dist_sq = d_sq;
				dungeon.start_idx = idx;
			}
		}
	}

	dungeon.win_idx = dungeon.phoenix_loc + 1 + 2 * MAP_WIDTH;
	dungeon.dist[dungeon.start_idx] = 1;
	dungeon.dist2 = dungeon.dist;

	int cc = 0;
	while (true)
	{
		dungeon.keep_going = false;
		for (int i = 0; i < MAP_SZ; i++)
		{
			update_dist(i);
		}
		dungeon.dist = dungeon.dist2;
		if (!dungeon.keep_going) break;
		if (++cc > 1000) return false;
	}

	// Phoenix room altar clearing
	int altar_x = dungeon.phoenix_loc % MAP_WIDTH;
	int altar_y = dungeon.phoenix_loc / MAP_WIDTH;
	for (int yy = 0; yy < 3; yy++)
	{
		for (int xx = 0; xx < 3; xx++)
		{
			if (xx == 1 && yy == 2) continue;
			dungeon.board[(altar_y + yy) * MAP_WIDTH + altar_x + xx] = 4;
		}
	}

	// Place 3 keys
	place_key_in_region(0, 25, 0, 18, &taken);
	place_key_in_region(0, 50, 18, 36, &taken);
	place_key_in_region(25, 75, 0, 18, &taken);

	// Place torches
	for (int yy = 0; yy < 2; yy++)
	{
		for (int xx = 0; xx < 3; xx++)
		{
			int mx = 1 + (xx > 0 ? 1 : 0) + (xx > 0 && yy == 0 ? 1 : 0) + (xx > 1 ? 1 : 0);
			for (int k = 0; k < mx; k++)
			{
				int attempts = 0;
				while (++attempts < 1000)
				{
					int tx = util_rand_range(1, 25) + xx * 25;
					int ty = util_rand_range(1, 18) + yy * 18;
					int idx = ty * MAP_WIDTH + tx;
					if (dungeon.board[idx] != -1 || taken[idx]) continue;

					bool pass = true;
					for (int dy = -1; dy <= 1; dy++)
					{
						for (int dx = -1; dx <= 1; dx++)
						{
							int nidx = idx + dy * MAP_WIDTH + dx;
							if (dungeon.board[nidx] != -1 || taken[nidx])
							{
								pass = false;
								break;
							}
						}
						if (!pass) break;
					}

					if (pass)
					{
						taken[idx] = true;
						dungeon.torches[dungeon.num_torches++] = { tx, ty };
						break;
					}
				}
			}
		}
	}

	// Place items
	ItemSpawn[*] item_spawns = {
		{ 0,  0, 1, HEART },
		{ 25, 0, 1, HEART },
		{ 50, 0, 1, HEART },
		{ 0, 18, 1, SHIELD },
		{ 25, 0, 1, HELMET },
		{ 50, 0, 1, MAIL },
		{ 25, 18, 1, ROD },
		{ 0, 18, 1, FOOD },
		{ 25, 18, 1, FOOD },
		{ 50, 18, 1, FOOD },
		{ 0,  0, 1, POTION_HEALTH },
		{ 0, 18, 2, POTION_HEALTH },
		{ 25, 18, 2, POTION_HEALTH },
		{ 25, 0, 2, POTION_HEALTH },
		{ 50, 0, 2, POTION_HEALTH },
		{ 50, 18, 1, POTION_HEALTH },
		{ 0, 18, 2, POTION_MANA },
		{ 25, 0, 2, POTION_MANA },
	};

	foreach (spawn : item_spawns)
	{
		for (int k = 0; k < spawn.count; k++)
		{
			while (true)
			{
				int x = util_rand_range(0, 25) + spawn.bx;
				int y = util_rand_range(0, 18) + spawn.by;
				int idx = y * MAP_WIDTH + x;
				if (dungeon.board[idx] == -1 && !taken[idx])
				{
					taken[idx] = true;
					item_new(x, y, spawn.kind);
					break;
				}
			}
		}
	}

	// Spawn player
	int start_x = dungeon.start_idx % MAP_WIDTH;
	int start_y = dungeon.start_idx / MAP_WIDTH;
	entity_new(start_x, start_y, 0, 10, 1, 1, 1, false);
	entities[0].mana = 5;
	entities[0].max_mana = 5;

	// Spawn monsters
	for (int i = 0; i < 75; i++)
	{
		int attempts = 0;
		while (++attempts < 1000)
		{
			int x = util_rand_range(0, MAP_WIDTH);
			int y = util_rand_range(0, MAP_HEIGHT);
			float dist_to_player = math::hypot((float)(x - start_x), (float)(y - start_y));
			if (dist_to_player < 8.0f) continue;
			if (dist_to_player < 15.0f && rnd() < 0.50) continue;
			if (x < 25 && rnd() < 0.30) continue;
			if (x < 50 && rnd() < 0.30) continue;

			int idx = y * MAP_WIDTH + x;
			if (dungeon.board[idx] != -1 || taken[idx]) continue;

			taken[idx] = true;
			int lvl = (int)(dist_to_player / (float)MAP_WIDTH) * 4 + util_rand_range(0, 3);
			entity_spawn_monster(x, y, lvl);
			break;
		}
	}

	render_map_textures();
	return true;
}

// -----------------------------------------------------------------------------
// Map Visibility
// -----------------------------------------------------------------------------

fn void map_update_visibility()
{
	float px = entities[0].ix;
	float py = entities[0].iy;
	float w  = 0.30f;

	for (int i = 0; i < 45; i++)
	{
		float an = math::deg_to_rad(i * 8.0f);
		float dx = math::cos(an);
		float dy = math::sin(an);

		for (int jj = 0; jj < 20; jj++)
		{
			float j = 0.50f + 0.35f * (float)jj;
			float rx = px + dx * j;
			float ry = py + dy * j;

			IntVec2[4] corners = {
				{ (int)(rx - w), (int)(ry - w) },
				{ (int)(rx - w), (int)(ry + w) },
				{ (int)(rx + w), (int)(ry + w) },
				{ (int)(rx + w), (int)(ry - w) },
			};

			int c = 0;
			foreach (pt : corners)
			{
				if (pt.x >= 0 && pt.y >= 0 && pt.x < MAP_WIDTH && pt.y < MAP_HEIGHT)
				{
					if (dungeon.board[pt.y * MAP_WIDTH + pt.x] == -1) c++;
				}
			}

			int ix  = (int)rx;
			int iy  = (int)ry;
			dungeon.seen[iy * MAP_WIDTH + ix] = true;
			if (c == 0) break;
		}
	}
}

// -----------------------------------------------------------------------------
// Item Management and Drawing
// -----------------------------------------------------------------------------

fn void item_new(int x, int y, ItemKind kind)
{
	loot[num_loot++] = {
		.ix = x,
		.iy = y,
		.kind = kind,
		.found = false,
	};
}

fn void item_draw_all()
{
	for (int i = 0; i < num_loot; i++)
	{
		if (loot[i].found) continue;

		int sprite = loot[i].kind.sprite;
		int tx     = sprite % 8;
		int ty     = sprite / 8;
		int x      = loot[i].ix;
		int y      = loot[i].iy;
		if (!dungeon.seen[y * MAP_WIDTH + x]) continue;

		float dist = math::hypot(entities[0].px - x, entities[0].py - y);

		if (dist < 7.0f)
		{
			RLColor col = (dist < 5.0f) ? loot[i].kind.color : DARKDARKGRAY;
			draw_icon(tx, ty, x * (float)SCALE_8 + shake.x, y * (float)SCALE_8 + shake.y, color: col);
		}

		if (x == entities[0].ix && y == entities[0].iy)
		{
			String found_text = string::tformat("Found %s!", loot[i].kind.name);
			switch (loot[i].kind)
			{
				case POTION_HEALTH:
					if (inv.potions[0] == 9) continue;
					inv.potions[0]++;
					add_note(found_text, rl::RED, 5.0f);
					rl::play_sound(assets.snd_pickup);
				case POTION_MANA:
					if (inv.potions[1] == 9) continue;
					inv.potions[1]++;
					add_note(found_text, rl::GREEN, 5.0f);
					rl::play_sound(assets.snd_pickup);
				case FOOD:
					entities[0].power++;
					add_note(found_text, rl::ORANGE, 5.0f);
					rl::play_sound(assets.snd_pickup);
				case SHIELD:
					entities[0].defense++;
					inv.shield = true;
					add_note(found_text, rl::VIOLET, 5.0f);
					rl::play_sound(assets.snd_pickup);
				case MAIL:
					entities[0].defense++;
					inv.mail = true;
					add_note(found_text, rl::VIOLET, 5.0f);
					rl::play_sound(assets.snd_pickup);
				case HELMET:
					entities[0].defense++;
					inv.helmet = true;
					add_note(found_text, rl::VIOLET, 5.0f);
					rl::play_sound(assets.snd_pickup);
				case KEY:
					inv.key = true;
					add_note(found_text, rl::GOLD, 5.0f);
					rl::play_sound(assets.snd_pickup);
				case ROD:
					inv.rod = true;
					add_note(found_text, rl::GREEN, 5.0f);
					rl::play_sound(assets.snd_cast);
				case HEART:
					add_note("LEVEL UP!", rl::PURPLE, 5.0f);
					entities[0].level++;
					entities[0].max_health = (int)(entities[0].max_health * (1.30f + 0.30f * (float)rnd()));
					entities[0].max_mana++;
					entities[0].health = entities[0].max_health;
					entities[0].mana = entities[0].max_mana;
					rl::play_sound(assets.snd_levelup);
			}
			loot[i].found = true;
		}
	}
}

// -----------------------------------------------------------------------------
// Map Rendering
// -----------------------------------------------------------------------------

fn void draw_map()
{
	draw_texture(assets.ground_tex.texture, 0, 0, MAP_WIDTH * 8.0f, -MAP_HEIGHT * 8.0f, shake.x, shake.y, MAP_WIDTH * (float)SCALE_8, MAP_HEIGHT * (float)SCALE_8);

	// Phoenix reveal animation
	int px = dungeon.phoenix_loc % MAP_WIDTH;
	int py = dungeon.phoenix_loc / MAP_WIDTH;
	int frame = math::min((int)dungeon.phoenix_frame, 6);
	int tx = frame % 4;
	int ty = frame / 4;
	draw_texture(assets.reveal, tx * 24.0f, ty * 24.0f, 24, 24, px * (float)SCALE_8, py * (float)SCALE_8, SCALE * 24.0f, SCALE * 24.0f);

	int ix = entities[0].ix;
	int iy = entities[0].iy;

	// Ground light circle around player
	for (int yi = 0; yi < 15; yi++)
	{
		for (int xi = 0; xi < 15; xi++)
		{
			IntVec2 d = { xi - 6, yi - 6 };
			int dist_sq = d.dot(d);
			if (dist_sq > 36) continue;

			int xx = ix + d.x;
			int yy = iy + d.y;
			if (xx < 0 || xx >= MAP_WIDTH || yy < 0 || yy >= MAP_HEIGHT) continue;

			int idx = yy * MAP_WIDTH + xx;
			if (dist_sq < 9) dungeon.known[idx] = true;
			if (!dungeon.seen[idx]) continue;

			float mag = 1.0f - math::min(1.0f, math::sqrt((float)dist_sq) / 6.0f);
			int t0 = dungeon.board[idx];
			if (t0 <= 0 || t0 == 4) continue;

			int tile_x = t0 % 8;
			int tile_y = t0 / 8;
			int r = 96;
			int g = 96;
			int b = 96;
			if (t0 == 3)
			{
				r = 64; g = 48; b = 32;
			}
			else if (t0 == 1)
			{
				r = 192; g = 127; b = 32;
			}

			r = math::min(255, 64 + r);
			g = math::min(255, 32 + g);

			if (xx < 26 && yy < 19) r = 0;
			if (xx > 49)
			{
				r = (int)(r * 1.20f);
				g = (int)(g * 1.20f);
				b = (int)(b * 1.20f);
				if (yy > 18) { r = 242; g = 242; b = 242; }
			}

			float rr = 0.33f + 0.66f * mag;
			draw_icon(tile_x, tile_y, xx * (float)SCALE_8 + shake.x, yy * (float)SCALE_8 + shake.y, color: { (char)(r * rr), (char)(g * rr), (char)(b * rr), 255 });
		}
	}

	// Torch light circles
	for (int i = 0; i < dungeon.num_torches; i++)
	{
		int torch_x = dungeon.torches[i].x;
		int torch_y = dungeon.torches[i].y;

		for (int yi = 0; yi < 7; yi++)
		{
			for (int xi = 0; xi < 7; xi++)
			{
				IntVec2 d = { xi - 3, yi - 3 };
				int delta = d.dot(d);
				int xx = torch_x + d.x;
				int yy = torch_y + d.y;
				if (xx < 0 || yy < 0 || xx >= MAP_WIDTH || yy >= MAP_HEIGHT) continue;

				int idx = yy * MAP_WIDTH + xx;
				if (!dungeon.seen[idx]) continue;

				int t = dungeon.board[idx];
				if (t < 0 || t == 4) continue;

				int tile_x = t % 8;
				int tile_y = t / 8;
				float ratio = math::clamp(1.0f - math::sqrt((float)delta) / 3.0f, 0.0f, 1.0f);
				int g = (int)(128.0 + rnd() * 127.0);

				draw_icon(tile_x, tile_y, xx * (float)SCALE_8 + shake.x, yy * (float)SCALE_8 + shake.y, color: { 255, (char)g, 0, (char)(ratio * 255.0f) });
			}
		}
	}

	draw_texture(assets.ceiling_tex.texture, 0, 0, MAP_WIDTH * 8.0f, -MAP_HEIGHT * 8.0f, shake.x, shake.y, MAP_WIDTH * (float)SCALE_8, MAP_HEIGHT * (float)SCALE_8);

	// Ceiling light circle around player
	for (int yi = 0; yi < 15; yi++)
	{
		for (int xi = 0; xi < 15; xi++)
		{
			IntVec2 d = { xi - 6, yi - 6 };
			int dist_sq = d.dot(d);
			if (dist_sq > 36) continue;

			int xx = ix + d.x;
			int yy = iy + d.y;
			if (xx < 0 || xx >= MAP_WIDTH || yy < 0 || yy >= MAP_HEIGHT) continue;

			int idx = yy * MAP_WIDTH + xx;
			if (!dungeon.seen[idx]) continue;

			float mag = 1.0f - math::min(1.0f, math::sqrt((float)dist_sq) / 6.0f);
			int t3 = dungeon.board3[idx];
			if (t3 <= 0) continue;

			int tile_x = t3 % 8;
			int tile_y = t3 / 8;
			int r = 127;
			int g = 64;
			int b = 96;
			if (xx < 26 && yy < 19)
			{
				g = 127; b = 96; r = 64;
				tile_x = 6 + (xx + yy) % 2;
				tile_y = (xx + yy) % 2;
			}
			if (xx > 49) r = (int)(r * 0.30f);

			float rr = 0.33f + 0.66f * mag;
			draw_icon(tile_x, tile_y, (float)(xx * SCALE_8 + 4 * SCALE) + shake.x, (float)(yy * SCALE_8 + 2 * SCALE) + shake.y, color: { (char)(r * rr), (char)(g * rr), (char)(b * rr), 255 });
		}
	}

	// Fog of war
	for (int yi = 0; yi < MAP_HEIGHT; yi++)
	{
		for (int xi = 0; xi < MAP_WIDTH; xi++)
		{
			int idx = yi * MAP_WIDTH + xi;
			if (dungeon.seen[idx]) continue;

			int tile_x = 5;
			int tile_y = 1;
			int r = 127;
			int g = 64;
			int b = 96;
			if (xi < 26 && yi < 19)
			{
				g = 127; b = 96; r = 64;
				tile_x = 6 + (xi + yi) % 2;
				tile_y = (xi + yi) % 2;
			}
			if (xi > 49)
			{
				r = (int)(r * 0.60f);
				b = (int)(b * 1.56f);
			}
			if (!dungeon.known[idx])
			{
				r = 96; g = 96; b = 96;
				tile_x = 3;
				tile_y = 0;
			}
			draw_icon(tile_x, tile_y, (float)(xi * SCALE_8 + 4 * SCALE) + shake.x, (float)(yi * SCALE_8 + 2 * SCALE) + shake.y, color: { (char)(r / 3), (char)(g / 3), (char)(b / 3), 255 });
		}
	}

	if (game.intro_hold)
	{
		draw_texture(assets.pre_game_tex.texture, 0, 0, MAP_WIDTH * 8.0f, -MAP_HEIGHT * 8.0f, shake.x, shake.y, MAP_WIDTH * (float)SCALE_8, MAP_HEIGHT * (float)SCALE_8);
	}
}

// -----------------------------------------------------------------------------
// Input Handling
// -----------------------------------------------------------------------------

fn void get_player_input()
{
	Direction move_dir = NONE;

	if (!$feat(EMSCRIPTEN) && rl::is_key_down(ESCAPE)) game.quit_game = true;

	if (entities[0].health <= 0)
	{
		entities[0].block_movement = false;
		entities[0].sprite = 47;
		return;
	}

	game.key_delay--;

	if (game.key_delay < 0 && game.intro_hold)
	{
		if (rl::is_key_pressed(SPACE) || rl::is_mouse_button_pressed(LEFT))
		{
			game.key_delay = 5;
			if (game.menu == INTRO)
			{
				game.menu = CONTROLS;
			}
			else if (game.menu == CONTROLS)
			{
				game.menu = GAME;
				game.intro_hold = false;
				rl::stop_sound(assets.snd_melody);
			}
			rl::play_sound(assets.snd_hurt);
		}
		return;
	}

	if (game.key_delay < 0 && game.game_win && game.menu == WIN)
	{
		if (rl::is_key_pressed(SPACE) || rl::is_mouse_button_pressed(LEFT)) game.quit_game = true;
		return;
	}

	if (!game.game_win && !shake.active)
	{
		if (rl::is_key_down(UP))    move_dir = UP;
		if (rl::is_key_down(DOWN))  move_dir = DOWN;
		if (rl::is_key_down(LEFT))  move_dir = LEFT;
		if (rl::is_key_down(RIGHT)) move_dir = RIGHT;

		if (game.key_delay < 0 && inv.rod && rl::is_key_down(C)
			&& entities[0].mana > 0 && entities[0].cooldown < 0)
		{
			game.key_delay = 5;
			entities[0].cooldown = 1.0f;
			magic_ball.p = { entities[0].px, entities[0].py };
			magic_ball.v = game.last_move.v * 8.0f;
			magic_ball.active = true;
			entities[0].mana--;
			rl::play_sound(assets.snd_cast);
		}

		if (game.key_delay < 0 && inv.potions[0] > 0 && entities[0].health < entities[0].max_health
			&& rl::is_key_down(H))
		{
			inv.potions[0]--;
			entities[0].health = entities[0].max_health;
			game.key_delay = 5;
			rl::play_sound(assets.snd_potion);
		}

		if (game.key_delay < 0 && inv.potions[1] > 0 && entities[0].mana < entities[0].max_mana
			&& rl::is_key_down(M))
		{
			inv.potions[1]--;
			entities[0].mana = entities[0].max_mana;
			game.key_delay = 5;
			rl::play_sound(assets.snd_potion);
		}
	}

	if (game.key_delay < 0 && move_dir != NONE)
	{
		game.last_move = move_dir;
		entity_move(0, move_dir);
		game.key_delay = 4;
		map_update_visibility();
	}

	step_to_zero(&entities[0].kx);
	step_to_zero(&entities[0].ky);
}

// -----------------------------------------------------------------------------
// Entry Point
// -----------------------------------------------------------------------------

fn void main() @winmain
{
	const int VIRT_WIDTH  = XRES * SCALE;
	const int VIRT_HEIGHT = YRES * SCALE;

	rl::set_config_flags(RLConfigFlag.WINDOW_RESIZABLE | RLConfigFlag.VSYNC_HINT);
	rl::init_window(VIRT_WIDTH, VIRT_HEIGHT, string::tformat_zstr("Dungeon of the Phoenix %s - by Syn9", VERSION));
	defer rl::close_window();
	rl::set_window_min_size(XRES, YRES);
	rl::set_exit_key(NONE);
	rl::init_audio_device();
	defer rl::close_audio_device();
	rl::set_target_fps(60);

	RLRenderTexture2D canvas = rl::load_render_texture(VIRT_WIDTH, VIRT_HEIGHT);
	defer rl::unload_render_texture(canvas);
	canvas.texture.set_filter(POINT);

	load_all_assets();

	while (!gen_rooms()) {}

	map_update_visibility();
	rl::play_sound(assets.snd_melody);
	game.t_clock = rl::get_time();

	while (true)
	{
		@pool()
		{
			game.amort = (game.amort + 1) % 4;
			get_player_input();
			entity_update_all();

			rl::@texture_mode(canvas)
			{
				rl::clear_background(rl::BLACK);
				draw_map();
				if (!game.intro_hold)
				{
					item_draw_all();
					entity_draw_all();
				}
				ui_draw();
			};

			float sw = (float)rl::get_screen_width();
			float sh = (float)rl::get_screen_height();
			float scale = math::min(sw / (float)VIRT_WIDTH, sh / (float)VIRT_HEIGHT);
			float rw = (float)VIRT_WIDTH * scale;
			float rh = (float)VIRT_HEIGHT * scale;
			float ox = (sw - rw) * 0.5f;
			float oy = (sh - rh) * 0.5f;

			rl::@drawing()
			{
				rl::clear_background(rl::BLACK);
				rl::draw_texture_pro(
					canvas.texture,
					{ 0, 0, (float)VIRT_WIDTH, -(float)VIRT_HEIGHT },
					{ ox, oy, rw, rh },
					{ 0, 0 },
					0,
					rl::WHITE
				);
			};

			if (rl::window_should_close() || game.quit_game) break;
		};
	}

	unload_all_assets();
}