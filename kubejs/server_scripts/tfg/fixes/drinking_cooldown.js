"use strict";

const TFGDrinkCooldownPlayerData = Java.loadClass('net.dries007.tfc.common.capabilities.player.PlayerData');
const TFGDrinkCooldownCalendars = Java.loadClass('net.dries007.tfc.util.calendar.Calendars');

function tfgRepairFutureDrinkCooldown(player) {
    const currentTick = TFGDrinkCooldownCalendars.SERVER.getTicks();
    if (currentTick <= 10) return;
    const data = TFGDrinkCooldownPlayerData.get(player);
    const previousTick = data.getLastDrinkTick();
    if (previousTick > currentTick) {
        data.setLastDrinkTick(0);
        console.info(`Repaired future TFC drinking cooldown for ${player.username}: ${previousTick} -> 0 (current tick ${currentTick})`);
    }
}

PlayerEvents.loggedIn(event => tfgRepairFutureDrinkCooldown(event.player));

// Also repair players already online when the scripts are reloaded.
let tfgDrinkCooldownOnlinePlayersChecked = false;
ServerEvents.tick(event => {
    if (tfgDrinkCooldownOnlinePlayersChecked || TFGDrinkCooldownCalendars.SERVER.getTicks() <= 10) return;
    tfgDrinkCooldownOnlinePlayersChecked = true;
    event.server.players.forEach(player => tfgRepairFutureDrinkCooldown(player));
});
