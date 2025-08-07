import consumer from "./consumer";

consumer.subscriptions.create("LodgingsChannel", {
  connected() {
    console.log("✅ Connected LodgingsChannel");
  },

  disconnected() {
    console.log("❌ DDisconnected LodgingsChannel");
  },

  received(data) {
    console.log("📩 Event received :", data);

    const container = document.getElementById("notifications");
    if (!container) return;

    const { action, lodging } = data;
    let message = "";

    switch (action) {
      case "created":
        message = `🏠 New lodging : ${lodging.title}`;
        break;
      case "updated":
        message = `✏️ Lodging updated : ${lodging.title}`;
        break;
      case "deleted":
    message = `🗑️ Lodging deleted : ${data.lodging.title}`;
        break;
      default:
        message = `ℹ️ Unknown action : ${action}`;
    }

    const el = document.createElement("div");
    el.innerText = message;
    el.classList.add("alert", "alert-info", "shadow", "rounded", "mb-2", "py-2", "px-3");
    container.prepend(el);

    setTimeout(() => el.remove(), 5000);
  }
});
