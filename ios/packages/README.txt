KpOS modular packages
=====================

Install a package by making a folder here:

  ios/packages/<package-id>/

Each package needs a package.lua or manifest.lua file that returns a table:

  return {
      id = "hello",
      name = "Hello World",
      version = "1.0.0",
      description = "Example KpOS package",
      entry = "main.lua",
      order = 20
  }

If entry points to a file inside the package folder, KpOS runs it from that
package folder so local helper files can be used easily.

If entry points to an existing KpOS path like ios/programs/MyApp/main.lua,
KpOS runs that path directly. This is useful for wrapping older apps as
packages without moving their files.

Optional fields:
- author = "name"
- hidden = true      -- hide from the Programs menu, still usable by code
- disabled = true    -- disable loading entirely
- order = number     -- lower numbers show earlier in the menu
