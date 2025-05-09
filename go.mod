import discord
from discord.ext import commands
from discord import app_commands
from datetime import datetime

intents = discord.Intents.default()
intents.message_content = True
intents.guilds = True
intents.members = True

bot = commands.Bot(command_prefix="/", intents=intents)

# Constants
SEASON_HOST_ROLE = "Season Host"
EARLY_ACCESS_ROLE = "Early Access"
TICKET_CHANNEL_ID = 1366726329449320549
WELCOME_CHANNEL_ID = 1368176370206638080
TICKET_CATEGORY_NAME = "Tickets"
EMBED_COLOR = 0xADD8E6  # Light blue
STAFF_TEAM_ROLE = "Staff Team"
HR_TEAM_ROLE = "HR Team"  # Added for HR-specific claims


def has_role(user: discord.Member, role_name: str):
    return any(role.name == role_name for role in user.roles)


async def send_ticket_panel():
    channel = bot.get_channel(TICKET_CHANNEL_ID)
    if channel:
        await channel.purge(limit=100)

        embed = discord.Embed(
            title="Greenville Empire | Server Assistance",
            description=(
                "** General Support:**\n"
                "You have the option to open a General Support ticket which is dedicated to assisting Civilians within Greenville Roleplay Frontier.\n"
                "If you have questions, need guidance, or face issues that require support, you can use the General Support option to reach out for help from one of our Staff members.\n\n"
                "** Civilian Report:**\n"
                "You can create a Civilian Report ticket to report any Civilians violating the rules and regulations of Greenville Roleplay Frontier. We strongly encourage Civilians to use this feature as it helps maintain a community free from individuals with malicious intentions.\n\n"
                "** Staff Report:**\n"
                "If you come across Staff members not adhering to rules, you can open a Staff Report ticket. We value feedback and strive to address issues promptly."
            ),
            color=EMBED_COLOR
        )
        await channel.send(embed=embed, view=TicketView())


class TicketView(discord.ui.View):
    def __init__(self):
        super().__init__(timeout=None)

    @discord.ui.button(label="  General Support", style=discord.ButtonStyle.primary)
    async def general_support(self, interaction: discord.Interaction, button: discord.ui.Button):
        await create_ticket(interaction, "general-support")

    @discord.ui.button(label="  Civilian Report", style=discord.ButtonStyle.danger)
    async def civilian_report(self, interaction: discord.Interaction, button: discord.ui.Button):
        await create_ticket(interaction, "civilian-report")

    @discord.ui.button(label="  Staff Report", style=discord.ButtonStyle.secondary)
    async def staff_report(self, interaction: discord.Interaction, button: discord.ui.Button):
        await create_ticket(interaction, "staff-report")


class TicketManagementView(discord.ui.View):
    def __init__(self):
        super().__init__(timeout=None)
        self.claimed = False
        self.claimed_by = None

    @discord.ui.button(label="Claim", style=discord.ButtonStyle.green)
    async def claim(self, interaction: discord.Interaction, button: discord.ui.Button):
        if has_role(interaction.user, STAFF_TEAM_ROLE) or has_role(interaction.user, HR_TEAM_ROLE):
            if not self.claimed:
                self.claimed = True
                self.claimed_by = interaction.user
                await interaction.response.send_message(
                    f"  {interaction.user.mention} has claimed this ticket.",
                    ephemeral=False
                )
                # Update the embed to show who claimed it
                embed = interaction.message.embeds[0]
                embed.add_field(name="Claimed by", value=interaction.user.mention, inline=False)
                await interaction.message.edit(embed=embed, view=self)
            else:
                await interaction.response.send_message(
                    f"  This ticket is already claimed by {self.claimed_by.mention}.",
                    ephemeral=True
                )
        else:
            await interaction.response.send_message(
                "  You need to be a staff member to claim tickets.",
                ephemeral=True
            )

    @discord.ui.button(label="Unclaim", style=discord.ButtonStyle.gray)
    async def unclaim(self, interaction: discord.Interaction, button: discord.ui.Button):
        if self.claimed and interaction.user == self.claimed_by:
            self.claimed = False
            self.claimed_by = None
            await interaction.response.send_message(
                f" ️ {interaction.user.mention} has unclaimed this ticket.",
                ephemeral=False
            )
            # Update the embed to remove claim info
            embed = interaction.message.embeds[0]
            if len(embed.fields) > 5:  # Assuming the claim field is the last one
                embed.remove_field(5)
            await interaction.message.edit(embed=embed, view=self)
        else:
            await interaction.response.send_message(
                "  You can only unclaim tickets you've claimed.",
                ephemeral=True
            )

    @discord.ui.button(label="Close", style=discord.ButtonStyle.red)
    async def close(self, interaction: discord.Interaction, button: discord.ui.Button):
        if has_role(interaction.user, STAFF_TEAM_ROLE) or has_role(interaction.user, HR_TEAM_ROLE):
            await interaction.response.send_message("Closing ticket...", ephemeral=True)
            await interaction.channel.delete()
        else:
            await interaction.response.send_message(
                "  You need to be a staff member to close tickets.",
                ephemeral=True
            )


async def create_ticket(interaction, reason):
    guild = interaction.guild
    category = discord.utils.get(guild.categories, name=TICKET_CATEGORY_NAME)
    if not category:
        category = await guild.create_category(TICKET_CATEGORY_NAME)

    staff_role = discord.utils.get(guild.roles, name=STAFF_TEAM_ROLE)
    hr_role = discord.utils.get(guild.roles, name=HR_TEAM_ROLE)

    staff_team_mention = staff_role.mention if staff_role else "@Staff Team"
    hr_team_mention = hr_role.mention if hr_role else "@HR Team"

    overwrites = {
        guild.default_role: discord.PermissionOverwrite(view_channel=False),
        interaction.user: discord.PermissionOverwrite(view_channel=True, send_messages=True),
        guild.me: discord.PermissionOverwrite(view_channel=True)
    }

    if staff_role:
        overwrites[staff_role] = discord.PermissionOverwrite(view_channel=True, send_messages=True)
    if hr_role:
        overwrites[hr_role] = discord.PermissionOverwrite(view_channel=True, send_messages=True)

    channel_name = f"{reason}-{interaction.user.display_name}".lower().replace(" ", "-")
    channel = await guild.create_text_channel(name=channel_name, overwrites=overwrites, category=category)

    if reason == "staff-report":
        embed = discord.Embed(
            title="Greenville Empire | Staff Report",
            description=(
                f"{staff_team_mention} {hr_team_mention}\n\n"
                "Please wait for an HR member to claim your ticket. While you wait, please "
                "fill out the format below.\n\n"
                "**Username:**\n"
                "**Staff reporting username:**\n"
                "**Reason:**\n"
                "**Date:**\n"
                "**Evidence:**"
            ),
            color=EMBED_COLOR,
            timestamp=datetime.now()
        )
        embed.set_footer(text=f"Ticket created by {interaction.user.display_name}")
        await channel.send(content=f"{interaction.user.mention} {staff_team_mention} {hr_team_mention}",
                         embed=embed,
                         view=TicketManagementView())
    else:
        embed = discord.Embed(
            title=f"Greenville Empire | {reason.replace('-', ' ').title()} Ticket",
            description=f"{interaction.user.mention}, a staff member will be with you shortly.",
            color=EMBED_COLOR,
            timestamp=datetime.now()
        )
        embed.add_field(name="Reason", value=reason.replace('-', ' ').title(), inline=False)
        embed.set_footer(text=f"Ticket created by {interaction.user.display_name}")
        await channel.send(content=f"{interaction.user.mention} {staff_team_mention}",
                         embed=embed,
                         view=TicketManagementView())

    await interaction.response.send_message(
        f"✅ Your {reason.replace('-', ' ')} ticket has been created: {channel.mention}",
        ephemeral=True
    )


@bot.tree.command(name="startup", description="Announce a session startup")
async def startup(interaction: discord.Interaction):
    if not has_role(interaction.user, SEASON_HOST_ROLE):
        return await interaction.response.send_message(embed=discord.Embed(
            description="You need the Season Host role to use this command.", color=discord.Color.red()),
            ephemeral=True)

    await interaction.response.send_message("@everyone", allowed_mentions=discord.AllowedMentions(everyone=True))
    embed = discord.Embed(
        title="Greenville Empire | Session Start Up",
        description=(
            f":: A session is now being hosted by {interaction.user.mention}.\n"
            ":: Please Make sure to read over server-regulations before joining any session.\n"
            ":: To avoid problems with the police, register your car in vehicle-registration.\n\n"
            ":: Any problem with a member? Go in staff-support and report them with a ticket!\n"
            ":: Ensure to join our Roblox Group , allowing you to be rewarded if you win any future giveaways.\n"
            ":: For the start of the session, we need at least 10 reactions."
        ),
        color=EMBED_COLOR
    )
    await interaction.followup.send(embed=embed)


@bot.tree.command(name="purge", description="Purge a number of messages from the channel")
@app_commands.describe(amount="Number of messages to delete (max 100)")
async def purge(interaction: discord.Interaction, amount: int):
    if not has_role(interaction.user, SEASON_HOST_ROLE):
        return await interaction.response.send_message(embed=discord.Embed(
            description="You need the Season Host role to use this command.",
            color=discord.Color.red()
        ), ephemeral=True)

    if amount <= 0 or amount > 100:
        return await interaction.response.send_message(embed=discord.Embed(
            description="Please provide a number between 1 and 100.",
            color=discord.Color.red()
        ), ephemeral=True)

    if not interaction.channel.permissions_for(interaction.guild.me).manage_messages:
        return await interaction.response.send_message(embed=discord.Embed(
            description="I don't have permission to delete messages in this channel.",
            color=discord.Color.red()
        ), ephemeral=True)

    await interaction.response.defer(ephemeral=True)
    deleted = await interaction.channel.purge(limit=amount)
    await interaction.followup.send(embed=discord.Embed(
        description=f"Successfully deleted {len(deleted)} messages.",
        color=EMBED_COLOR
    ), ephemeral=True)


@bot.tree.command(name="setup", description="Notify that a session is being set up")
async def setup(interaction: discord.Interaction):
    if not has_role(interaction.user, SEASON_HOST_ROLE):
        return await interaction.response.send_message(embed=discord.Embed(
            description="You need the Season Host role to use this command.", color=discord.Color.red()),
            ephemeral=True)

    embed = discord.Embed(
        title="Greenville Empire | Set Up",
        description=(
            f"{interaction.user.mention} is currently setting up the session.\n"
            "Please do not ping or disturb the host during this time. The session will be released shortly once everything is ready. Thank you for your patience and cooperation!"
        ),
        color=EMBED_COLOR
    )
    await interaction.response.send_message(embed=embed)

@bot.tree.command(name="early", description="Announce early access and provide button")
@app_commands.describe(link="Roblox game link for early access")
async def early(interaction: discord.Interaction, link: str):
    if not has_role(interaction.user, SEASON_HOST_ROLE):
        return await interaction.response.send_message(embed=discord.Embed(
            description="You need the Season Host role to use this command.", color=discord.Color.red()),
            ephemeral=True)

    role = discord.utils.get(interaction.guild.roles, name=EARLY_ACCESS_ROLE)
    staff_role = discord.utils.get(interaction.guild.roles, name="Staff Team")
    dps_role = discord.utils.get(interaction.guild.roles, name="—Department of Public Safety and Professional Services—")

    mentions = []
    if role: mentions.append(role.mention)
    if staff_role: mentions.append(staff_role.mention)
    if dps_role: mentions.append(dps_role.mention)

    await interaction.response.send_message(" ".join(mentions), allowed_mentions=discord.AllowedMentions.all())

    class EarlyAccessButton(discord.ui.View):
        def __init__(self):
            super().__init__(timeout=None)

        @discord.ui.button(label="Get Early Access", style=discord.ButtonStyle.primary)
        async def button_callback(self, interaction: discord.Interaction, button: discord.ui.Button):
            if has_role(interaction.user, EARLY_ACCESS_ROLE):
                embed = discord.Embed(description=f"Early access link: {link}", color=EMBED_COLOR)
                await interaction.response.send_message(embed=embed, ephemeral=True)
            else:
                await interaction.response.send_message(embed=discord.Embed(
                    description="You don't have the Early Access role.", color=discord.Color.red()), ephemeral=True)

    embed = discord.Embed(
        title="Greenville Empire | Early Access",
        description=(
            "Early Access is now available.\n"
            "Do not share your link. It is monitored and tied to your account."
        ),
        color=EMBED_COLOR
    )
    await interaction.followup.send(embed=embed, view=EarlyAccessButton())


@bot.tree.command(name="end", description="Announce the end of a session")
async def end(interaction: discord.Interaction):
    if not has_role(interaction.user, SEASON_HOST_ROLE):
        return await interaction.response.send_message(embed=discord.Embed(
            description="You need the Season Host role to use this command.", color=discord.Color.red()),
            ephemeral=True)

    await interaction.response.send_message("@everyone", allowed_mentions=discord.AllowedMentions(everyone=True))
    embed = discord.Embed(
        title="Greenville Empire | Session Over",
        description=f"The session hosted by {interaction.user.mention} has sadly come to an end, another session will start when staff has time. We hope you enjoyed the session!",
        color=EMBED_COLOR
    )
    embed.set_image(url="https://media.discordapp.net/attachments/1195487863737735259/1236287148838144000/standard_1.gif?width=1200&height=675")
    await interaction.followup.send(embed=embed)


@bot.tree.command(name="release", description="Release a session to the public")
@app_commands.describe(
    link="Roblox join link",
    frp_speeds="FRP speed rule",
    speed_limit="Speed limit",
    leo_status="Peace time or LEO status",
    co_host="Co-host",
    other_info="Other session info"
)
async def release(interaction: discord.Interaction, link: str, frp_speeds: str, speed_limit: str, leo_status: str,
                  co_host: str, other_info: str = "N/A"):
    if not has_role(interaction.user, SEASON_HOST_ROLE):
        return await interaction.response.send_message(embed=discord.Embed(
            description="You need the Season Host role to use this command.", color=discord.Color.red()),
            ephemeral=True)

    class SessionLinkButton(discord.ui.View):
        def __init__(self):
            super().__init__(timeout=None)

        @discord.ui.button(label="Session Link", style=discord.ButtonStyle.primary)
        async def session_link(self, interaction: discord.Interaction, button: discord.ui.Button):
            await interaction.response.send_message(f"Session link: {link}", ephemeral=True)

    await interaction.response.send_message("@everyone", allowed_mentions=discord.AllowedMentions(everyone=True))

    embed = discord.Embed(
        title="Greenville Empire | Session Released",
        description=(
            f"{interaction.user.mention} has released their session!\n\n"
            f"• FRP Speed: {frp_speeds}\n"
            f"• Speed Limit: {speed_limit}\n"
            f"• LEO Status: {leo_status}\n"
            f"• Co-Host: {co_host}\n"
            f"• Other Info: {other_info}\n\n"
            "Click the button below to get the session link."
        ),
        color=EMBED_COLOR
    )
    await interaction.followup.send(embed=embed, view=SessionLinkButton())


@bot.tree.command(name="re-invites", description="Re-invites for people who want to join the session")
@app_commands.describe(
    link="Roblox join link",
    frp_speeds="FRP speed rule",
    speed_limit="Speed limit",
    leo_status="Peace time or LEO status",
    co_host="Co-host",
    other_info="Other session info"
)
async def re_invites(interaction: discord.Interaction, link: str, frp_speeds: str, speed_limit: str, leo_status: str,
                     co_host: str, other_info: str = "N/A"):
    if not has_role(interaction.user, SEASON_HOST_ROLE):
        return await interaction.response.send_message(embed=discord.Embed(
            description="You need the Season Host role to use this command.", color=discord.Color.red()),
            ephemeral=True)

    class SessionLinkButton(discord.ui.View):
        def __init__(self):
            super().__init__(timeout=None)

        @discord.ui.button(label="Session Link", style=discord.ButtonStyle.primary)
        async def session_link(self, interaction: discord.Interaction, button: discord.ui.Button):
            await interaction.response.send_message(f"Session link: {link}", ephemeral=True)

    await interaction.response.send_message("@everyone", allowed_mentions=discord.AllowedMentions(everyone=True))

    embed = discord.Embed(
        title="Greenville Empire | Session re-invite",
        description=(
            f"{interaction.user.mention} has re-invited their session!\n\n"
            f"• FRP Speed: {frp_speeds}\n"
            f"• Speed Limit: {speed_limit}\n"
            f"• LEO Status: {leo_status}\n"
            f"• Co-Host: {co_host}\n"
            f"• Other Info: {other_info}\n\n"
            "Click the button below to get the session link."
        ),
        color=EMBED_COLOR
    )
    await interaction.followup.send(embed=embed, view=SessionLinkButton())
@bot.event
async def on_ready():
    await bot.tree.sync()
    print(f"✅ Bot is ready! Logged in as {bot.user}")
    await send_ticket_panel()


bot.run("MTM2OTk5MjMyMTExNzk4Mjg0MQ.Gj1RD7.isbZ44n9Bl6UgUYCIBywTPjhsyPNonZyZhcwas")
