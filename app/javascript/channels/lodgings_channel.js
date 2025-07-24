import consumer from "channels/consumer"

consumer.subscriptions.create("LodgingsChannel", {
  connected() {
    console.log("Connected to LodgingsChannel");
  },

  disconnected() {},

  received(data) {
    const event = JSON.parse(data);
    alert(`Nouveau logement ajouté: ${event.title}`);
  }
});