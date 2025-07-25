import consumer from "./consumer"

consumer.subscriptions.create("LodgingsChannel", {
  connected() {
    console.log("✅ Connecté à LodgingsChannel");
  },

  disconnected() {
    console.log("Disconnected from LodgingsChannel");
  },

  received(data) {
  console.log("📩 Nouveau logement reçu :", data);

  // alert(`🏠 Nouveau logement : ${data.title}`);

  // Rechercher le container à chaque message reçu
  
  const container = document.getElementById("notifications");
  console.log("container:", container);

  if (container) {
    const el = document.createElement("div");
    el.innerText = `Nouveau logement ajouté : ${data.title}`;
    el.classList.add(
    "alert",           // composant alert Bootstrap
    "alert-success",   // vert, succès
    "shadow",          // ombre légère
    "rounded",         // coins arrondis
    "mb-2",            // marge en bas entre notifications
    "py-2", "px-3",    // padding vertical & horizontal
    "text-truncate"   // texte coupé si trop long
    );
    container.prepend(el);

    setTimeout(() => el.remove(), 5000);
  } else {
    console.warn("Element #notifications introuvable");
  }
}


});
