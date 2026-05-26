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
        key TEXT UNIQUE
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

@bot.slash_command(name="createuser", description="Создать пользователя")
async def createuser(ctx, username: str, password: str):
    if ctx.author.id != OWNER_ID:
        await ctx.respond("Нет доступа.", ephemeral=True)
        return
    key = gen_key()
    try:
        conn.execute(
            "INSERT INTO users (username, password, key) VALUES (?, ?, ?)",
            (username, hash_pass(password), key)
        )
        conn.commit()
        await ctx.respond(
            f"✅ Пользователь создан!\n"
            f"Ник: `{username}`\n"
            f"Пароль: `{password}`\n"
            f"Ключ: `{key}`",
            ephemeral=True
        )
    except sqlite3.IntegrityError:
        await ctx.respond("Пользователь уже существует.", ephemeral=True)

@bot.slash_command(name="userlist", description="Список пользователей")
async def userlist(ctx):
    if ctx.author.id != OWNER_ID:
        await ctx.respond("Нет доступа.", ephemeral=True)
        return
    rows = conn.execute("SELECT username, key FROM users").fetchall()
    if not rows:
        await ctx.respond("Пользователей нет.", ephemeral=True)
        return
    text = "\n".join([f"`{r[1]}` — {r[0]}" for r in rows])
    await ctx.respond(text, ephemeral=True)

@bot.slash_command(name="deluser", description="Удалить пользователя")
async def deluser(ctx, username: str):
    if ctx.author.id != OWNER_ID:
        await ctx.respond("Нет доступа.", ephemeral=True)
        return
    conn.execute("DELETE FROM users WHERE username = ?", (username,))
    conn.commit()
    await ctx.respond(f"Пользователь `{username}` удалён.", ephemeral=True)

# ── HTTP API ──
async def login(request):
    try:
        data = await request.json()
    except:
        return web.json_response({"valid": False, "reason": "bad request"})

    username = data.get("username", "").strip()
    password = data.get("password", "").strip()

    row = conn.execute(
        "SELECT key FROM users WHERE username = ? AND password = ?",
        (username, hash_pass(password))
    ).fetchone()

    if not row:
        return web.json_response({"valid": False, "reason": "invalid login"})

    return web.json_response({"valid": True, "username": username, "key": row[0]})

async def start_api():
    app = web.Application()
    app.router.add_post("/login", login)
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
