# pfQuest-turtle

Turtle WoW and RavenCraft quest data and interface additions for the regular pfQuest addon. This extension requires the matching [regular pfQuest fork](https://github.com/rivi-s/pfQuest). It includes custom quest corrections, map additions, nameplate objectives, party progress, and loot panels.

## Choose an edition

| Edition | Install | Requirements |
| --- | --- | --- |
| Regular pfQuest | [pfQuest](https://github.com/rivi-s/pfQuest) | Loads its database in Lua; no HearthDB DLL required. |
| Regular Turtle/Raven content | [pfQuest-turtle](https://github.com/rivi-s/pfQuest-turtle) alongside regular pfQuest | Both regular addon folders. |
| HDB Vanilla | [pfQuest-HDB-Install](https://github.com/rivi-s/pfQuest-HDB-Install) | HearthDB client component; English database included. |
| HDB Turtle/Raven content | [pfQuest-turtle-HDB-Install](https://github.com/rivi-s/pfQuest-turtle-HDB-Install) | HearthDB client component; both addon folders and combined English database included. |

Install one edition at a time. Both editions use the folder names `pfQuest` and `pfQuest-turtle`; mixing regular and HDB folders can leave the wrong database or code loaded.

## Install or update

1. Close the game and [install/update regular pfQuest](https://github.com/rivi-s/pfQuest#install-or-update-the-regular-edition).
2. [Download this extension](https://github.com/rivi-s/pfQuest-turtle/archive/refs/heads/master.zip), extract it, and rename `pfQuest-turtle-master` to `pfQuest-turtle`.
3. Replace `Interface/AddOns/pfQuest-turtle` with that folder. Preserve your `WTF` character settings.
4. Restart and enable both addons. Open `/db config` to review tracking and quest filters.

```text
Interface/AddOns/
  pfQuest/
    pfQuest.toc
  pfQuest-turtle/
    pfQuest-turtle.toc
```

Use English (`enUS`) for the maintained custom-content matching. Other translation files may be present, but custom-content coverage can vary. This regular edition requires no HearthDB DLL.

## Help and content corrections

Missing markers can come from filters, completed quest history, prerequisites, map coordinates, or missing data. Follow the [troubleshooting steps and report checklist](https://github.com/rivi-s/pfQuest/blob/master/SUPPORT.md) before [opening a Turtle issue](https://github.com/rivi-s/pfQuest-turtle/issues).

Include whether the problem affects an offer, objective, or turn-in, plus character level/faction, quest ID, map name, and coordinates. Confirmed player reports are welcome; they are reviewed as maintenance time allows.

## Project status

Maintenance focuses on occasional database corrections and reported bugs. Updates have no fixed schedule. Compatibility with Raven's Classic Era 1.14 client is unverified; work on that port is paused. These packages target the existing 1.12 client.

## Credits

Original pfQuest authors: Shagu and txtsd. Original Turtle extension: Shagu, with contributors listed in the addon TOC. Rivi maintains these forks and contributes features, database corrections, and HearthDB integration.
