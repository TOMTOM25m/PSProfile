# Überarbeitetes Regelwerk für Skriptpipeline

## 1. Struktur der Skriptpipeline

* Die Pipeline besteht aus modularen Skriptbausteinen, die sequentiell oder bedingt ausgeführt werden.
* Jeder Baustein erfüllt eine klar definierte Funktion (z. B. Datenvorverarbeitung, Modelltraining, Evaluation).
* Bausteine sind als eigenständige `.py`-Dateien organisiert und über eine zentrale Steuerlogik verbunden.

## 2. Benennungskonventionen

* Skripte: `step_<nummer>_<funktion>.py` (z. B. `step_01_preprocessing.py`)
* Funktionen: `def <funktion>_<beschreibung>()`
* Variablen: `snake_case`, sprechende Namen

## 3. Logging und Monitoring

* Jeder Baustein schreibt strukturierte Logs in ein zentrales Log-Verzeichnis.
* Verwende das `logging`-Modul mit einheitlichem Format.
* Optional: Integration von `mlflow` oder `wandb` zur Nachverfolgung von Experimenten.

## 4. Fehlerbehandlung

* Verwende `try-except`-Blöcke mit aussagekräftigen Fehlermeldungen.
* Kritische Fehler sollen die Pipeline stoppen und ein Alert auslösen.

## 5. Konfigurierbarkeit

* Parameter werden über eine zentrale `config.yaml`-Datei gesteuert.
* Jeder Baustein liest nur die für ihn relevanten Parameter.

## 6. Wiederverwendbarkeit

* Gemeinsame Funktionen werden in einem `utils/`-Verzeichnis ausgelagert.
* Dokumentation und Typannotationen sind verpflichtend.

## 7. Tests und Validierung

* Jeder Baustein besitzt Unit-Tests (`tests/test_<baustein>.py`).
* Verwende `pytest` und `coverage` zur Testausführung und Abdeckung.

## 8. Versionskontrolle

* Alle Skripte und Konfigurationsdateien liegen unter Git-Versionierung.
* Commits sind klein, sprechend und thematisch fokussiert.

## 9. Dokumentation

* Jeder Baustein enthält eine Kopfzeile mit Beschreibung, Autor, Datum.
* Zusätzlich: zentrale `README.md` mit Überblick über die Pipeline.

## 10. Deployment

* Die Pipeline kann lokal oder in der Cloud (z. B. AWS, GCP) ausgeführt werden.
* Verwende `Docker` zur Containerisierung und `Makefile` zur Automatisierung.
