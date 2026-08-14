import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { getOwner } from "@ember/application";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { service } from "@ember/service";
import DModal from "discourse/components/d-modal";
import DButton from "discourse/components/d-button";
import icon from "discourse/helpers/d-icon";
import replaceEmoji from "discourse/helpers/replace-emoji";
import DTooltip from "float-kit/components/d-tooltip";
import { and, eq, not } from "truth-helpers";
import { i18n } from "discourse-i18n";

const OTHER_PACK_KEY = "__other__";

export default class Stickers extends Component {
  @service site;
  @service capabilities;
  @service composer;

  get isChatContext() {
    return !!this.args.model?.customPickHandler;
  }

  get composerStickerImages() {
    const categoryId = this.composer?.model?.category?.id;

    return settings.sticker_images.filter((sticker) => {
      if (!sticker.categories || sticker.categories.length === 0) {
        return true;
      }
      return categoryId && sticker.categories.includes(categoryId);
    });
  }

  get chatStickerImages() {
    const isPrivateChannel = !!this.args.model?.isPrivateChannel;
    const channelId = this.args.model?.channelId;

    return settings.sticker_images.filter((sticker) => {
      if (isPrivateChannel) {
        return !sticker.chat_hide_from_private;
      }

      const allowedChannelIds = this.parseChannelIds(sticker.chat_channels);
      if (allowedChannelIds.length === 0) {
        return true;
      }
      return channelId && allowedChannelIds.includes(channelId);
    });
  }

  parseChannelIds(rawValue) {
    if (!rawValue) {
      return [];
    }

    return rawValue
      .split(",")
      .map((value) => parseInt(value.trim(), 10))
      .filter((value) => !isNaN(value));
  }

  @tracked selectedPack = null;

  get availableStickerImages() {
    return this.isChatContext
      ? this.chatStickerImages
      : this.composerStickerImages;
  }

  get packOptions() {
    const names = new Set();
    let hasUngrouped = false;

    this.availableStickerImages.forEach((sticker) => {
      const pack = sticker.pack?.trim();
      if (pack) {
        names.add(pack);
      } else {
        hasUngrouped = true;
      }
    });

    const options = [...names]
      .sort((a, b) => a.localeCompare(b))
      .map((name) => ({ value: name, label: name }));

    if (hasUngrouped) {
      options.push({
        value: OTHER_PACK_KEY,
        label: i18n(themePrefix("sticker.filter_other")),
      });
    }

    return options;
  }

  get showPackFilter() {
    return this.packOptions.length > 1;
  }

  get stickerImages() {
    if (!this.selectedPack) {
      return this.availableStickerImages;
    }

    if (this.selectedPack === OTHER_PACK_KEY) {
      return this.availableStickerImages.filter(
        (sticker) => !sticker.pack?.trim()
      );
    }

    return this.availableStickerImages.filter(
      (sticker) => sticker.pack?.trim() === this.selectedPack
    );
  }

  get hasStickers() {
    return this.availableStickerImages.length > 0;
  }

  @action
  selectPack(packValue) {
    this.selectedPack = packValue;
  }

  base62Sha1(sha1) {
    const alphabet =
      "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";
    let value = BigInt(`0x${sha1}`);
    let encoded = "";

    while (value > 0n) {
      encoded = alphabet[Number(value % 62n)] + encoded;
      value /= 62n;
    }

    return encoded;
  }

  discourseUploadShortUrl(imageUrl) {
    try {
      const url = new URL(imageUrl);
      const match = url.pathname.match(
        /\/(?:optimized|original)\/(.+\/)([a-f0-9]{40})(?:_[^/]+)?(\.[^/?#]+)$/i
      );

      if (match) {
        const [, , sha1, extension] = match;
        return `upload://${this.base62Sha1(sha1)}${extension}`;
      }
    } catch {
      // Fall back to the hydrated upload URL if it cannot be converted.
    }

    return imageUrl;
  }

  @action
  pick(sticker) {
    const stickerAlt = `sticker:${sticker.title}`;
    const imageUrl = this.discourseUploadShortUrl(sticker.image);
    const markupComposer = `\n[wrap=sticker]![${sticker.title}|180x180](${imageUrl})[/wrap]\n`;
    const markupChatComposer = `\n![${stickerAlt}|180x180](${imageUrl})\n`;

    if (this.args.model?.customPickHandler) {
      this.args.model.customPickHandler(markupChatComposer);
    } else {
      getOwner(this)
        .lookup("service:app-events")
        .trigger("composer:insert-text", markupComposer);
    }

    this.args.closeModal();
  }

  <template>
    <DModal
      @title={{i18n (themePrefix "sticker.modal_title")}}
      @closeModal={{@closeModal}}
      id="sticker-modal"
      class="sticker-modal"
    >
      <:body>
        {{#if this.hasStickers}}
          {{#if this.showPackFilter}}
            <div class="sticker-pack-filter">
              <DButton
                @translatedLabel={{i18n (themePrefix "sticker.filter_all")}}
                aria-pressed={{if (eq this.selectedPack null) "true" "false"}}
                class="sticker-pack-filter-button {{if (eq this.selectedPack null) "btn-primary active" "btn-default"}}"
                {{on "click" (fn this.selectPack null)}}
              />          
              {{#each this.packOptions as |opt|}}
                <DButton
                  @translatedLabel={{opt.label}}
                  aria-pressed={{if (eq this.selectedPack opt.value) "true" "false"}}
                  class="sticker-pack-filter-button {{if (eq this.selectedPack opt.value) "btn-primary active" "btn-default"}}"
                  {{on "click" (fn this.selectPack opt.value)}}
                />
              {{/each}}
            </div>
          {{/if}}
          <div class="sticker-pack">
            {{#each this.stickerImages as |si|}}
              <span
                class="sticker-holder"
                {{on "click" (fn this.pick si)}}
              >
                {{#if
                  (and
                    this.site.desktopView
                    (not this.capabilities.touch)
                  )
                }}
                  <DTooltip>
                    <:trigger>
                      <img
                        class="sticker"
                        alt={{si.title}}
                        src={{si.image}}
                        markdownUrl={{si.image}}
                        width="100"
                        height="100"
                        loading="lazy"
                      />
                      <span class="emoji-alt">{{replaceEmoji si.emoji}}</span>
                    </:trigger>
                    <:content>
                      {{si.title}}
                    </:content>
                  </DTooltip>
                {{else}}
                  <img
                    class="sticker"
                    title={{si.title}}
                    alt={{si.title}}
                    src={{si.image}}
                    markdownUrl={{si.image}}
                    width="100"
                    height="100"
                    loading="lazy"
                  />
                  <span class="emoji-alt">{{replaceEmoji si.emoji}}</span>
                {{/if}}
              </span>
            {{/each}}
          </div>
        {{else}}
          <div class="sticker-empty-state">
            {{icon "note-sticky"}}
            <p>{{i18n (themePrefix "sticker.empty_state")}}</p>
          </div>
        {{/if}}
      </:body>
    </DModal>
  </template>
}
