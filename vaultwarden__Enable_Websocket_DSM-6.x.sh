#!/bin/bash
##==============================================================================================
##                                                                                            ##
##                      Script vaultwarden__Enable_Websocket-DSM_6.x.sh                       ##
##                                                                                            ##
##          Source : https://gist.github.com/nstanke/3949ae1c4706854d8f166d1fb3dadc81         ##
##                                                                                            ##
##==============================================================================================
##                                                                                            ##
##   Ce script pemet de router ce qui ne peut pas être fait avec le reverse-proxy             ##
##   de DSM (Synology) pour faire fonctionner les notifications Websocket                     ##
##   Doc. vaultwarden :                                                                       ##
##        Route the /notifications/hub endpoint to the WebSocket server, by default           ##
##        at port 3012, making sure to pass the Connection and Upgrade headers.               ##
##        (Note the port can be changed with WEBSOCKET_PORT variable)                         ##
##        https://github.com/dani-garcia/vaultwarden/wiki/Enabling-WebSocket-notifications    ##
##                                                                                            ##
##==============================================================================================
##                                                                                            ##
##                             Principe de Tâche planifier à créer                            ##
##                                                                                            ##
## Il faut lancer régulièrement le script car toutes modifications faites dans l'interface    ##
## graphique du Reverse-Proxy de DSM va modifier le fichier de configuration. Il en va de     ##
## même lorsque le NAS redémarre.                                                             ##
##                                                                                            ##
##==============================================================================================
##                                                                                            ##
##        /!\    Il faut modifier l'adresse IP en ligne 79 et 85 par l'IP du NAS    /!\       ##
##                                                                                            ##
##==============================================================================================
##                                                                                            ##
## Paramètres de lancement du script :                                                        ##
## bash /volume1/docker/bitwarden/enable_ws.sh vault.example.com 5555 5556                    ##
##                                                                                            ##
## -- vault.example.com = Nom de domaine de vaultwarden (celui du Reverse Proxy de DSM)      ##
## -- 5555 = Port exposé ROCKET_PORT par Docker (Identique à celui du Reverse Proxy de DSM)   ##
## -- 5556 = Port exposé WEBSOCKET_PORT par Docker                                            ##
##                                                                                            ##
##==============================================================================================

LOC_DIR="/etc/nginx"
part1=0
part2=0

echo -e "\n$(date "+%R:%S - ") Script vaultwarden__Enable_Websocket.sh pour activer les Notifications Websockets"

f_affiche_parametre() {
    echo "          bash /volume1/docker/_Scripts-DOCKER/vaultwarden__Enable_Websocket.sh vault.example.com 5555 5556 "
    echo "                           -- vault.example.com = Nom de domaine de vaultwarden (celui du Reverse Proxy de DSM) "
    echo "                           -- 5555 = Port exposé ROCKET_PORT par Docker (Identique à celui du Reverse Proxy de DSM)"
    echo "                           -- 5556 = Port exposé WEBSOCKET_PORT par Docker"
}

if [ ! $# -eq 3 ]; then
    if [ $# -eq 0 ]; then
        # Aucun paramètre n'a été fourni. On va afficher la liste de ce qui peut être utilisé.
        echo "$(date "+%R:%S - ") Aucun paramètre fourni ! Revoir l'appel du script :"
        f_affiche_parametre
    else
        echo "$(date "+%R:%S - ") Le nombre de paramètres fournis n'est pas correct ! Revoir l'appel du script :"
        f_affiche_parametre
    fi
    echo -e "$(date "+%R:%S - ") ECHEC de lancement du script !!!!!!!!!\n"
    exit 1
fi

echo "$(date "+%R:%S - ") Exécution des commandes..."


#############################################################################################################
## Début de la partie de création/modification de fichiers
##
if [ -f $LOC_DIR/ws.locations ]; then
  rm /etc/nginx/ws.locations
  part1=1
fi
echo """
location /notifications/hub {
    proxy_pass http://192.168.2.200:$3;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection \"upgrade\";
}

location /notifications/hub/negotiate {
    proxy_pass http://192.168.2.200:$2;
}
""" >> $LOC_DIR/ws.locations


if ! grep -q "ws.locations" /etc/nginx/app.d/server.ReverseProxy.conf; then
    sed -i "/$1;/ a\ include $LOC_DIR/ws.locations;" /etc/nginx/app.d/server.ReverseProxy.conf
    if nginx -t 2>/dev/null; then synoservicecfg --reload nginx; else exit 1; fi

    part2=1     # Variable pour indiquer que cette partie a été exécutée
fi
##
## Fin de la partie de création/modification de fichiers
#############################################################################################################

if [ $part1 -eq 1 ]; then
  echo "$(date "+%R:%S - ")    -- Le fichier $LOC_DIR/ws.locations existait déjà, il a été supprimé puis recréé."
else
  echo "$(date "+%R:%S - ")    -- Le fichier $LOC_DIR/ws.locations n'existait pas, il a été créé."
fi
if [ $part2 -eq 1 ]; then
  echo "$(date "+%R:%S - ")    -- !!!!!! --->  La modification dans le fichier /etc/nginx/app.d/server.ReverseProxy.conf n'existait pas. Elle a été écrite."
  echo "$(date "+%R:%S - ")    -- !!!!!! --->  Le fichier /etc/nginx/app.d/server.ReverseProxy.conf a du être réinitialisé après un reboot ou lors d'une modification du reverse-proxy dans DSM."
else
  echo "$(date "+%R:%S - ")    -- La modification du fichier /etc/nginx/app.d/server.ReverseProxy.conf a déjà été effectuée lors d'une précédente exécution. Aucune modification n'est donc nécessaire."
fi

echo "$(date "+%R:%S - ") Script vaultwarden__Enable_Websocket.sh terminé"

exit