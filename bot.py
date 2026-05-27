import discord
import aiohttp
from aiohttp import web
import sqlite3
import random
import string
import hashlib
import os

conn = sqlite3.connect("keys.db")

conn.execute("""
    CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE,
        password TEXT,
        scripts TEXT DEFAULT ''
    )
""")

conn.execute("""
    CREATE TABLE IF NOT EXISTS redeem_keys (
        key TEXT PRIMARY KEY,
        scripts TEXT,
        used INTEGER DEFAULT 0
    )
""")

conn.commit()

def gen_key():
    parts = [''.join(random.choices(string.ascii_uppercase + string.digits, k=4)) for _ in range(4)]
    return "HARM-" + "-".join(parts)

def hash_pass(password):
    return hashlib.sha256(password.encode()).hexdigest()

intents = discord.Intents.default()
bot = discord.Bot()

OWNER_ID = 1441291795320406029
SCRIPTS = ["Mandarin", "Overflame", "Antarctica"]

@bot.slash_command(name="genkey", description="Генерация ключа для регистрации (без скриптов)")
async def genkey(ctx):
    if ctx.author.id != OWNER_ID:
        await ctx.respond("Нет доступа.", ephemeral=True)
        return
    key = gen_key()
    conn.execute("INSERT INTO redeem_keys (key, scripts) VALUES (?, ?)", (key, ""))
    conn.commit()
    await ctx.respond(f"✅ Ключ регистрации: `{key}`", ephemeral=True)

@bot.slash_command(name="genkey2", description="Генерация ключа со скриптами")
async def genkey2(ctx, scripts: str):
    if ctx.author.id != OWNER_ID:
        await ctx.respond("Нет доступа.", ephemeral=True)
        return
    chosen = [s.strip() for s in scripts.split(",") if s.strip() in SCRIPTS]
    if not chosen:
        await ctx.respond(f"❌ Доступные скрипты: {', '.join(SCRIPTS)}", ephemeral=True)
        return
    key = gen_key()
    conn.execute("INSERT INTO redeem_keys (key, scripts) VALUES (?, ?)", (key, ",".join(chosen)))
    conn.commit()
    await ctx.respond(
        f"✅ Ключ со скриптами создан!\n"
        f"Ключ: `{key}`\n"
        f"Скрипты: `{', '.join(chosen)}`",
        ephemeral=True
    )

@bot.slash_command(name="keylist", description="Список ключей")
async def keylist(ctx):
    if ctx.author.id != OWNER_ID:
        await ctx.respond("Нет доступа.", ephemeral=True)
        return
    rows = conn.execute("SELECT key, scripts, used FROM redeem_keys").fetchall()
    if not rows:
        await ctx.respond("Ключей нет.", ephemeral=True)
        return
    text = "\n".join([
        f"`{r[0]}` — {r[1] or 'регистрация'} — {'✅ использован' if r[2] else '❌ не использован'}"
        for r in rows
    ])
    await ctx.respond(text, ephemeral=True)

@bot.slash_command(name="userlist", description="Список пользователей")
async def userlist(ctx):
    if ctx.author.id != OWNER_ID:
        await ctx.respond("Нет доступа.", ephemeral=True)
        return
    rows = conn.execute("SELECT username, scripts FROM users").fetchall()
    if not rows:
        await ctx.respond("Пользователей нет.", ephemeral=True)
        return
    text = "\n".join([f"`{r[0]}` — {r[1] or 'нет скриптов'}" for r in rows])
    await ctx.respond(text, ephemeral=True)

@bot.slash_command(name="deluser", description="Удалить пользователя")
async def deluser(ctx, username: str):
    if ctx.author.id != OWNER_ID:
        await ctx.respond("Нет доступа.", ephemeral=True)
        return
    conn.execute("DELETE FROM users WHERE username = ?", (username,))
    conn.commit()
    await ctx.respond(f"Пользователь `{username}` удалён.", ephemeral=True)

@bot.slash_command(name="delkey", description="Удалить ключ")
async def delkey(ctx, key: str):
    if ctx.author.id != OWNER_ID:
        await ctx.respond("Нет доступа.", ephemeral=True)
        return
    conn.execute("DELETE FROM redeem_keys WHERE key = ?", (key,))
    conn.commit()
    await ctx.respond(f"Ключ `{key}` удалён.", ephemeral=True)

# ── HTTP API ──

async def register(request):
    try:
        data = await request.json()
    except:
        return web.json_response({"valid": False, "reason": "bad request"})

    username = data.get("username", "").strip()
    password = data.get("password", "").strip()
    key      = data.get("key", "").strip()

    if not username or not password or not key:
        return web.json_response({"valid": False, "reason": "missing fields"})

    row = conn.execute(
        "SELECT scripts, used FROM redeem_keys WHERE key = ?", (key,)
    ).fetchone()

    if not row:
        return web.json_response({"valid": False, "reason": "invalid key"})
    if row[1]:
        return web.json_response({"valid": False, "reason": "key already used"})

    exists = conn.execute(
        "SELECT 1 FROM users WHERE username = ?", (username,)
    ).fetchone()
    if exists:
        return web.json_response({"valid": False, "reason": "username taken"})

    conn.execute(
        "INSERT INTO users (username, password, scripts) VALUES (?, ?, ?)",
        (username, hash_pass(password), row[0])
    )
    conn.execute("UPDATE redeem_keys SET used = 1 WHERE key = ?", (key,))
    conn.commit()

    return web.json_response({"valid": True, "username": username, "scripts": row[0]})

async def login(request):
    try:
        data = await request.json()
    except:
        return web.json_response({"valid": False, "reason": "bad request"})

    username = data.get("username", "").strip()
    password = data.get("password", "").strip()

    row = conn.execute(
        "SELECT username, scripts FROM users WHERE username = ? AND password = ?",
        (username, hash_pass(password))
    ).fetchone()

    if not row:
        return web.json_response({"valid": False, "reason": "invalid login"})

    return web.json_response({"valid": True, "username": row[0], "scripts": row[1] or ""})

async def redeem(request):
    try:
        data = await request.json()
    except:
        return web.json_response({"valid": False, "reason": "bad request"})

    username = data.get("username", "").strip()
    password = data.get("password", "").strip()
    key      = data.get("key", "").strip()

    user = conn.execute(
        "SELECT scripts FROM users WHERE username = ? AND password = ?",
        (username, hash_pass(password))
    ).fetchone()
    if not user:
        return web.json_response({"valid": False, "reason": "invalid login"})

    row = conn.execute(
        "SELECT scripts, used FROM redeem_keys WHERE key = ?", (key,)
    ).fetchone()
    if not row:
        return web.json_response({"valid": False, "reason": "invalid key"})
    if row[1]:
        return web.json_response({"valid": False, "reason": "key already used"})

    existing = set(filter(None, user[0].split(",")))
    new      = set(filter(None, row[0].split(",")))
    merged   = ",".join(existing | new)

    conn.execute("UPDATE users SET scripts = ? WHERE username = ?", (merged, username))
    conn.execute("UPDATE redeem_keys SET used = 1 WHERE key = ?", (key,))
    conn.commit()

    return web.json_response({"valid": True, "scripts": merged})

async def start_api():
    app = web.Application()
    app.router.add_post("/register", register)
    app.router.add_post("/login",    login)
    app.router.add_post("/redeem",   redeem)
    runner = web.AppRunner(app)
    await runner.setup()
    site = web.TCPSite(runner, "0.0.0.0", 8080)
    await site.start()
    print("API запущен на порту 8080")

@bot.event
async def on_ready():
    await start_api()
    print(f"Бот запущен: {bot.user}")

bot.run(os.environ.get("TOKEN"))
