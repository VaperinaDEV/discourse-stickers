export default function migrate(settings) {
  if (!settings.has("sticker_images")) {
    return settings;
  }

  const rawValue = settings.get("sticker_images");

  let stickers;

  try {
    stickers = Array.isArray(rawValue) ? rawValue : JSON.parse(rawValue);
  } catch {
    // Never destroy the existing setting if the legacy value is malformed.
    return settings;
  }

  if (!Array.isArray(stickers)) {
    return settings;
  }

  const migratedStickers = stickers
    .filter((sticker) => sticker && typeof sticker === "object")
    .map((sticker, index) => {
      let image;

      /*
       * The new `image` property is an upload. Prefer the legacy previewUrl,
       * because it contains the SHA1 needed to resolve the existing Discourse
       * Upload record.
       *
       * Supported legacy preview URL forms:
       *   /optimized/.../<sha1>_...ext
       *   /original/.../<sha1>ext
       *
       * If the URL is already an original upload URL, keep it unchanged.
       * If it is optimized, convert it to the corresponding original URL.
       */
      if (typeof sticker.previewUrl === "string" && sticker.previewUrl) {
        const previewUrl = sticker.previewUrl;

        if (/\/original\/.+\/[a-f0-9]{40}(?:_[^/?#]+)?\.[^/?#]+(?:[?#].*)?$/i.test(previewUrl)) {
          image = previewUrl;
        } else {
          const match = previewUrl.match(
            /^(.*\/)optimized\/(.+\/)([a-f0-9]{40})(?:_[^/?#]+)?(\.[^/?#]+)(?:[?#].*)?$/i
          );

          if (match) {
            const [, base, path, sha1, extension] = match;
            image = `${base}original/${path}${sha1}${extension}`;
          }
        }
      }

      if (!image) {
        return null;
      }

      const migrated = {
        title:
          typeof sticker.title === "string" && sticker.title.trim()
            ? sticker.title.trim()
            : `Sticker ${index + 1}`,
        image,
      };

      if (typeof sticker.pack === "string" && sticker.pack) {
        migrated.pack = sticker.pack;
      }

      if (typeof sticker.emoji === "string" && sticker.emoji) {
        migrated.emoji = sticker.emoji;
      }

      if (Array.isArray(sticker.categories)) {
        migrated.categories = sticker.categories;
      }

      if (typeof sticker.chat_hide_from_private === "boolean") {
        migrated.chat_hide_from_private = sticker.chat_hide_from_private;
      }

      if (typeof sticker.chat_channels === "string" && sticker.chat_channels) {
        migrated.chat_channels = sticker.chat_channels;
      }

      return migrated;
    })
    .filter(Boolean);

  settings.set("sticker_images", migratedStickers);

  return settings;
}
