# Finddon 0.4.1 (WoW Forever)

NPC-Suche für World of Warcraft: Forever (Client "Camelot", Interface 16001): der nächste Lehrer, Händler, Reparatur,
Flugmeister, Gastwirt, die nächste Bank, das nächste Auktionshaus oder ein Rare, mit Pfeil und Kartenpin dorthin.

## Installation
Ordner `Finddon` in den AddOns-Ordner des Clients kopieren (`...\Interface\AddOns\`). Finddon braucht DonMap (Pfeil und Pins).

## Funktionen
- **Suche nach Rolle:** Klassenlehrer (eigene Klasse zuerst), Berufslehrer, Waffenmeister, Reit- und Tierlehrer, Händler,
  Reparatur, Reagenzien, Essen und Trinken, Munition, Gastwirt, Bank, Auktionshaus, Flugmeister, Stallmeister, Rares.
- **Suche nach Name oder Titel:** ein Teil des Namens oder ein Titel wie "Weaponsmith".
- **Suche nach Waren (0.4.0):** Warenname im Suchfeld ("thread", "apple") oder eine Warengruppe links (Getränke, Fleisch,
  Fisch, Obst, Brot, Käse, Pilze, Handwerkswaren, Rezepte, Taschen): die nächsten Händler, die das verkaufen.
- **Der nächste zuerst:** Treffer nach Entfernung sortiert, mit Zone und Entfernung; eigene Fraktion und neutral.
- **Bilder:** 3D-Modell des NPCs in jeder Zeile und groß unter den Rollen (Option). **Kochfeuer** je Zone als eigene Rolle.
- **Zur Karte:** Knopf "Karte" in jeder Trefferzeile (oder `/fd map <Text>`) öffnet die Weltkarte der Zone.
- **Pfeil und Pin:** Klick auf einen Treffer setzt DonMaps Pfeil und einen Pin auf Welt- und Minikarte. Rechtsklick,
  `/fd clear` oder die Ankunft räumen auf.
- Rollen und Oberfläche in neun Sprachen, NPC-Namen in dieser Fassung englisch. Seit 0.3.0 auch Quest-NPCs und alle ansprechbaren NPCs (rund 3.500).

## Befehle
- `/fd` (oder `/finddon`) Fenster zeigen oder ausblenden
- `/fd <Text>` nach Rolle, Name, Titel oder Ware suchen (`/fd repair`, `/fd thread`)
- `/fd go <Text>` Pfeil zum nächsten Treffer (`/fd go innkeeper`)
- `/fd clear` Pfeil und Pin entfernen
- `/fd options`, `/fd button`, `/fd help`

## Datenquellen und Lizenzen
Code MIT (LICENSE.txt). NPC- und Warendaten (Data/NPCs.lua, Data/Goods.lua) aus CMaNGOS classic-db (GPL v3) und Data from ForeverDB.net
(https://foreverdb.net), GPL v3; siehe THIRD_PARTY_LICENSES.txt und Data/NPCs-LICENSE-GPLv3.txt.
