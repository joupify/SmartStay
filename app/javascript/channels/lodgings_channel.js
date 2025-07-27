import consumer from "./consumer";

consumer.subscriptions.create("LodgingsChannel", {
  connected() {
    console.log("✅ Connecté à LodgingsChannel");
  },

  disconnected() {
    console.log("❌ Déconnecté de LodgingsChannel");
  },

  received(data) {
    console.log("📩 Événement reçu :", data);

    const container = document.getElementById("notifications");
    if (!container) return;

    const { action, lodging } = data; // ✅ Déstructuration propre
    let message = "";

    switch (action) {
      case "created":
        message = `🏠 Nouveau logement : ${lodging.title}`;
        break;
      case "updated":
        message = `✏️ Logement mis à jour : ${lodging.title}`;
        break;
      case "deleted":
    message = `🗑️ Logement supprimé : ${data.title}`;
        break;
      default:
        message = `ℹ️ Action inconnue : ${action}`;
    }

    const el = document.createElement("div");
    el.innerText = message;
    el.classList.add("alert", "alert-info", "shadow", "rounded", "mb-2", "py-2", "px-3");
    container.prepend(el);

    setTimeout(() => el.remove(), 5000);
  }
});
