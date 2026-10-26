# Validierung in der Codex-Cloud

Geprüft am 26. Oktober 2026 mit Docker Engine 28.4.0.

Erfolgreich:

- Beide offiziellen Images mit Docker heruntergeladen und ihre Digests in der Vorlage festgelegt.
- HTTP-Stack und Kombination aus Basis- und TLS-Stack mit `docker stack config` aufgelöst. Port 80/443 und Docker-Socket-Mount bleiben beim Zusammenführen erhalten.
- Shell-Syntax von `deploy.sh` geprüft.
- Temporären Single-Node-Swarm initialisiert, Manager gelabelt und das Deployment-Skript ausgeführt. Docker akzeptiert Services, Overlay-Netz und Website-Config.
- Nginx separat gestartet und die tatsächliche Website per HTTP abgerufen: Status 200 und erwarteter Inhalt `Hello Swarm!`. Die kopierte Datei bekam dabei dieselben Leserechte wie die Docker Config (0444).
- Traefik separat mit den HTTP-Startargumenten und Swarm-Provider gestartet; `/ping` über `traefik healthcheck --ping` erfolgreich geprüft. Für den lokalen Check wurden die in der Cloud injizierten HTTP-Proxys mittels `NO_PROXY=*` im Prüfprozess umgangen.
- Temporäre Services, Testcontainer und Test-Swarm wieder entfernt.

Nicht erfolgreich ausführbar:

- Die Swarm-Tasks können hier dem Overlay-Netz nicht beitreten: `error creating vxlan interface: operation not supported`. Das ist eine Kernel-/Runtime-Grenze dieser Cloud-Maschine. Deshalb sind vollständiges Routing über Swarm, Lastverteilung, Rolling Updates und Multi-Node-Betrieb hier **nicht funktional bestätigt**.
- HTTPS-Konfiguration syntaktisch geprüft, aber keine echten Zertifikate angefordert. Dafür werden eine eigene Domain und ein öffentlich erreichbarer Zielserver benötigt.

Die Vorlage ist zum Prüfen und Weiterentwickeln vorbereitet. Vor echtem Betrieb auf geeigneten Linux-Servern die Funktionsprüfungen aus der README ausführen.
