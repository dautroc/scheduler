# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = "1.0"

# Add additional assets to the asset load path.
# Rails.application.config.assets.paths << Emoji.images_path

# The Tailwind build output lives at app/assets/builds/tailwind.css. Propshaft
# discovers files on the load path, but listing it here guarantees the asset is
# precompiled for production (where only precompile-listed assets are emitted).
# The tailwindcss-rails gem augments `assets:precompile` to run the build first.
Rails.application.config.assets.precompile << "tailwind.css"
