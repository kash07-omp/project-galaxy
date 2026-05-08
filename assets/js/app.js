// Include phoenix_html to handle method=DELETE links in forms and buttons.
import "phoenix_html";
// Establish Phoenix Socket and LiveSocket connection to the server.
import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";
import SolarSystemHook from "./hooks/solar_system_hook";

let csrfToken = document
  .querySelector("meta[name='csrf-token']")
  .getAttribute("content");

let hooks = {
  SolarSystem: SolarSystemHook,
  AutoDismissFlash: {
    mounted() {
      const duration = Number(this.el.dataset.duration || 3500);
      this.timeoutRef = window.setTimeout(() => {
        this.el.click();
      }, duration);
    },
    destroyed() {
      if (this.timeoutRef) {
        window.clearTimeout(this.timeoutRef);
      }
    },
  },
};

let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: { _csrf_token: csrfToken },
  hooks,
});

liveSocket.connect();

// Expose liveSocket for debugging in dev tools.
window.liveSocket = liveSocket;
