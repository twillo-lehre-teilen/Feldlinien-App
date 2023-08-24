# Magnet

A tool that can be used to introduce students to the concept of magnetic flux.

## Development

This program is developed using the [Godot](https://godotengine.org/) engine, version 3.5.1.

While it may be possible to create native builds, the main target is HTML5. The reason for this is that this program should be easy to distribute and run on pretty much any device. To ensure maximum compatibility, this program uses Godot's GLES2 renderer.


## Deployment

Create an export preset for HTML5 and enable "VRAM Texture Compression" for both desktop and mobile. You should also tick the "Experimental Virtual Keyboard" checkbox. To make the app installable as a PWA, simply tick the "enabled" checkbox in the "Progressive Web App" section. Then, under "Resources", tell Godot to include the about text files by adding `locale/about_text/*.txt` to the filters to export non-resource files/folders. Using this preset, the project can be exported (without debug) to a folder and copied to a webserver.
One thing to keep in mind when hosting this tool is, that the webserver needs to be set up to correctly provide the mime type of Godot's 'wasm' file, which may not be the case out of the box.
For some reason safari on an ipad seems to be a bit more picky compared to other browsers, so make sure to test loading the page on an ipad at least once.

If you are using nginx, you may need to add this to your config:

```
types { application/wasm wasm; }
```

Check out the [official Godot docs](https://docs.godotengine.org/en/3.5/tutorials/export/exporting_for_web.html#serving-the-files) on serving an HTML5 export for more info

## Simple UI mode

There are two UI modes. You may switch to a simpler version of the UI without units by appending `?mode=simple` to the URL of a web build, or passing `--simpleui` as a command line argument to a native build.

## Translation

Translations work using the GNU gettext format, which is natively supported by Godot. 

See Godot's [documentation](https://docs.godotengine.org/en/stable/tutorials/i18n/localization_using_gettext.html#doc-localization-using-gettext) for using gettext to localise an application.

The translations live inside the 'locale' directory.

Adding or removing strings should only be done in the 'messages.pot' file. After that the language-specific files can be updated using msgmerge. (You may need to install the 'gettext' tools for this command to be available; on Debian this should be as simple as 'apt install gettext')

```bash
msgmerge --update --backup=none en.po messages.pot
msgmerge --update --backup=none de.po messages.pot
```

You can then edit the strings in those files respectively.

### Using the translations in Godot

Placing the 'msgid' of a message in anything that displays text should automatically fetch the correct message at runtime.

You can also ask the TranslationServer for messages at runtime:

```
TranslationServer.translate("MEASURED_POWER")
```

## License

Mangetic-Flux-Demo (c) by Simon Sievert

Mangetic-Flux-Demo is licensed under a
Creative Commons Attribution-ShareAlike 4.0 International License.

You should have received a copy of the license along with this
work. If not, see [http://creativecommons.org/licenses/by-sa/4.0/]().

Exempt from this is the Godot engine itself, which is MIT-licensed, and the following assets:

- 'assets/materials/brushed_metal': CC-BY [source](https://www.materialmaker.org/material?id=197)
- 'icon.png': [based on this](https://www.flaticon.com/de/kostenloses-icon/magnet_2477154)
- 'assets/images/gear.png': [source](https://www.flaticon.com/de/kostenloses-icon/gang_5693700)
- 'assets/images/language.svg': CC BY 4.0 [source](https://fontawesome.com/icons/language?s=solid&f=classic)
- 'assets/images/question.svg': CC BY 4.0 [source](https://fontawesome.com/icons/circle-question?s=regular&f=classic)
- 'assets/images/expand.svg': CC BY 4.0 [source](https://fontawesome.com/icons/expand?s=solid&f=classic)
- 'assets/images/compress.svg': CC BY 4.0 [source](https://fontawesome.com/icons/compress?s=solid&f=classic)
- 'assets/images/comments.svg': CC BY 4.0 [source](https://fontawesome.com/icons/comments?f=classic&s=regular)
- 'assets/fonts/roboto/': Apache-2.0, see 'assets/fonts/roboto/LICENSE.txt'

Additionally, the following addons are used:

- Antialiased Line2D: MIT [source](https://github.com/godot-extended-libraries/godot-antialiased-line2d)
