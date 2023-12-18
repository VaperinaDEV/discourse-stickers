import { withPluginApi } from "discourse/lib/plugin-api";
import { action } from "@ember/object";
import StickerModal from "../components/modal/sticker";

export default {
  name: "discourse-stickers",

  initialize(container) {
    withPluginApi("0.1", (api) => {
      api.onToolbarCreate((toolbar) => {
        if (toolbar.context.composerEvents) {
          toolbar.addButton({
            title: themePrefix("sticker.composer_title"),
            id: "sticker_button",
            group: "extras",
            icon: settings.composer_icon,
            action: () => {
              const modal = api.container.lookup("service:modal");
              modal.show(StickerModal);
            },
          });
        }
      });

      const chat = api.container.lookup("service:chat");
      if (chat) {
        api.registerChatComposerButton?.({
          translatedLabel: themePrefix("sticker.composer_title"),
          id: "sticker_button",
          icon: settings.composer_icon,
          action: "showChatStickerModal",
          position: "dropdown",
        });

        api.modifyClass("component:chat-composer", {
          pluginId: "discourse-stickers",

          @action
          showChatStickerModal(context) {
            this.modal.show(StickerModal, {
              model: {
                customPickHandler: (message) => {
                  api.sendChatMessage(this.draft.channel.id, {
                    message,
                    threadId:
                      context === "thread" ? this.draft.thread.id : null,
                  });
                },
              },
            });
          },
        });
      }
    });
  },
};
