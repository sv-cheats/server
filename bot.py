import discord
import aiohttp
from aiohttp import web
import sqlite3
import random
import string

# ── База данных ──
conn = sqlite3.connect("keys.db")
conn.execute("""
    CREATE TABLE IF NOT EXISTS keys (
        key TEXT PRIMARY KEY,
        username TEXT,
        used INTEGER DEFAULT 0
    )
""")
conn.commit()

def gen_key():
    parts = [''.join(random.choices(string.ascii_uppercase + string.digits, k=4)) for _ in range(4)]
    return "HARM-" + "-".join(parts)

# ── Discord бот ──
intents = discord.Intents.default()
bot = discord.Bot()

@bot.slash_command(name="genkey", description="Генерация ключа")
async def genkey(ctx, username: str):
    # Только ты можешь выдавать ключи (вставь свой Discord ID)
    if ctx.author.id != 123456789:
        await ctx.respond("Нет доступа.", ephemeral=True)
        return
    key = gen_key()
    conn.execute("INSERT INTO keys (key, username) VALUES (?, ?)", (key, username))
    conn.commit()
    await ctx.respond(f"Ключ для `{username}`: `{key}`", ephemeral=True)

@bot.slash_command(name="keylist", description="Список ключей")
async def keylist(ctx):
    if ctx.author.id != 123456789:
        await ctx.respond("Нет доступа.", ephemeral=True)
        return
    rows = conn.execute("SELECT key, username, used FROM keys").fetchall()
    if not rows:
        await ctx.respond("Ключей нет.", ephemeral=True)
        return
    text = "\n".join([f"`{r[0]}` — {r[1]} — {'✅' if r[2] else '❌'}" for r in rows])
    await ctx.respond(text, ephemeral=True)

@bot.slash_command(name="delkey", description="Удалить ключ")
async def delkey(ctx, key: str):
    if ctx.author.id != 123456789:
        await ctx.respond("Нет доступа.", ephemeral=True)
        return
    conn.execute("DELETE FROM keys WHERE key = ?", (key,))
    conn.commit()
    await ctx.respond(f"Ключ `{key}` удалён.", ephemeral=True)

# ── HTTP API для Lua ──
async def check_key(request):
    data = await request.json()
    key  = data.get("key", "")
    row  = conn.execute("SELECT username, used FROM keys WHERE key = ?", (key,)).fetchone()
    if not row:
        return web.json_response({"valid": False, "reason": "invalid"})
    if row[1]:
        return web.json_response({"valid": False, "reason": "used"})
    return web.json_response({"valid": True, "username": row[0]})

async def start_api():
    app = web.Application()
    app.router.add_post("/check", check_key)
    runner = web.AppRunner(app)
    await runner.setup()
    site = web.TCPSite(runner, "0.0.0.0", 8080)
    await site.start()

@bot.event
async def on_ready():
    await start_api()
    print(f"Бот запущен: {bot.user}")

bot.run("token")