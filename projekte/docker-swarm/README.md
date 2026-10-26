# Docker Swarm mit Traefik

Vorlage für eigene Linux-Server: Traefik nimmt HTTP/HTTPS entgegen und verteilt Anfragen an zwei Nginx-Replikate mit unserer Beispielwebsite. Hier wird nichts automatisch auf fremden Servern installiert oder veröffentlicht.

**Für den ersten eigenen Versuch:** [Schritt-für-Schritt-Anleitung](SCHRITT-FUER-SCHRITT.md) mit Serverzugang, Docker-Installation und den Befehlen bis zur Website.

```text
Browser → Traefik auf einem ausgewählten Manager → Overlay-Netz → Website (2 Replikate)
```

## Inhalt

- `stack.yml`: HTTP-Stack mit Healthchecks, Ressourcenlimits und Update-Rollback
- `stack.tls.yml`: zusätzliche HTTPS-Konfiguration mit Let's Encrypt und HTTP→HTTPS-Weiterleitung
- `deploy.sh`: prüft Voraussetzungen und deployt auf dem aktuellen Swarm
- `.env.example`: Vorlage für eigene Einstellungen; `.env` ist von Git ausgeschlossen
- `website/index.html`: Beispielwebsite, verteilt als Docker Config statt als lokaler Bind-Mount
- `VALIDIERUNG.md`: tatsächlich ausgeführte Prüfungen und Grenzen der Cloud-Umgebung

## 1. Server vorbereiten

Ein Linux-Server reicht zum Lernen. Empfehlung zum Einstieg: mindestens 2 CPUs und 2 GB RAM. Docker Engine muss auf allen Nodes laufen; diese Vorlage wurde mit Docker Engine 28.4.0 geprüft. Installationsanleitung: <https://docs.docker.com/engine/install/>. Du brauchst Zugriff auf Docker und Bash sowie `sha256sum` auf dem Manager. Das Compose-Plugin wird nicht benötigt.

Der Linux-Kernel muss Overlay/VXLAN und für das verschlüsselte Overlay IPsec unterstützen. Docker in eingeschränkten Containern kann daran scheitern. Alle Nodes brauchen Zugriff auf Docker Hub zum Laden der Images.

Firewall-Regeln:

| Verbindung | Ports | Erlaubte Quelle |
| --- | --- | --- |
| Website auf dem Traefik-Manager | TCP 80, für HTTPS zusätzlich 443 | gewünschte Clients / Internet |
| Swarm-Verwaltung zum Manager | TCP 2377 | ausschließlich andere Swarm-Nodes |
| Node-Kommunikation | TCP und UDP 7946 | ausschließlich andere Swarm-Nodes |
| Overlay | UDP 4789 und IP-Protokoll 50 (ESP) | ausschließlich andere Swarm-Nodes |

SSH nur für deine Administration erlauben. Swarm-Ports und Docker-API nicht öffentlich freigeben.

Auf dem ersten Server einmalig initialisieren. `MANAGER_IP` durch dessen feste, für die anderen Nodes erreichbare IP ersetzen:

```sh
docker swarm init --advertise-addr MANAGER_IP
docker node update --label-add traefik=true "$(docker info --format '{{.Swarm.NodeID}}')"
```

Die Initialisierung gibt einen Join-Befehl aus. Diesen bei Bedarf auf weiteren Servern ausführen. Join-Tokens vertraulich behandeln und nicht committen. Später erneut anzeigen: `docker swarm join-token worker`.

Genau **ein Manager** soll das Label `traefik=true` tragen. Dieser ist der Eingangspunkt; deine Domain muss auf ihn zeigen. Website-Replikate können auf beliebigen aktiven Nodes laufen. Zwei Replikate auf demselben Server bieten keine Absicherung gegen Serverausfall. Für ein hochverfügbares Manager-Quorum sind typischerweise drei Manager nötig; der einzelne Traefik-Eingangspunkt dieser Vorlage bleibt trotzdem ein Ausfallpunkt.

## 2. HTTP-Test deployen

Repository auf dem Manager bereitstellen und in diesen Projektordner wechseln. Für spätere Codex-Aufgaben den vorhandenen Checkout verwenden; kein zusätzliches Git-Worktree nötig.

```sh
cd projekte/docker-swarm
cp .env.example .env
# .env nach Bedarf bearbeiten. Für den ersten HTTP-Test sind die Vorgaben geeignet.
set -a
. ./.env
set +a
bash deploy.sh http
```

Das Skript liest `.env` nicht automatisch; die obigen Befehle exportieren die Einstellungen. Verwende nur eine selbst erstellte, vertrauenswürdige `.env`, da das Einlesen Shell-Code ausführt. Starte für jedes Projekt mit einem eigenen Stack-Namen. Die Beispiel-Routernamen sind für einen einzelnen Stack vorgesehen; bei mehreren Stacks am gleichen Traefik müssen Router-/Service-Namen eindeutig sein. Dieser Stack betreibt seinen eigenen Traefik und belegt dafür die Host-Ports 80/443.

Auf dem Traefik-Manager prüfen:

```sh
docker stack services "$STACK_NAME"
docker stack ps "$STACK_NAME" --no-trunc
docker service logs --tail 50 "${STACK_NAME}_traefik"
curl --fail --noproxy '*' -H "Host: $DOMAIN" http://127.0.0.1/
```

Warte, bis Traefik `1/1` und die Website `2/2` Replikate melden. Der HTTP-Aufruf muss `Hello Swarm!` enthalten. Ein erfolgreich beendetes Deployment-Kommando allein bestätigt noch keine laufenden Dienste.

Vom eigenen Computer: `curl --fail -H 'Host: demo.localhost' http://SERVER_IP/`. Für den Browser kannst du `SERVER_IP demo.localhost` in der lokalen Hosts-Datei hinterlegen. Ohne passenden Hostnamen liefert Traefik erwartungsgemäß 404.

## 3. Optional: öffentliches HTTPS

Voraussetzungen: eigene öffentliche Domain mit passendem A-Record (und nur dann AAAA, wenn IPv6 tatsächlich funktioniert), öffentlich erreichbare Ports 80 und 443 sowie ausgehender HTTPS-Zugriff auf Let's Encrypt. Die Domain muss auf den gelabelten Traefik-Manager zeigen. HTTP ist zum Nachweis der Domaininhaberschaft auch bei HTTPS nötig.

In `.env` eine echte Domain und E-Mail-Adresse setzen und die Einstellungen erneut exportieren:

```sh
export DOMAIN=app.deine-domain.de
export ACME_EMAIL=du@deine-domain.de
bash deploy.sh tls
```

`deine-domain.de` und die E-Mail sind Platzhalter. Danach `https://app.deine-domain.de` mit deiner tatsächlichen Domain aufrufen und mit `curl --fail https://DEINE_DOMAIN/` prüfen. Zertifikatsausstellung kann etwas dauern; bei Fehlern die Traefik-Logs prüfen. Kein `curl -k` verwenden.

Zertifikate liegen im lokalen Volume `${STACK_NAME}_certificates` auf dem Traefik-Manager. Dieses vertraulich sichern. Bei Wechsel des Managers wandert es nicht automatisch mit. Traefik wegen dieser lokalen Zertifikatsverwaltung nicht einfach auf mehrere Replikate skalieren. Das Dashboard wird nicht veröffentlicht. Für spätere reine HTTP-Deployments wieder `bash deploy.sh http` verwenden.

## Aktualisieren und verwalten

Nach Änderungen an `website/index.html` das passende Deployment erneut ausführen. Das Skript berechnet einen Inhalts-Hash, damit eine neue, unveränderliche Docker Config entsteht. Vorherige Configs können zurückbleiben; nur nach Prüfung entfernen, wenn kein Service sie mehr verwendet.

```sh
docker service logs --tail 50 "${STACK_NAME}_website"
docker service scale "${STACK_NAME}_website=3"
# Der nächste Deploy setzt wieder die zwei Replikate aus stack.yml.
```

Images sind über SHA-256-Digests festgelegt, damit die Vorlage reproduzierbar bleibt. Für Sicherheitsupdates neue offizielle Images prüfen und Tag plus Digest in `stack.yml` aktualisieren. Ein erneuter Deploy mit demselben Digest aktualisiert das Image nicht.

## Entfernen

Nur den gewünschten Stack entfernen:

```sh
docker stack rm "$STACK_NAME"
```

Dies beendet seine Dienste und entfernt seine Netzwerke/Configs asynchron. Das Zertifikatsvolume bleibt erhalten. Einen bestehenden Swarm nicht zum normalen Stoppen verlassen oder neu initialisieren.

## Betriebsgrenzen

Die Vorlage enthält weder automatisches Server-Provisioning noch Datenbank, Backups oder Monitoring. Zugangsdaten später über Docker Secrets einbinden, nicht in Stack-Dateien oder Git ablegen. Der Docker-Socket wird nur lesbar gemountet, vermittelt Traefik aber dennoch mächtigen Zugriff auf Docker; `:ro` ist keine Zugriffskontrolle für die Docker-API. Auf gemeinsam genutzten oder untrusted Hosts ist eine eingeschränkte API-Anbindung gesondert zu planen.
