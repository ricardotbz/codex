# Später selbst starten: vom Server zur Website

Diese Anleitung führst du später selbst aus. Durch das Ablegen oder Committen dieser Dateien startet kein Server und es entstehen keine Hosting-Kosten. Ein selbst gebuchter Server kann dagegen Kosten verursachen.

## Was du brauchst

- Einen eigenen Linux-Server, zum Beispiel eine VM mit Ubuntu 24.04 LTS, mindestens 2 CPUs und 2 GB RAM.
- SSH-Zugang und Administratorrechte auf diesem Server.
- Für den ersten Test nur die Server-IP; eine Domain ist erst für öffentliches HTTPS erforderlich.
- Die Projektdateien auf dem Server. **Lokale Codex-Commits sind noch nicht auf GitHub:** Vor dem Klonen müssen die Änderungen auf den gewünschten GitHub-Branch gepusht sein. Alternativ kannst du den Projektordner selbst übertragen.

Ein einzelner Server genügt für den Einstieg. Er ist trotz zweier Website-Replikate nicht ausfallsicher.

## 1. Mit dem Server verbinden

Auf deinem eigenen Computer ausführen; Benutzername und IP ersetzen:

```sh
ssh BENUTZER@SERVER_IP
```

Alle folgenden Befehle bis zum Browser-Test laufen **auf dem Server**. Nutze für dieses Beispiel eine frische VM ohne bestehende Docker-Projekte. Die Firewall des Anbieters soll SSH für deinen Zugriff und TCP 80 für den Website-Test zulassen. Für einen einzelnen Node müssen die internen Swarm-Ports nicht ins Internet geöffnet werden.

## 2. Docker installieren

Falls Docker bereits läuft, diesen Installationsschritt überspringen. Die folgenden Befehle sind für eine frische Ubuntu-24.04-VM ohne bestehende Docker-Installation gedacht. Bei einem anderen System oder vorhandenen Docker-Paketen die [offizielle Installationsanleitung](https://docs.docker.com/engine/install/ubuntu/) verwenden.

```sh
sudo apt-get update
sudo apt-get install -y ca-certificates curl git
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

. /etc/os-release
printf 'deb [arch=%s signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu %s stable\n' \
  "$(dpkg --print-architecture)" "$VERSION_CODENAME" | \
  sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable --now docker
sudo docker version
```

`docker version` muss Client **und** Server anzeigen. Die nächsten Docker-Befehle verwenden ebenfalls `sudo`; du musst deinen Benutzer dafür nicht zur Docker-Gruppe hinzufügen.

## 3. Repository holen

Erst nach dem Push der Projektdateien nach GitHub:

```sh
git clone https://github.com/ricardotbz/codex.git
cd codex
# Falls die Dateien auf einem anderen Branch liegen: git switch BRANCHNAME
cd projekte/docker-swarm
ls
```

Du solltest unter anderem `stack.yml`, `deploy.sh` und den Ordner `website` sehen. Bei einem privaten Repository benötigst du deinen eigenen GitHub-Zugriff auf dem Zielserver. Die Authentifizierung der Codex-Cloud wird nicht automatisch auf diesen Server übertragen.

## 4. Swarm einmalig anlegen

`SERVER_IP` durch die feste IP des Servers ersetzen. Bei mehreren Netzwerkkarten die für künftige Nodes erreichbare Adresse wählen:

```sh
sudo docker swarm init --advertise-addr SERVER_IP
sudo docker node update --label-add traefik=true "$(sudo docker info --format '{{.Swarm.NodeID}}')"
```

Falls der Server schon zu einem Swarm gehört, nicht erneut initialisieren. Dann auf dem bestehenden Manager weiterarbeiten. Den ausgegebenen Join-Token nicht in Git speichern.

## 5. Website deployen

Weiter im Ordner `projekte/docker-swarm`:

```sh
sudo env STACK_NAME=demo DOMAIN=demo.localhost bash deploy.sh http
sudo docker stack services demo
sudo docker stack ps demo --no-trunc
```

Wiederhole die Statusabfrage nach etwas Wartezeit. Erwartet: `demo_traefik` mit `1/1` und `demo_website` mit `2/2` Replikaten.

```sh
curl --fail --noproxy '*' -H 'Host: demo.localhost' http://127.0.0.1/
```

Die Antwort muss `Hello Swarm!` enthalten.

## 6. Von deinem Computer ansehen

Auf deinem eigenen Computer, mit der echten Server-IP:

```sh
curl --fail -H 'Host: demo.localhost' http://SERVER_IP/
```

Für den Browser ergänze lokal die Hosts-Datei um `SERVER_IP demo.localhost` und öffne anschließend `http://demo.localhost`. Unter Linux/macOS heißt die Datei `/etc/hosts`, unter Windows `C:\Windows\System32\drivers\etc\hosts`. Das Bearbeiten benötigt Administratorrechte. Eine Anfrage nur an die Server-IP kann 404 liefern, weil die Route den Hostnamen erwartet.

## 7. Eigene Inhalte und HTTPS

Bearbeite `website/index.html` und führe den HTTP-Deployment-Befehl aus Schritt 5 erneut aus. Das Skript verteilt die geänderte Website als neue Docker Config.

Für HTTPS: eigene Domain per DNS auf diesen Server zeigen lassen und zusätzlich TCP 443 freigeben. Danach mit deiner tatsächlichen Domain und E-Mail-Adresse ausführen:

```sh
sudo env STACK_NAME=demo DOMAIN=app.deine-domain.de ACME_EMAIL=du@deine-domain.de bash deploy.sh tls
```

Anschließend `https://DEINE_DOMAIN` im Browser öffnen. Weitere Details zu Zertifikaten, zusätzlichen Nodes und Firewall-Ports stehen in der [technischen Anleitung](README.md).

## 8. Wieder entfernen

Nur zum Entfernen dieses Beispiel-Stacks ausführen:

```sh
sudo docker stack rm demo
```

Das beendet die Website, löscht aber weder den Server noch das Zertifikatsvolume. Einen gemieteten Server musst du beim Anbieter separat kündigen/löschen, damit dessen Kosten enden.

## Wenn etwas nicht klappt

| Symptom | Was du prüfen solltest |
| --- | --- |
| Docker meldet fehlende Berechtigung | Die Docker-Befehle wie oben mit `sudo` ausführen. |
| Skript verlangt einen Manager | Schritt 4 prüfen und auf dem Manager ausführen. |
| Traefik bleibt bei `0/1` | Manager-Label, freie Ports 80/443 und `sudo docker stack ps demo --no-trunc` prüfen. |
| `error creating vxlan interface` | Host unterstützt das Overlay-Netz nicht; geeignete Linux-VM statt eingeschränktem Container verwenden. |
| Website liefert 404 | Den Hostnamen `demo.localhost` im Browser bzw. Host-Header verwenden. |
| Verbindung von außen schlägt fehl | Server-IP, Anbieter-Firewall und lokale Firewall prüfen. |
| HTTPS funktioniert nicht | Domain/DNS, Erreichbarkeit von 80/443 und `sudo docker service logs --tail 50 demo_traefik` prüfen. |

Die Anleitung ist vorbereitet; eine vollständige Swarm-Funktionsprüfung auf deinem Zielserver steht noch aus. Die Grenzen der bisherigen Prüfungen sind in [VALIDIERUNG.md](VALIDIERUNG.md) dokumentiert.
